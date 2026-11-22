import 'package:flutter/material.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/features/strizh/strizh_api.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum _Step { choose, email, code }

/// Экран «вошёл — подключился» для Strizh. Показывается, когда активного профиля нет.
/// Free: одна кнопка. Premium: email -> код. После успеха подставляет подписку /sub/{sub_id}
/// как активный профиль и подключает.
class StrizhOnboarding extends ConsumerStatefulWidget {
  const StrizhOnboarding({super.key});

  @override
  ConsumerState<StrizhOnboarding> createState() => _StrizhOnboardingState();
}

class _StrizhOnboardingState extends ConsumerState<StrizhOnboarding> {
  final _api = StrizhApi();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  _Step _step = _Step.choose;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _setBusy(bool v, [String? err]) {
    if (!mounted) return;
    setState(() {
      _loading = v;
      _error = err;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    _setBusy(true);
    try {
      await action();
    } on StrizhException catch (e) {
      _setBusy(false, e.message);
      return;
    } catch (_) {
      _setBusy(false, 'Ошибка сети. Попробуй ещё раз.');
      return;
    }
    _setBusy(false);
  }

  /// Подставляет подписку /sub/{subId} как активный профиль и подключает.
  Future<void> _activate(String subId, String name) async {
    await ref.read(addProfileNotifierProvider.notifier).addManual(
          url: StrizhApi.subUrl(subId),
          userOverride: UserOverride(name: name),
        );
    if (ref.read(addProfileNotifierProvider).hasError) {
      throw StrizhException('Не удалось применить подписку. Попробуй ещё раз.');
    }
    // авто-connect после добавления активного профиля
    try {
      await ref.read(connectionNotifierProvider.notifier).toggleConnection();
    } catch (_) {/* если авто-коннект не удался — покажется большая кнопка подключения */}
  }

  Future<void> _free() => _run(() async {
        final subId = await _api.freeConnect();
        await _activate(subId, 'Strizh Free');
      });

  Future<void> _sendCode() => _run(() async {
        final email = _emailCtrl.text.trim();
        if (!email.contains('@') || !email.contains('.')) {
          throw StrizhException('Введи корректный email');
        }
        await _api.requestCode(email);
        if (mounted) setState(() => _step = _Step.code);
      });

  Future<void> _verify() => _run(() async {
        final email = _emailCtrl.text.trim();
        final code = _codeCtrl.text.trim();
        if (code.length < 4) throw StrizhException('Введи код из письма');
        final jwt = await _api.verify(email, code);
        final subId = await _api.premiumSubId(jwt);
        if (subId == null) {
          throw StrizhException('Нет активной подписки. Оформи Premium на strizhvpn.com');
        }
        await _activate(subId, 'Strizh VPN');
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flight_takeoff_rounded, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 14),
              Text('Strizh VPN', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Войди и подключайся — ключи не нужны',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 26),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13)),
                ),
                const SizedBox(height: 14),
              ],
              if (_loading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
              if (!_loading) ..._body(theme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(ThemeData theme) {
    switch (_step) {
      case _Step.choose:
        return [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _free,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text('Подключиться бесплатно'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _step = _Step.email),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text('У меня Premium — войти по email'),
            ),
          ),
          const SizedBox(height: 12),
          Text('Free — 30 минут в день, без карты и регистрации',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ];
      case _Step.email:
        return [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _sendCode,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text('Отправить код'),
            ),
          ),
          TextButton(onPressed: () => setState(() => _step = _Step.choose), child: const Text('Назад')),
        ];
      case _Step.code:
        return [
          Text('Код отправлен на ${_emailCtrl.text.trim()}',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(hintText: '000000', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _verify,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text('Войти и подключиться'),
            ),
          ),
          TextButton(onPressed: () => setState(() => _step = _Step.email), child: const Text('Изменить email')),
        ];
    }
  }
}
