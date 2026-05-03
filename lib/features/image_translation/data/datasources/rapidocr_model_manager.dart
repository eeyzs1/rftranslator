import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OcrModelVariant {
  server,
  mobile,
}

extension OcrModelVariantExtension on OcrModelVariant {
  String get folderName {
    return switch (this) {
      OcrModelVariant.server => 'pp-ocrv5-server',
      OcrModelVariant.mobile => 'pp-ocrv5-mobile',
    };
  }

  String get displayName {
    return switch (this) {
      OcrModelVariant.server => 'PP-OCRv5 Server',
      OcrModelVariant.mobile => 'PP-OCRv5 Mobile',
    };
  }

  String get description {
    return switch (this) {
      OcrModelVariant.server => 'Server版 (~166MB)：精度最高，适合高性能设备',
      OcrModelVariant.mobile => 'Mobile版 (~22MB)：轻量快速，适合低性能设备',
    };
  }

  String get sizeInfo {
    return switch (this) {
      OcrModelVariant.server => '~166MB',
      OcrModelVariant.mobile => '~22MB',
    };
  }
}

class RapidOcrModelFile {
  final String fileName;
  final String huggingfaceUrl;
  final String modelScopeUrl;
  final int approximateSizeBytes;

  const RapidOcrModelFile({
    required this.fileName,
    required this.huggingfaceUrl,
    required this.modelScopeUrl,
    required this.approximateSizeBytes,
  });
}

class RapidOcrModelConfig {
  static const String kOcrModelType = 'ocr_model';

  static const RapidOcrModelFile serverDetModel = RapidOcrModelFile(
    fileName: 'ch_PP-OCRv5_server_det.onnx',
    huggingfaceUrl:
        'https://huggingface.co/RapidAI/RapidOCR/resolve/main/onnx/PP-OCRv5/det/ch_PP-OCRv5_server_det.onnx',
    modelScopeUrl:
        'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.4.0/onnx/PP-OCRv5/det/ch_PP-OCRv5_server_det.onnx',
    approximateSizeBytes: 84 * 1024 * 1024,
  );

  static const RapidOcrModelFile serverRecModel = RapidOcrModelFile(
    fileName: 'ch_PP-OCRv5_rec_server_infer.onnx',
    huggingfaceUrl:
        'https://huggingface.co/RapidAI/RapidOCR/resolve/main/onnx/PP-OCRv5/rec/ch_PP-OCRv5_rec_server_infer.onnx',
    modelScopeUrl:
        'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.4.0/onnx/PP-OCRv5/rec/ch_PP-OCRv5_rec_server_infer.onnx',
    approximateSizeBytes: 81 * 1024 * 1024,
  );

  static const RapidOcrModelFile mobileDetModel = RapidOcrModelFile(
    fileName: 'ch_PP-OCRv5_mobile_det.onnx',
    huggingfaceUrl:
        'https://huggingface.co/RapidAI/RapidOCR/resolve/main/onnx/PP-OCRv5/det/ch_PP-OCRv5_mobile_det.onnx',
    modelScopeUrl:
        'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.4.0/onnx/PP-OCRv5/det/ch_PP-OCRv5_mobile_det.onnx',
    approximateSizeBytes: 5 * 1024 * 1024,
  );

  static const RapidOcrModelFile mobileRecModel = RapidOcrModelFile(
    fileName: 'ch_PP-OCRv5_rec_mobile_infer.onnx',
    huggingfaceUrl:
        'https://huggingface.co/RapidAI/RapidOCR/resolve/main/onnx/PP-OCRv5/rec/ch_PP-OCRv5_rec_mobile_infer.onnx',
    modelScopeUrl:
        'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.4.0/onnx/PP-OCRv5/rec/ch_PP-OCRv5_rec_mobile_infer.onnx',
    approximateSizeBytes: 16 * 1024 * 1024,
  );

