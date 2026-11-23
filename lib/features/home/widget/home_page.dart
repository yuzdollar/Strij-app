import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
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
            Assets.images.logo.svg(height: 24),
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
          RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                // A sky behind the connect button, as at an eclipse: in dark mode a touch lighter round
                // the button, fading to the theme's own dark; in light mode brightest there, a touch
                // darker towards the edges. Both barely there, centred on where the button sits.
                gradient: theme.brightness == Brightness.dark
                    ? RadialGradient(
                        center: const Alignment(0, -.15),
                        radius: .85,
                        colors: [
                          Colors.white.withValues(alpha: .045),
                          Colors.white.withValues(alpha: .015),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0, .45, 1],
                      )
                    : RadialGradient(
                        center: const Alignment(0, -.15),
                        radius: 1.1,
                        colors: [
                          Colors.white.withValues(alpha: .55),
                          Colors.white.withValues(alpha: 0),
                          Colors.black.withValues(alpha: .045),
                        ],
                        stops: const [0, .5, 1],
                      ),
                image: DecorationImage(
                  image: const AssetImage('assets/images/world_map.png'), // Replace with your image path
                  fit: BoxFit.cover,
                  opacity: 0.09,
                  colorFilter: theme.brightness == Brightness.dark
                      ? ColorFilter.mode(Colors.white.withValues(alpha: .15), BlendMode.srcIn) //
                      : ColorFilter.mode(
                          Colors.grey.withValues(alpha: 1),
                          BlendMode.srcATop,
                        ), // Apply white tint in dark mode
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
