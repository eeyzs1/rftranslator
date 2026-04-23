import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:rftranslator/core/storage/resource_registry.dart';

part 'model_manager.g.dart';

enum ModelType {
  opusMtEnZh,
  opusMtZhEn,
  opusMtEnDe,
  opusMtEnFr,
  opusMtEnEs,
  opusMtEnIt,
  opusMtEnRu,
  opusMtEnAr,
  opusMtEnJap,
  opusMtEnKo,
  opusMtDeEn,
  opusMtFrEn,
  opusMtEsEn,
  opusMtItEn,
  opusMtRuEn,
  opusMtArEn,
  opusMtJapEn,
  opusMtKoEn,
  opusMtZhDe,
  opusMtDeZh,
  opusMtZhIt,
  opusMtZhVi,
  opusMtZhJap,
  opusMtFiZh,
  opusMtSvZh,
  opusMtZhBg,
  opusMtZhFi,
  opusMtZhHe,
  opusMtZhMs,
  opusMtZhNl,
  opusMtZhSv,
  opusMtZhUk,
}

enum ModelDownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

class ModelState {
  final ModelType type;
  final Set<ModelType> enabledModelTypes;
  final ModelDownloadStatus downloadStatus;
  final double downloadProgress;
  final int downloadedBytes;
  final int totalBytes;
  final String? downloadError;

  ModelState({
    required this.type,
    this.enabledModelTypes = const {},
    this.downloadStatus = ModelDownloadStatus.idle,
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.downloadError,
  });

  ModelState copyWith({
    ModelType? type,
    Set<ModelType>? enabledModelTypes,
    ModelDownloadStatus? downloadStatus,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    String? downloadError,
  }) {
    return ModelState(
      type: type ?? this.type,
      enabledModelTypes: enabledModelTypes ?? this.enabledModelTypes,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadError: downloadError ?? this.downloadError,
    );
  }
}

class HardwareRequirements {
  final int minimumRamGb;
  final int recommendedRamGb;
  final int minimumStorageMb;
  final bool requiresCuda;

  const HardwareRequirements({
    required this.minimumRamGb,
    required this.recommendedRamGb,
    required this.minimumStorageMb,
    this.requiresCuda = false,
  });
}

class CustomModelEntry {
  final String folderName;
  final String sourceLang;
  final String targetLang;
  final String localPath;

  const CustomModelEntry({
    required this.folderName,
    required this.sourceLang,
    required this.targetLang,
    required this.localPath,
  });

  Map<String, dynamic> toJson() => {
    'folderName': folderName,
    'sourceLang': sourceLang,
    'targetLang': targetLang,
    'localPath': localPath,
  };

  factory CustomModelEntry.fromJson(Map<String, dynamic> json) =>
      CustomModelEntry(
        folderName: json['folderName'] as String,
        sourceLang: json['sourceLang'] as String,
        targetLang: json['targetLang'] as String,
        localPath: json['localPath'] as String,
      );

  String get displayName => 'OPUS-MT $sourceLang→$targetLang';
}

extension ModelTypeExtension on ModelType {
  String get displayName {
    return switch (this) {
      ModelType.opusMtEnZh => 'OPUS-MT en→zh (English to Chinese)',
      ModelType.opusMtZhEn => 'OPUS-MT zh→en (Chinese to English)',
      ModelType.opusMtEnDe => 'OPUS-MT en→de (English to German)',
      ModelType.opusMtEnFr => 'OPUS-MT en→fr (English to French)',
      ModelType.opusMtEnEs => 'OPUS-MT en→es (English to Spanish)',
      ModelType.opusMtEnIt => 'OPUS-MT en→it (English to Italian)',
      ModelType.opusMtEnRu => 'OPUS-MT en→ru (English to Russian)',
      ModelType.opusMtEnAr => 'OPUS-MT en→ar (English to Arabic)',
      ModelType.opusMtEnJap => 'OPUS-MT en→ja (English to Japanese)',
      ModelType.opusMtEnKo => 'OPUS-MT en→ko (English to Korean)',
      ModelType.opusMtDeEn => 'OPUS-MT de→en (German to English)',
      ModelType.opusMtFrEn => 'OPUS-MT fr→en (French to English)',
      ModelType.opusMtEsEn => 'OPUS-MT es→en (Spanish to English)',
      ModelType.opusMtItEn => 'OPUS-MT it→en (Italian to English)',
      ModelType.opusMtRuEn => 'OPUS-MT ru→en (Russian to English)',
      ModelType.opusMtArEn => 'OPUS-MT ar→en (Arabic to English)',
      ModelType.opusMtJapEn => 'OPUS-MT ja→en (Japanese to English)',
      ModelType.opusMtKoEn => 'OPUS-MT ko→en (Korean to English)',
      ModelType.opusMtZhDe => 'OPUS-MT zh→de (Chinese to German)',
      ModelType.opusMtDeZh => 'OPUS-MT de→zh (German to Chinese)',
      ModelType.opusMtZhIt => 'OPUS-MT zh→it (Chinese to Italian)',
      ModelType.opusMtZhVi => 'OPUS-MT zh→vi (Chinese to Vietnamese)',
      ModelType.opusMtZhJap => 'OPUS-MT zh→ja (Chinese to Japanese)',
      ModelType.opusMtFiZh => 'OPUS-MT fi→zh (Finnish to Chinese)',
      ModelType.opusMtSvZh => 'OPUS-MT sv→zh (Swedish to Chinese)',
      ModelType.opusMtZhBg => 'OPUS-MT zh→bg (Chinese to Bulgarian)',
      ModelType.opusMtZhFi => 'OPUS-MT zh→fi (Chinese to Finnish)',
      ModelType.opusMtZhHe => 'OPUS-MT zh→he (Chinese to Hebrew)',
      ModelType.opusMtZhMs => 'OPUS-MT zh→ms (Chinese to Malay)',
      ModelType.opusMtZhNl => 'OPUS-MT zh→nl (Chinese to Dutch)',
      ModelType.opusMtZhSv => 'OPUS-MT zh→sv (Chinese to Swedish)',
      ModelType.opusMtZhUk => 'OPUS-MT zh→uk (Chinese to Ukrainian)',
    };
  }

