import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

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
  final ModelDownloadStatus downloadStatus;
  final double downloadProgress;
  final int downloadedBytes;
  final int totalBytes;
  final String? downloadError;

  ModelState({
    required this.type,
    this.downloadStatus = ModelDownloadStatus.idle,
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.downloadError,
  });

  ModelState copyWith({
    ModelType? type,
    ModelDownloadStatus? downloadStatus,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    String? downloadError,
  }) {
    return ModelState(
      type: type ?? this.type,
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
      ModelType.opusMtEnZh => 'OPUS-MT en→zh (英译中)',
      ModelType.opusMtZhEn => 'OPUS-MT zh→en (中译英)',
      ModelType.opusMtEnDe => 'OPUS-MT en→de (英译德)',
      ModelType.opusMtEnFr => 'OPUS-MT en→fr (英译法)',
      ModelType.opusMtEnEs => 'OPUS-MT en→es (英译西)',
      ModelType.opusMtEnIt => 'OPUS-MT en→it (英译意)',
      ModelType.opusMtEnRu => 'OPUS-MT en→ru (英译俄)',
      ModelType.opusMtEnAr => 'OPUS-MT en→ar (英译阿)',
      ModelType.opusMtEnJap => 'OPUS-MT en→ja (英译日)',
      ModelType.opusMtEnKo => 'OPUS-MT en→ko (英译韩)',
      ModelType.opusMtDeEn => 'OPUS-MT de→en (德译英)',
      ModelType.opusMtFrEn => 'OPUS-MT fr→en (法译英)',
      ModelType.opusMtEsEn => 'OPUS-MT es→en (西译英)',
      ModelType.opusMtItEn => 'OPUS-MT it→en (意译英)',
      ModelType.opusMtRuEn => 'OPUS-MT ru→en (俄译英)',
      ModelType.opusMtArEn => 'OPUS-MT ar→en (阿译英)',
      ModelType.opusMtJapEn => 'OPUS-MT ja→en (日译英)',
      ModelType.opusMtKoEn => 'OPUS-MT ko→en (韩译英)',
      ModelType.opusMtZhDe => 'OPUS-MT zh→de (中译德)',
      ModelType.opusMtDeZh => 'OPUS-MT de→zh (德译中)',
      ModelType.opusMtZhIt => 'OPUS-MT zh→it (中译意)',
      ModelType.opusMtZhVi => 'OPUS-MT zh→vi (中译越)',
      ModelType.opusMtZhJap => 'OPUS-MT zh→ja (中译日)',
      ModelType.opusMtFiZh => 'OPUS-MT fi→zh (芬译中)',
      ModelType.opusMtSvZh => 'OPUS-MT sv→zh (瑞译中)',
      ModelType.opusMtZhBg => 'OPUS-MT zh→bg (中译保)',
      ModelType.opusMtZhFi => 'OPUS-MT zh→fi (中译芬)',
      ModelType.opusMtZhHe => 'OPUS-MT zh→he (中译希)',
      ModelType.opusMtZhMs => 'OPUS-MT zh→ms (中译马)',
      ModelType.opusMtZhNl => 'OPUS-MT zh→nl (中译荷)',
      ModelType.opusMtZhSv => 'OPUS-MT zh→sv (中译瑞)',
      ModelType.opusMtZhUk => 'OPUS-MT zh→uk (中译乌)',
    };
  }

  String get description {
    return switch (this) {
      ModelType.opusMtEnZh || ModelType.opusMtZhEn =>
        'Encoder-Decoder 架构，专为中英互译优化\n专为长句和段落翻译设计',
      _ => 'Helsinki-NLP OPUS-MT 翻译模型\n质量高、速度快',
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
      ModelType.opusMtEnZh || ModelType.opusMtZhEn => '约150MB / ~150MB',
      _ => '约300MB / ~300MB',
    };
  }

  int get approximateSizeBytes {
    return switch (this) {
      ModelType.opusMtEnZh || ModelType.opusMtZhEn => 150 * 1024 * 1024,
      _ => 300 * 1024 * 1024,
    };
  }

  String? get modelHubUrl {
    return switch (this) {
      ModelType.opusMtEnZh => 'Helsinki-NLP/opus-mt-en-zh',
      ModelType.opusMtZhEn => 'Helsinki-NLP/opus-mt-zh-en',
      ModelType.opusMtEnDe => 'Helsinki-NLP/opus-mt-en-de',
      ModelType.opusMtEnFr => 'Helsinki-NLP/opus-mt-en-fr',
      ModelType.opusMtEnEs => 'Helsinki-NLP/opus-mt-en-es',
      ModelType.opusMtEnIt => 'Helsinki-NLP/opus-mt-en-it',
      ModelType.opusMtEnRu => 'Helsinki-NLP/opus-mt-en-ru',
      ModelType.opusMtEnAr => 'Helsinki-NLP/opus-mt-en-ar',
      ModelType.opusMtEnJap => 'Helsinki-NLP/opus-mt-en-jap',
      ModelType.opusMtEnKo => 'Helsinki-NLP/opus-mt-tc-big-en-ko',
      ModelType.opusMtDeEn => 'Helsinki-NLP/opus-mt-de-en',
      ModelType.opusMtFrEn => 'Helsinki-NLP/opus-mt-fr-en',
      ModelType.opusMtEsEn => 'Helsinki-NLP/opus-mt-es-en',
      ModelType.opusMtItEn => 'Helsinki-NLP/opus-mt-it-en',
      ModelType.opusMtRuEn => 'Helsinki-NLP/opus-mt-ru-en',
      ModelType.opusMtArEn => 'Helsinki-NLP/opus-mt-ar-en',
      ModelType.opusMtJapEn => 'Helsinki-NLP/opus-mt-jap-en',
      ModelType.opusMtKoEn => 'Helsinki-NLP/opus-mt-ko-en',
      ModelType.opusMtZhDe => 'Helsinki-NLP/opus-mt-zh-de',
      ModelType.opusMtDeZh => 'Helsinki-NLP/opus-mt-de-ZH',
      ModelType.opusMtZhIt => 'Helsinki-NLP/opus-mt-zh-it',
      ModelType.opusMtZhVi => 'Helsinki-NLP/opus-mt-zh-vi',
      ModelType.opusMtZhJap => 'Helsinki-NLP/opus-mt-tc-big-zh-ja',
      ModelType.opusMtFiZh => 'Helsinki-NLP/opus-mt-fi-ZH',
      ModelType.opusMtSvZh => 'Helsinki-NLP/opus-mt-sv-ZH',
      ModelType.opusMtZhBg => 'Helsinki-NLP/opus-mt-zh-bg',
      ModelType.opusMtZhFi => 'Helsinki-NLP/opus-mt-zh-fi',
      ModelType.opusMtZhHe => 'Helsinki-NLP/opus-mt-zh-he',
      ModelType.opusMtZhMs => 'Helsinki-NLP/opus-mt-zh-ms',
      ModelType.opusMtZhNl => 'Helsinki-NLP/opus-mt-zh-nl',
      ModelType.opusMtZhSv => 'Helsinki-NLP/opus-mt-zh-sv',
      ModelType.opusMtZhUk => 'Helsinki-NLP/opus-mt-zh-uk',
    };
  }

  String? get modelScopeUrl {
    return switch (this) {
      ModelType.opusMtEnZh => 'Helsinki-NLP/opus-mt-en-zh',
      ModelType.opusMtZhEn => 'Helsinki-NLP/opus-mt-zh-en',
      ModelType.opusMtEnDe => 'Helsinki-NLP/opus-mt-en-de',
      ModelType.opusMtEnFr => 'Helsinki-NLP/opus-mt-en-fr',
      ModelType.opusMtEnEs => 'Helsinki-NLP/opus-mt-en-es',
      ModelType.opusMtEnIt => 'Helsinki-NLP/opus-mt-en-it',
      ModelType.opusMtEnRu => 'Helsinki-NLP/opus-mt-en-ru',
      ModelType.opusMtEnAr => 'Helsinki-NLP/opus-mt-en-ar',
      ModelType.opusMtEnJap => 'Helsinki-NLP/opus-mt-en-jap',
      ModelType.opusMtEnKo => 'Helsinki-NLP/opus-mt-tc-big-en-ko',
      ModelType.opusMtDeEn => 'Helsinki-NLP/opus-mt-de-en',
      ModelType.opusMtFrEn => 'Helsinki-NLP/opus-mt-fr-en',
      ModelType.opusMtEsEn => 'Helsinki-NLP/opus-mt-es-en',
      ModelType.opusMtItEn => 'Helsinki-NLP/opus-mt-it-en',
      ModelType.opusMtRuEn => 'Helsinki-NLP/opus-mt-ru-en',
      ModelType.opusMtArEn => 'Helsinki-NLP/opus-mt-ar-en',
      ModelType.opusMtJapEn => 'Helsinki-NLP/opus-mt-jap-en',
      ModelType.opusMtKoEn => 'Helsinki-NLP/opus-mt-ko-en',
      ModelType.opusMtZhDe => 'Helsinki-NLP/opus-mt-zh-de',
      ModelType.opusMtDeZh => 'Helsinki-NLP/opus-mt-de-zh',
      ModelType.opusMtZhIt => 'Helsinki-NLP/opus-mt-zh-it',
      ModelType.opusMtZhVi => 'Helsinki-NLP/opus-mt-zh-vi',
      ModelType.opusMtZhJap => 'Helsinki-NLP/opus-mt-tc-big-zh-ja',
      ModelType.opusMtFiZh => 'Helsinki-NLP/opus-mt-fi-zh',
      ModelType.opusMtSvZh => 'Helsinki-NLP/opus-mt-sv-zh',
      ModelType.opusMtZhBg => 'Helsinki-NLP/opus-mt-zh-bg',
      ModelType.opusMtZhFi => 'Helsinki-NLP/opus-mt-zh-fi',
      ModelType.opusMtZhHe => 'Helsinki-NLP/opus-mt-zh-he',
      ModelType.opusMtZhMs => 'Helsinki-NLP/opus-mt-zh-ms',
      ModelType.opusMtZhNl => 'Helsinki-NLP/opus-mt-zh-nl',
      ModelType.opusMtZhSv => 'Helsinki-NLP/opus-mt-zh-sv',
      ModelType.opusMtZhUk => 'Helsinki-NLP/opus-mt-zh-uk',
    };
  }

  List<String> get requiredFiles {
    return [
      'config.json',
      'pytorch_model.bin',
      'source.spm',
      'target.spm',
      'vocab.json',
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
}

@Riverpod(keepAlive: true)
class ModelManager extends _$ModelManager {
  static const String _kSelectedModelKey = 'selected_model';
  static const String _kModelsPathKey = 'models_path';
  static const String _kCustomModelsKey = 'custom_models';

  CancelToken? _cancelToken;
  Ref get _ref => ref;

  List<CustomModelEntry> _customModels = [];

  List<CustomModelEntry> get customModels => _customModels;

  @override
  ModelState build() {
    _loadCustomModels();
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

  static const List<String> _requiredModelFiles = [
    'config.json',
    'pytorch_model.bin',
    'source.spm',
    'target.spm',
    'vocab.json',
  ];

  static bool isValidModelDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return false;
    for (final file in _requiredModelFiles) {
      if (!File(path.join(dirPath, file)).existsSync()) return false;
    }
    return true;
  }

  static final RegExp _opusMtPattern = RegExp(r'^opus-mt-([a-z]{2,3})-([a-z]{2,3})$');

  static CustomModelEntry? parseFolderName(String folderPath) {
    final name = path.basename(folderPath);
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
      return '文件夹缺少必需文件 (config.json, pytorch_model.bin, source.spm, target.spm, vocab.json)';
    }

    final entry = parseFolderName(folderPath);
    if (entry == null) {
      return '文件夹名格式不正确，需要 opus-mt-[l1]-[l2] 格式 (如 opus-mt-zh-de)';
    }

    final existingKnown = ModelType.values.where(
      (t) => t.folderName == entry.folderName,
    );
    if (existingKnown.isNotEmpty) {
      final modelsDir = await getModelsDirectory();
      final targetDir = Directory(path.join(modelsDir.path, entry.folderName));
      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }
      for (final file in _requiredModelFiles) {
        final src = File(path.join(folderPath, file));
        final dst = File(path.join(targetDir.path, file));
        if (src.existsSync()) {
          await src.copy(dst.path);
        }
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
    ));
    await _saveCustomModels();
    return null;
  }

  Future<void> removeCustomModel(String folderName) async {
    _customModels = _customModels.where((e) => e.folderName != folderName).toList();
    await _saveCustomModels();
  }

  Future<void> loadSavedModel() async {
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
    final modelsDir = await getModelsDirectory();
    final modelDir = Directory(path.join(modelsDir.path, modelType.folderName));

    if (!await modelDir.exists()) {
      return false;
    }

    for (final file in modelType.requiredFiles) {
      final filePath = File(path.join(modelDir.path, file));
      if (!await filePath.exists()) {
        return false;
      }
    }

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
    final modelsDir = await getModelsDirectory();
    final modelDir = Directory(path.join(modelsDir.path, modelType.folderName));

    try {
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
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
    final modelsDir = await getModelsDirectory();
    final modelDir = Directory(path.join(modelsDir.path, modelType.folderName));

    if (await modelDir.exists()) {
      return modelDir.path;
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

  Future<void> startDownload({String? customDirectory, String downloadSource = 'huggingface'}) async {
    if (state.downloadStatus == ModelDownloadStatus.downloading) {
      return;
    }

    final repoId = state.type.modelHubUrl ?? state.type.modelScopeUrl;
    if (repoId == null) {
      state = state.copyWith(
        downloadStatus: ModelDownloadStatus.failed,
        downloadError: '该模型暂不支持直接下载，请使用本地导入功能',
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
        success = await _downloadWithAutoFallback(repoId, savePath);
      } else if (downloadSource == 'modelscope') {
        final scopeRepoId = state.type.modelScopeUrl;
        if (scopeRepoId == null) {
          state = state.copyWith(
            downloadStatus: ModelDownloadStatus.failed,
            downloadError: '此模型在 ModelScope 上不可用，请切换到 HuggingFace 或 Auto Detect',
          );
          return;
        }
        success = await _downloadFromSource(scopeRepoId, savePath, 'modelscope');
      } else {
        success = await _downloadFromSource(repoId, savePath, 'huggingface');
      }

      if (success) {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.completed,
          downloadProgress: 1.0,
        );
      } else {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.failed,
          downloadError: '下载失败，请重试',
        );
      }
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.idle,
          downloadError: '下载已取消',
        );
      } else {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.failed,
          downloadError: '下载失败: ${e.toString()}',
        );
      }
    }
  }

  Future<bool> _downloadWithAutoFallback(String repoId, String savePath) async {
    debugPrint('[ModelManager] Auto mode: trying HuggingFace first...');
    try {
      return await _downloadFromSource(repoId, savePath, 'huggingface');
    } catch (e) {
      debugPrint('[ModelManager] HuggingFace failed ($e), falling back to ModelScope...');
      if (_cancelToken?.isCancelled ?? false) return false;
      final scopeRepoId = state.type.modelScopeUrl;
      if (scopeRepoId == null) {
        throw Exception(
          '此模型在 ModelScope 上不可用，请尝试 HuggingFace （可能需要代理）或选择其他模型',
        );
      }
      return await _downloadFromSource(scopeRepoId, savePath, 'modelscope');
    }
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
