import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:rftranslator/features/image_translation/data/datasources/ocr_postprocessor.dart' as post;
import 'package:rftranslator/features/image_translation/data/datasources/rapidocr_model_manager.dart';
import 'package:rftranslator/features/image_translation/data/models/ocr_result.dart';
import 'package:rftranslator/features/image_translation/domain/entities/ocr_text_block.dart';

class RapidOcrDataSource {
  final RapidOcrModelManager _modelManager = RapidOcrModelManager();
  OcrModelVariant _activeVariant = OcrModelVariant.server;

  void setActiveVariant(OcrModelVariant variant) {
    _activeVariant = variant;
  }

  Future<bool> isModelAvailable() => _modelManager.isVariantDownloaded(_activeVariant);

  Future<OcrResult> recognize(File imageFile) async {
    final stopwatch = Stopwatch()..start();

    if (!await isModelAvailable()) {
      throw StateError('OCR models not available. Please download first.');
    }

    final modelPaths = await _getModelPaths();
    if (modelPaths == null) {
      throw StateError('Failed to locate OCR model files.');
    }

    await post.OcrPostprocessor.initialize();
    final charList = post.OcrPostprocessor.characterList;

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw ArgumentError('Failed to decode image.');
    }

    final preprocessed = _preprocessImage(decoded);

    try {
      final ort = OnnxRuntime();
      final sessionOptions = OrtSessionOptions(intraOpNumThreads: 1);

      final detSession = await ort.createSession(modelPaths.detPath, options: sessionOptions);
      final recSession = await ort.createSession(modelPaths.recPath, options: sessionOptions);
      final clsSession = await ort.createSession(modelPaths.clsPath, options: sessionOptions);

      final detResult = await _runDetection(
        detSession: detSession,
        image: preprocessed,
      );

      final scaleX = decoded.width / preprocessed.width;
      final scaleY = decoded.height / preprocessed.height;

      final results = <Map<String, dynamic>>[];

      for (final box in detResult.boxes) {
        final origBox = [
          box[0] * scaleX,
          box[1] * scaleY,
          box[2] * scaleX,
          box[3] * scaleY,
        ];
        final cropResult = await _cropAndClassify(
          clsSession: clsSession,
          image: decoded,
          box: origBox,
        );

        final textResult = await _runRecognition(
          recSession: recSession,
          croppedImage: cropResult.image,
          box: origBox,
          characterList: charList,
        );

        if (textResult['text'] != null &&
            (textResult['text'] as String).isNotEmpty) {
          final confidence = (textResult['confidence'] as num?)?.toDouble() ?? 0.0;
          if (confidence < 0.5) {
            final enhancedCrop = _enhanceCropForRec(cropResult.image);
            final retryResult = await _runRecognition(
              recSession: recSession,
              croppedImage: enhancedCrop,
              box: origBox,
              characterList: charList,
            );
            final retryConf = (retryResult['confidence'] as num?)?.toDouble() ?? 0.0;
            if (retryConf > confidence) {
              results.add(retryResult);
            } else {
              results.add(textResult);
            }
          } else {
            results.add(textResult);
          }
        }
      }

      await detSession.close();
      await recSession.close();
      await clsSession.close();

      stopwatch.stop();

      final blocks = <OcrTextBlock>[];
      final texts = <String>[];

      for (final item in results) {
        final text = item['text'] as String? ?? '';
        final confidence = (item['confidence'] as num?)?.toDouble() ?? 0.0;
        final box = item['box'] as List<dynamic>? ?? [];

        if (text.isEmpty) continue;

        final points = <Point>[];
        for (final p in box) {
          if (p is List && p.length >= 2) {
            points.add(Point((p[0] as num).toDouble(), (p[1] as num).toDouble()));
          }
        }

        blocks.add(
          OcrTextBlock(
            text: text,
            points: points,
            confidence: confidence,
          ),
        );
        texts.add(text);
      }

      return OcrResult(
        blocks: blocks,
        fullText: texts.join(' '),
        elapsedTime: stopwatch.elapsed,
      );
    } catch (e, stackTrace) {
      debugPrint('[RapidOCR] Inference error: $e');
      debugPrint('[RapidOCR] StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<_ModelPaths?> _getModelPaths() async {
    final models = RapidOcrModelConfig.getModels(_activeVariant);
    final detPath = await _modelManager.getModelPath(
      _activeVariant,
      models[0].fileName,
    );
    final recPath = await _modelManager.getModelPath(
      _activeVariant,
      models[1].fileName,
    );
    final clsPath = await _modelManager.getModelPath(
      _activeVariant,
      models[2].fileName,
    );

    if (detPath == null || recPath == null || clsPath == null) {
      return null;
    }

    return _ModelPaths(
      detPath: detPath,
      recPath: recPath,
      clsPath: clsPath,
    );
  }

  static img.Image _preprocessImage(img.Image image) {
    var result = image;

    if (result.height < 64 || result.width < 64) {
      final scale = (64.0 / (result.height < result.width ? result.height : result.width)).ceil();
      if (scale > 1) {
        result = img.copyResize(
          result,
          width: result.width * scale,
          height: result.height * scale,
          interpolation: img.Interpolation.cubic,
        );
      }
    }

    result = _enhanceContrast(result, factor: 1.5);
    result = _sharpen(result);

    return result;
  }

  static img.Image _enhanceContrast(img.Image image, {double factor = 1.5}) {
    final result = img.Image(width: image.width, height: image.height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = ((pixel.rNormalized.toDouble() - 0.5) * factor + 0.5).clamp(0.0, 1.0);
        final g = ((pixel.gNormalized.toDouble() - 0.5) * factor + 0.5).clamp(0.0, 1.0);
        final b = ((pixel.bNormalized.toDouble() - 0.5) * factor + 0.5).clamp(0.0, 1.0);
        result.setPixelRgba(
          x, y,
          (r * 255).round().clamp(0, 255),
          (g * 255).round().clamp(0, 255),
          (b * 255).round().clamp(0, 255),
          pixel.a.toInt(),
        );
      }
    }
    return result;
  }