  String get description {
    return switch (this) {
      ModelType.opusMtEnZh || ModelType.opusMtZhEn =>
          'Encoder-Decoder architecture optimized for EN↔ZH\nDesigned for long sentences and paragraphs',
      _ => 'Helsinki-NLP OPUS-MT translation model\nHigh quality, fast',
    };
  }

  String get folderName {
    return switch (this) {
      ModelType.opusMtEnZh => 'opus-mt-en-zh',
      ModelType.opusMtZhEn => 'opus-mt-zh-en',
      ModelType.opusMtEnDe => 'opus-mt-en-de',
      ModelType.opusMtEnFr => 'opus-mt-en-fr',
      ModelType.opusMtEnEs => 'opus-mt-en-es',
      ModelType.opusMtEnIt => 'opus-mt-en-it',
      ModelType.opusMtEnRu => 'opus-mt-en-ru',
      ModelType.opusMtEnAr => 'opus-mt-en-ar',
      ModelType.opusMtEnJap => 'opus-mt-en-jap',
      ModelType.opusMtEnKo => 'opus-mt-en-ko',
      ModelType.opusMtDeEn => 'opus-mt-de-en',
      ModelType.opusMtFrEn => 'opus-mt-fr-en',
      ModelType.opusMtEsEn => 'opus-mt-es-en',
      ModelType.opusMtItEn => 'opus-mt-it-en',
      ModelType.opusMtRuEn => 'opus-mt-ru-en',
      ModelType.opusMtArEn => 'opus-mt-ar-en',
      ModelType.opusMtJapEn => 'opus-mt-jap-en',
      ModelType.opusMtKoEn => 'opus-mt-ko-en',
      ModelType.opusMtZhDe => 'opus-mt-zh-de',
      ModelType.opusMtDeZh => 'opus-mt-de-zh',
      ModelType.opusMtZhIt => 'opus-mt-zh-it',
      ModelType.opusMtZhVi => 'opus-mt-zh-vi',
      ModelType.opusMtZhJap => 'opus-mt-zh-jap',
      ModelType.opusMtFiZh => 'opus-mt-fi-zh',
      ModelType.opusMtSvZh => 'opus-mt-sv-zh',
      ModelType.opusMtZhBg => 'opus-mt-zh-bg',
      ModelType.opusMtZhFi => 'opus-mt-zh-fi',
      ModelType.opusMtZhHe => 'opus-mt-zh-he',
      ModelType.opusMtZhMs => 'opus-mt-zh-ms',
      ModelType.opusMtZhNl => 'opus-mt-zh-nl',
      ModelType.opusMtZhSv => 'opus-mt-zh-sv',
      ModelType.opusMtZhUk => 'opus-mt-zh-uk',
    };
  }

  String get sizeInfo {
    return switch (this) {
      ModelType.opusMtEnZh || ModelType.opusMtZhEn ||
      ModelType.opusMtEnJap || ModelType.opusMtJapEn ||
      ModelType.opusMtEnKo || ModelType.opusMtKoEn ||
      ModelType.opusMtZhJap => '~400MB',
      _ => '~100MB',
    };
  }

  int get approximateSizeBytes {
    return switch (this) {
      ModelType.opusMtEnZh || ModelType.opusMtZhEn ||
      ModelType.opusMtEnJap || ModelType.opusMtJapEn ||
      ModelType.opusMtEnKo || ModelType.opusMtKoEn ||
      ModelType.opusMtZhJap => 400 * 1024 * 1024,
      _ => 100 * 1024 * 1024,
    };
  }

