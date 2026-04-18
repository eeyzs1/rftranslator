import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive_io.dart';
import 'package:rftranslator/core/di/providers.dart';
import 'package:rftranslator/core/storage/resource_registry.dart';
import 'package:rftranslator/features/translation/domain/entities/language.dart';
import 'package:rftranslator/features/llm/domain/model_manager.dart';

part 'dictionary_manager.g.dart';

const _stardictReleaseTag = '20260324';
const _stardictBaseUrl =
    'https://github.com/xxyzz/wiktionary_stardict/releases/download/$_stardictReleaseTag';

const _langNames = <String, Map<String, String>>{
  'en': {'en': 'English', 'zh': '英语'},
  'zh': {'en': 'Chinese', 'zh': '汉语'},
  'ja': {'en': 'Japanese', 'zh': '日语'},
  'ko': {'en': 'Korean', 'zh': '韩语'},
  'fr': {'en': 'French', 'zh': '法语'},
  'de': {'en': 'German', 'zh': '德语'},
  'es': {'en': 'Spanish', 'zh': '西班牙语'},
  'ru': {'en': 'Russian', 'zh': '俄语'},
  'it': {'en': 'Italian', 'zh': '意大利语'},
  'pt': {'en': 'Portuguese', 'zh': '葡萄牙语'},
  'ar': {'en': 'Arabic', 'zh': '阿拉伯语'},
  'cs': {'en': 'Czech', 'zh': '捷克语'},
  'da': {'en': 'Danish', 'zh': '丹麦语'},
  'nl': {'en': 'Dutch', 'zh': '荷兰语'},
  'fi': {'en': 'Finnish', 'zh': '芬兰语'},
  'el': {'en': 'Greek', 'zh': '希腊语'},
  'he': {'en': 'Hebrew', 'zh': '希伯来语'},
  'hi': {'en': 'Hindi', 'zh': '印地语'},
  'is': {'en': 'Icelandic', 'zh': '冰岛语'},
  'id': {'en': 'Indonesian', 'zh': '印尼语'},
  'la': {'en': 'Latin', 'zh': '拉丁语'},
  'ms': {'en': 'Malay', 'zh': '马来语'},
  'no': {'en': 'Norwegian', 'zh': '挪威语'},
  'nb': {'en': 'Norwegian Bokmål', 'zh': '书面挪威语'},
  'nn': {'en': 'Norwegian Nynorsk', 'zh': '新挪威语'},
  'fa': {'en': 'Persian', 'zh': '波斯语'},
  'pl': {'en': 'Polish', 'zh': '波兰语'},
  'sv': {'en': 'Swedish', 'zh': '瑞典语'},
  'th': {'en': 'Thai', 'zh': '泰语'},
  'tr': {'en': 'Turkish', 'zh': '土耳其语'},
  'uk': {'en': 'Ukrainian', 'zh': '乌克兰语'},
  'vi': {'en': 'Vietnamese', 'zh': '越南语'},
  'bn': {'en': 'Bengali', 'zh': '孟加拉语'},
  'bg': {'en': 'Bulgarian', 'zh': '保加利亚语'},
  'ca': {'en': 'Catalan', 'zh': '加泰罗尼亚语'},
  'oc': {'en': 'Occitan', 'zh': '奥克语'},
  'ro': {'en': 'Romanian', 'zh': '罗马尼亚语'},
  'sl': {'en': 'Slovene', 'zh': '斯洛文尼亚语'},
  'lv': {'en': 'Latvian', 'zh': '拉脱维亚语'},
  'ku': {'en': 'Kurdish', 'zh': '库尔德语'},
  'lt': {'en': 'Lithuanian', 'zh': '立陶宛语'},
  'mg': {'en': 'Malagasy', 'zh': '马达加斯加语'},
};

const _isoToLanguage = <String, Language>{
  'en': Language.english,
  'zh': Language.chinese,
  'ja': Language.japanese,
  'ko': Language.korean,
  'fr': Language.french,
  'de': Language.german,
  'es': Language.spanish,
  'ru': Language.russian,
  'it': Language.italian,
  'pt': Language.portuguese,
  'ar': Language.arabic,
};

String langDisplayName(String code, String localeCode) {
  return _langNames[code]?[localeCode] ?? _langNames[code]?['en'] ?? code.toUpperCase();
}

class DictionaryMeta {
  final String id;
  final String? downloadUrl;
  final String sourceLang;
  final String targetLang;
  final int sizeBytes;
  final bool isStarDict;
  final bool isMDict;
  final String localDirName;
  final String? originalName;

  const DictionaryMeta({
    required this.id,
    this.downloadUrl,
    required this.sourceLang,
    required this.targetLang,
    required this.sizeBytes,
    this.isStarDict = true,
    this.isMDict = false,
    required this.localDirName,
    this.originalName,
  });

  String displayName(String localeCode) {
    final src = langDisplayName(sourceLang, localeCode);
    final tgt = langDisplayName(targetLang, localeCode);
    final localized = '$src → $tgt';
    if (originalName != null && originalName != localized) {
      return '$originalName ($localized)';
    }
    return localized;
  }

  String description(String localeCode) {
    if (!isStarDict) {
      if (localeCode == 'zh') {
        return '包含超过 300 万词条的英汉词典（SQLite）';
      }
      return 'English-Chinese dictionary with over 3M entries (SQLite)';
    }
    final src = langDisplayName(sourceLang, localeCode);
    final tgt = langDisplayName(targetLang, localeCode);
    if (originalName != null) {
      final source = _detectSource();
      if (localeCode == 'zh') {
        return 'StarDict 格式的$src$tgt词典（$source）';
      }
      return 'StarDict $src-$tgt dictionary ($source)';
    }
    if (localeCode == 'zh') {
      return 'StarDict 格式的$src$tgt词典（Wiktionary）';
    }
    return 'StarDict $src-$tgt dictionary (Wiktionary)';
  }

  String _detectSource() {
    if (originalName == null) return 'Wiktionary';
    final name = originalName!.toLowerCase();
    if (name.contains('freedict')) return 'FreeDict';
    if (name.contains('wikdict')) return 'WikDict';
    if (name.contains('ecdict')) return 'ECDICT';
    return 'Wiktionary';
  }

  String sizeInfo(String localeCode) {
    if (localeCode == 'zh') {
      return '约${(sizeBytes / (1024 * 1024)).round()}MB';
    }
    return '~${(sizeBytes / (1024 * 1024)).round()}MB';
  }

  Language? get sourceLanguage => _isoToLanguage[sourceLang];
  Language? get targetLanguage => _isoToLanguage[targetLang];
}

const _freeDictBase = 'https://download.freedict.org/dictionaries';
const _wikDictBase = 'https://download.wikdict.com/dictionaries/stardict';

