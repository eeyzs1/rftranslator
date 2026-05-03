import 'package:rftranslator/features/translation/domain/entities/language.dart';

class LanguageDetector {
  static Language detect(String text) {
    if (text.isEmpty) return Language.english;

    final stats = _CharStats.fromText(text);

    if (stats.cjkRatio > 0.3) {
      if (stats.hiraganaCount > 0 || stats.katakanaCount > 0) {
        return Language.japanese;
      }
      if (stats.hangulRatio > 0.2) {
        return Language.korean;
      }
      return Language.chinese;
    }

    if (stats.hangulRatio > 0.2) {
      return Language.korean;
    }

    if (stats.cyrillicRatio > 0.3) {
      if (stats.ukrainianSpecific > 0) {
        return Language.ukrainian;
      }
      return Language.russian;
    }

    if (stats.arabicRatio > 0.3) {
      return Language.arabic;
    }

    if (stats.hebrewRatio > 0.3) {
      return Language.hebrew;
    }

    if (stats.vietnameseRatio > 0.1) {
      return Language.vietnamese;
    }

    if (stats.latinRatio > 0.3) {
      return _detectLatinLanguage(text, stats);
    }

    return Language.english;
  }

  static Language _detectLatinLanguage(String text, _CharStats stats) {
    final lower = text.toLowerCase();

    final deMarkers = _countMarkers(lower, ['ß', 'ü', 'ö', 'ä', 'und ', 'der ', 'die ', 'das ', 'ist ', 'ein ']);
    final frMarkers = _countMarkers(lower, ['é', 'è', 'ê', 'ç', 'à', 'ù', 'les ', 'des ', 'une ', 'est ', 'que ', 'pas ']);
    final esMarkers = _countMarkers(lower, ['ñ', '¿', '¡', 'el ', 'la ', 'los ', 'las ', 'de ', 'en ', 'que ', 'es ']);
    final ptMarkers = _countMarkers(lower, ['ã', 'õ', 'ç', 'os ', 'as ', 'um ', 'uma ', 'de ', 'em ', 'que ']);
    final itMarkers = _countMarkers(lower, ['è', 'ù', 'il ', 'la ', 'le ', 'di ', 'che ', 'non ', 'un ', 'per ']);
    final nlMarkers = _countMarkers(lower, ['ij', 'het ', 'een ', 'de ', 'van ', 'dat ', 'zijn ', 'met ', 'voor ']);
    final svMarkers = _countMarkers(lower, ['å', 'ö', 'ä', 'och ', 'att ', 'det ', 'som ', 'den ', 'med ', 'har ']);
    final fiMarkers = _countMarkers(lower, ['ä', 'ö', 'ja ', 'on ', 'ei ', 'se ', 'niin ', 'että ', 'tämä ', 'olla ']);
    final bgMarkers = _countMarkers(lower, ['ъ', 'ь', 'на ', 'е ', 'и ', 'да ', 'не ', 'за ', 'от ', 'се ']);
    final msMarkers = _countMarkers(lower, ['yang ', 'dan ', 'di ', 'ke ', 'dari ', 'ini ', 'itu ', 'untuk ', 'dengan ']);

    final scores = <Language, int>{
      Language.german: deMarkers,
      Language.french: frMarkers,
      Language.spanish: esMarkers,
      Language.portuguese: ptMarkers,
      Language.italian: itMarkers,
      Language.dutch: nlMarkers,
      Language.swedish: svMarkers,
      Language.finnish: fiMarkers,
      Language.bulgarian: bgMarkers,
      Language.malay: msMarkers,
      Language.english: _countMarkers(lower, ['the ', 'and ', 'is ', 'are ', 'of ', 'to ', 'in ', 'that ', 'for ', 'with ']),
    };

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  static int _countMarkers(String text, List<String> markers) {
    var count = 0;
    for (final marker in markers) {
      var idx = 0;
      while ((idx = text.indexOf(marker, idx)) != -1) {
        count++;
        idx += marker.length;
      }
    }
    return count;
  }
}

class _CharStats {
  final int totalChars;
  final int cjkCount;
  final int hiraganaCount;
  final int katakanaCount;
  final int hangulCount;
  final int cyrillicCount;
  final int ukrainianSpecific;
  final int arabicCount;
  final int hebrewCount;
  final int latinCount;
  final int vietnameseCount;