  String? get modelHubUrl {
    return switch (this) {
      ModelType.opusMtEnZh => 'gaudi/opus-mt-en-zh-ctranslate2',
      ModelType.opusMtZhEn => 'gaudi/opus-mt-zh-en-ctranslate2',
      ModelType.opusMtEnDe => 'gaudi/opus-mt-en-de-ctranslate2',
      ModelType.opusMtEnFr => 'gaudi/opus-mt-en-fr-ctranslate2',
      ModelType.opusMtEnEs => 'gaudi/opus-mt-en-es-ctranslate2',
      ModelType.opusMtEnIt => 'gaudi/opus-mt-en-it-ctranslate2',
      ModelType.opusMtEnRu => 'gaudi/opus-mt-en-ru-ctranslate2',
      ModelType.opusMtEnAr => 'gaudi/opus-mt-en-ar-ctranslate2',
      ModelType.opusMtEnJap => 'gaudi/opus-mt-en-jap-ctranslate2',
      ModelType.opusMtEnKo => 'eeyzs1/opus-mt-tc-big-en-ko-ct2',
      ModelType.opusMtDeEn => 'gaudi/opus-mt-de-en-ctranslate2',
      ModelType.opusMtFrEn => 'gaudi/opus-mt-fr-en-ctranslate2',
      ModelType.opusMtEsEn => 'gaudi/opus-mt-es-en-ctranslate2',
      ModelType.opusMtItEn => 'gaudi/opus-mt-it-en-ctranslate2',
      ModelType.opusMtRuEn => 'gaudi/opus-mt-ru-en-ctranslate2',
      ModelType.opusMtArEn => 'gaudi/opus-mt-ar-en-ctranslate2',
      ModelType.opusMtJapEn => 'gaudi/opus-mt-jap-en-ctranslate2',
      ModelType.opusMtKoEn => 'gaudi/opus-mt-ko-en-ctranslate2',
      ModelType.opusMtZhDe => 'manancode/opus-mt-zh-de-ctranslate2-android',
      ModelType.opusMtDeZh => 'manancode/opus-mt-de-ZH-ctranslate2-android',
      ModelType.opusMtZhIt => 'manancode/opus-mt-zh-it-ctranslate2-android',
      ModelType.opusMtZhVi => 'manancode/opus-mt-zh-vi-ctranslate2-android',
      ModelType.opusMtZhJap => 'eeyzs1/opus-mt-tc-big-zh-ja-ct2',
      ModelType.opusMtFiZh => 'manancode/opus-mt-fi-ZH-ctranslate2-android',
      ModelType.opusMtSvZh => 'manancode/opus-mt-sv-ZH-ctranslate2-android',
      ModelType.opusMtZhBg => 'manancode/opus-mt-zh-bg-ctranslate2-android',
      ModelType.opusMtZhFi => 'manancode/opus-mt-zh-fi-ctranslate2-android',
      ModelType.opusMtZhHe => 'manancode/opus-mt-zh-he-ctranslate2-android',
      ModelType.opusMtZhMs => 'manancode/opus-mt-zh-ms-ctranslate2-android',
      ModelType.opusMtZhNl => 'manancode/opus-mt-zh-nl-ctranslate2-android',
      ModelType.opusMtZhSv => 'manancode/opus-mt-zh-sv-ctranslate2-android',
      ModelType.opusMtZhUk => 'manancode/opus-mt-zh-uk-ctranslate2-android',
    };
  }

  String? get modelScopeUrl {
    return switch (this) {
      ModelType.opusMtEnZh => 'eeyzs1/opus-mt-en-zh-ct2',
      ModelType.opusMtZhEn => 'eeyzs1/opus-mt-zh-en-ct2',
      ModelType.opusMtEnDe => 'eeyzs1/opus-mt-en-de-ct2',
      ModelType.opusMtEnFr => 'eeyzs1/opus-mt-en-fr-ct2',
      ModelType.opusMtEnEs => 'eeyzs1/opus-mt-en-es-ct2',
      ModelType.opusMtEnIt => 'eeyzs1/opus-mt-en-it-ct2',
      ModelType.opusMtEnRu => 'eeyzs1/opus-mt-en-ru-ct2',
      ModelType.opusMtEnAr => 'eeyzs1/opus-mt-en-ar-ct2',
      ModelType.opusMtEnJap => 'eeyzs1/opus-mt-en-jap-ct2',
      ModelType.opusMtEnKo => 'eeyzs1/opus-mt-en-ko-ct2',
      ModelType.opusMtDeEn => 'eeyzs1/opus-mt-de-en-ct2',
      ModelType.opusMtFrEn => 'eeyzs1/opus-mt-fr-en-ct2',
      ModelType.opusMtEsEn => 'eeyzs1/opus-mt-es-en-ct2',
      ModelType.opusMtItEn => 'eeyzs1/opus-mt-it-en-ct2',
      ModelType.opusMtRuEn => 'eeyzs1/opus-mt-ru-en-ct2',
      ModelType.opusMtArEn => 'eeyzs1/opus-mt-ar-en-ct2',
      ModelType.opusMtJapEn => 'eeyzs1/opus-mt-jap-en-ct2',
      ModelType.opusMtKoEn => 'eeyzs1/opus-mt-ko-en-ct2',
      ModelType.opusMtZhDe => 'eeyzs1/opus-mt-zh-de-ct2',
      ModelType.opusMtDeZh => 'eeyzs1/opus-mt-de-zh-ct2',
      ModelType.opusMtZhIt => 'eeyzs1/opus-mt-zh-it-ct2',
      ModelType.opusMtZhVi => 'eeyzs1/opus-mt-zh-vi-ct2',
      ModelType.opusMtZhJap => 'eeyzs1/opus-mt-zh-jap-ct2',
      ModelType.opusMtFiZh => 'eeyzs1/opus-mt-fi-zh-ct2',
      ModelType.opusMtSvZh => 'eeyzs1/opus-mt-sv-zh-ct2',
      ModelType.opusMtZhBg => 'eeyzs1/opus-mt-zh-bg-ct2',
      ModelType.opusMtZhFi => 'eeyzs1/opus-mt-zh-fi-ct2',
      ModelType.opusMtZhHe => 'eeyzs1/opus-mt-zh-he-ct2',
      ModelType.opusMtZhMs => 'eeyzs1/opus-mt-zh-ms-ct2',
      ModelType.opusMtZhNl => 'eeyzs1/opus-mt-zh-nl-ct2',
      ModelType.opusMtZhSv => 'eeyzs1/opus-mt-zh-sv-ct2',
      ModelType.opusMtZhUk => 'eeyzs1/opus-mt-zh-uk-ct2',
    };
  }

