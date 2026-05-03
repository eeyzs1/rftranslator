import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rftranslator/core/storage/resource_registry.dart';
import 'package:rftranslator/features/image_translation/data/datasources/rapidocr_model_manager.dart';

part 'ocr_model_manager_provider.g.dart';

enum OcrModelDownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

class OcrModelManagerState {
  final OcrModelVariant selectedVariant;
  final Set<OcrModelVariant> downloadedVariants;
  final Set<OcrModelVariant> enabledVariants;
  final OcrModelDownloadStatus downloadStatus;
  final double downloadProgress;
  final int downloadedBytes;
  final int totalBytes;
  final String? downloadError;
  final String? currentFile;

  const OcrModelManagerState({
    this.selectedVariant = OcrModelVariant.server,
    this.downloadedVariants = const {},
    this.enabledVariants = const {},
    this.downloadStatus = OcrModelDownloadStatus.idle,
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.downloadError,
    this.currentFile,
  });

  bool get isModelAvailable => enabledVariants.isNotEmpty;

  bool isVariantEnabled(OcrModelVariant variant) {
    return enabledVariants.contains(variant);
  }

  bool isVariantDownloaded(OcrModelVariant variant) {
    return downloadedVariants.contains(variant);
  }

  OcrModelManagerState copyWith({
    OcrModelVariant? selectedVariant,
    Set<OcrModelVariant>? downloadedVariants,
    Set<OcrModelVariant>? enabledVariants,
    OcrModelDownloadStatus? downloadStatus,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    String? downloadError,
    String? currentFile,
  }) {
    return OcrModelManagerState(
      selectedVariant: selectedVariant ?? this.selectedVariant,
      downloadedVariants: downloadedVariants ?? this.downloadedVariants,
      enabledVariants: enabledVariants ?? this.enabledVariants,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadError: downloadError,
      currentFile: currentFile ?? this.currentFile,
    );
  }
}

@Riverpod(keepAlive: true)
class OcrModelManager extends _$OcrModelManager {
  static const String _kOcrModelType = 'ocr_model';
  static const String _kSelectedVariantKey = 'selected_ocr_variant';
  static const String _kEnabledVariantsKey = 'ocr_enabled_variants';

  CancelToken? _cancelToken;
  final _registry = ResourceRegistry();
  final _modelManager = RapidOcrModelManager();

  @override
  OcrModelManagerState build() {
    return const OcrModelManagerState();
  }

  Future<void> loadState() async {
    await _registry.load();

    await _modelManager.cleanupEmptyVariantDirs();

    final downloaded = <OcrModelVariant>{};
    for (final variant in OcrModelVariant.values) {
      if (await _modelManager.isVariantDownloaded(variant)) {
        downloaded.add(variant);
      }
    }

    final prefs = await SharedPreferences.getInstance();

    final savedIndex = prefs.getInt(_kSelectedVariantKey);
    final selectedVariant = savedIndex != null &&
            savedIndex < OcrModelVariant.values.length
        ? OcrModelVariant.values[savedIndex]
        : OcrModelVariant.server;

    final enabledList = prefs.getStringList(_kEnabledVariantsKey);
    final enabled = <OcrModelVariant>{};
    if (enabledList != null) {
      for (final name in enabledList) {
        final variant = OcrModelVariant.values.where((v) => v.name == name).firstOrNull;
        if (variant != null && downloaded.contains(variant)) {
          enabled.add(variant);
        }
      }
    } else {
      enabled.addAll(downloaded);
    }

    state = state.copyWith(
      downloadedVariants: downloaded,
      enabledVariants: enabled,
      selectedVariant: selectedVariant,
    );
  }

