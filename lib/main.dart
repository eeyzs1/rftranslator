import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'package:rftranslator/app.dart';
import 'package:rftranslator/core/localization/app_localizations.dart';
import 'package:rftranslator/core/utils/platform_utils.dart';
import 'package:rftranslator/features/favorites/data/models/favorite_word.dart';
import 'package:rftranslator/features/history/data/models/history_entry.dart';
import 'package:rftranslator/features/translation/data/models/translation_history.dart';
import 'package:rftranslator/features/llm/data/datasources/ctranslate2_datasource.dart';

class AppWindowListener with WindowListener {
  @override
  void onWindowClose() {
    TranslationIsolateWorker.instance.sendShutdownSignal();
    windowManager.destroy();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (PlatformUtils.isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Hive.initFlutter();
  Hive.registerAdapter(FavoriteWordAdapter());
  Hive.registerAdapter(HistoryEntryAdapter());
  Hive.registerAdapter(TranslationHistoryAdapter());
  await Hive.openBox<FavoriteWord>('favorites');
  await Hive.openBox<HistoryEntry>('history');
  await Hive.openBox<TranslationHistory>('translation_history');

  final prefs = await SharedPreferences.getInstance();

  if (PlatformUtils.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(400, 600));
    await windowManager.setSize(const Size(900, 700));
    await windowManager.setTitle('rftranslator');
    await windowManager.center();
    windowManager.addListener(AppWindowListener());
    await windowManager.setPreventClose(true);
  }

  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => SettingsNotifier(prefs)),
      ],
      child: const App(),
    ),
  );
}
