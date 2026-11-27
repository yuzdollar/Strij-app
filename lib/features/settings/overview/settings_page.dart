import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/strizh/strizh_l10n.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

/// Strizh: экран настроек по макету — только Язык / Тема / Аккаунт + версия внизу.
/// Назад — стрелка в AppBar (→ домой). Технические разделы Hiddify (роутинг, DNS, inbound…)
/// видны только в скрытом «режиме разработчика» (7 тапов по версии на странице About).
class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  Future<void> _openAccount() async {
    try {
      await launchUrl(Uri.parse('https://strizhvpn.com/account'), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final devMode = ref.watch(Preferences.developerMode);
    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    final s = StrizhL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.goNamed('home'),
        ),
        title: Text(t.pages.settings.title),
      ),
      body: ListView(
        children: [
          const Gap(4),
          // Язык
          const LocalePrefTile(),
          // Тема
          const ThemeModePrefTile(),
          // Аккаунт
          ListTile(
            leading: const Icon(Icons.person_rounded),
            title: Text(s.account),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.signIn, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Gap(4),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: _openAccount,
          ),

          // Технические разделы — только в режиме разработчика.
          if (devMode) ...[
            const Divider(height: 24),
            SettingsSection(
              title: t.pages.settings.general.title,
              icon: Icons.layers_rounded,
              namedLocation: context.namedLocation('general'),
            ),
            SettingsSection(
              title: t.pages.settings.routing.title,
              icon: Icons.route_rounded,
              namedLocation: context.namedLocation('routingOptions'),
            ),
            SettingsSection(
              title: t.pages.settings.dns.title,
              icon: Icons.dns_rounded,
              namedLocation: context.namedLocation('dnsOptions'),
            ),
            SettingsSection(
              title: t.pages.settings.inbound.title,
              icon: Icons.input_rounded,
              namedLocation: context.namedLocation('inboundOptions'),
            ),
            SettingsSection(
              title: t.pages.settings.tlsTricks.title,
              icon: Icons.content_cut_rounded,
              namedLocation: context.namedLocation('tlsTricks'),
            ),
            SettingsSection(
              title: t.pages.logs.title,
              icon: Icons.description_rounded,
              namedLocation: context.namedLocation('logs'),
            ),
          ],

          const Gap(28),
          // Нажатие по версии на странице About включает режим разработчика (7 тапов).
          Center(
            child: GestureDetector(
              onTap: () => context.go(context.namedLocation('about')),
              child: Text(
                'Strizh · v$version',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    required this.namedLocation,
  });

  final String title;
  final Widget? subtitle;
  final IconData icon;
  final String namedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(namedLocation),
    );
  }
}