  List<String> get requiredFiles {
    return [
      'model.bin',
      'config.json',
      'shared_vocabulary.json',
    ];
  }

  HardwareRequirements get hardwareRequirements {
    return switch (this) {
      ModelType.opusMtEnZh || ModelType.opusMtZhEn => const HardwareRequirements(
          minimumRamGb: 2,
          recommendedRamGb: 4,
          minimumStorageMb: 300,
        ),
      _ => const HardwareRequirements(
          minimumRamGb: 3,
          recommendedRamGb: 6,
          minimumStorageMb: 500,
        ),
    };
  }

  (String, String) get languagePair {
    return switch (this) {
      ModelType.opusMtEnZh => ('en', 'zh'),
      ModelType.opusMtZhEn => ('zh', 'en'),
      ModelType.opusMtEnDe => ('en', 'de'),
      ModelType.opusMtEnFr => ('en', 'fr'),
      ModelType.opusMtEnEs => ('en', 'es'),
      ModelType.opusMtEnIt => ('en', 'it'),
      ModelType.opusMtEnRu => ('en', 'ru'),
      ModelType.opusMtEnAr => ('en', 'ar'),
      ModelType.opusMtEnJap => ('en', 'ja'),
      ModelType.opusMtEnKo => ('en', 'ko'),
      ModelType.opusMtDeEn => ('de', 'en'),
      ModelType.opusMtFrEn => ('fr', 'en'),
      ModelType.opusMtEsEn => ('es', 'en'),
      ModelType.opusMtItEn => ('it', 'en'),
      ModelType.opusMtRuEn => ('ru', 'en'),
      ModelType.opusMtArEn => ('ar', 'en'),
      ModelType.opusMtJapEn => ('ja', 'en'),
      ModelType.opusMtKoEn => ('ko', 'en'),
      ModelType.opusMtZhDe => ('zh', 'de'),
      ModelType.opusMtDeZh => ('de', 'zh'),
      ModelType.opusMtZhIt => ('zh', 'it'),
      ModelType.opusMtZhVi => ('zh', 'vi'),
      ModelType.opusMtZhJap => ('zh', 'ja'),
      ModelType.opusMtFiZh => ('fi', 'zh'),
      ModelType.opusMtSvZh => ('sv', 'zh'),
      ModelType.opusMtZhBg => ('zh', 'bg'),
      ModelType.opusMtZhFi => ('zh', 'fi'),
      ModelType.opusMtZhHe => ('zh', 'he'),
      ModelType.opusMtZhMs => ('zh', 'ms'),
      ModelType.opusMtZhNl => ('zh', 'nl'),
      ModelType.opusMtZhSv => ('zh', 'sv'),
      ModelType.opusMtZhUk => ('zh', 'uk'),
    };
  }

  String get pythonModelTypeKey {
    return switch (this) {
      ModelType.opusMtEnZh => 'opus_mt_en_zh',
      ModelType.opusMtZhEn => 'opus_mt_zh_en',
      ModelType.opusMtEnDe => 'opus_mt_en_de',
      ModelType.opusMtEnFr => 'opus_mt_en_fr',
      ModelType.opusMtEnEs => 'opus_mt_en_es',
      ModelType.opusMtEnIt => 'opus_mt_en_it',
      ModelType.opusMtEnRu => 'opus_mt_en_ru',
      ModelType.opusMtEnAr => 'opus_mt_en_ar',
      ModelType.opusMtEnJap => 'opus_mt_en_ja',
      ModelType.opusMtEnKo => 'opus_mt_en_ko',
      ModelType.opusMtDeEn => 'opus_mt_de_en',
      ModelType.opusMtFrEn => 'opus_mt_fr_en',
      ModelType.opusMtEsEn => 'opus_mt_es_en',
      ModelType.opusMtItEn => 'opus_mt_it_en',
      ModelType.opusMtRuEn => 'opus_mt_ru_en',
      ModelType.opusMtArEn => 'opus_mt_ar_en',
      ModelType.opusMtJapEn => 'opus_mt_ja_en',
      ModelType.opusMtKoEn => 'opus_mt_ko_en',
      ModelType.opusMtZhDe => 'opus_mt_zh_de',
      ModelType.opusMtDeZh => 'opus_mt_de_zh',
      ModelType.opusMtZhIt => 'opus_mt_zh_it',
      ModelType.opusMtZhVi => 'opus_mt_zh_vi',
      ModelType.opusMtZhJap => 'opus_mt_zh_ja',
      ModelType.opusMtFiZh => 'opus_mt_fi_zh',
      ModelType.opusMtSvZh => 'opus_mt_sv_zh',
      ModelType.opusMtZhBg => 'opus_mt_zh_bg',
      ModelType.opusMtZhFi => 'opus_mt_zh_fi',
      ModelType.opusMtZhHe => 'opus_mt_zh_he',
      ModelType.opusMtZhMs => 'opus_mt_zh_ms',
      ModelType.opusMtZhNl => 'opus_mt_zh_nl',
      ModelType.opusMtZhSv => 'opus_mt_zh_sv',
      ModelType.opusMtZhUk => 'opus_mt_zh_uk',
    };
  }

