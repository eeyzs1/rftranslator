import 'dart:io';
import 'package:rftranslator/features/image_translation/data/models/ocr_result.dart';

abstract class OcrService {
  Future<bool> isModelAvailable();
  Future<void> downloadModel({void Function(double progress)? onProgress});
  Future<OcrResult> recognize(File imageFile);
  Future<void> dispose();
}
