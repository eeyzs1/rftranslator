import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rftranslator/features/image_translation/data/datasources/rapidocr_datasource.dart';
import 'package:rftranslator/features/image_translation/data/models/ocr_result.dart';
import 'package:rftranslator/features/image_translation/domain/ocr_model_manager_provider.dart';
import 'package:rftranslator/features/translation/domain/entities/language.dart';

enum ImageTranslationStatus {
  idle,
  pickingImage,
  imageSelected,
  downloadingModel,
  ocrInProgress,
  ocrCompleted,
  translating,
  completed,
  error,
}

class ImageTranslationState {
  final ImageTranslationStatus status;
  final File? selectedImage;
  final OcrResult? ocrResult;
  final String? translatedText;
  final String? errorMessage;
  final Language sourceLang;
  final Language targetLang;
  final bool isModelAvailable;
  final double modelDownloadProgress;
  final String? modelDownloadFile;

  const ImageTranslationState({
    this.status = ImageTranslationStatus.idle,
    this.selectedImage,
    this.ocrResult,
    this.translatedText,
    this.errorMessage,
    this.sourceLang = Language.english,
    this.targetLang = Language.chinese,
    this.isModelAvailable = false,
    this.modelDownloadProgress = 0.0,
    this.modelDownloadFile,
  });

  ImageTranslationState copyWith({
    ImageTranslationStatus? status,
    File? selectedImage,
    OcrResult? ocrResult,
    String? translatedText,
    String? errorMessage,
    Object? selectedImageNull = const Object(),
    Language? sourceLang,
    Language? targetLang,
    bool? isModelAvailable,
    double? modelDownloadProgress,
    String? modelDownloadFile,
  }) {
    return ImageTranslationState(
      status: status ?? this.status,
      selectedImage: identical(selectedImageNull, const Object())
          ? this.selectedImage
          : selectedImage,
      ocrResult: ocrResult ?? this.ocrResult,
      translatedText: translatedText ?? this.translatedText,
      errorMessage: errorMessage,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      isModelAvailable: isModelAvailable ?? this.isModelAvailable,
      modelDownloadProgress: modelDownloadProgress ?? this.modelDownloadProgress,
      modelDownloadFile: modelDownloadFile ?? this.modelDownloadFile,
    );
  }
}

class ImageTranslationNotifier extends StateNotifier<ImageTranslationState> {
  final RapidOcrDataSource _ocrDataSource;
  final Ref _ref;

  ImageTranslationNotifier(this._ocrDataSource, this._ref)
      : super(const ImageTranslationState()) {
    _init();
  }

  void _init() {
    _checkModelAvailability();
    _ref.listen(ocrModelManagerProvider, (previous, next) {
      _checkModelAvailability();
    });
  }

  Future<void> _checkModelAvailability() async {
    final ocrState = _ref.read(ocrModelManagerProvider);
    final activeVariant = ocrState.selectedVariant;
    _ocrDataSource.setActiveVariant(activeVariant);
    final available = await _ocrDataSource.isModelAvailable();
    if (state.isModelAvailable != available) {
      state = state.copyWith(isModelAvailable: available);
    }
  }

  void setImage(File image) {
    state = state.copyWith(
      selectedImage: image,
      selectedImageNull: Object(),
      status: ImageTranslationStatus.imageSelected,
      ocrResult: null,
      translatedText: null,
      errorMessage: null,
    );
    _checkModelAvailability();
  }

  void clearImage() {
    state = state.copyWith(
      selectedImage: null,
      selectedImageNull: Object(),
      status: ImageTranslationStatus.idle,
      ocrResult: null,
      translatedText: null,
      errorMessage: null,
    );
  }

  void updateSourceLang(Language lang) {
    state = state.copyWith(sourceLang: lang);
  }

  void updateTargetLang(Language lang) {
    state = state.copyWith(targetLang: lang);
  }

  Future<void> performOcr() async {
    final image = state.selectedImage;
    if (image == null) {
      debugPrint('[ImageTranslation] performOcr: no image selected');
      return;
    }

    debugPrint('[ImageTranslation] performOcr: checking model availability...');
    if (!await _ocrDataSource.isModelAvailable()) {
      debugPrint('[ImageTranslation] performOcr: model not available');
      state = state.copyWith(
        status: ImageTranslationStatus.error,
        errorMessage: 'OCR models not downloaded. Please download first.',
      );
      return;
    }

    debugPrint('[ImageTranslation] performOcr: starting OCR recognition...');
    state = state.copyWith(
      status: ImageTranslationStatus.ocrInProgress,
      errorMessage: null,
    );

    try {
      final result = await _ocrDataSource.recognize(image);
      debugPrint('[ImageTranslation] performOcr: OCR completed, blocks=${result.blocks.length}, text="${result.fullText.substring(0, (result.fullText.length > 100 ? 100 : result.fullText.length))}"');
      state = state.copyWith(
        status: ImageTranslationStatus.ocrCompleted,
        ocrResult: result,
      );
    } catch (e, stackTrace) {
      debugPrint('[ImageTranslation] performOcr: OCR error: $e');
      debugPrint('[ImageTranslation] performOcr: StackTrace: $stackTrace');
      state = state.copyWith(
        status: ImageTranslationStatus.error,
        errorMessage: 'OCR failed: ${e.toString()}',
      );
    }
  }

  void setTranslatedText(String text) {
    state = state.copyWith(
      status: ImageTranslationStatus.completed,
      translatedText: text,
    );
  }

  void setOcrResult(OcrResult result) {
    state = state.copyWith(
      ocrResult: result,
    );
  }

  void setTranslating() {
    state = state.copyWith(
      status: ImageTranslationStatus.translating,
    );
  }

  void setError(String message) {
    state = state.copyWith(
      status: ImageTranslationStatus.error,
      errorMessage: message,
    );
  }

  void reset() {
    state = const ImageTranslationState();
    _checkModelAvailability();
  }
}

final imageTranslationProvider =
    StateNotifierProvider<ImageTranslationNotifier, ImageTranslationState>(
  (ref) {
    final ocrDataSource = RapidOcrDataSource();
    return ImageTranslationNotifier(ocrDataSource, ref);
  },
);
