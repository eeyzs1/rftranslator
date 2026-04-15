enum Language {
  english,
  chinese,
  japanese,
  korean,
  french,
  german,
  spanish,
  russian,
  italian,
  portuguese,
  arabic,
}

extension LanguageExtension on Language {
  String get displayName {
    return switch (this) {
      Language.english => 'English',
      Language.chinese => '中文',
      Language.japanese => '日本語',
      Language.korean => '한국어',
      Language.french => 'Français',
      Language.german => 'Deutsch',
      Language.spanish => 'Español',
      Language.russian => 'Русский',
      Language.italian => 'Italiano',
      Language.portuguese => 'Português',
      Language.arabic => 'العربية',
    };
  }

  String get code {
    return switch (this) {
      Language.english => 'en',
      Language.chinese => 'zh',
      Language.japanese => 'ja',
      Language.korean => 'ko',
      Language.french => 'fr',
      Language.german => 'de',
      Language.spanish => 'es',
      Language.russian => 'ru',
      Language.italian => 'it',
      Language.portuguese => 'pt',
      Language.arabic => 'ar',
    };
  }

  String get nativeName => displayName;

  String get isoCode => code;
}
