import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rftranslator/core/ffi/ctranslate2_ffi.dart';
import 'package:rftranslator/features/llm/domain/llm_service.dart';

class CTranslate2DataSource implements LlmDataSource {
  CTranslate2Translator? _translator;
  String? _modelPath;
  bool _isDisposed = false;

  bool get isLoaded => _translator?.isLoaded ?? false;

  static Future<bool> isAvailable() async {
    return await CTranslate2FFI.initialize();
  }

  @override
  Future<void> loadModel(String modelPath) async {
    if (_isDisposed) throw StateError('DataSource is disposed');

    if (_translator != null && _modelPath == modelPath) {
      debugPrint('[CT2] model already loaded: $modelPath');
      return;
    }

    debugPrint('[CT2] loadModel: $modelPath');

    if (!CTranslate2FFI.isAvailable) {
      final ok = await CTranslate2FFI.initialize();
      if (!ok) {
        throw StateError(
          'CTranslate2 library not found. '
          'Please run scripts/build_ctranslate2_windows.ps1 to compile it.',
        );
      }
    }

    _translator ??= CTranslate2Translator(CTranslate2FFI.instance!);

    _translator!.load(modelPath, numThreads: 4, computeType: 'int8');
    _modelPath = modelPath;
    debugPrint('[CT2] model loaded successfully from: $modelPath');
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) {
    if (_isDisposed) return Stream.error(StateError('DataSource is disposed'));
    if (_translator == null || !_translator!.isLoaded) {
      return Stream.error(StateError('Model not loaded'));
    }

    final controller = StreamController<String>();

    try {
      final result = _translator!.translate(
        prompt,
        beamSize: 4,
        maxLength: params?.maxTokens ?? 512,
      );
      controller.add(result);
      controller.close();
    } catch (e) {
      controller.addError(e);
      controller.close();
    }

    return controller.stream;
  }

  @override
  Future<void> releaseContext() async {}

  @override
  Future<void> restoreContext() async {}

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _translator?.dispose();
    _translator = null;
    _modelPath = null;
    debugPrint('[CT2] disposed');
  }
}