  _CharStats({
    required this.totalChars,
    required this.cjkCount,
    required this.hiraganaCount,
    required this.katakanaCount,
    required this.hangulCount,
    required this.cyrillicCount,
    required this.ukrainianSpecific,
    required this.arabicCount,
    required this.hebrewCount,
    required this.latinCount,
    required this.vietnameseCount,
  });

  double get cjkRatio => totalChars > 0 ? cjkCount / totalChars : 0;
  double get hangulRatio => totalChars > 0 ? hangulCount / totalChars : 0;
  double get cyrillicRatio => totalChars > 0 ? cyrillicCount / totalChars : 0;
  double get arabicRatio => totalChars > 0 ? arabicCount / totalChars : 0;
  double get hebrewRatio => totalChars > 0 ? hebrewCount / totalChars : 0;
  double get latinRatio => totalChars > 0 ? latinCount / totalChars : 0;
  double get vietnameseRatio => totalChars > 0 ? vietnameseCount / totalChars : 0;

  static _CharStats fromText(String text) {
    int cjk = 0, hiragana = 0, katakana = 0, hangul = 0;
    int cyrillic = 0, ukrainian = 0, arabic = 0, hebrew = 0;
    int latin = 0, vietnamese = 0;

    for (final ch in text.runes) {
      if (_isCJK(ch)) cjk++;
      if (_isHiragana(ch)) hiragana++;
      if (_isKatakana(ch)) katakana++;
      if (_isHangul(ch)) hangul++;
      if (_isCyrillic(ch)) cyrillic++;
      if (_isUkrainianSpecific(ch)) ukrainian++;
      if (_isArabic(ch)) arabic++;
      if (_isHebrew(ch)) hebrew++;
      if (_isLatin(ch)) latin++;
      if (_isVietnamese(ch)) vietnamese++;
    }

    return _CharStats(
      totalChars: text.length,
      cjkCount: cjk,
      hiraganaCount: hiragana,
      katakanaCount: katakana,
      hangulCount: hangul,
      cyrillicCount: cyrillic,
      ukrainianSpecific: ukrainian,
      arabicCount: arabic,
      hebrewCount: hebrew,
      latinCount: latin,
      vietnameseCount: vietnamese,
    );
  }

  static bool _isCJK(int ch) {
    return (ch >= 0x4E00 && ch <= 0x9FFF) ||
        (ch >= 0x3400 && ch <= 0x4DBF) ||
        (ch >= 0x20000 && ch <= 0x2A6DF) ||
        (ch >= 0xF900 && ch <= 0xFAFF);
  }

  static bool _isHiragana(int ch) {
    return ch >= 0x3040 && ch <= 0x309F;
  }

  static bool _isKatakana(int ch) {
    return ch >= 0x30A0 && ch <= 0x30FF;
  }

  static bool _isHangul(int ch) {
    return (ch >= 0xAC00 && ch <= 0xD7AF) ||
        (ch >= 0x1100 && ch <= 0x11FF) ||
        (ch >= 0x3130 && ch <= 0x318F);
  }

  static bool _isCyrillic(int ch) {
    return ch >= 0x0400 && ch <= 0x04FF;
  }

  static bool _isUkrainianSpecific(int ch) {
    return ch == 0x0404 || ch == 0x0454 ||
        ch == 0x0490 || ch == 0x0491;
  }

  static bool _isArabic(int ch) {
    return (ch >= 0x0600 && ch <= 0x06FF) ||
        (ch >= 0x0750 && ch <= 0x077F) ||
        (ch >= 0x08A0 && ch <= 0x08FF);
  }

  static bool _isHebrew(int ch) {
    return ch >= 0x0590 && ch <= 0x05FF;
  }

  static bool _isLatin(int ch) {
    return (ch >= 0x0041 && ch <= 0x005A) ||
        (ch >= 0x0061 && ch <= 0x007A) ||
        (ch >= 0x00C0 && ch <= 0x024F);
  }

  static bool _isVietnamese(int ch) {
    return (ch >= 0x0102 && ch <= 0x0103) ||
        (ch >= 0x0110 && ch <= 0x0111) ||
        (ch >= 0x0128 && ch <= 0x0129) ||
        (ch >= 0x0168 && ch <= 0x0169) ||
        (ch >= 0x01A0 && ch <= 0x01A1) ||
        (ch >= 0x01AF && ch <= 0x01B0) ||
        (ch == 0x1EA0 || ch == 0x1EA1) ||
        (ch >= 0x1EB0 && ch <= 0x1EF9);
  }
}
