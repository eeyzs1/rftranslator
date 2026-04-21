import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:rftranslator/core/ffi/ctranslate2_ffi.dart';
import 'package:rftranslator/features/llm/domain/llm_service.dart';

class CTranslate2DataSource implements LlmDataSource {
  CTranslate2Translator? _translator;
  String? _modelPath;
  String? _targetPrefix;
  bool _isDisposed = false;

  bool get isLoaded => _translator?.isLoaded ?? false;

  static Future<bool> isAvailable() async {
    return CTranslate2FFI.initializeSync();
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
      final ok = CTranslate2FFI.initializeSync();
      if (!ok) {
        throw StateError(
          'CTranslate2 library not found. '
          'Please run scripts/build_ctranslate2_windows.ps1 to compile it.',
        );
      }
    }

    _translator ??= CTranslate2Translator(CTranslate2FFI.instance!);

    debugPrint('[CT2] loadModel: $modelPath');
    _translator!.load(
      modelPath,
      numThreads: 4,
      computeType: 'float32',
      targetPrefix: _targetPrefix,
    );
    _modelPath = modelPath;
    debugPrint('[CT2] model loaded successfully from: $modelPath');
  }

  void setTargetPrefix(String? prefix) {
    _targetPrefix = prefix;
    debugPrint('[CT2] target prefix set to: $prefix');
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) {
    if (_isDisposed) return Stream.error(StateError('DataSource is disposed'));
    if (_translator == null || !_translator!.isLoaded) {
      return Stream.error(StateError('Model not loaded'));
    }

    final controller = StreamController<String>();

    try {
      String input = prompt;
      final zhPrefix = RegExp(r'^请将以下内容翻译成中文[，,]只输出翻译结果[：:]');
      final enPrefix = RegExp(r'^请将以下内容翻译成英文[，,]只输出翻译结果[：:]');
      final zhWordPrefix = RegExp(r'^翻译为中文[：:]');
      final enWordPrefix = RegExp(r'^翻译为英文[：:]');

      if (zhPrefix.hasMatch(input)) {
        input = input.replaceFirst(zhPrefix, '');
      } else if (enPrefix.hasMatch(input)) {
        input = input.replaceFirst(enPrefix, '');
      } else if (zhWordPrefix.hasMatch(input)) {
        input = input.replaceFirst(zhWordPrefix, '');
      } else if (enWordPrefix.hasMatch(input)) {
        input = input.replaceFirst(enWordPrefix, '');
      }

      final result = _translator!.translate(
        input,
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

  static Future<String?> translateInIsolate({
    required String modelPath,
    required String text,
    String? targetPrefix,
    int beamSize = 4,
    int maxLength = 512,
    double repetitionPenalty = 1.1,
  }) {
    return TranslationIsolateWorker.instance.translate(
      modelPath: modelPath,
      text: text,
      targetPrefix: targetPrefix,
      beamSize: beamSize,
      maxLength: maxLength,
      repetitionPenalty: repetitionPenalty,
    );
  }

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

class TranslationIsolateWorker {
  static TranslationIsolateWorker? _instance;
  static TranslationIsolateWorker get instance =>
      _instance ??= TranslationIsolateWorker._();

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _mainReceivePort;
  Completer<void>? _initCompleter;
  final _pendingResponses = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 0;
  bool _isShuttingDown = false;
  String? _currentModelPath;
  String? _currentTargetPrefix;

  TranslationIsolateWorker._();

  bool get _isModelLoaded =>
      _sendPort != null &&
      !_isShuttingDown &&
      _currentModelPath != null;

  bool _isSameModel(String modelPath, String? targetPrefix) =>
      _currentModelPath == modelPath &&
      _currentTargetPrefix == targetPrefix;

  Future<void> _ensureStarted() async {
    if (_sendPort != null && !_isShuttingDown) return;
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      return _initCompleter!.future;
    }

    _isShuttingDown = false;
    _initCompleter = Completer<void>();
    _mainReceivePort = ReceivePort();

    debugPrint('[CT2 Worker] Spawning worker isolate...');
    _isolate = await Isolate.spawn(
      _workerEntry,
      _mainReceivePort!.sendPort,
      debugName: 'CT2Worker',
    );

    _mainReceivePort!.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        if (!_initCompleter!.isCompleted) _initCompleter!.complete();
        debugPrint('[CT2 Worker] Worker isolate ready');
      } else if (message is Map) {
        final msg = Map<String, dynamic>.from(message);
        final id = msg['id'] as int?;
        if (id != null && _pendingResponses.containsKey(id)) {
          _pendingResponses.remove(id)!.complete(msg);
        }
      }
    });

    await _initCompleter!.future;
  }

  Future<Map<String, dynamic>> _send(Map<String, dynamic> req) async {
    await _ensureStarted();
    final id = _nextId++;
    req['id'] = id;
    final completer = Completer<Map<String, dynamic>>();
    _pendingResponses[id] = completer;
    _sendPort!.send(req);

    final cmd = req['cmd'] as String?;
    final timeoutDuration = cmd == 'load'
        ? const Duration(seconds: 120)
        : const Duration(minutes: 5);

    return completer.future.timeout(
      timeoutDuration,
      onTimeout: () {
        _pendingResponses.remove(id);
        debugPrint('[CT2 Worker] Request timed out, killing and restarting worker...');
        _killAndResetWorker();
        return {'id': id, 'type': 'error', 'error': 'Request timed out, worker restarted'};
      },
    );
  }

  void _killAndResetWorker() {
    _isolate?.kill(priority: Isolate.immediate);
    _mainReceivePort?.close();
    _isolate = null;
    _sendPort = null;
    _mainReceivePort = null;
    _isShuttingDown = false;
    _currentModelPath = null;
    _currentTargetPrefix = null;

    for (final completer in _pendingResponses.values) {
      if (!completer.isCompleted) {
        completer.complete({'type': 'error', 'error': 'Worker killed'});
      }
    }
    _pendingResponses.clear();
  }

  Future<String?> translate({
    required String modelPath,
    required String text,
    String? targetPrefix,
    int beamSize = 4,
    int maxLength = 512,
    double repetitionPenalty = 1.1,
  }) async {
    final sw = Stopwatch()..start();
    debugPrint('[CT2 Worker] translate: modelPath=$modelPath, targetPrefix=$targetPrefix');

    try {
      if (_isModelLoaded && !_isSameModel(modelPath, targetPrefix)) {
        debugPrint('[CT2 Worker] Model changed, killing old worker to avoid dispose hang...');
        _killAndResetWorker();
      }

      final loadResp = await _send({
        'cmd': 'load',
        'modelPath': modelPath,
        'targetPrefix': targetPrefix,
      });

      if (loadResp['success'] != true) {
        debugPrint('[CT2 Worker] Load failed: ${loadResp['error']}');
        return null;
      }

      _currentModelPath = modelPath;
      _currentTargetPrefix = targetPrefix;

      debugPrint('[CT2 Worker] Model loaded, translating...');

      final translateResp = await _send({
        'cmd': 'translate',
        'text': text,
        'beamSize': beamSize,
        'maxLength': maxLength,
        'repetitionPenalty': repetitionPenalty,
      });

      sw.stop();
      final result = translateResp['result'] as String?;
      debugPrint('[CT2 Worker] Translation completed in ${sw.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      sw.stop();
      debugPrint('[CT2 Worker] Error: $e (${sw.elapsedMilliseconds}ms)');
      return null;
    }
  }

  void sendShutdownSignal() {
    if (_sendPort != null && !_isShuttingDown) {
      _isShuttingDown = true;
      _sendPort!.send({'cmd': 'shutdown'});
    }
  }

  Future<void> shutdown() async {
    _isShuttingDown = true;
    _isolate?.kill(priority: Isolate.immediate);
    _mainReceivePort?.close();
    _isolate = null;
    _sendPort = null;
    _mainReceivePort = null;
    _currentModelPath = null;
    _currentTargetPrefix = null;
    _instance = null;
  }

  static void _workerEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    CTranslate2Translator? translator;
    String? loadedModelPath;
    String? loadedTargetPrefix;

    receivePort.listen((message) {
      if (message is! Map) return;
      final msg = Map<String, dynamic>.from(message);
      final cmd = msg['cmd'] as String?;

      if (cmd == 'shutdown') {
        receivePort.close();
        Isolate.exit();
      }

      final id = msg['id'] as int;

      if (cmd == 'load') {
        final modelPath = msg['modelPath'] as String;
        final targetPrefix = msg['targetPrefix'] as String?;

        if (loadedModelPath == modelPath &&
            loadedTargetPrefix == targetPrefix &&
            translator != null &&
            translator!.isLoaded) {
          mainSendPort.send({'id': id, 'type': 'load', 'success': true});
          return;
        }

        try {
          if (!CTranslate2FFI.isAvailable) {
            if (!CTranslate2FFI.initializeSync()) {
              mainSendPort.send({
                'id': id,
                'type': 'load',
                'success': false,
                'error': 'FFI init failed',
              });
              return;
            }
          }

          translator = CTranslate2Translator(CTranslate2FFI.instance!);
          translator!.load(modelPath, targetPrefix: targetPrefix);
          loadedModelPath = modelPath;
          loadedTargetPrefix = targetPrefix;

          mainSendPort.send({'id': id, 'type': 'load', 'success': true});
        } catch (e) {
          translator = null;
          loadedModelPath = null;
          loadedTargetPrefix = null;
          mainSendPort.send({
            'id': id,
            'type': 'load',
            'success': false,
            'error': e.toString(),
          });
        }
      } else if (cmd == 'translate') {
        try {
          if (translator == null || !translator!.isLoaded) {
            mainSendPort.send({
              'id': id,
              'type': 'translate',
              'result': null,
              'error': 'Model not loaded',
            });
            return;
          }

          final result = translator!.translate(
            msg['text'] as String,
            beamSize: msg['beamSize'] as int,
            maxLength: msg['maxLength'] as int,
            repetitionPenalty: msg['repetitionPenalty'] as double,
          );

          mainSendPort.send({'id': id, 'type': 'translate', 'result': result});
        } catch (e) {
          mainSendPort.send({
            'id': id,
            'type': 'translate',
            'result': null,
            'error': e.toString(),
          });
        }
      }
    });
  }
}
