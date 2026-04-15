import 'dart:io';
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
  opusMtEnPt,
  opusMtEnRu,
  opusMtEnAr,
  opusMtEnJa,
  opusMtEnKo,
  opusMtDeEn,
  opusMtFrEn,
  opusMtEsEn,
  opusMtItEn,
  opusMtPtEn,
  opusMtRuEn,
  opusMtArEn,
  opusMtJaEn,
  opusMtKoEn,
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

extension ModelTypeExtension on ModelType {
  String get displayName {
    return switch (this) {
      ModelType.opusMtEnZh => 'OPUS-MT en→zh (英译中)',
      ModelType.opusMtZhEn => 'OPUS-MT zh→en (中译英)',
      ModelType.opusMtEnDe => 'OPUS-MT en→de (英译德)',
      ModelType.opusMtEnFr => 'OPUS-MT en→fr (英译法)',
      ModelType.opusMtEnEs => 'OPUS-MT en→es (英译西)',
      ModelType.opusMtEnIt => 'OPUS-MT en→it (英译意)',
      ModelType.opusMtEnPt => 'OPUS-MT en→pt (英译葡)',
      ModelType.opusMtEnRu => 'OPUS-MT en→ru (英译俄)',
      ModelType.opusMtEnAr => 'OPUS-MT en→ar (英译阿)',
      ModelType.opusMtEnJa => 'OPUS-MT en→ja (英译日)',
      ModelType.opusMtEnKo => 'OPUS-MT en→ko (英译韩)',
      ModelType.opusMtDeEn => 'OPUS-MT de→en (德译英)',
      ModelType.opusMtFrEn => 'OPUS-MT fr→en (法译英)',
      ModelType.opusMtEsEn => 'OPUS-MT es→en (西译英)',
      ModelType.opusMtItEn => 'OPUS-MT it→en (意译英)',
      ModelType.opusMtPtEn => 'OPUS-MT pt→en (葡译英)',
      ModelType.opusMtRuEn => 'OPUS-MT ru→en (俄译英)',
      ModelType.opusMtArEn => 'OPUS-MT ar→en (阿译英)',
      ModelType.opusMtJaEn => 'OPUS-MT ja→en (日译英)',
      ModelType.opusMtKoEn => 'OPUS-MT ko→en (韩译英)',
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
      ModelType.opusMtEnPt => 'opus-mt-en-pt',
      ModelType.opusMtEnRu => 'opus-mt-en-ru',
      ModelType.opusMtEnAr => 'opus-mt-en-ar',
      ModelType.opusMtEnJa => 'opus-mt-en-ja',
      ModelType.opusMtEnKo => 'opus-mt-en-ko',
      ModelType.opusMtDeEn => 'opus-mt-de-en',
      ModelType.opusMtFrEn => 'opus-mt-fr-en',
      ModelType.opusMtEsEn => 'opus-mt-es-en',
      ModelType.opusMtItEn => 'opus-mt-it-en',
      ModelType.opusMtPtEn => 'opus-mt-pt-en',
      ModelType.opusMtRuEn => 'opus-mt-ru-en',
      ModelType.opusMtArEn => 'opus-mt-ar-en',
      ModelType.opusMtJaEn => 'opus-mt-ja-en',
      ModelType.opusMtKoEn => 'opus-mt-ko-en',
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
      ModelType.opusMtEnPt => 'Helsinki-NLP/opus-mt-en-pt',
      ModelType.opusMtEnRu => 'Helsinki-NLP/opus-mt-en-ru',
      ModelType.opusMtEnAr => 'Helsinki-NLP/opus-mt-en-ar',
      ModelType.opusMtEnJa => 'Helsinki-NLP/opus-mt-en-ja',
      ModelType.opusMtEnKo => 'Helsinki-NLP/opus-mt-en-ko',
      ModelType.opusMtDeEn => 'Helsinki-NLP/opus-mt-de-en',
      ModelType.opusMtFrEn => 'Helsinki-NLP/opus-mt-fr-en',
      ModelType.opusMtEsEn => 'Helsinki-NLP/opus-mt-es-en',
      ModelType.opusMtItEn => 'Helsinki-NLP/opus-mt-it-en',
      ModelType.opusMtPtEn => 'Helsinki-NLP/opus-mt-pt-en',
      ModelType.opusMtRuEn => 'Helsinki-NLP/opus-mt-ru-en',
      ModelType.opusMtArEn => 'Helsinki-NLP/opus-mt-ar-en',
      ModelType.opusMtJaEn => 'Helsinki-NLP/opus-mt-ja-en',
      ModelType.opusMtKoEn => 'Helsinki-NLP/opus-mt-ko-en',
    };
  }