  bool get isMultiLingual => false;

  String? getTargetLangCode(String targetLang) => null;

  String get supportedLanguagesText => '';
}

@Riverpod(keepAlive: true)
class ModelManager extends _$ModelManager {
  static const String _kSelectedModelKey = 'selected_model';
  static const String _kModelsPathKey = 'models_path';
  static const String _kCustomModelsKey = 'custom_models';
  static const String _kModelType = 'model';

  CancelToken? _cancelToken;
  final _registry = ResourceRegistry();

  List<CustomModelEntry> _customModels = [];
  List<CustomModelEntry> get customModels => _customModels;

  @override
  ModelState build() {
    return ModelState(type: ModelType.opusMtEnZh);
  }

  Future<void> _loadCustomModels() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kCustomModelsKey);
    if (jsonStr != null) {
      try {
        final list = jsonDecode(jsonStr) as List;
        _customModels = list.map((e) => CustomModelEntry.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Error loading custom models: $e');
        _customModels = [];
      }
    }
  }

  Future<void> _saveCustomModels() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_customModels.map((e) => e.toJson()).toList());
    await prefs.setString(_kCustomModelsKey, jsonStr);
  }

  static bool isValidModelDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return false;
    if (File(path.join(dirPath, 'model.bin')).existsSync() &&
        File(path.join(dirPath, 'config.json')).existsSync()) {
      if (File(path.join(dirPath, 'shared_vocabulary.json')).existsSync()) return true;
      if (File(path.join(dirPath, 'source_vocabulary.json')).existsSync() &&
          File(path.join(dirPath, 'target_vocabulary.json')).existsSync()) {
        return true;
      }
    }
    return false;
  }

  static final RegExp _opusMtPattern = RegExp(r'^opus-mt-([a-z]{2,3})-([a-z]{2,3})$');

  static const Map<String, String> _folderNameAliases = {
    'opus-mt-tc-big-en-ko': 'opus-mt-en-ko',
    'opus-mt-tc-big-zh-ja': 'opus-mt-zh-jap',
    'opus-mt-de-ZH': 'opus-mt-de-zh',
    'opus-mt-fi-ZH': 'opus-mt-fi-zh',
    'opus-mt-sv-ZH': 'opus-mt-sv-zh',
  };

  static String? normalizeFolderName(String name) {
    if (_opusMtPattern.hasMatch(name)) return name;
    return _folderNameAliases[name];
  }

  static CustomModelEntry? parseFolderName(String folderPath) {
    final name = path.basename(folderPath);
    final normalizedName = normalizeFolderName(name);
    if (normalizedName != null) {
      final match = _opusMtPattern.firstMatch(normalizedName);
      if (match != null) {
        return CustomModelEntry(
          folderName: normalizedName,
          sourceLang: match.group(1)!,
          targetLang: match.group(2)!,
          localPath: folderPath,
        );
      }
    }
    final match = _opusMtPattern.firstMatch(name);
    if (match == null) return null;
    return CustomModelEntry(
      folderName: name,
      sourceLang: match.group(1)!,
      targetLang: match.group(2)!,
      localPath: folderPath,
    );
  }

  Future<String?> importLocalModel(String folderPath) async {
    if (!isValidModelDirectory(folderPath)) {
      return 'Missing required files (model.bin, config.json, shared_vocabulary.json or source_vocabulary.json + target_vocabulary.json)';
    }

    final entry = parseFolderName(folderPath);
    if (entry == null) {
      return 'Invalid folder name format\nSupported: opus-mt-[l1]-[l2] (e.g. opus-mt-zh-de)';
    }

    final existingKnown = ModelType.values.where(
      (t) => t.folderName == entry.folderName,
    );
    if (existingKnown.isNotEmpty) {
      final pair = existingKnown.first.languagePair;
      await _registry.addOrUpdate(ResourceEntry(
        id: entry.folderName,
        type: _kModelType,
        localPath: folderPath,
        sourceLang: pair.$1,
        targetLang: pair.$2,
        isEnabled: true,
      ),);

      final enabled = Set<ModelType>.from(state.enabledModelTypes);
      if (!enabled.contains(existingKnown.first)) {
        enabled.add(existingKnown.first);
        state = state.copyWith(enabledModelTypes: enabled);
      }
      return null;
    }

    final existingCustom = _customModels.where((e) => e.folderName == entry.folderName);
    if (existingCustom.isNotEmpty) {
      _customModels = _customModels.where((e) => e.folderName != entry.folderName).toList();
    }

    _customModels.add(CustomModelEntry(
      folderName: entry.folderName,
      sourceLang: entry.sourceLang,
      targetLang: entry.targetLang,
      localPath: folderPath,
    ),);
    await _saveCustomModels();
    return null;
  }

  Future<void> removeCustomModel(String folderName) async {
    _customModels = _customModels.where((e) => e.folderName != folderName).toList();
    await _saveCustomModels();
  }

  Future<void> loadSavedModel() async {
    await _registry.load();
    await _loadCustomModels();

    final enabled = <ModelType>{};
    for (final entry in _registry.getEnabledByType(_kModelType)) {
      for (final type in ModelType.values) {
        if (type.folderName == entry.id) {
          enabled.add(type);
          break;
        }
      }
    }
    state = state.copyWith(enabledModelTypes: enabled);

    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_kSelectedModelKey);
    if (index != null && index >= 0 && index < ModelType.values.length) {
      state = state.copyWith(type: ModelType.values[index]);
    }
  }

  Future<void> selectModel(ModelType model) async {
    state = state.copyWith(type: model);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSelectedModelKey, model.index);
  }

  Future<void> toggleModelEnabled(ModelType model) async {
    final current = Set<ModelType>.from(state.enabledModelTypes);
    final enable = !current.contains(model);
    if (enable) {
      current.add(model);
    } else {
      current.remove(model);
    }
    state = state.copyWith(enabledModelTypes: current);
    await _registry.setEnabled(model.folderName, enable, type: _kModelType);
  }

  ModelType? getEnabledModelForLangPair(String sourceCode, String targetCode) {
    return getEnabledModelsForLangPair(sourceCode, targetCode).firstOrNull;
  }

  List<ModelType> getEnabledModelsForLangPair(String sourceCode, String targetCode) {
    final results = <ModelType>[];
    for (final type in state.enabledModelTypes) {
      final pair = type.languagePair;
      if (pair.$1 == sourceCode && pair.$2 == targetCode) {
        final entry = _registry.getEntry(type.folderName);
        if (entry != null && entry.pathExists) results.add(type);
      }
    }
    return results;
  }

  Future<void> autoEnableDownloadedModels() async {
    await _registry.load();
    final enabled = Set<ModelType>.from(state.enabledModelTypes);
    bool changed = false;

    final toRemove = <ModelType>[];
    for (final type in enabled) {
      if (!await isModelDownloaded(type)) {
        toRemove.add(type);
      }
    }
    for (final type in toRemove) {
      enabled.remove(type);
      changed = true;
    }

    for (final type in ModelType.values) {
      if (!enabled.contains(type) && await isModelDownloaded(type)) {
        enabled.add(type);
        final pair = type.languagePair;
        final existingEntry = _registry.getEntry(type.folderName);
        await _registry.addOrUpdate(ResourceEntry(
          id: type.folderName,
          type: _kModelType,
          localPath: existingEntry?.localPath ?? (await getValidModelPath(type)) ?? '',
          sourceLang: pair.$1,
          targetLang: pair.$2,
          isEnabled: true,
        ),);
        changed = true;
      }
    }

    if (changed) {
      state = state.copyWith(enabledModelTypes: enabled);
    }
  }

  Future<void> migrateExistingModels() async {
    await _registry.load();

    final modelsDir = await getModelsDirectory();
    for (final type in ModelType.values) {
      if (_registry.isRegistered(type.folderName, type: _kModelType)) continue;

      final modelDir = Directory(path.join(modelsDir.path, type.folderName));
      if (!modelDir.existsSync()) continue;

      bool allFilesExist = true;
      for (final file in type.requiredFiles) {
        if (!File(path.join(modelDir.path, file)).existsSync()) {
          allFilesExist = false;
          break;
        }
      }
      if (allFilesExist) {
        final pair = type.languagePair;
        await _registry.addOrUpdate(ResourceEntry(
          id: type.folderName,
          type: _kModelType,
          localPath: modelDir.path,
          sourceLang: pair.$1,
          targetLang: pair.$2,
          isEnabled: false,
        ),);
      }
    }

    final savedPath = await getSavedModelsPath();
    if (savedPath != null && savedPath != modelsDir.path) {
      final customDir = Directory(savedPath);
      if (customDir.existsSync()) {
        for (final type in ModelType.values) {
          if (_registry.isRegistered(type.folderName, type: _kModelType)) continue;

          final modelDir = Directory(path.join(customDir.path, type.folderName));
          if (!modelDir.existsSync()) continue;

          bool allFilesExist = true;
          for (final file in type.requiredFiles) {
            if (!File(path.join(modelDir.path, file)).existsSync()) {
              allFilesExist = false;
              break;
            }
          }
          if (allFilesExist) {
            final pair = type.languagePair;
            await _registry.addOrUpdate(ResourceEntry(
              id: type.folderName,
              type: _kModelType,
              localPath: modelDir.path,
              sourceLang: pair.$1,
              targetLang: pair.$2,
              isEnabled: false,
            ),);
          }
        }
      }
    }
  }

  Future<void> setModelsPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModelsPathKey, path);
  }

  Future<String?> getSavedModelsPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kModelsPathKey);
  }

  Future<Directory> getModelsDirectory() async {
    final savedPath = await getSavedModelsPath();
    if (savedPath != null && Directory(savedPath).existsSync()) {
      return Directory(savedPath);
    }

    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(dir.path, 'models', 'translation'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<bool> isModelDownloaded(ModelType modelType) async {
    final entry = _registry.getEntry(modelType.folderName);
    if (entry != null && entry.pathExists) {
      bool allFilesExist = true;
      for (final file in modelType.requiredFiles) {
        if (!File(path.join(entry.localPath, file)).existsSync()) {
          allFilesExist = false;
          break;
        }
      }
      if (allFilesExist) return true;
      await _registry.remove(modelType.folderName, type: _kModelType);
    }

    final modelsDir = await getModelsDirectory();
    final modelDir = Directory(path.join(modelsDir.path, modelType.folderName));
    if (!modelDir.existsSync()) return false;

    for (final file in modelType.requiredFiles) {
      if (!File(path.join(modelDir.path, file)).existsSync()) return false;
    }

    final pair = modelType.languagePair;
    await _registry.addOrUpdate(ResourceEntry(
      id: modelType.folderName,
      type: _kModelType,
      localPath: modelDir.path,
      sourceLang: pair.$1,
      targetLang: pair.$2,
      isEnabled: _registry.isEnabled(modelType.folderName, type: _kModelType),
    ),);
    return true;
  }

  Future<bool> isModelAvailable(ModelType modelType) async {
    return isModelDownloaded(modelType);
  }

  bool isCustomModelDownloaded(String folderName) {
    return _customModels.any((e) => e.folderName == folderName);
  }

  Future<bool> isAnyModelDownloaded() async {
    for (final type in ModelType.values) {
      if (await isModelDownloaded(type)) {
        return true;
      }
    }
    return _customModels.isNotEmpty;
  }

  Future<void> deleteModel(ModelType modelType) async {
    final entry = _registry.getEntry(modelType.folderName);
    String? deletedPath;

    if (entry != null && Directory(entry.localPath).existsSync()) {
      deletedPath = entry.localPath;
    } else {
      final modelsDir = await getModelsDirectory();
      final modelDir = Directory(path.join(modelsDir.path, modelType.folderName));
      if (modelDir.existsSync()) {
        deletedPath = modelDir.path;
      }
    }

    try {
      if (deletedPath != null) {
        await Directory(deletedPath).delete(recursive: true);
      }

      await _registry.remove(modelType.folderName, type: _kModelType);

      final enabled = Set<ModelType>.from(state.enabledModelTypes);
      if (enabled.contains(modelType)) {
        enabled.remove(modelType);
        state = state.copyWith(enabledModelTypes: enabled);
      }

      if (state.type == modelType) {
        ModelType? newSelectedModel;

        for (final type in ModelType.values) {
          if (type != modelType) {
            final isDownloaded = await isModelDownloaded(type);
            if (isDownloaded) {
              newSelectedModel = type;
              break;
            }
          }
        }

        if (newSelectedModel != null) {
          await selectModel(newSelectedModel);
        } else {
          await selectModel(ModelType.values.first);
        }
      }
    } catch (e) {
      debugPrint('Error deleting model: $e');
    }
  }

  Future<String?> getValidModelPath(ModelType modelType) async {
    final entry = _registry.getEntry(modelType.folderName);
    if (entry != null && entry.pathExists) {
      bool allFilesExist = true;
      for (final file in modelType.requiredFiles) {
        if (!File(path.join(entry.localPath, file)).existsSync()) {
          allFilesExist = false;
          break;
        }
      }
      if (allFilesExist) return entry.localPath;
      await _registry.remove(modelType.folderName, type: _kModelType);
    }

    final modelsDir = await getModelsDirectory();
    final modelDir = Directory(path.join(modelsDir.path, modelType.folderName));

    if (modelDir.existsSync()) {
      bool allFilesExist = true;
      for (final file in modelType.requiredFiles) {
        if (!File(path.join(modelDir.path, file)).existsSync()) {
          allFilesExist = false;
          break;
        }
      }
      if (allFilesExist) {
        final pair = modelType.languagePair;
        await _registry.addOrUpdate(ResourceEntry(
          id: modelType.folderName,
          type: _kModelType,
          localPath: modelDir.path,
          sourceLang: pair.$1,
          targetLang: pair.$2,
          isEnabled: _registry.isEnabled(modelType.folderName, type: _kModelType),
        ),);
        return modelDir.path;
      }
    }

    return null;
  }

  Future<String?> getModelPath(ModelType modelType) async {
    return getValidModelPath(modelType);
  }

  String? getCustomModelPath(String folderName) {
    final entry = _customModels.where((e) => e.folderName == folderName);
    if (entry.isEmpty) return null;
    return entry.first.localPath;
  }

  Future<String?> getModelPathByFolderName(String folderName) async {
    for (final type in ModelType.values) {
      if (type.folderName == folderName) {
        return getValidModelPath(type);
      }
    }
    return getCustomModelPath(folderName);
  }

  Future<void> startDownload({
    String? customDirectory,
    String downloadSource = 'huggingface',
    bool? huggingFaceAvailable,
    bool? modelScopeAvailable,
  }) async {
    if (state.downloadStatus == ModelDownloadStatus.downloading) {
      return;
    }

    final hfRepoId = state.type.modelHubUrl;
    final scopeRepoId = state.type.modelScopeUrl;
    final repoId = hfRepoId ?? scopeRepoId;
    if (repoId == null) {
      state = state.copyWith(
        downloadStatus: ModelDownloadStatus.failed,
        downloadError: 'This model does not support direct download. Please use local import.',
      );
      return;
    }

    state = state.copyWith(
      downloadStatus: ModelDownloadStatus.downloading,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: state.type.approximateSizeBytes,
      downloadError: null,
    );
    _cancelToken = CancelToken();

    try {
      String savePath;

      if (customDirectory != null && Directory(customDirectory).existsSync()) {
        savePath = path.join(customDirectory, state.type.folderName);
      } else {
        final modelsDir = await getModelsDirectory();
        savePath = path.join(modelsDir.path, state.type.folderName);
      }

      final saveDir = Directory(savePath);
      if (await saveDir.exists()) {
        await saveDir.delete(recursive: true);
      }
      await saveDir.create(recursive: true);

      bool success;
      if (downloadSource == 'auto') {
        success = await _downloadWithAutoFallback(
          hfRepoId,
          scopeRepoId,
          savePath,
          hfAvailable: huggingFaceAvailable,
          scopeAvailable: modelScopeAvailable,
        );
      } else if (downloadSource == 'modelscope') {
        if (scopeRepoId == null) {
          state = state.copyWith(
            downloadStatus: ModelDownloadStatus.failed,
            downloadError: 'This model is not available on ModelScope. Please switch to HuggingFace or Auto Detect.',
          );
          return;
        }
        success = await _downloadFromSource(scopeRepoId, savePath, 'modelscope');
      } else {
        if (hfRepoId == null) {
          state = state.copyWith(
            downloadStatus: ModelDownloadStatus.failed,
            downloadError: 'This model is not available on HuggingFace. Please switch to ModelScope or Auto Detect.',
          );
          return;
        }
        success = await _downloadFromSource(hfRepoId, savePath, 'huggingface');
      }

      if (success) {
        final pair = state.type.languagePair;
        await _registry.addOrUpdate(ResourceEntry(
          id: state.type.folderName,
          type: _kModelType,
          localPath: savePath,
          sourceLang: pair.$1,
          targetLang: pair.$2,
          isEnabled: true,
        ),);

        if (customDirectory != null && Directory(customDirectory).existsSync()) {
          final prefs = await SharedPreferences.getInstance();
          final existingPath = prefs.getString(_kModelsPathKey);
          if (existingPath == null || !Directory(existingPath).existsSync()) {
            await prefs.setString(_kModelsPathKey, customDirectory);
          }
        }

        final enabled = Set<ModelType>.from(state.enabledModelTypes);
        if (!enabled.contains(state.type)) {
          enabled.add(state.type);
          state = state.copyWith(enabledModelTypes: enabled);
        }

        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.completed,
          downloadProgress: 1.0,
        );
      } else {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.failed,
          downloadError: 'Download failed, please try again.',
        );
      }
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.idle,
          downloadError: 'Download cancelled.',
        );
      } else {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.failed,
          downloadError: 'Download failed: ${e.toString()}',
        );
      }
    }
  }

  Future<bool> _downloadWithAutoFallback(
    String? hfRepoId,
    String? scopeRepoId,
    String savePath, {
    bool? hfAvailable,
    bool? scopeAvailable,
  }) async {
    if (hfAvailable == false && scopeRepoId != null && scopeAvailable != false) {
      debugPrint('[ModelManager] Auto mode: HuggingFace unavailable, trying ModelScope first...');
      try {
        return await _downloadFromSource(scopeRepoId, savePath, 'modelscope');
      } catch (e) {
        debugPrint('[ModelManager] ModelScope also failed ($e), trying HuggingFace as last resort...');
        if (_cancelToken?.isCancelled ?? false) return false;
        if (hfRepoId == null) {
          throw Exception('All download sources are unavailable. Please check your network.');
        }
        try {
          return await _downloadFromSource(hfRepoId, savePath, 'huggingface');
        } catch (e2) {
          throw Exception('All download sources are unavailable. Please check your network.');
        }
      }
    }

    if (hfRepoId != null) {
      debugPrint('[ModelManager] Auto mode: trying HuggingFace first...');
      try {
        return await _downloadFromSource(hfRepoId, savePath, 'huggingface');
      } catch (e) {
        debugPrint('[ModelManager] HuggingFace failed ($e), falling back to ModelScope...');
        if (_cancelToken?.isCancelled ?? false) return false;
        if (scopeRepoId == null) {
          throw Exception(
            'This model is not available on ModelScope. Try HuggingFace (may require proxy) or choose another model.',
          );
        }
        return await _downloadFromSource(scopeRepoId, savePath, 'modelscope');
      }
    }

    if (scopeRepoId != null) {
      debugPrint('[ModelManager] Auto mode: HuggingFace unavailable, trying ModelScope...');
      return await _downloadFromSource(scopeRepoId, savePath, 'modelscope');
    }

    throw Exception('No download source available for this model.');
  }

  Future<bool> _downloadFromSource(String repoId, String savePath, String source) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(seconds: 30),
    ),);
    final files = state.type.requiredFiles;
    final totalFiles = files.length;

    for (int i = 0; i < totalFiles; i++) {
      final fileName = files[i];
      final url = switch (source) {
        'modelscope' =>
          'https://modelscope.cn/models/$repoId/resolve/master/$fileName',
        _ => 'https://huggingface.co/$repoId/resolve/main/$fileName',
      };
      final filePath = path.join(savePath, fileName);

      if (_cancelToken?.isCancelled ?? false) return false;

      debugPrint('[ModelManager] Downloading $fileName from $source ...');
      await dio.download(
        url,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final baseProgress = i / totalFiles;
            final fileProgress = received / total / totalFiles;
            state = state.copyWith(
              downloadProgress: baseProgress + fileProgress,
              downloadedBytes: received,
              totalBytes: total,
            );
          }
        },
      );
    }

    state = state.copyWith(
      downloadProgress: 1.0,
      downloadedBytes: state.totalBytes,
    );
    return true;
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }

  void resetDownload() {
    state = state.copyWith(
      downloadStatus: ModelDownloadStatus.idle,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: 0,
      downloadError: null,
    );
  }
}
