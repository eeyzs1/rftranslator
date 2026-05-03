import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:rftranslator/features/image_translation/data/datasources/rapidocr_model_manager.dart';

enum OcrDownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

class OcrDownloadState {
  final OcrDownloadStatus status;
  final double progress;
  final String? currentFile;
  final String? error;
  final OcrModelVariant variant;

  const OcrDownloadState({
    this.status = OcrDownloadStatus.idle,
    this.progress = 0.0,
    this.currentFile,
    this.error,
    this.variant = OcrModelVariant.server,
  });

  OcrDownloadState copyWith({
    OcrDownloadStatus? status,
    double? progress,
    String? currentFile,
    String? error,
    OcrModelVariant? variant,
  }) {
    return OcrDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentFile: currentFile ?? this.currentFile,
      error: error,
      variant: variant ?? this.variant,
    );
  }
}

class OcrModelDownloader {
  final RapidOcrModelManager _modelManager = RapidOcrModelManager();
  CancelToken? _cancelToken;

  OcrDownloadState _state = const OcrDownloadState();
  OcrDownloadState get state => _state;

  void Function(OcrDownloadState)? onStateChanged;

  void _updateState(OcrDownloadState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  Future<bool> downloadModels({
    String source = 'auto',
    bool? huggingFaceAvailable,
    bool? modelScopeAvailable,
    OcrModelVariant variant = OcrModelVariant.server,
  }) async {
    if (_state.status == OcrDownloadStatus.downloading) {
      return false;
    }

    _cancelToken = CancelToken();
    _updateState(
      OcrDownloadState(
        status: OcrDownloadStatus.downloading,
        variant: variant,
      ),
    );

    final modelsDir = await _modelManager.getModelsDirectory();
    final models = RapidOcrModelConfig.getModels(variant);

    try {
      for (int i = 0; i < models.length; i++) {
        final model = models[i];
        final filePath = path.join(modelsDir.path, model.fileName);

        if (File(filePath).existsSync()) {
          debugPrint(
            '[OcrModelDownloader] ${model.fileName} already exists, skipping',
          );
          continue;
        }

        _updateState(
          _state.copyWith(
            currentFile: model.fileName,
            progress: i / models.length,
          ),
        );

        bool downloaded = false;

        if (source == 'auto' || source == 'huggingface') {
          if (huggingFaceAvailable != false) {
            try {
              await _downloadFile(
                url: model.huggingfaceUrl,
                savePath: filePath,
              );
              downloaded = true;
              debugPrint(
                '[OcrModelDownloader] Downloaded ${model.fileName} from HuggingFace',
              );
            } catch (e) {
              debugPrint(
                '[OcrModelDownloader] HuggingFace failed for ${model.fileName}: $e',
              );
            }
          }
        }

        if (!downloaded && (source == 'auto' || source == 'modelscope')) {
          try {
            await _downloadFile(
              url: model.modelScopeUrl,
              savePath: filePath,
            );
            downloaded = true;
            debugPrint(
              '[OcrModelDownloader] Downloaded ${model.fileName} from ModelScope',
            );
          } catch (e) {
            debugPrint(
              '[OcrModelDownloader] ModelScope failed for ${model.fileName}: $e',
            );
          }
        }

        if (!downloaded) {
          throw Exception(
            'Failed to download ${model.fileName} from all sources',
          );
        }
      }

      _updateState(
        const OcrDownloadState(
          status: OcrDownloadStatus.completed,
          progress: 1.0,
        ),
      );
      return true;
    } catch (e) {
      if (_cancelToken?.isCancelled ?? false) {
        _updateState(
          const OcrDownloadState(
            status: OcrDownloadStatus.idle,
            error: 'Download cancelled',
          ),
        );
      } else {
        _updateState(
          OcrDownloadState(
            status: OcrDownloadStatus.failed,
            error: 'Download failed: ${e.toString()}',
          ),
        );
      }
      return false;
    }
  }

  Future<void> _downloadFile({
    required String url,
    required String savePath,
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
          // Progress is handled at model level
        }
      },
    );
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }

  void reset() {
    _state = const OcrDownloadState();
  }
}