const dictionaryCatalog = <DictionaryMeta>[
  DictionaryMeta(
    id: 'ecdict',
    downloadUrl: 'https://github.com/skywind3000/ECDICT/releases/download/1.0.28/ecdict-sqlite-28.zip',
    sourceLang: 'en',
    targetLang: 'zh',
    sizeBytes: 210 * 1024 * 1024,
    isStarDict: false,
    localDirName: 'stardict',
    originalName: 'ECDICT',
  ),
  DictionaryMeta(
    id: 'ecdict_stardict',
    downloadUrl: 'https://github.com/skywind3000/ECDICT/releases/download/1.0.28/ecdict-stardict-28.zip',
    sourceLang: 'en',
    targetLang: 'zh',
    sizeBytes: 80 * 1024 * 1024,
    localDirName: 'stardict_ecdict',
    originalName: 'ECDICT',
  ),
  // English Wiktionary: X → English
  DictionaryMeta(id: 'arabic_english', downloadUrl: '$_stardictBaseUrl/Arabic-English.tar.zst', sourceLang: 'ar', targetLang: 'en', sizeBytes: 5 * 1024 * 1024, localDirName: 'stardict_arabic_english', originalName: 'Arabic-English'),
  DictionaryMeta(id: 'bengali_english', downloadUrl: '$_stardictBaseUrl/Bengali-English.tar.zst', sourceLang: 'bn', targetLang: 'en', sizeBytes: 2 * 1024 * 1024, localDirName: 'stardict_bengali_english', originalName: 'Bengali-English'),
  DictionaryMeta(id: 'chinese_english', downloadUrl: '$_stardictBaseUrl/Chinese-English.tar.zst', sourceLang: 'zh', targetLang: 'en', sizeBytes: 17 * 1024 * 1024, localDirName: 'stardict_chinese_english', originalName: 'Chinese-English'),
  DictionaryMeta(id: 'czech_english', downloadUrl: '$_stardictBaseUrl/Czech-English.tar.zst', sourceLang: 'cs', targetLang: 'en', sizeBytes: 4 * 1024 * 1024, localDirName: 'stardict_czech_english', originalName: 'Czech-English'),
  DictionaryMeta(id: 'danish_english', downloadUrl: '$_stardictBaseUrl/Danish-English.tar.zst', sourceLang: 'da', targetLang: 'en', sizeBytes: 2 * 1024 * 1024, localDirName: 'stardict_danish_english', originalName: 'Danish-English'),
  DictionaryMeta(id: 'dutch_english', downloadUrl: '$_stardictBaseUrl/Dutch-English.tar.zst', sourceLang: 'nl', targetLang: 'en', sizeBytes: 6 * 1024 * 1024, localDirName: 'stardict_dutch_english', originalName: 'Dutch-English'),
  DictionaryMeta(id: 'english_english', downloadUrl: '$_stardictBaseUrl/English-English.tar.zst', sourceLang: 'en', targetLang: 'en', sizeBytes: 69 * 1024 * 1024, localDirName: 'stardict_english_english', originalName: 'English-English'),
  DictionaryMeta(id: 'finnish_english', downloadUrl: '$_stardictBaseUrl/Finnish-English.tar.zst', sourceLang: 'fi', targetLang: 'en', sizeBytes: 76 * 1024 * 1024, localDirName: 'stardict_finnish_english', originalName: 'Finnish-English'),
  DictionaryMeta(id: 'french_english', downloadUrl: '$_stardictBaseUrl/French-English.tar.zst', sourceLang: 'fr', targetLang: 'en', sizeBytes: 8 * 1024 * 1024, localDirName: 'stardict_french_english', originalName: 'French-English'),
  DictionaryMeta(id: 'german_english', downloadUrl: '$_stardictBaseUrl/German-English.tar.zst', sourceLang: 'de', targetLang: 'en', sizeBytes: 11 * 1024 * 1024, localDirName: 'stardict_german_english', originalName: 'German-English'),
  DictionaryMeta(id: 'greek_english', downloadUrl: '$_stardictBaseUrl/Greek-English.tar.zst', sourceLang: 'el', targetLang: 'en', sizeBytes: 4 * 1024 * 1024, localDirName: 'stardict_greek_english', originalName: 'Greek-English'),
  DictionaryMeta(id: 'hebrew_english', downloadUrl: '$_stardictBaseUrl/Hebrew-English.tar.zst', sourceLang: 'he', targetLang: 'en', sizeBytes: 2 * 1024 * 1024, localDirName: 'stardict_hebrew_english', originalName: 'Hebrew-English'),
  DictionaryMeta(id: 'hindi_english', downloadUrl: '$_stardictBaseUrl/Hindi-English.tar.zst', sourceLang: 'hi', targetLang: 'en', sizeBytes: 3 * 1024 * 1024, localDirName: 'stardict_hindi_english', originalName: 'Hindi-English'),
  DictionaryMeta(id: 'icelandic_english', downloadUrl: '$_stardictBaseUrl/Icelandic-English.tar.zst', sourceLang: 'is', targetLang: 'en', sizeBytes: 2 * 1024 * 1024, localDirName: 'stardict_icelandic_english', originalName: 'Icelandic-English'),
  DictionaryMeta(id: 'indonesian_english', downloadUrl: '$_stardictBaseUrl/Indonesian-English.tar.zst', sourceLang: 'id', targetLang: 'en', sizeBytes: 3 * 1024 * 1024, localDirName: 'stardict_indonesian_english', originalName: 'Indonesian-English'),
  DictionaryMeta(id: 'italian_english', downloadUrl: '$_stardictBaseUrl/Italian-English.tar.zst', sourceLang: 'it', targetLang: 'en', sizeBytes: 9 * 1024 * 1024, localDirName: 'stardict_italian_english', originalName: 'Italian-English'),
  DictionaryMeta(id: 'japanese_english', downloadUrl: '$_stardictBaseUrl/Japanese-English.tar.zst', sourceLang: 'ja', targetLang: 'en', sizeBytes: 10 * 1024 * 1024, localDirName: 'stardict_japanese_english', originalName: 'Japanese-English'),
  DictionaryMeta(id: 'korean_english', downloadUrl: '$_stardictBaseUrl/Korean-English.tar.zst', sourceLang: 'ko', targetLang: 'en', sizeBytes: 4 * 1024 * 1024, localDirName: 'stardict_korean_english', originalName: 'Korean-English'),
  DictionaryMeta(id: 'latin_english', downloadUrl: '$_stardictBaseUrl/Latin-English.tar.zst', sourceLang: 'la', targetLang: 'en', sizeBytes: 8 * 1024 * 1024, localDirName: 'stardict_latin_english', originalName: 'Latin-English'),
  DictionaryMeta(id: 'malay_english', downloadUrl: '$_stardictBaseUrl/Malay-English.tar.zst', sourceLang: 'ms', targetLang: 'en', sizeBytes: 2 * 1024 * 1024, localDirName: 'stardict_malay_english', originalName: 'Malay-English'),
  DictionaryMeta(id: 'norwegian_bokmal_english', downloadUrl: '$_stardictBaseUrl/Norwegian_Bokmal-English.tar.zst', sourceLang: 'nb', targetLang: 'en', sizeBytes: 2 * 1024 * 1024, localDirName: 'stardict_norwegian_bokmal_english', originalName: 'Norwegian Bokmål-English'),
  DictionaryMeta(id: 'persian_english', downloadUrl: '$_stardictBaseUrl/Persian-English.tar.zst', sourceLang: 'fa', targetLang: 'en', sizeBytes: 2 * 1024 * 1024, localDirName: 'stardict_persian_english', originalName: 'Persian-English'),
  DictionaryMeta(id: 'polish_english', downloadUrl: '$_stardictBaseUrl/Polish-English.tar.zst', sourceLang: 'pl', targetLang: 'en', sizeBytes: 13 * 1024 * 1024, localDirName: 'stardict_polish_english', originalName: 'Polish-English'),
  DictionaryMeta(id: 'portuguese_english', downloadUrl: '$_stardictBaseUrl/Portuguese-English.tar.zst', sourceLang: 'pt', targetLang: 'en', sizeBytes: 7 * 1024 * 1024, localDirName: 'stardict_portuguese_english', originalName: 'Portuguese-English'),
  DictionaryMeta(id: 'russian_english', downloadUrl: '$_stardictBaseUrl/Russian-English.tar.zst', sourceLang: 'ru', targetLang: 'en', sizeBytes: 10 * 1024 * 1024, localDirName: 'stardict_russian_english', originalName: 'Russian-English'),
  DictionaryMeta(id: 'spanish_english', downloadUrl: '$_stardictBaseUrl/Spanish-English.tar.zst', sourceLang: 'es', targetLang: 'en', sizeBytes: 12 * 1024 * 1024, localDirName: 'stardict_spanish_english', originalName: 'Spanish-English'),
  DictionaryMeta(id: 'swedish_english', downloadUrl: '$_stardictBaseUrl/Swedish-English.tar.zst', sourceLang: 'sv', targetLang: 'en', sizeBytes: 5 * 1024 * 1024, localDirName: 'stardict_swedish_english', originalName: 'Swedish-English'),
  DictionaryMeta(id: 'thai_english', downloadUrl: '$_stardictBaseUrl/Thai-English.tar.zst', sourceLang: 'th', targetLang: 'en', sizeBytes: 2 * 1024 * 1024, localDirName: 'stardict_thai_english', originalName: 'Thai-English'),
  DictionaryMeta(id: 'turkish_english', downloadUrl: '$_stardictBaseUrl/Turkish-English.tar.zst', sourceLang: 'tr', targetLang: 'en', sizeBytes: 4 * 1024 * 1024, localDirName: 'stardict_turkish_english', originalName: 'Turkish-English'),
  DictionaryMeta(id: 'ukrainian_english', downloadUrl: '$_stardictBaseUrl/Ukrainian-English.tar.zst', sourceLang: 'uk', targetLang: 'en', sizeBytes: 5 * 1024 * 1024, localDirName: 'stardict_ukrainian_english', originalName: 'Ukrainian-English'),
  DictionaryMeta(id: 'vietnamese_english', downloadUrl: '$_stardictBaseUrl/Vietnamese-English.tar.zst', sourceLang: 'vi', targetLang: 'en', sizeBytes: 4 * 1024 * 1024, localDirName: 'stardict_vietnamese_english', originalName: 'Vietnamese-English'),
  // French Wiktionary: X → French
  DictionaryMeta(id: 'german_french', downloadUrl: '$_stardictBaseUrl/Allemand-Francais.tar.zst', sourceLang: 'de', targetLang: 'fr', sizeBytes: 11 * 1024 * 1024, localDirName: 'stardict_german_french', originalName: 'Allemand-Français'),
  DictionaryMeta(id: 'english_french', downloadUrl: '$_stardictBaseUrl/Anglais-Francais.tar.zst', sourceLang: 'en', targetLang: 'fr', sizeBytes: 8 * 1024 * 1024, localDirName: 'stardict_english_french', originalName: 'Anglais-Français'),
  DictionaryMeta(id: 'arabic_french', downloadUrl: '$_stardictBaseUrl/Arabe-Francais.tar.zst', sourceLang: 'ar', targetLang: 'fr', sizeBytes: 2 * 1024 * 1024, localDirName: 'stardict_arabic_french', originalName: 'Arabe-Français'),
  DictionaryMeta(id: 'chinese_french', downloadUrl: '$_stardictBaseUrl/Chinois-Francais.tar.zst', sourceLang: 'zh', targetLang: 'fr', sizeBytes: 1 * 1024 * 1024, localDirName: 'stardict_chinese_french', originalName: 'Chinois-Français'),
  DictionaryMeta(id: 'korean_french', downloadUrl: '$_stardictBaseUrl/Coreen-Francais.tar.zst', sourceLang: 'ko', targetLang: 'fr', sizeBytes: 1 * 1024 * 1024, localDirName: 'stardict_korean_french', originalName: 'Coréen-Français'),
  DictionaryMeta(id: 'spanish_french', downloadUrl: '$_stardictBaseUrl/Espagnol-Francais.tar.zst', sourceLang: 'es', targetLang: 'fr', sizeBytes: 3 * 1024 * 1024, localDirName: 'stardict_spanish_french', originalName: 'Espagnol-Français'),
  DictionaryMeta(id: 'french_french', downloadUrl: '$_stardictBaseUrl/Francais-Francais.tar.zst', sourceLang: 'fr', targetLang: 'fr', sizeBytes: 87 * 1024 * 1024, localDirName: 'stardict_french_french', originalName: 'Français-Français'),
  DictionaryMeta(id: 'italian_french', downloadUrl: '$_stardictBaseUrl/Italien-Francais.tar.zst', sourceLang: 'it', targetLang: 'fr', sizeBytes: 8 * 1024 * 1024, localDirName: 'stardict_italian_french', originalName: 'Italien-Français'),
  DictionaryMeta(id: 'japanese_french', downloadUrl: '$_stardictBaseUrl/Japonais-Francais.tar.zst', sourceLang: 'ja', targetLang: 'fr', sizeBytes: 1 * 1024 * 1024, localDirName: 'stardict_japanese_french', originalName: 'Japonais-Français'),
  DictionaryMeta(id: 'dutch_french', downloadUrl: '$_stardictBaseUrl/Neerlandais-Francais.tar.zst', sourceLang: 'nl', targetLang: 'fr', sizeBytes: 2 * 1024 * 1024, localDirName: 'stardict_dutch_french', originalName: 'Néerlandais-Français'),
  DictionaryMeta(id: 'polish_french', downloadUrl: '$_stardictBaseUrl/Polonais-Francais.tar.zst', sourceLang: 'pl', targetLang: 'fr', sizeBytes: 1 * 1024 * 1024, localDirName: 'stardict_polish_french', originalName: 'Polonais-Français'),
  DictionaryMeta(id: 'portuguese_french', downloadUrl: '$_stardictBaseUrl/Portugais-Francais.tar.zst', sourceLang: 'pt', targetLang: 'fr', sizeBytes: 3 * 1024 * 1024, localDirName: 'stardict_portuguese_french', originalName: 'Portugais-Français'),
  DictionaryMeta(id: 'russian_french', downloadUrl: '$_stardictBaseUrl/Russe-Francais.tar.zst', sourceLang: 'ru', targetLang: 'fr', sizeBytes: 4 * 1024 * 1024, localDirName: 'stardict_russian_french', originalName: 'Russe-Français'),
  DictionaryMeta(id: 'vietnamese_french', downloadUrl: '$_stardictBaseUrl/Vietnamien-Francais.tar.zst', sourceLang: 'vi', targetLang: 'fr', sizeBytes: 1 * 1024 * 1024, localDirName: 'stardict_vietnamese_french', originalName: 'Vietnamien-Français'),
  // Spanish Wiktionary: X → Spanish
  DictionaryMeta(id: 'german_spanish', downloadUrl: '$_stardictBaseUrl/Aleman-Espanol.tar.zst', sourceLang: 'de', targetLang: 'es', sizeBytes: 1 * 1024 * 1024, localDirName: 'stardict_german_spanish', originalName: 'Alemán-Español'),
  DictionaryMeta(id: 'spanish_spanish', downloadUrl: '$_stardictBaseUrl/Espanol-Espanol.tar.zst', sourceLang: 'es', targetLang: 'es', sizeBytes: 16 * 1024 * 1024, localDirName: 'stardict_spanish_spanish', originalName: 'Español-Español'),
  DictionaryMeta(id: 'french_spanish', downloadUrl: '$_stardictBaseUrl/Frances-Espanol.tar.zst', sourceLang: 'fr', targetLang: 'es', sizeBytes: 1 * 1024 * 1024, localDirName: 'stardict_french_spanish', originalName: 'Francés-Español'),
  DictionaryMeta(id: 'english_spanish', downloadUrl: '$_stardictBaseUrl/Ingles-Espanol.tar.zst', sourceLang: 'en', targetLang: 'es', sizeBytes: 2 * 1024 * 1024, localDirName: 'stardict_english_spanish', originalName: 'Inglés-Español'),
  DictionaryMeta(id: 'japanese_spanish', downloadUrl: '$_stardictBaseUrl/Japones-Espanol.tar.zst', sourceLang: 'ja', targetLang: 'es', sizeBytes: 1 * 1024 * 1024, localDirName: 'stardict_japanese_spanish', originalName: 'Japonés-Español'),
  // FreeDict: Chinese-related dictionaries
  DictionaryMeta(id: 'freedict_eng_zho', downloadUrl: '$_freeDictBase/eng-zho/2025.11.23/freedict-eng-zho-2025.11.23.stardict.tar.xz', sourceLang: 'en', targetLang: 'zh', sizeBytes: 2 * 1024 * 1024, localDirName: 'freedict_eng_zho', originalName: 'English-Chinese (FreeDict)'),
  DictionaryMeta(id: 'freedict_fra_zho', downloadUrl: '$_freeDictBase/fra-zho/2025.11.23/freedict-fra-zho-2025.11.23.stardict.tar.xz', sourceLang: 'fr', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'freedict_fra_zho', originalName: 'Français-Chinois (FreeDict)'),
  DictionaryMeta(id: 'freedict_zho_rus', downloadUrl: '$_freeDictBase/zho-rus/2025.11.23/freedict-zho-rus-2025.11.23.stardict.tar.xz', sourceLang: 'zh', targetLang: 'ru', sizeBytes: 7 * 1024 * 1024, localDirName: 'freedict_zho_rus', originalName: 'Chinese-Russian (FreeDict)'),
  DictionaryMeta(id: 'freedict_zho_ind', downloadUrl: '$_freeDictBase/zho-ind/2024.10.10/freedict-zho-ind-2024.10.10.stardict.tar.xz', sourceLang: 'zh', targetLang: 'id', sizeBytes: 4 * 1024 * 1024, localDirName: 'freedict_zho_ind', originalName: 'Chinese-Indonesian (FreeDict)'),
  DictionaryMeta(id: 'freedict_swe_zho', downloadUrl: '$_freeDictBase/swe-zho/2025.11.23/freedict-swe-zho-2025.11.23.stardict.tar.xz', sourceLang: 'sv', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'freedict_swe_zho', originalName: 'Swedish-Chinese (FreeDict)'),
  DictionaryMeta(id: 'freedict_zho_nor', downloadUrl: '$_freeDictBase/zho-nor/2025.11.23/freedict-zho-nor-2025.11.23.stardict.tar.xz', sourceLang: 'zh', targetLang: 'no', sizeBytes: 3 * 1024 * 1024, localDirName: 'freedict_zho_nor', originalName: 'Chinese-Norwegian (FreeDict)'),
  DictionaryMeta(id: 'freedict_zho_lat', downloadUrl: '$_freeDictBase/zho-lat/2025.08.04/freedict-zho-lat-2025.08.04.stardict.tar.xz', sourceLang: 'zh', targetLang: 'la', sizeBytes: 1 * 1024 * 1024, localDirName: 'freedict_zho_lat', originalName: 'Chinese-Latin (FreeDict)'),
  DictionaryMeta(id: 'freedict_zho_kur', downloadUrl: '$_freeDictBase/zho-kur/2025.11.23/freedict-zho-kur-2025.11.23.stardict.tar.xz', sourceLang: 'zh', targetLang: 'ku', sizeBytes: 2 * 1024 * 1024, localDirName: 'freedict_zho_kur', originalName: 'Chinese-Kurdish (FreeDict)'),
  DictionaryMeta(id: 'freedict_zho_lit', downloadUrl: '$_freeDictBase/zho-lit/2024.10.10/freedict-zho-lit-2024.10.10.stardict.tar.xz', sourceLang: 'zh', targetLang: 'lt', sizeBytes: 3 * 1024 * 1024, localDirName: 'freedict_zho_lit', originalName: 'Chinese-Lithuanian (FreeDict)'),
  DictionaryMeta(id: 'freedict_zho_mlg', downloadUrl: '$_freeDictBase/zho-mlg/2025.11.23/freedict-zho-mlg-2025.11.23.stardict.tar.xz', sourceLang: 'zh', targetLang: 'mg', sizeBytes: 2 * 1024 * 1024, localDirName: 'freedict_zho_mlg', originalName: 'Chinese-Malagasy (FreeDict)'),
  // WikDict: X → Chinese
  DictionaryMeta(id: 'wikdict_de_zh', downloadUrl: '$_wikDictBase/wikdict-de-zh.zip', sourceLang: 'de', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_de_zh', originalName: 'Deutsch-Chinesisch (WikDict)'),
  DictionaryMeta(id: 'wikdict_en_zh', downloadUrl: '$_wikDictBase/wikdict-en-zh.zip', sourceLang: 'en', targetLang: 'zh', sizeBytes: 2 * 1024 * 1024, localDirName: 'wikdict_en_zh', originalName: 'English-Chinese (WikDict)'),
  DictionaryMeta(id: 'wikdict_es_zh', downloadUrl: '$_wikDictBase/wikdict-es-zh.zip', sourceLang: 'es', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_es_zh', originalName: 'Español-Chino (WikDict)'),
  DictionaryMeta(id: 'wikdict_fr_zh', downloadUrl: '$_wikDictBase/wikdict-fr-zh.zip', sourceLang: 'fr', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_fr_zh', originalName: 'Français-Chinois (WikDict)'),
  DictionaryMeta(id: 'wikdict_it_zh', downloadUrl: '$_wikDictBase/wikdict-it-zh.zip', sourceLang: 'it', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_it_zh', originalName: 'Italiano-Cinese (WikDict)'),
  DictionaryMeta(id: 'wikdict_ru_zh', downloadUrl: '$_wikDictBase/wikdict-ru-zh.zip', sourceLang: 'ru', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ru_zh', originalName: 'Русский-Китайский (WikDict)'),
  DictionaryMeta(id: 'wikdict_pl_zh', downloadUrl: '$_wikDictBase/wikdict-pl-zh.zip', sourceLang: 'pl', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_pl_zh', originalName: 'Polski-Chiński (WikDict)'),
  DictionaryMeta(id: 'wikdict_sv_zh', downloadUrl: '$_wikDictBase/wikdict-sv-zh.zip', sourceLang: 'sv', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_sv_zh', originalName: 'Svenska-Kinesiska (WikDict)'),
  DictionaryMeta(id: 'wikdict_nl_zh', downloadUrl: '$_wikDictBase/wikdict-nl-zh.zip', sourceLang: 'nl', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_nl_zh', originalName: 'Nederlands-Chinees (WikDict)'),
  // WikDict: Chinese → X
  DictionaryMeta(id: 'wikdict_zh_de', downloadUrl: '$_wikDictBase/wikdict-zh-de.zip', sourceLang: 'zh', targetLang: 'de', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_zh_de', originalName: 'Chinesisch-Deutsch (WikDict)'),
  DictionaryMeta(id: 'wikdict_zh_en', downloadUrl: '$_wikDictBase/wikdict-zh-en.zip', sourceLang: 'zh', targetLang: 'en', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_zh_en', originalName: 'Chinese-English (WikDict)'),
  DictionaryMeta(id: 'wikdict_zh_es', downloadUrl: '$_wikDictBase/wikdict-zh-es.zip', sourceLang: 'zh', targetLang: 'es', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_zh_es', originalName: 'Chino-Español (WikDict)'),
  DictionaryMeta(id: 'wikdict_zh_fr', downloadUrl: '$_wikDictBase/wikdict-zh-fr.zip', sourceLang: 'zh', targetLang: 'fr', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_zh_fr', originalName: 'Chinois-Français (WikDict)'),
  DictionaryMeta(id: 'wikdict_zh_ru', downloadUrl: '$_wikDictBase/wikdict-zh-ru.zip', sourceLang: 'zh', targetLang: 'ru', sizeBytes: 5 * 1024 * 1024, localDirName: 'wikdict_zh_ru', originalName: 'Китайский-Русский (WikDict)'),
  DictionaryMeta(id: 'wikdict_zh_id', downloadUrl: '$_wikDictBase/wikdict-zh-id.zip', sourceLang: 'zh', targetLang: 'id', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_zh_id', originalName: 'Chinese-Indonesian (WikDict)'),
  DictionaryMeta(id: 'wikdict_zh_es', downloadUrl: '$_wikDictBase/wikdict-zh-es.zip', sourceLang: 'zh', targetLang: 'es', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_zh_es', originalName: 'Chino-Español (WikDict)'),
  DictionaryMeta(id: 'wikdict_zh_it', downloadUrl: '$_wikDictBase/wikdict-zh-it.zip', sourceLang: 'zh', targetLang: 'it', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_zh_it', originalName: 'Cinese-Italiano (WikDict)'),
  DictionaryMeta(id: 'wikdict_zh_nl', downloadUrl: '$_wikDictBase/wikdict-zh-nl.zip', sourceLang: 'zh', targetLang: 'nl', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_zh_nl', originalName: 'Chinees-Nederlands (WikDict)'),
  DictionaryMeta(id: 'wikdict_zh_sv', downloadUrl: '$_wikDictBase/wikdict-zh-sv.zip', sourceLang: 'zh', targetLang: 'sv', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_zh_sv', originalName: 'Kinesiska-Svenska (WikDict)'),
  DictionaryMeta(id: 'wikdict_fi_zh', downloadUrl: '$_wikDictBase/wikdict-fi-zh.zip', sourceLang: 'fi', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_fi_zh', originalName: 'Suomi-Kiina (WikDict)'),
  DictionaryMeta(id: 'wikdict_el_zh', downloadUrl: '$_wikDictBase/wikdict-el-zh.zip', sourceLang: 'el', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_el_zh', originalName: 'Ελληνικά-Κινεζικά (WikDict)'),
  DictionaryMeta(id: 'wikdict_tr_zh', downloadUrl: '$_wikDictBase/wikdict-tr-zh.zip', sourceLang: 'tr', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_tr_zh', originalName: 'Türkçe-Çince (WikDict)'),
  DictionaryMeta(id: 'wikdict_ku_zh', downloadUrl: '$_wikDictBase/wikdict-ku-zh.zip', sourceLang: 'ku', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ku_zh', originalName: 'Kurdî-Chinese (WikDict)'),
  DictionaryMeta(id: 'wikdict_pl_zh', downloadUrl: '$_wikDictBase/wikdict-pl-zh.zip', sourceLang: 'pl', targetLang: 'zh', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_pl_zh', originalName: 'Polski-Chiński (WikDict)'),
  // WikDict: X → Japanese
  DictionaryMeta(id: 'wikdict_en_ja', downloadUrl: '$_wikDictBase/wikdict-en-ja.zip', sourceLang: 'en', targetLang: 'ja', sizeBytes: 3 * 1024 * 1024, localDirName: 'wikdict_en_ja', originalName: 'English-Japanese (WikDict)'),
  DictionaryMeta(id: 'wikdict_de_ja', downloadUrl: '$_wikDictBase/wikdict-de-ja.zip', sourceLang: 'de', targetLang: 'ja', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_de_ja', originalName: 'Deutsch-Japanisch (WikDict)'),
  DictionaryMeta(id: 'wikdict_fr_ja', downloadUrl: '$_wikDictBase/wikdict-fr-ja.zip', sourceLang: 'fr', targetLang: 'ja', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_fr_ja', originalName: 'Français-Japonais (WikDict)'),
  DictionaryMeta(id: 'wikdict_es_ja', downloadUrl: '$_wikDictBase/wikdict-es-ja.zip', sourceLang: 'es', targetLang: 'ja', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_es_ja', originalName: 'Español-Japonés (WikDict)'),
  DictionaryMeta(id: 'wikdict_it_ja', downloadUrl: '$_wikDictBase/wikdict-it-ja.zip', sourceLang: 'it', targetLang: 'ja', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_it_ja', originalName: 'Italiano-Giapponese (WikDict)'),
  DictionaryMeta(id: 'wikdict_ru_ja', downloadUrl: '$_wikDictBase/wikdict-ru-ja.zip', sourceLang: 'ru', targetLang: 'ja', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ru_ja', originalName: 'Русский-Японский (WikDict)'),
  // WikDict: Japanese → X
  DictionaryMeta(id: 'wikdict_ja_de', downloadUrl: '$_wikDictBase/wikdict-ja-de.zip', sourceLang: 'ja', targetLang: 'de', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ja_de', originalName: '日本語-ドイツ語 (WikDict)'),
  DictionaryMeta(id: 'wikdict_ja_it', downloadUrl: '$_wikDictBase/wikdict-ja-it.zip', sourceLang: 'ja', targetLang: 'it', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ja_it', originalName: '日本語-イタリア語 (WikDict)'),
  DictionaryMeta(id: 'wikdict_ja_pt', downloadUrl: '$_wikDictBase/wikdict-ja-pt.zip', sourceLang: 'ja', targetLang: 'pt', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ja_pt', originalName: '日本語-ポルトガル語 (WikDict)'),
  DictionaryMeta(id: 'wikdict_ja_ru', downloadUrl: '$_wikDictBase/wikdict-ja-ru.zip', sourceLang: 'ja', targetLang: 'ru', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ja_ru', originalName: '日本語-ロシア語 (WikDict)'),
  DictionaryMeta(id: 'wikdict_ja_en', downloadUrl: '$_wikDictBase/wikdict-ja-en.zip', sourceLang: 'ja', targetLang: 'en', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ja_en', originalName: '日本語-英語 (WikDict)'),
  DictionaryMeta(id: 'wikdict_ja_sv', downloadUrl: '$_wikDictBase/wikdict-ja-sv.zip', sourceLang: 'ja', targetLang: 'sv', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ja_sv', originalName: '日本語-スウェーデン語 (WikDict)'),
  DictionaryMeta(id: 'wikdict_ja_fr', downloadUrl: '$_wikDictBase/wikdict-ja-fr.zip', sourceLang: 'ja', targetLang: 'fr', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ja_fr', originalName: '日本語-フランス語 (WikDict)'),
  DictionaryMeta(id: 'wikdict_ja_nl', downloadUrl: '$_wikDictBase/wikdict-ja-nl.zip', sourceLang: 'ja', targetLang: 'nl', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ja_nl', originalName: '日本語-オランダ語 (WikDict)'),
  DictionaryMeta(id: 'wikdict_ja_pl', downloadUrl: '$_wikDictBase/wikdict-ja-pl.zip', sourceLang: 'ja', targetLang: 'pl', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ja_pl', originalName: '日本語-ポーランド語 (WikDict)'),
  DictionaryMeta(id: 'wikdict_ja_fi', downloadUrl: '$_wikDictBase/wikdict-ja-fi.zip', sourceLang: 'ja', targetLang: 'fi', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_ja_fi', originalName: '日本語-フィンランド語 (WikDict)'),
  // WikDict: English → X (reverse direction)
  DictionaryMeta(id: 'wikdict_en_de', downloadUrl: '$_wikDictBase/wikdict-en-de.zip', sourceLang: 'en', targetLang: 'de', sizeBytes: 6 * 1024 * 1024, localDirName: 'wikdict_en_de', originalName: 'English-German (WikDict)'),
  DictionaryMeta(id: 'wikdict_en_it', downloadUrl: '$_wikDictBase/wikdict-en-it.zip', sourceLang: 'en', targetLang: 'it', sizeBytes: 4 * 1024 * 1024, localDirName: 'wikdict_en_it', originalName: 'English-Italian (WikDict)'),
  DictionaryMeta(id: 'wikdict_en_pt', downloadUrl: '$_wikDictBase/wikdict-en-pt.zip', sourceLang: 'en', targetLang: 'pt', sizeBytes: 4 * 1024 * 1024, localDirName: 'wikdict_en_pt', originalName: 'English-Portuguese (WikDict)'),
  DictionaryMeta(id: 'wikdict_en_ru', downloadUrl: '$_wikDictBase/wikdict-en-ru.zip', sourceLang: 'en', targetLang: 'ru', sizeBytes: 5 * 1024 * 1024, localDirName: 'wikdict_en_ru', originalName: 'English-Russian (WikDict)'),
  // WikDict: Portuguese → X
  DictionaryMeta(id: 'wikdict_pt_en', downloadUrl: '$_wikDictBase/wikdict-pt-en.zip', sourceLang: 'pt', targetLang: 'en', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_pt_en', originalName: 'Português-Inglês (WikDict)'),
  DictionaryMeta(id: 'wikdict_pt_es', downloadUrl: '$_wikDictBase/wikdict-pt-es.zip', sourceLang: 'pt', targetLang: 'es', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_pt_es', originalName: 'Português-Español (WikDict)'),
  DictionaryMeta(id: 'wikdict_pt_fr', downloadUrl: '$_wikDictBase/wikdict-pt-fr.zip', sourceLang: 'pt', targetLang: 'fr', sizeBytes: 1 * 1024 * 1024, localDirName: 'wikdict_pt_fr', originalName: 'Português-Français (WikDict)'),
];

DictionaryMeta? findDictionaryById(String id) {
  for (final d in dictionaryCatalog) {
    if (d.id == id) return d;
  }
  return null;
}

DictionaryMeta? findDictionaryForLangPair(
  Set<String> selectedIds,
  Language source,
  Language target,
) {
  final all = findAllDictionariesForLangPair(selectedIds, source, target);
  if (all.isEmpty) return null;
  return all.first;
}

List<DictionaryMeta> findAllDictionariesForLangPair(
  Set<String> selectedIds,
  Language source,
  Language target,
) {
  final matches = <DictionaryMeta>[];
  for (final id in selectedIds) {
    final meta = findDictionaryById(id) ?? _mdictRegistry[id];
    if (meta == null) {
      debugPrint('[DictManager] id=$id not found in catalog or mdictRegistry');
      continue;
    }
    debugPrint('[DictManager] checking id=$id: sourceLanguage=${meta.sourceLanguage} (${meta.sourceLanguage?.code}), targetLanguage=${meta.targetLanguage} (${meta.targetLanguage?.code}) vs source=$source (${source.code}), target=$target (${target.code})');
    if (meta.sourceLanguage == source && meta.targetLanguage == target) {
      matches.add(meta);
    }
  }
  matches.sort((a, b) => _dictPriority(b).compareTo(_dictPriority(a)));
  return matches;
}

int _dictPriority(DictionaryMeta meta) {
  if (meta.id == 'ecdict') return 100;
  if (meta.id == 'ecdict_stardict') return 90;
  if (meta.isMDict) return 70;
  if (meta.originalName?.contains('FreeDict') == true) return 30;
  if (meta.originalName?.contains('WikDict') == true) return 40;
  if (meta.sizeBytes > 50 * 1024 * 1024) return 60;
  if (meta.sizeBytes > 10 * 1024 * 1024) return 50;
  return 20;
}

final _mdictRegistry = <String, DictionaryMeta>{};

DictionaryMeta? findMDictById(String id) => _mdictRegistry[id];

void registerMDict(DictionaryMeta meta) {
  _mdictRegistry[meta.id] = meta;
}

void unregisterMDict(String id) {
  _mdictRegistry.remove(id);
}

List<DictionaryMeta> get allMDictDictionaries => _mdictRegistry.values.toList();

const String _kDictType = 'dictionary';
final _dictRegistry = ResourceRegistry();

String? getDownloadedPath(String id) => _dictRegistry.getEntry(id)?.localPath;

void setDownloadedPath(String id, String p) {
  final existing = _dictRegistry.getEntry(id);
  if (existing != null) {
    _dictRegistry.addOrUpdate(existing.copyWith(localPath: p));
  }
}

void removeDownloadedPath(String id) {
  _dictRegistry.remove(id, type: _kDictType);
}

Map<String, String> get allDownloadedPaths {
  final result = <String, String>{};
  for (final entry in _dictRegistry.getByType(_kDictType)) {
    result[entry.id] = entry.localPath;
  }
  return result;
}

enum DownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

class DictionaryState {
  final String selectedId;
  final Set<String> selectedDictionaryIds;
  final DownloadStatus downloadStatus;
  final double downloadProgress;
  final int downloadedBytes;
  final int totalBytes;
  final String? downloadError;

  DictionaryState({
    required this.selectedId,
    this.selectedDictionaryIds = const {},
    this.downloadStatus = DownloadStatus.idle,
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.downloadError,
  });

  DictionaryMeta? get meta => findDictionaryById(selectedId);

  DictionaryState copyWith({
    String? selectedId,
    Set<String>? selectedDictionaryIds,
    DownloadStatus? downloadStatus,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    String? downloadError,
  }) {
    return DictionaryState(
      selectedId: selectedId ?? this.selectedId,
      selectedDictionaryIds: selectedDictionaryIds ?? this.selectedDictionaryIds,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadError: downloadError ?? this.downloadError,
    );
  }
}

@Riverpod(keepAlive: true)
class DictionaryManager extends _$DictionaryManager {
  static const String _kDictionaryIdKey = 'dictionary_id';
  static const String _kDictionaryPathKey = 'dictionary_path';
  static const String _kSelectedDictionariesKey = 'selected_dictionary_ids';
  static const String _kMDictRegistryKey = 'mdict_registry';
  static const String _kRecentLangPairsKey = 'recent_lang_pairs';

  CancelToken? _cancelToken;

  @override
  DictionaryState build() {
    return DictionaryState(selectedId: 'ecdict');
  }

  Future<void> loadSavedDictionary() async {
    final prefs = await SharedPreferences.getInstance();

    await _dictRegistry.load();
    await _loadMDictRegistry();

    final savedId = prefs.getString(_kDictionaryIdKey);
    if (savedId != null && (findDictionaryById(savedId) != null || _mdictRegistry.containsKey(savedId))) {
      state = state.copyWith(selectedId: savedId);
    }

    final selectedIds = prefs.getStringList(_kSelectedDictionariesKey);
    if (selectedIds != null) {
      final valid = <String>{};
      for (final id in selectedIds) {
        final isInCatalog = findDictionaryById(id) != null;
        final isMDict = _mdictRegistry.containsKey(id);
        if (!isInCatalog && !isMDict) continue;

        if (isMDict) {
          final mdictMeta = _mdictRegistry[id];
          if (mdictMeta != null && File(mdictMeta.localDirName).existsSync()) {
            valid.add(id);
          }
        } else {
          final entry = _dictRegistry.getEntry(id);
          if (entry != null && entry.pathExists) {
            valid.add(id);
          } else {
            final meta = findDictionaryById(id);
            if (meta != null) {
              final dir = await getApplicationDocumentsDirectory();
              final defaultPath = path.join(dir.path, meta.localDirName);
              if (File(defaultPath).existsSync() || Directory(defaultPath).existsSync()) {
                valid.add(id);
                await _dictRegistry.addOrUpdate(ResourceEntry(
                  id: id,
                  type: _kDictType,
                  localPath: defaultPath,
                  sourceLang: meta.sourceLang,
                  targetLang: meta.targetLang,
                  isEnabled: true,
                ));
              }
            }
          }
        }
      }
      state = state.copyWith(selectedDictionaryIds: valid);
    }
  }

  static const String _kMDictRegistryPrefix = 'mdict_';

  Future<void> _loadMDictRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    final registryJson = prefs.getStringList(_kMDictRegistryKey);
    if (registryJson == null) return;

    for (final json in registryJson) {
      final parts = json.split('|||');
      if (parts.length >= 6) {
        final id = parts[0];
        final filePath = parts[1];
        final sourceLang = parts[2];
        final targetLang = parts[3];
        final originalName = parts[4];
        final fileSize = int.tryParse(parts[5]) ?? 0;

        if (!File(filePath).existsSync()) continue;

        registerMDict(DictionaryMeta(
          id: id,
          downloadUrl: null,
          sourceLang: sourceLang,
          targetLang: targetLang,
          sizeBytes: fileSize,
          isStarDict: false,
          isMDict: true,
          localDirName: filePath,
          originalName: originalName,
        ),);
      }
    }
  }

  Future<void> _saveMDictRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = <String>[];
    for (final meta in _mdictRegistry.values) {
      entries.add('${meta.id}|||${meta.localDirName}|||${meta.sourceLang}|||${meta.targetLang}|||${meta.originalName ?? ""}|||${meta.sizeBytes}');
    }
    await prefs.setStringList(_kMDictRegistryKey, entries);
  }

  Future<DictionaryMeta?> importMDictFile(String filePath, {String? sourceLang, String? targetLang}) async {
    if (!File(filePath).existsSync()) return null;
    if (!filePath.toLowerCase().endsWith('.mdx')) return null;

    final fileName = path.basenameWithoutExtension(filePath);
    final id = '$_kMDictRegistryPrefix${DateTime.now().millisecondsSinceEpoch}';

    final src = sourceLang ?? _guessSourceLang(fileName);
    final tgt = targetLang ?? _guessTargetLang(fileName);

    final fileSize = await File(filePath).length();

    final meta = DictionaryMeta(
      id: id,
      downloadUrl: null,
      sourceLang: src,
      targetLang: tgt,
      sizeBytes: fileSize,
      isStarDict: false,
      isMDict: true,
      localDirName: filePath,
      originalName: fileName,
    );

    registerMDict(meta);
    await _saveMDictRegistry();

    final current = Set<String>.from(state.selectedDictionaryIds);
    current.add(id);
    state = state.copyWith(selectedDictionaryIds: current);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSelectedDictionariesKey, current.toList());

    return meta;
  }

  Future<void> removeMDict(String id) async {
    unregisterMDict(id);
    await _saveMDictRegistry();

    final current = Set<String>.from(state.selectedDictionaryIds);
    current.remove(id);
    state = state.copyWith(selectedDictionaryIds: current);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSelectedDictionariesKey, current.toList());

    if (state.selectedId == id) {
      state = state.copyWith(selectedId: 'ecdict');
      await prefs.setString(_kDictionaryIdKey, 'ecdict');
    }
  }

  String _guessSourceLang(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('英汉') || lower.contains('英和') || lower.contains('eng-chi') || lower.contains('en-zh') || lower.contains('en-ja')) return 'en';
    if (lower.contains('汉英') || lower.contains('和英') || lower.contains('chi-eng') || lower.contains('zh-en')) return 'zh';
    if (lower.contains('日汉') || lower.contains('ja-zh') || lower.contains('ja-en')) return 'ja';
    if (lower.contains('法汉') || lower.contains('fr-zh') || lower.contains('fr-en')) return 'fr';
    if (lower.contains('德汉') || lower.contains('de-zh') || lower.contains('de-en')) return 'de';
    if (lower.contains('西汉') || lower.contains('es-zh') || lower.contains('es-en')) return 'es';
    if (lower.contains('韩汉') || lower.contains('ko-zh') || lower.contains('ko-en')) return 'ko';
    if (lower.contains('俄汉') || lower.contains('ru-zh') || lower.contains('ru-en')) return 'ru';
    return 'en';
  }

  String _guessTargetLang(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('英汉') || lower.contains('eng-chi') || lower.contains('en-zh')) return 'zh';
    if (lower.contains('汉英') || lower.contains('chi-eng') || lower.contains('zh-en')) return 'en';
    if (lower.contains('英和') || lower.contains('en-ja')) return 'ja';
    if (lower.contains('和英') || lower.contains('ja-en')) return 'en';
    if (lower.contains('日汉') || lower.contains('ja-zh')) return 'zh';
    if (lower.contains('法汉') || lower.contains('fr-zh')) return 'zh';
    if (lower.contains('德汉') || lower.contains('de-zh')) return 'zh';
    if (lower.contains('西汉') || lower.contains('es-zh')) return 'zh';
    if (lower.contains('韩汉') || lower.contains('ko-zh')) return 'zh';
    if (lower.contains('俄汉') || lower.contains('ru-zh')) return 'zh';
    if (lower.contains('fr-en')) return 'en';
    if (lower.contains('de-en')) return 'en';
    if (lower.contains('es-en')) return 'en';
    if (lower.contains('ko-en')) return 'en';
    if (lower.contains('ru-en')) return 'en';
    return 'zh';
  }

  Future<void> selectDictionary(String id) async {
    state = state.copyWith(
      selectedId: id,
      downloadStatus: DownloadStatus.idle,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: 0,
      downloadError: null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDictionaryIdKey, id);
  }

  Future<void> toggleDictionarySelection(String id) async {
    final current = Set<String>.from(state.selectedDictionaryIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(selectedDictionaryIds: current);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSelectedDictionariesKey, current.toList());
  }

  Set<(Language, Language)> getAvailableLanguagePairs() {
    final pairs = <(Language, Language)>{};
    for (final id in state.selectedDictionaryIds) {
      final meta = findDictionaryById(id) ?? _mdictRegistry[id];
      if (meta != null && meta.sourceLanguage != null && meta.targetLanguage != null) {
        pairs.add((meta.sourceLanguage!, meta.targetLanguage!));
      }
    }
    return pairs;
  }

  Future<void> setDictionaryPath(String p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDictionaryPathKey, p);
  }

  Future<String?> getDictionaryPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDictionaryPathKey);
  }

  Future<bool> isDictionaryAvailable() async {
    final meta = state.meta;
    if (meta == null) return false;

    final entry = _dictRegistry.getEntry(meta.id);
    if (entry != null && entry.pathExists) return true;

    final dir = await getApplicationDocumentsDirectory();
    final defaultPath = path.join(dir.path, meta.localDirName);
    return File(defaultPath).existsSync() || Directory(defaultPath).existsSync();
  }

  Future<String?> getValidDictionaryPath() async {
    final meta = state.meta;
    if (meta == null) return null;

    final entry = _dictRegistry.getEntry(meta.id);
    if (entry != null && entry.pathExists) return entry.localPath;

    final dir = await getApplicationDocumentsDirectory();
    final defaultPath = path.join(dir.path, meta.localDirName);
    if (File(defaultPath).existsSync()) return defaultPath;
    if (Directory(defaultPath).existsSync()) return defaultPath;

    return null;
  }

  Future<void> clearDictionaryPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDictionaryPathKey);
  }

  Future<void> startDownload({String? customDirectory}) async {
    if (state.downloadStatus == DownloadStatus.downloading) return;

    final meta = state.meta;
    if (meta == null || meta.downloadUrl == null) {
      state = state.copyWith(
        downloadStatus: DownloadStatus.failed,
        downloadError: '该词典暂不支持直接下载',
      );
      return;
    }

    state = state.copyWith(
      downloadStatus: DownloadStatus.downloading,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: meta.sizeBytes,
      downloadError: null,
    );
    _cancelToken = CancelToken();

    try {
      String savePath;
      if (customDirectory != null && Directory(customDirectory).existsSync()) {
        savePath = path.join(customDirectory, meta.localDirName);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        savePath = path.join(dir.path, meta.localDirName);
      }

      final tempPath = '$savePath.tmp';
      if (File(tempPath).existsSync()) {
        await File(tempPath).delete();
      }

      final dio = Dio();
      await dio.download(
        meta.downloadUrl!,
        tempPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(
              downloadProgress: received / total,
              downloadedBytes: received,
              totalBytes: total,
            );
          }
        },
      );

      if (File(tempPath).existsSync()) {
        String finalPath;

        if (meta.isStarDict) {
          String archiveExt = '.tar.zst';
          final urlLower = meta.downloadUrl?.toLowerCase() ?? '';
          if (urlLower.endsWith('.tar.xz')) {
            archiveExt = '.tar.xz';
          } else if (urlLower.endsWith('.tar.bz2')) {
            archiveExt = '.tar.bz2';
          } else if (urlLower.endsWith('.tar.gz')) {
            archiveExt = '.tar.gz';
          } else if (urlLower.endsWith('.zip')) {
            archiveExt = '.zip';
          } else if (urlLower.endsWith('.tar')) {
            archiveExt = '.tar';
          }

          final archivePath = '$savePath$archiveExt';
          await File(tempPath).rename(archivePath);

          final extractDir = savePath;
          final extractDirObj = Directory(extractDir);
          if (!extractDirObj.existsSync()) {
            await extractDirObj.create(recursive: true);
          }

          final ifoPath = await _extractStarDictArchive(archivePath, extractDir, archiveExt);

          if (ifoPath != null) {
            finalPath = ifoPath;
            try {
              await File(archivePath).delete();
            } catch (_) {}
          } else {
            throw Exception('解压 StarDict 词典失败');
          }
        } else if (meta.downloadUrl!.toLowerCase().endsWith('.zip') || tempPath.toLowerCase().endsWith('.zip')) {
          final zipPath = tempPath;
          final extractDir = Directory(path.dirname(savePath));
          final bytes = await File(zipPath).readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);

          String? dbFilePath;
          for (final file in archive) {
            if (file.isFile && file.name.toLowerCase().endsWith('.db')) {
              dbFilePath = path.join(extractDir.path, path.basename(file.name));
              final outputStream = OutputFileStream(dbFilePath);
              outputStream.writeBytes(file.content as List<int>);
              await outputStream.close();
              break;
            }
          }

          await File(zipPath).delete();

          if (dbFilePath != null) {
            finalPath = dbFilePath;
          } else {
            throw Exception('ZIP 文件中未找到 .db 数据库文件');
          }
        } else {
          await File(tempPath).rename(savePath);
          finalPath = savePath;
        }

        await setDictionaryPath(finalPath);
        await _dictRegistry.addOrUpdate(ResourceEntry(
          id: meta.id,
          type: _kDictType,
          localPath: finalPath,
          sourceLang: meta.sourceLang,
          targetLang: meta.targetLang,
          isEnabled: true,
        ));

        final current = Set<String>.from(state.selectedDictionaryIds);
        if (!current.contains(meta.id)) {
          current.add(meta.id);
          state = state.copyWith(selectedDictionaryIds: current);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_kSelectedDictionariesKey, current.toList());
        }

        state = state.copyWith(
          downloadStatus: DownloadStatus.completed,
          downloadProgress: 1.0,
        );
      }
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = state.copyWith(
          downloadStatus: DownloadStatus.idle,
          downloadError: '下载已取消',
        );
      } else {
        state = state.copyWith(
          downloadStatus: DownloadStatus.failed,
          downloadError: '下载失败: ${e.toString()}',
        );
      }

      try {
        final meta = state.meta;
        String tempPath;
        if (customDirectory != null) {
          tempPath = path.join(customDirectory, '${meta?.localDirName ?? "unknown"}.tmp');
        } else {
          final dir = await getApplicationDocumentsDirectory();
          tempPath = path.join(dir.path, '${meta?.localDirName ?? "unknown"}.tmp');
        }
        if (File(tempPath).existsSync()) {
          await File(tempPath).delete();
        }
      } catch (_) {}
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }

  void resetDownload() {
    state = state.copyWith(
      downloadStatus: DownloadStatus.idle,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: 0,
      downloadError: null,
    );
  }

  Future<String?> _extractStarDictArchive(String archivePath, String outputDir, String archiveExt) async {
    try {
      if (archiveExt == '.zip') {
        await _extractZip(archivePath, outputDir);
      } else if (archiveExt == '.tar.xz' || archiveExt == '.tar.zst' ||
                 archiveExt == '.tar.gz' || archiveExt == '.tar.bz2' ||
                 archiveExt == '.tar') {
        await _extractTarArchive(archivePath, outputDir);
      } else {
        return null;
      }

      return _findIfoFile(outputDir);
    } catch (e) {
      return null;
    }
  }

  Future<void> _extractZip(String archivePath, String outputDir) async {
    final bytes = await File(archivePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filePath = path.join(outputDir, file.name);
      if (file.isFile) {
        await File(filePath).parent.create(recursive: true);
        final outputFile = OutputFileStream(filePath);
        outputFile.writeBytes(file.content as List<int>);
        await outputFile.close();
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }
  }

  Future<void> _extractTarArchive(String archivePath, String outputDir) async {
    final result = await Process.run(
      'tar',
      ['-xf', archivePath, '-C', outputDir],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw Exception('tar extraction failed: ${result.stderr}');
    }
  }

  String? _findIfoFile(String directory) {
    final dir = Directory(directory);
    if (!dir.existsSync()) return null;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.ifo')) {
        return entity.path;
      }
    }
    return null;
  }

  Future<void> saveRecentLangPair(Language source, Language target) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pairKey = '${source.code}_${target.code}';
      debugPrint('[DictManager] saveRecentLangPair: saving pair=$pairKey');

      final recentPairs = prefs.getStringList(_kRecentLangPairsKey) ?? [];
      debugPrint('[DictManager]   current pairs before save: $recentPairs');

      recentPairs.remove(pairKey);
      recentPairs.insert(0, pairKey);

      final uniquePairs = <String>[];
      for (final p in recentPairs) {
        if (!uniquePairs.contains(p)) {
          uniquePairs.add(p);
        }
        if (uniquePairs.length >= 2) break;
      }

      debugPrint('[DictManager]   saving pairs: $uniquePairs');
      final success = await prefs.setStringList(_kRecentLangPairsKey, uniquePairs);
      debugPrint('[DictManager]   save result: $success');

      // 验证保存
      final verifyPairs = prefs.getStringList(_kRecentLangPairsKey);
      debugPrint('[DictManager]   verification - saved pairs: $verifyPairs');
    } catch (e, stackTrace) {
      debugPrint('[DictManager] ERROR in saveRecentLangPair: $e');
      debugPrint('[DictManager] StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<List<(Language, Language)>> getRecentLangPairs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentPairs = prefs.getStringList(_kRecentLangPairsKey) ?? [];
      debugPrint('[DictManager] getRecentLangPairs: raw pairs from prefs = $recentPairs');
      final result = <(Language, Language)>[];

      for (final pair in recentPairs) {
        final parts = pair.split('_');
        if (parts.length == 2) {
          final sourceLang = _languageFromCode(parts[0]);
          final targetLang = _languageFromCode(parts[1]);
          debugPrint('[DictManager]   pair=$pair => source=${parts[0]}(${sourceLang?.name ?? "null"}), target=${parts[1]}(${targetLang?.name ?? "null"})');
          if (sourceLang != null && targetLang != null) {
            result.add((sourceLang, targetLang));
          }
        } else {
          debugPrint('[DictManager]   skipping invalid pair format: "$pair" (parts.length=${parts.length})');
        }
      }

      debugPrint('[DictManager] getRecentLangPairs: returning ${result.length} valid pairs');
      return result;
    } catch (e, stackTrace) {
      debugPrint('[DictManager] ERROR in getRecentLangPairs: $e');
      debugPrint('[DictManager] StackTrace: $stackTrace');
      return [];
    }
  }

  Language? _languageFromCode(String code) {
    for (final lang in Language.values) {
      if (lang.code == code) return lang;
    }
    return null;
  }

  Future<void> preloadRecentDictionaries() async {
    try {
      final recentPairs = await getRecentLangPairs();
      debugPrint('[DictManager] Preloading dictionaries for ${recentPairs.length} recent language pairs');
      
      for (final (source, target) in recentPairs) {
        final matchedDicts = findAllDictionariesForLangPair(
          state.selectedDictionaryIds,
          source,
          target,
        );
        
        for (final meta in matchedDicts) {
          if (meta.isStarDict) {
            String? dictPath = getDownloadedPath(meta.id);
            if (dictPath == null || !_pathExists(dictPath)) {
              final dir = await getApplicationDocumentsDirectory();
              final defaultPath = path.join(dir.path, meta.localDirName);
              if (Directory(defaultPath).existsSync()) {
                final ifoFile = _findIfoInDir(defaultPath);
                if (ifoFile != null) dictPath = ifoFile;
              } else if (File(defaultPath).existsSync()) {
                dictPath = defaultPath;
              }
            }
            
            if (dictPath != null) {
              debugPrint('[DictManager] Preloading dictionary: ${meta.id} from $dictPath');
              try {
                final starDictSource = ref.read(starDictDataSourceProvider);
                await starDictSource.setPath(dictPath);
                await starDictSource.loadDictionary();
                debugPrint('[DictManager]   Preloaded successfully: ${meta.id}');
              } catch (e) {
                debugPrint('[DictManager]   Failed to preload ${meta.id}: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DictManager] Error preloading dictionaries: $e');
    }
  }

  bool _pathExists(String p) {
    return File(p).existsSync() || Directory(p).existsSync();
  }

  String? _findIfoInDir(String directory) {
    final dir = Directory(directory);
    if (!dir.existsSync()) return null;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.ifo')) {
        return entity.path;
      }
    }
    return null;
  }

  Future<bool> hasAnyDictionaryOrModel() async {
    if (state.selectedDictionaryIds.isNotEmpty) return true;
    
    final modelManager = ref.read(modelManagerProvider.notifier);
    final hasModel = await modelManager.isAnyModelDownloaded();
    return hasModel;
  }
}
