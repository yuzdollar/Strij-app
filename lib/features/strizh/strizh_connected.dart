import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/active/ip_widget.dart';
import 'package:hiddify/features/proxy/keep_top/country_names.dart';
import 'package:hiddify/features/proxy/model/proxy_entity.dart';
import 'package:hiddify/features/strizh/strizh_api.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Короткие русские названия стран для частых VPN-локаций (фолбэк — английское countryNames, затем код).
const _ruCountry = <String, String>{
  'US': 'США',
  'GB': 'Великобритания',
  'DE': 'Германия',
  'NL': 'Нидерланды',
  'FR': 'Франция',
  'FI': 'Финляндия',
  'SE': 'Швеция',
  'PL': 'Польша',
  'TR': 'Турция',
  'JP': 'Япония',
  'SG': 'Сингапур',
  'HK': 'Гонконг',
  'CA': 'Канада',
  'CH': 'Швейцария',
  'AT': 'Австрия',
  'LT': 'Литва',
  'LV': 'Латвия',
  'EE': 'Эстония',
  'CZ': 'Чехия',
  'RO': 'Румыния',
  'BG': 'Болгария',
  'UA': 'Украина',
  'KZ': 'Казахстан',
  'RU': 'Россия',
  'AE': 'ОАЭ',
  'ES': 'Испания',
  'IT': 'Италия',
};

/// Экран «подключено» в стиле макета (референс = телефон-превью на лендинге strizhvpn.com):
/// большая кнопка-стриж + пинг + чип локации + полоса трафика + «Перейти на Premium».
/// Заменяет Hiddify-плитку профиля ProfileTile на главном. Показывается при активном профиле.
class StrizhConnectedBody extends ConsumerWidget {
  const StrizhConnectedBody({super.key, required this.profile});

  final ProfileEntity profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final subInfo = switch (profile) {
      RemoteProfileEntity(:final subInfo) => subInfo,
      _ => null,
    };
    // free = бесплатный профиль (имя «Strizh Free») или без инфо о трафике.
    final isFree = subInfo == null || profile.name.toLowerCase().contains('free');

    final activeProxy = ref.watch(activeProxyNotifierProvider).valueOrNull;
    // Страна = страна ВЫБРАННОГО сервера (как в списке прокси), чтобы чип и список совпадали.
    // Фолбэк — гео выходного IP (ipInfoNotifier). Пока не определено — имя сервера с глобусом.
    final proxyCc = activeProxy?.ipinfo.countryCode ?? '';
    final exitCc = ref.watch(ipInfoNotifierProvider).valueOrNull?.countryCode ?? '';
    final cc = (proxyCc.isNotEmpty ? proxyCc : exitCc).toUpperCase();
    final locationName = cc.isNotEmpty
        ? (_ruCountry[cc] ?? countryNames[cc] ?? (activeProxy?.name ?? profile.name))
        : ((activeProxy?.name.isNotEmpty ?? false) ? activeProxy!.name : profile.name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 46),
      child: Column(
        children: [
          const Spacer(flex: 3),
          // Кольцо-подключение как на макете (тонкое синее кольцо + птица), плоское.
          const _ConnectRing(),
          const Gap(12),
          const ActiveProxyDelayIndicator(),
          const Spacer(flex: 3),
          _LocationChip(countryCode: cc, name: locationName, onTap: () => context.goNamed('proxies')),
          const Gap(14),
          // Free — карточка «Бесплатно · 2 Мбит/с» (по макету, без «Unlimited»).
          // Premium — реальная полоса трафика подписки.
          if (isFree)
            _FreeQuota(theme: theme)
          else
            _TrafficBar(subInfo),
          const Gap(18),
          if (isFree) _PremiumButton(theme: theme),
        ],
      ),
    );
  }
}

/// Кольцо-подключение (по макету): тонкое синее кольцо, плоский тёмный центр, птица внутри.
/// Тап — вкл/выкл. Под кольцом — статус (Подключено / Подключение… / Подключить).
class _ConnectRing extends ConsumerWidget {
  const _ConnectRing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(connectionNotifierProvider).valueOrNull;
    final connected = status is Connected || status is NoAvailableProxies || status is HotReloading;
    final busy = status is Connecting || status is Waiting || status is Disconnecting;

    final ringColor = connected
        ? AppTheme.brandBlue
        : busy
        ? AppTheme.brandBlue.withValues(alpha: .6)
        : theme.colorScheme.outlineVariant;
    final birdColor = (connected || busy) ? AppTheme.brandBlue : theme.colorScheme.onSurfaceVariant;
    final t = ref.watch(translationsProvider).requireValue;
    final label = connected
        ? t.connection.connected
        : busy
        ? t.connection.connecting
        : t.strizh.connect;

    return Column(
      children: [
        GestureDetector(
          onTap: () => ref.read(connectionNotifierProvider.notifier).toggleConnection(),
          child: SizedBox.square(
            dimension: 168,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .22),
                    border: Border.all(color: ringColor, width: 4),
                  ),
                ),
                if (busy)
                  const SizedBox.square(
                    dimension: 168,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.brandBlue),
                  ),
                Padding(
                  padding: const EdgeInsets.all(54),
                  child: Assets.images.logo.svg(colorFilter: ColorFilter.mode(birdColor, BlendMode.srcIn)),
                ),
              ],
            ),
          ),
        ),
        const Gap(16),
        Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Чип текущей локации: иконка + название сервера + шеврон. Тап открывает выбор локаций.
