import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';
import 'package:rftranslator/features/llm/domain/llm_service.dart';

class LlamaCppDataSource implements LlmDataSource {
  LlamaEngine? _engine;
  String? _modelPath;
  bool _isLoaded = false;
  bool _isDisposed = false;

  bool get isLoaded => _isLoaded;

  @override
  Future<void> loadModel(String modelPath) async {
    if (_isDisposed) throw StateError('DataSource is disposed');

    if (_isLoaded && _modelPath == modelPath) {
      debugPrint('[LlamaCpp] model already loaded: $modelPath');
      return;
    }

    debugPrint('[LlamaCpp] loadModel: $modelPath');

    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
    }

    _engine = LlamaEngine(LlamaBackend());
    await _engine!.loadModel(modelPath);

    _modelPath = modelPath;
    _isLoaded = true;
    debugPrint('[LlamaCpp] model loaded successfully');
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) {
    if (_isDisposed) return Stream.error(StateError('DataSource is disposed'));
    if (_engine == null || !_isLoaded) {
      return Stream.error(StateError('Model not loaded'));
    }

    final effectiveParams = params ?? InferenceParams.defaults;

    debugPrint('[LlamaCpp] generate: prompt="${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}..." maxTokens=${effectiveParams.maxTokens}');

    return _engine!.generate(prompt).map((token) {
      return token;
    }).handleError((error, stackTrace) {
      debugPrint('[LlamaCpp] generate error: $error');
      debugPrint('[LlamaCpp] StackTrace: $stackTrace');
    });
  }

  @override
  Future<void> releaseContext() async {
    debugPrint('[LlamaCpp] releaseContext (no-op for llamadart)');
  }

  @override
  Future<void> restoreContext() async {
    debugPrint('[LlamaCpp] restoreContext (no-op for llamadart)');
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
    }
    _isLoaded = false;
    _modelPath = null;
    debugPrint('[LlamaCpp] disposed');
  }
}