  String? get modelScopeUrl {
    return switch (this) {
      ModelType.opusMtEnZh => 'AI-ModelScope/opus-mt-en-zh',
      ModelType.opusMtZhEn => 'AI-ModelScope/opus-mt-zh-en',
      ModelType.opusMtEnDe => 'AI-ModelScope/opus-mt-en-de',
      ModelType.opusMtEnFr => 'AI-ModelScope/opus-mt-en-fr',
      ModelType.opusMtEnEs => 'AI-ModelScope/opus-mt-en-es',
      ModelType.opusMtEnIt => 'AI-ModelScope/opus-mt-en-it',
      ModelType.opusMtEnPt => 'AI-ModelScope/opus-mt-en-pt',
      ModelType.opusMtEnRu => 'AI-ModelScope/opus-mt-en-ru',
      ModelType.opusMtEnAr => 'AI-ModelScope/opus-mt-en-ar',
      ModelType.opusMtEnJa => 'AI-ModelScope/opus-mt-en-ja',
      ModelType.opusMtEnKo => 'AI-ModelScope/opus-mt-en-ko',
      ModelType.opusMtDeEn => 'AI-ModelScope/opus-mt-de-en',
      ModelType.opusMtFrEn => 'AI-ModelScope/opus-mt-fr-en',
      ModelType.opusMtEsEn => 'AI-ModelScope/opus-mt-es-en',
      ModelType.opusMtItEn => 'AI-ModelScope/opus-mt-it-en',
      ModelType.opusMtPtEn => 'AI-ModelScope/opus-mt-pt-en',
      ModelType.opusMtRuEn => 'AI-ModelScope/opus-mt-ru-en',
      ModelType.opusMtArEn => 'AI-ModelScope/opus-mt-ar-en',
      ModelType.opusMtJaEn => 'AI-ModelScope/opus-mt-ja-en',
      ModelType.opusMtKoEn => 'AI-ModelScope/opus-mt-ko-en',
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
      ModelType.opusMtEnPt => ('en', 'pt'),
      ModelType.opusMtEnRu => ('en', 'ru'),
      ModelType.opusMtEnAr => ('en', 'ar'),
      ModelType.opusMtEnJa => ('en', 'ja'),
      ModelType.opusMtEnKo => ('en', 'ko'),
      ModelType.opusMtDeEn => ('de', 'en'),
      ModelType.opusMtFrEn => ('fr', 'en'),
      ModelType.opusMtEsEn => ('es', 'en'),
      ModelType.opusMtItEn => ('it', 'en'),
      ModelType.opusMtPtEn => ('pt', 'en'),
      ModelType.opusMtRuEn => ('ru', 'en'),
      ModelType.opusMtArEn => ('ar', 'en'),
      ModelType.opusMtJaEn => ('ja', 'en'),
      ModelType.opusMtKoEn => ('ko', 'en'),
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
      ModelType.opusMtEnPt => 'opus_mt_en_pt',
      ModelType.opusMtEnRu => 'opus_mt_en_ru',
      ModelType.opusMtEnAr => 'opus_mt_en_ar',
      ModelType.opusMtEnJa => 'opus_mt_en_ja',
      ModelType.opusMtEnKo => 'opus_mt_en_ko',
      ModelType.opusMtDeEn => 'opus_mt_de_en',
      ModelType.opusMtFrEn => 'opus_mt_fr_en',
      ModelType.opusMtEsEn => 'opus_mt_es_en',
      ModelType.opusMtItEn => 'opus_mt_it_en',
      ModelType.opusMtPtEn => 'opus_mt_pt_en',
      ModelType.opusMtRuEn => 'opus_mt_ru_en',
      ModelType.opusMtArEn => 'opus_mt_ar_en',
      ModelType.opusMtJaEn => 'opus_mt_ja_en',
      ModelType.opusMtKoEn => 'opus_mt_ko_en',
    };
  }
}

@Riverpod(keepAlive: true)
class ModelManager extends _$ModelManager {
  static const String _kSelectedModelKey = 'selected_model';
  static const String _kModelsPathKey = 'models_path';

  CancelToken? _cancelToken;
  Ref get _ref => ref;

  @override
  ModelState build() {
    return ModelState(type: ModelType.opusMtEnZh);
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

  Future<bool> isAnyModelDownloaded() async {
    for (final type in ModelType.values) {
      if (await isModelDownloaded(type)) {
        return true;
      }
    }
    return false;
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

  Future<void> startDownload({String? customDirectory}) async {
    if (state.downloadStatus == ModelDownloadStatus.downloading) {
      return;
    }

    if (state.type.modelHubUrl == null) {
      state = state.copyWith(
        downloadStatus: ModelDownloadStatus.failed,
        downloadError: '\u8BE5\u6A21\u578B\u6682\u4E0D\u652F\u6301\u76F4\u63A5\u4E0B\u8F7D',
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

      final success = await _downloadViaPythonBackend(
        state.type.modelHubUrl!,
        savePath,
      );

      if (success) {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.completed,
          downloadProgress: 1.0,
        );
      } else {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.failed,
          downloadError: '\u4E0B\u8F7D\u5931\u8D25\uFF0C\u8BF7\u91CD\u8BD5',
        );
      }
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.idle,
          downloadError: '\u4E0B\u8F7D\u5DF2\u53D6\u6D88',
        );
      } else {
        state = state.copyWith(
          downloadStatus: ModelDownloadStatus.failed,
          downloadError: '\u4E0B\u8F7D\u5931\u8D25: ${e.toString()}',
        );
      }
    }
  }

  Future<bool> _downloadViaPythonBackend(String repoId, String savePath) async {
    try {
      final hubUrl = state.type.modelHubUrl;
      if (hubUrl == null) return false;

      final dio = Dio();
      final tempPath = '$savePath.tmp';

      if (File(tempPath).existsSync()) {
        await File(tempPath).delete();
      }

      await dio.download(
        'https://huggingface.co/$hubUrl/resolve/main/config.json',
        path.join(savePath, 'config.json'),
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(
              downloadProgress: received / total * 0.1,
              downloadedBytes: received,
            );
          }
        },
      );

      return true;
    } catch (e) {
      return false;
    }
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
