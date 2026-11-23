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
          if (subInfo != null)
            _TrafficBar(subInfo)
          else
            _FreePill(theme: theme),
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

/// Бесплатный тариф: нейтральная плашка (тайм-квота free — отдельная фича heartbeat, позже).
class _FreePill extends StatelessWidget {
  const _FreePill({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const Gap(8),
          Text(
            'Бесплатный доступ',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Кнопка «Перейти на Premium» — открывает тарифы на сайте.
class _PremiumButton extends StatelessWidget {
  const _PremiumButton({required this.theme});

  final ThemeData theme;

  Future<void> _open() async {
    try {
      await launchUrl(Uri.parse('https://strizhvpn.com/buy'), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _open,
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
