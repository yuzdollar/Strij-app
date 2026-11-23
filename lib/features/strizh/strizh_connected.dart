import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/model/proxy_entity.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final locationName = (activeProxy?.name.isNotEmpty ?? false) ? activeProxy!.name : profile.name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 46),
      child: Column(
        children: [
          const Spacer(flex: 3),
          const ConnectionButton(),
          const Gap(6),
          const ActiveProxyDelayIndicator(),
          const Spacer(flex: 3),
          _LocationChip(name: locationName, onTap: () => context.goNamed('proxies')),
          const Gap(14),
          // Free — плашка «Бесплатно · 2 Мбит/с» (по макету, без «Unlimited»).
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

/// Чип текущей локации: иконка + название сервера + шеврон. Тап открывает выбор локаций.
class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.name, required this.onTap});

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

/// Бесплатный тариф: полоса + «Бесплатно · 2 Мбит/с» (по макету).
/// Тайм-квота «Сегодня осталось 28:30» — отдельная фича heartbeat на бэкенде, добавим позже.
class _FreeQuota extends StatelessWidget {
  const _FreeQuota({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: 1,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const Gap(8),
        Center(
          child: Text(
            'Бесплатно · 2 Мбит/с',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Кнопка «Перейти на Premium» — открывает модалку Premium (по макету), а не сразу сайт.
class _PremiumButton extends StatelessWidget {
  const _PremiumButton({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
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
        label: const Text('Перейти на Premium'),
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
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Premium',
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
                'Полная скорость, без лимитов',
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
                    'Локации по всему миру',
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
                  label: const Text('Выбрать тариф'),
                ),
              ),
              const Gap(10),
              Text(
                'Откроется сайт Strizh',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    },
  );
}
