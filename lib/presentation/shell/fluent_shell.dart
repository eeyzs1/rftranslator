import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:rftranslator/core/localization/app_localizations.dart';
import 'package:rftranslator/features/translation/presentation/screens/translation_screen.dart';
import 'package:rftranslator/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:rftranslator/features/history/presentation/screens/history_screen.dart';
import 'package:rftranslator/features/settings/presentation/screens/settings_screen.dart';

class FluentShell extends ConsumerWidget {
  const FluentShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.watch(settingsProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return fluent.NavigationView(
      pane: fluent.NavigationPane(
        selected: settings.currentIndex,
        onChanged: (index) {
          settingsNotifier.setCurrentIndex(index);
        },
        items: [
          fluent.PaneItem(
            icon: const Icon(Icons.translate_outlined),
            title: Text(l10n.translateNav),
            body: const TranslationScreen(),
          ),
          fluent.PaneItem(
            icon: const Icon(Icons.star_outlined),
            title: Text(l10n.favorites),
            body: const FavoritesScreen(),
          ),
          fluent.PaneItem(
            icon: const Icon(Icons.history),
            title: Text(l10n.history),
            body: const HistoryScreen(),
          ),
          fluent.PaneItem(
            icon: const Icon(Icons.settings_outlined),
            title: Text(l10n.settings),
            body: const SettingsScreen(),
          ),
        ],
        displayMode: fluent.PaneDisplayMode.compact,
      ),
    );
  }
}