  static img.Image _sharpen(img.Image image) {
    final result = img.Image(width: image.width, height: image.height);
    final kernel = [0, -1, 0, -1, 5, -1, 0, -1, 0];
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        double sumR = 0, sumG = 0, sumB = 0;
        int ki = 0;
        for (var ky = -1; ky <= 1; ky++) {
          for (var kx = -1; kx <= 1; kx++) {
            final nx = (x + kx).clamp(0, image.width - 1);
            final ny = (y + ky).clamp(0, image.height - 1);
            final p = image.getPixel(nx, ny);
            final w = kernel[ki++];
            sumR += p.rNormalized.toDouble() * w;
            sumG += p.gNormalized.toDouble() * w;
            sumB += p.bNormalized.toDouble() * w;
          }
        }
        final a = image.getPixel(x, y).a.toInt();
        result.setPixelRgba(
          x, y,
          (sumR.clamp(0.0, 1.0) * 255).round(),
          (sumG.clamp(0.0, 1.0) * 255).round(),
          (sumB.clamp(0.0, 1.0) * 255).round(),
          a,
        );
      }
    }
    return result;
  }

  static img.Image _enhanceCropForRec(img.Image cropped) {
    var enhanced = _enhanceContrast(cropped, factor: 2.0);
    enhanced = _sharpen(enhanced);
    return enhanced;
  }

  static Float32List _normalizeImage(
    img.Image image, {
    required List<double> mean,
    required List<double> std,
    bool bgr = true,
  }) {
    final h = image.height;
    final w = image.width;
    final data = Float32List(w * h * 3);
    final channelSize = w * h;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final pixel = image.getPixel(x, y);
        final spatialIdx = y * w + x;
        if (bgr) {
          data[spatialIdx] = (pixel.bNormalized.toDouble() - mean[0]) / std[0];
          data[channelSize + spatialIdx] = (pixel.gNormalized.toDouble() - mean[1]) / std[1];
          data[2 * channelSize + spatialIdx] = (pixel.rNormalized.toDouble() - mean[2]) / std[2];
        } else {
          data[spatialIdx] = (pixel.rNormalized.toDouble() - mean[0]) / std[0];
          data[channelSize + spatialIdx] = (pixel.gNormalized.toDouble() - mean[1]) / std[1];
          data[2 * channelSize + spatialIdx] = (pixel.bNormalized.toDouble() - mean[2]) / std[2];
        }
      }
    }
    return data;
  }

  static Future<_DetResult> _runDetection({
    required OrtSession detSession,
    required img.Image image,
  }) async {
    const int limitSideLen = 960;
    const int alignSize = 32;

    final h = image.height;
    final w = image.width;
    double ratio = 1.0;

    final shortSide = h < w ? h : w;
    if (shortSide < limitSideLen) {
      ratio = limitSideLen / shortSide;
    }

    var newHeight = (h * ratio).round().clamp(1, 4096);
    var newWidth = (w * ratio).round().clamp(1, 4096);
    newHeight = (newHeight / alignSize).round() * alignSize;
    newWidth = (newWidth / alignSize).round() * alignSize;

    final resized = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.cubic,
    );

    const detMean = [0.5, 0.5, 0.5];
    const detStd = [0.5, 0.5, 0.5];
    final inputData = _normalizeImage(resized, mean: detMean, std: detStd, bgr: true);

    final inputTensor = await OrtValue.fromList(
      inputData,
      [1, 3, newHeight, newWidth],
    );

    final inputName = detSession.inputNames[0];
    final outputs = await detSession.run({inputName: inputTensor});
    final outputName = detSession.outputNames[0];
    final outputTensor = outputs[outputName]!;

    final flatData = await outputTensor.asFlattenedList();
    final outputData = flatData.map((e) => (e as num).toDouble()).toList();
    final outputShape = outputTensor.shape;

    await inputTensor.dispose();
    await outputTensor.dispose();

    final boxes = post.OcrPostprocessor.dbPostprocess(
      probabilityMap: outputData,
      width: outputShape[3],
      height: outputShape[2],
      originalWidth: image.width,
      originalHeight: image.height,
      resizedWidth: newWidth,
      resizedHeight: newHeight,
      thresh: 0.2,
      boxThresh: 0.3,
      unclipRatio: 1.5,
    );

    return _DetResult(boxes: boxes, resizedWidth: newWidth, resizedHeight: newHeight);
  }

  static Future<_CropResult> _cropAndClassify({
    required OrtSession clsSession,
    required img.Image image,
    required List<double> box,
  }) async {
    final x1 = box[0].clamp(0, image.width - 1).toInt();
    final y1 = box[1].clamp(0, image.height - 1).toInt();
    final x2 = box[2].clamp(0, image.width - 1).toInt();
    final y2 = box[3].clamp(0, image.height - 1).toInt();

    if (x2 <= x1 || y2 <= y1) {
      final emptyCrop = img.copyCrop(image, x: 0, y: 0, width: 1, height: 1);
      return _CropResult(image: emptyCrop, box: box);
    }

    var cropped = img.copyCrop(
      image,
      x: x1,
      y: y1,
      width: x2 - x1,
      height: y2 - y1,
    );

    const clsHeight = 48;
    const clsWidth = 192;
    final cropW = cropped.width;
    final cropH = cropped.height;
    final resizeW = (cropW * clsHeight / cropH).round().clamp(1, clsWidth);
    final resized = img.copyResize(
      cropped,
      width: resizeW,
      height: clsHeight,
      interpolation: img.Interpolation.cubic,
    );

    const clsMean = [0.5, 0.5, 0.5];
    const clsStd = [0.5, 0.5, 0.5];
    final inputData = _normalizeImage(resized, mean: clsMean, std: clsStd, bgr: true);

    final paddedData = Float32List(3 * clsHeight * clsWidth);
    final srcLen = 3 * clsHeight * resizeW;
    for (var i = 0; i < srcLen && i < paddedData.length; i++) {
      paddedData[i] = inputData[i];
    }

    final inputTensor = await OrtValue.fromList(
      paddedData,
      [1, 3, clsHeight, clsWidth],
    );

    final inputName = clsSession.inputNames[0];
    final outputs = await clsSession.run({inputName: inputTensor});
    final outputName = clsSession.outputNames[0];
    final outputTensor = outputs[outputName]!;

    final flatData = await outputTensor.asFlattenedList();
    final outputData = flatData.map((e) => (e as num).toDouble()).toList();

    await inputTensor.dispose();
    await outputTensor.dispose();

    final angle = post.OcrPostprocessor.classifyOrientation(outputData);
    if (angle == 180) {
      cropped = post.OcrPostprocessor.rotate180(cropped);
    }

    return _CropResult(image: cropped, box: box);
  }

  static Future<Map<String, dynamic>> _runRecognition({
    required OrtSession recSession,
    required img.Image croppedImage,
    required List<double> box,
    required List<String> characterList,
  }) async {
    const recHeight = 48;
    final cropWidth = croppedImage.width;
    final cropHeight = croppedImage.height;
    final recWidth = (cropWidth * recHeight / cropHeight).round().clamp(10, 4096);
    final resized = img.copyResize(
      croppedImage,
      width: recWidth,
      height: recHeight,
      interpolation: img.Interpolation.cubic,
    );

    const recMean = [0.5, 0.5, 0.5];
    const recStd = [0.5, 0.5, 0.5];
    final inputData = _normalizeImage(resized, mean: recMean, std: recStd, bgr: true);

    final inputTensor = await OrtValue.fromList(
      inputData,
      [1, 3, recHeight, recWidth],
    );

    final inputName = recSession.inputNames[0];
    final outputs = await recSession.run({inputName: inputTensor});
    final outputName = recSession.outputNames[0];
    final outputTensor = outputs[outputName]!;

    final flatData = await outputTensor.asFlattenedList();
    final outputData = flatData.map((e) => (e as num).toDouble()).toList();
    final outputShape = outputTensor.shape;

    await inputTensor.dispose();
    await outputTensor.dispose();

    final timeSteps = outputShape.length == 3 ? outputShape[1] : outputShape[0];
    final numClasses = outputShape.length == 3 ? outputShape[2] : outputShape[1];

    final indices = post.OcrPostprocessor.argmax2D(outputData, numClasses, timeSteps);
    final text = post.OcrPostprocessor.ctcDecode(indices, chars: characterList);

    double confidence = 0.0;
    if (timeSteps > 0) {
      var totalProb = 0.0;
      for (int t = 0; t < timeSteps; t++) {
        final maxIdx = indices[t];
        totalProb += outputData[t * numClasses + maxIdx];
      }
      confidence = totalProb / timeSteps;
    }

    return {
      'text': text,
      'confidence': confidence,
      'box': box,
    };
  }
}

class _ModelPaths {
  final String detPath;
  final String recPath;
  final String clsPath;

  _ModelPaths({
    required this.detPath,
    required this.recPath,
    required this.clsPath,
  });
}

class _DetResult {
  final List<List<double>> boxes;
  final int resizedWidth;
  final int resizedHeight;

  _DetResult({
    required this.boxes,
    required this.resizedWidth,
    required this.resizedHeight,
  });
}

class _CropResult {
  final img.Image image;
  final List<double> box;

  _CropResult({required this.image, required this.box});
}
