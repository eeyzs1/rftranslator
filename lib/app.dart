import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:rftranslator/core/localization/app_localizations.dart';
import 'package:rftranslator/core/router/app_router.dart';
import 'package:rftranslator/core/utils/platform_utils.dart';

fluent.AccentColor _toFluentAccentColor(Color color) {
  return fluent.AccentColor.swatch({
    'darkest': color.withValues(alpha: 0.2),
    'darker': color.withValues(alpha: 0.4),
    'dark': color.withValues(alpha: 0.6),
    'normal': color,
    'light': color.withValues(alpha: 0.8),
    'lighter': color.withValues(alpha: 0.6),
    'lightest': color.withValues(alpha: 0.4),
  });
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.watch(settingsProvider.notifier);

    UIStyle effectiveStyle = settings.uiStyle;
    if (effectiveStyle == UIStyle.adaptive) {
      effectiveStyle = PlatformUtils.isDesktop ? UIStyle.fluent : UIStyle.material3;
    }

    final bool isFluent = effectiveStyle == UIStyle.fluent;
    final seedColor = settings.seedColor;

    const localizationsDelegates = [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

    const supportedLocales = [
      Locale('en'),
      Locale('zh'),
    ];

    Locale localeResolution(Locale? locale, Iterable<Locale> supported) {
      if (locale != null) {
        for (final supportedLocale in supported) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }
      }
      return const Locale('en');
    }

    if (isFluent) {
      final fluentAccentColor = _toFluentAccentColor(seedColor);
      return fluent.FluentApp.router(
        title: 'rftranslator',
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        locale: settingsNotifier.effectiveLocale,
        localeResolutionCallback: localeResolution,
        theme: fluent.FluentThemeData(
          accentColor: fluentAccentColor,
        ),
        darkTheme: fluent.FluentThemeData(
          brightness: Brightness.dark,
          accentColor: fluentAccentColor,
        ),
        themeMode: switch (settingsNotifier.effectiveThemeMode) {
          ThemeMode.system => fluent.ThemeMode.system,
          ThemeMode.light => fluent.ThemeMode.light,
          ThemeMode.dark => fluent.ThemeMode.dark,
        },
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return ScaffoldMessenger(
            key: scaffoldMessengerKey,
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
    }

    return MaterialApp.router(
      title: 'rftranslator',
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: settingsNotifier.effectiveLocale,
      localeResolutionCallback: localeResolution,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: settingsNotifier.effectiveThemeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return ScaffoldMessenger(
          key: scaffoldMessengerKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
