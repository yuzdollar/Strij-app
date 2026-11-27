import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/strizh/strizh_connected.dart';
import 'package:hiddify/features/strizh/strizh_onboarding.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;
    // final hasAnyProfile = ref.watch(hasAnyProfileProvider);
    final activeProfile = ref.watch(activeProfileProvider);

    return Scaffold(
      appBar: AppBar(
        // leading: (RootScaffold.stateKey.currentState?.hasDrawer ?? false) && showDrawerButton(context)
        //     ? DrawerButton(
        //         onPressed: () {
        //           RootScaffold.stateKey.currentState?.openDrawer();
        //         },
        //       )
        //     : null,
        title: Row(
          children: [
            Assets.images.logo.svg(
              height: 24,
              colorFilter: const ColorFilter.mode(AppTheme.brandBlue, BlendMode.srcIn),
            ),
            const Gap(8),
            // Strizh: только название, без бейджа версии «5.9.8 dev» (выглядел как бета).
            Text(t.common.appTitle),
          ],
        ),
        actions: [
          // Strizh: «+» (импорт ключа/профиля) убран — подписку заводит вход в приложении.
          // В AppBar только шестерёнка настроек (по макету).
          IconButton(
            tooltip: t.pages.settings.title,
            icon: Icon(Icons.settings_rounded, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () => context.goNamed('settings'),
          ),
          const Gap(8),
        ],
      ),
      // The sky and the map are drawn once into their own layer: a ripple or a label changing on
      // the page no longer redraws the whole map image under it.
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Strizh: карта мира на тёмном фоне (по просьбе) + мягкое синее свечение к центру.
          RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -.25),
                  radius: .9,
                  colors: [
                    AppTheme.brandBlue.withValues(alpha: theme.brightness == Brightness.dark ? .10 : .06),
                    AppTheme.brandBlue.withValues(alpha: 0),
                  ],
                  stops: const [0, 1],
                ),
                image: DecorationImage(
                  image: const AssetImage('assets/images/world_map.png'),
                  fit: BoxFit.cover,
                  opacity: theme.brightness == Brightness.dark ? 0.08 : 0.06,
                  colorFilter: ColorFilter.mode(
                    theme.brightness == Brightness.dark ? Colors.white.withValues(alpha: .25) : Colors.black54,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 600, // Set the maximum width here
                  ),
                  // The page does not move under the finger: no bounce (iOS) or stretch (Android) when it
                  // fits the screen. It still scrolls, without them, when it does not (a small screen or a
                  // large font).
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                    child: CustomScrollView(
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        // switch (activeProfile) {
                        // AsyncData(value: final profile?) =>
                        // Strizh: нет активного профиля -> экран входа (free/premium);
                        // есть -> стандартная плитка профиля + кнопка подключения.
                        switch (activeProfile) {
                          // Strizh: активный профиль -> экран «подключено» по макету
                          // (кнопка-стриж + пинг + локация + трафик + Premium);
                          // нет профиля -> экран входа.
                          AsyncData(value: final profile?) => SliverFillRemaining(
                            hasScrollBody: false,
                            child: StrizhConnectedBody(profile: profile),
                          ),
                          _ => const SliverFillRemaining(
                            hasScrollBody: false,
                            child: StrizhOnboarding(),
                          ),
                        },
                        // AsyncData() => switch (hasAnyProfile) {
                        //     AsyncData(value: true) => const EmptyActiveProfileHomeBody(),
                        //     _ => const EmptyProfilesHomeBody(),
                        //   },
                        // AsyncError(:final error) => SliverErrorBodyPlaceholder(t.presentShortError(error)),
                        // _ => const SliverToBoxAdapter(),
                        // },
                      ],
                    ),
                  ),
                ),
              ),
              // Strizh: «Quick settings» и подсказка локального прокси убраны (по макету).
            ],
          ),
        ],
      ),
    );
  }
}

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();

    return Semantics(
      label: t.common.version,
      button: false,
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          version,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