class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.countryCode, required this.name, required this.onTap});

  final String countryCode;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              // Флаг страны активного сервера (из геолокации IP); пока не определён — глобус.
              if (countryCode.isNotEmpty)
                IPCountryFlag(countryCode: countryCode, size: 26, radius: 6)
              else
                Icon(Icons.public_rounded, size: 20, color: theme.colorScheme.primary),
              const Gap(10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const Gap(6),
              Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Полоса трафика по подписке (premium): прогресс + «X из Y» и срок.
class _TrafficBar extends StatelessWidget {
  const _TrafficBar(this.subInfo);

  final SubscriptionInfo subInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RemainingTrafficIndicator(subInfo.ratio),
          const Gap(8),
          ProfileSubscriptionInfo(subInfo),
        ],
      ),
    );
  }
}

/// Бесплатный тариф (по макету): карточка «Сегодня осталось MM:SS» + полоса + «Бесплатно · 2 Мбит/с».
/// Учёт СЕРВЕРНЫЙ (источник правды — бэкенд, по стабильному ID устройства): при открытии берём
/// остаток (/free/quota), каждую секунду тикаем локально для плавности, раз в 30 сек шлём
/// накопленное на /free/heartbeat и сверяем остаток. На нуле (или stop от сервера) — отключаемся
/// и показываем Premium. Переустановка не сбрасывает лимит (ID стабильный, см. StrizhApi.hwid).
class _FreeQuota extends ConsumerStatefulWidget {
  const _FreeQuota({required this.theme});

  final ThemeData theme;

  @override
  ConsumerState<_FreeQuota> createState() => _FreeQuotaState();
}

class _FreeQuotaState extends ConsumerState<_FreeQuota> {
  final _api = StrizhApi();
  int _limit = 30 * 60;
  int? _remaining; // null — ещё не загрузили с сервера
  int _elapsed = 0; // секунды с последней отправки heartbeat
  int _retry = 0;
  bool _nudged = false;
  bool _hb = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadQuota();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _loadQuota() async {
    final q = await _api.freeQuota();
    if (!mounted || q == null) return;
    setState(() {
      _limit = (q['limit_seconds'] as num?)?.toInt() ?? _limit;
      _remaining = (q['remaining_seconds'] as num?)?.toInt();
    });
  }

  bool get _connected {
    final s = ref.read(connectionNotifierProvider).valueOrNull;
    return s is Connected || s is NoAvailableProxies || s is HotReloading;
  }

  void _nudge() {
    if (_nudged) return;
    _nudged = true;
    ref.read(connectionNotifierProvider.notifier).toggleConnection();
    if (mounted) showStrizhPremiumSheet(context);
  }

  Future<void> _sendHeartbeat() async {
    if (_hb || _elapsed <= 0) return;
    _hb = true;
    final secs = _elapsed;
    _elapsed = 0;
    final res = await _api.freeHeartbeat(secs);
    _hb = false;
    if (res == null || !mounted) return;
    final rem = (res['remaining_seconds'] as num?)?.toInt();
    if (rem != null) setState(() => _remaining = rem);
    if (res['stop'] == true || (rem != null && rem <= 0)) _nudge();
  }

  void _tick() {
    // Ещё не загрузили остаток — повторяем попытку раз в ~8 сек.
    if (_remaining == null) {
      if (++_retry % 8 == 0) _loadQuota();
      return;
    }
    // Считаем только пока VPN реально подключён.
    if (!_connected) {
      if (_elapsed > 0) _sendHeartbeat(); // долить накопленное на паузе
      return;
    }
    if (_remaining! <= 0) {
      _nudge();
      return;
    }
    setState(() {
      _remaining = _remaining! - 1;
      _elapsed++;
    });
    if (_elapsed >= 30) _sendHeartbeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_elapsed > 0) _api.freeHeartbeat(_elapsed); // долить при уходе с экрана
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final t = ref.watch(translationsProvider).requireValue;
    final rem = _remaining;
    final mm = rem == null ? '--' : (rem ~/ 60).toString().padLeft(2, '0');
    final ss = rem == null ? '--' : (rem % 60).toString().padLeft(2, '0');
    final double ratio = (rem == null || _limit == 0) ? 1.0 : (rem / _limit).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                t.strizh.todayLeft,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '$mm:$ss',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const Gap(10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const Gap(10),
          Text(
            t.strizh.freeSpeed,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Кнопка «Перейти на Premium» — открывает модалку Premium (по макету), а не сразу сайт.
class _PremiumButton extends ConsumerWidget {
  const _PremiumButton({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => showStrizhPremiumSheet(context),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        icon: const Icon(Icons.bolt_rounded, size: 20),
        label: Text(t.strizh.goPremium),
      ),
    );
  }
}

/// Модалка Premium (по макету): молния, «Полная скорость, без лимитов»,
/// «Локации по всему миру», кнопка «Выбрать тариф» → сайт strizhvpn.com.
Future<void> showStrizhPremiumSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final t = ProviderScope.containerOf(context, listen: false).read(translationsProvider).requireValue;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    t.strizh.premium,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Gap(8),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt_rounded, size: 34, color: theme.colorScheme.primary),
              ),
              const Gap(18),
              Text(
                t.strizh.premiumTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Gap(8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.public_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const Gap(6),
                  Text(
                    t.strizh.premiumWorld,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const Gap(24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      await launchUrl(
                        Uri.parse('https://strizhvpn.com/buy'),
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {}
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(t.strizh.choosePlan),
                ),
              ),
              const Gap(10),
              Text(
                t.strizh.opensSite,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    },
  );
}