  static const RapidOcrModelFile clsModel = RapidOcrModelFile(
    fileName: 'ch_ppocr_mobile_v2.0_cls_infer.onnx',
    huggingfaceUrl:
        'https://huggingface.co/RapidAI/RapidOCR/resolve/main/onnx/PP-OCRv4/cls/ch_ppocr_mobile_v2.0_cls_infer.onnx',
    modelScopeUrl:
        'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.4.0/onnx/PP-OCRv4/cls/ch_ppocr_mobile_v2.0_cls_infer.onnx',
    approximateSizeBytes: 1 * 1024 * 1024,
  );

  static List<RapidOcrModelFile> getModels(OcrModelVariant variant) {
    return switch (variant) {
      OcrModelVariant.server => [serverDetModel, serverRecModel, clsModel],
      OcrModelVariant.mobile => [mobileDetModel, mobileRecModel, clsModel],
    };
  }

  static int getTotalSizeBytes(OcrModelVariant variant) {
    return getModels(variant)
        .fold(0, (sum, m) => sum + m.approximateSizeBytes);
  }
}

class RapidOcrModelManager {
  static const String _kOcrModelsDir = 'models/ocr';
  static const String _kModelsPathKey = 'ocr_models_path';

  Future<void> setModelsPath(String customPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModelsPathKey, customPath);
  }

  Future<String?> getSavedModelsPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kModelsPathKey);
  }

  Future<Directory> getModelsDirectory() async {
    final savedPath = await getSavedModelsPath();
    if (savedPath != null && Directory(savedPath).existsSync()) {
      final dirName = savedPath.split(Platform.pathSeparator).last;
      final isVariantDir = OcrModelVariant.values.any((v) => v.folderName == dirName);
      if (isVariantDir) {
        final parentPath = Directory(savedPath).parent.path;
        await setModelsPath(parentPath);
        return Directory(parentPath);
      }
      return Directory(savedPath);
    }

    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(dir.path, _kOcrModelsDir));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<Directory> getVariantDirectory(OcrModelVariant variant, {bool autoCreate = true}) async {
    final modelsDir = await getModelsDirectory();
    final variantDir = Directory(path.join(modelsDir.path, variant.folderName));
    if (autoCreate && !await variantDir.exists()) {
      await variantDir.create(recursive: true);
    }
    return variantDir;
  }

  Future<bool> isVariantDownloaded(OcrModelVariant variant) async {
    final variantDir = await getVariantDirectory(variant, autoCreate: false);
    if (!await variantDir.exists()) {
      return false;
    }
    final models = RapidOcrModelConfig.getModels(variant);
    for (final model in models) {
      final file = File(path.join(variantDir.path, model.fileName));
      if (!await file.exists()) {
        return false;
      }
    }
    return true;
  }

  Future<bool> isAnyModelAvailable() async {
    for (final variant in OcrModelVariant.values) {
      if (await isVariantDownloaded(variant)) {
        return true;
      }
    }
    return false;
  }

  Future<String?> getModelPath(OcrModelVariant variant, String fileName) async {
    final variantDir = await getVariantDirectory(variant, autoCreate: false);
    final file = File(path.join(variantDir.path, fileName));
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  Future<void> deleteVariant(OcrModelVariant variant) async {
    final variantDir = await getVariantDirectory(variant, autoCreate: false);
    if (await variantDir.exists()) {
      await variantDir.delete(recursive: true);
    }
  }

  Future<void> cleanupEmptyVariantDirs() async {
    final modelsDir = await getModelsDirectory();
    if (!await modelsDir.exists()) return;

    await for (final entity in modelsDir.list()) {
      if (entity is Directory) {
        final dirName = path.basename(entity.path);
        final isVariantDir = OcrModelVariant.values.any((v) => v.folderName == dirName);
        if (isVariantDir) {
          final matchingVariant = OcrModelVariant.values.firstWhere(
            (v) => v.folderName == dirName,
          );
          if (!await isVariantDownloaded(matchingVariant)) {
            bool isEmpty = true;
            await for (final _ in entity.list()) {
              isEmpty = false;
              break;
            }
            if (isEmpty) {
              await entity.delete();
            }
          }
        }
      }
    }
  }
}