  Future<void> selectVariant(OcrModelVariant variant) async {
    state = state.copyWith(selectedVariant: variant);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSelectedVariantKey, variant.index);
  }

  Future<void> toggleVariantEnabled(OcrModelVariant variant) async {
    final current = Set<OcrModelVariant>.from(state.enabledVariants);
    final enable = !current.contains(variant);
    if (enable) {
      current.add(variant);
    } else {
      current.remove(variant);
    }
    state = state.copyWith(enabledVariants: current);
    await _registry.setEnabled(variant.folderName, enable, type: _kOcrModelType);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kEnabledVariantsKey,
      current.map((v) => v.name).toList(),
    );
  }

  Future<bool> isVariantDownloaded(OcrModelVariant variant) async {
    return _modelManager.isVariantDownloaded(variant);
  }

  Future<bool> isAnyModelDownloaded() async {
    return _modelManager.isAnyModelAvailable();
  }

  Future<String?> getSavedModelsPath() async {
    return _modelManager.getSavedModelsPath();
  }

  Future<String> getCurrentModelsPath() async {
    final dir = await _modelManager.getModelsDirectory();
    return dir.path;
  }

  Future<String?> getVariantPath(OcrModelVariant variant) async {
    if (!await _modelManager.isVariantDownloaded(variant)) return null;
    final dir = await _modelManager.getVariantDirectory(variant);
    return dir.path;
  }

  Future<void> setModelsPath(String customPath) async {
    await _modelManager.setModelsPath(customPath);
  }

  Future<void> importFromDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);

    final dirName = dir.path.split(Platform.pathSeparator).last;
    OcrModelVariant? directVariant;
    for (final v in OcrModelVariant.values) {
      if (v.folderName == dirName) {
        directVariant = v;
        break;
      }
    }

    if (directVariant != null) {
      final parentPath = dir.parent.path;
      await _modelManager.setModelsPath(parentPath);
    } else {
      await _modelManager.setModelsPath(directoryPath);
    }

    await loadState();
  }

  Future<void> deleteVariant(OcrModelVariant variant) async {
    try {
      await _modelManager.deleteVariant(variant);
      await _registry.remove(variant.folderName, type: _kOcrModelType);

      final downloaded = Set<OcrModelVariant>.from(state.downloadedVariants);
      downloaded.remove(variant);

      final enabled = Set<OcrModelVariant>.from(state.enabledVariants);
      enabled.remove(variant);

      if (state.selectedVariant == variant) {
        final remaining = enabled.firstOrNull ?? OcrModelVariant.server;
        await selectVariant(remaining);
      }

      state = state.copyWith(
        downloadedVariants: downloaded,
        enabledVariants: enabled,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kEnabledVariantsKey,
        enabled.map((v) => v.name).toList(),
      );
    } catch (e) {
      debugPrint('[OcrModelManager] Error deleting variant: $e');
    }
  }

  Future<void> startDownload({
    String? customDirectory,
    String downloadSource = 'auto',
    bool? huggingFaceAvailable,
    bool? modelScopeAvailable,
  }) async {
    if (state.downloadStatus == OcrModelDownloadStatus.downloading) {
      return;
    }

    final variant = state.selectedVariant;
    final models = RapidOcrModelConfig.getModels(variant);
    final totalSize = RapidOcrModelConfig.getTotalSizeBytes(variant);

    state = state.copyWith(
      downloadStatus: OcrModelDownloadStatus.downloading,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: totalSize,
      downloadError: null,
      currentFile: null,
    );
    _cancelToken = CancelToken();

    try {
      String savePath;
      if (customDirectory != null && Directory(customDirectory).existsSync()) {
        savePath =
            '$customDirectory${Platform.pathSeparator}${variant.folderName}';
      } else {
        final variantDir = await _modelManager.getVariantDirectory(variant);
        savePath = variantDir.path;
      }

      final saveDir = Directory(savePath);
      if (await saveDir.exists()) {
        await saveDir.delete(recursive: true);
      }
      await saveDir.create(recursive: true);

      bool allSuccess = true;

      for (int i = 0; i < models.length; i++) {
        final model = models[i];
        final filePath = '$savePath${Platform.pathSeparator}${model.fileName}';

        state = state.copyWith(currentFile: model.fileName);

        bool downloaded = false;

        if (downloadSource == 'auto' || downloadSource == 'huggingface') {
          if (huggingFaceAvailable != false) {
            try {
              await _downloadFile(
                url: model.huggingfaceUrl,
                savePath: filePath,
                fileIndex: i,
                totalFiles: models.length,
              );
              downloaded = true;
              debugPrint(
                '[OcrModelManager] Downloaded ${model.fileName} from HuggingFace',
              );
            } catch (e) {
              debugPrint(
                '[OcrModelManager] HuggingFace failed for ${model.fileName}: $e',
              );
            }
          }
        }

        if (!downloaded &&
            (downloadSource == 'auto' || downloadSource == 'modelscope')) {
          try {
            await _downloadFile(
              url: model.modelScopeUrl,
              savePath: filePath,
              fileIndex: i,
              totalFiles: models.length,
            );
            downloaded = true;
            debugPrint(
              '[OcrModelManager] Downloaded ${model.fileName} from ModelScope',
            );
          } catch (e) {
            debugPrint(
              '[OcrModelManager] ModelScope failed for ${model.fileName}: $e',
            );
          }
        }

        if (!downloaded) {
          allSuccess = false;
          break;
        }
      }

      if (allSuccess) {
        await _registry.addOrUpdate(
          ResourceEntry(
            id: variant.folderName,
            type: _kOcrModelType,
            localPath: savePath,
            sourceLang: 'ocr',
            targetLang: 'text',
            isEnabled: true,
          ),
        );

        if (customDirectory != null && Directory(customDirectory).existsSync()) {
          final prefs = await SharedPreferences.getInstance();
          final existingPath = prefs.getString('ocr_models_path');
          if (existingPath == null || !Directory(existingPath).existsSync()) {
            await _modelManager.setModelsPath(customDirectory);
          }
        }

        final downloaded = Set<OcrModelVariant>.from(state.downloadedVariants);
        downloaded.add(variant);

        final enabled = Set<OcrModelVariant>.from(state.enabledVariants);
        enabled.add(variant);

        state = state.copyWith(
          downloadStatus: OcrModelDownloadStatus.completed,
          downloadProgress: 1.0,
          downloadedVariants: downloaded,
          enabledVariants: enabled,
          currentFile: null,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          _kEnabledVariantsKey,
          enabled.map((v) => v.name).toList(),
        );
      } else {
        state = state.copyWith(
          downloadStatus: OcrModelDownloadStatus.failed,
          downloadError: 'Download failed: some files could not be downloaded',
          currentFile: null,
        );
      }
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        state = state.copyWith(
          downloadStatus: OcrModelDownloadStatus.idle,
          downloadError: 'Download cancelled',
          currentFile: null,
        );
      } else {
        state = state.copyWith(
          downloadStatus: OcrModelDownloadStatus.failed,
          downloadError: 'Download failed: ${e.toString()}',
          currentFile: null,
        );
      }
    }
  }

  Future<void> _downloadFile({
    required String url,
    required String savePath,
    required int fileIndex,
    required int totalFiles,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    await dio.download(
      url,
      savePath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final baseProgress = fileIndex / totalFiles;
          final fileProgress = received / total / totalFiles;
          state = state.copyWith(
            downloadProgress: baseProgress + fileProgress,
            downloadedBytes: received,
          );
        }
      },
    );
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }

  void resetDownload() {
    state = state.copyWith(
      downloadStatus: OcrModelDownloadStatus.idle,
      downloadProgress: 0.0,
      downloadedBytes: 0,
      totalBytes: 0,
      downloadError: null,
      currentFile: null,
    );
  }
}
