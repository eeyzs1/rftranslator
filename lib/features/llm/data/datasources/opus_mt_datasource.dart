import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rftranslator/features/llm/domain/llm_service.dart';

class OpusMtDataSource implements LlmDataSource {
  Process? _process;
  String? _modelPath;
  bool _isLoaded = false;
  bool _isDisposed = false;
  final _pendingRequests = <Completer<Map<String, dynamic>>>[];

  bool get isLoaded => _isLoaded;

  @override
  Future<void> loadModel(String modelPath) async {
    if (_isDisposed) throw StateError('DataSource is disposed');

    if (_isLoaded && _modelPath == modelPath) {
      debugPrint('[OpusMt] model already loaded: $modelPath');
      return;
    }

    debugPrint('[OpusMt] loadModel: $modelPath');

    await _ensureProcessRunning();

    final result = await _sendCommand({
      'cmd': 'load',
      'model_path': modelPath,
    });

    if (result['status'] == 'error') {
      throw Exception('Failed to load OPUS-MT model: ${result['error']}');
    }

    _modelPath = modelPath;
    _isLoaded = true;
    debugPrint('[OpusMt] model loaded successfully');
  }

  Future<void> _ensureProcessRunning() async {
    if (_process != null) {
      return;
    }

    final scriptPath = await _findServerScript();
    if (scriptPath == null) {
      throw StateError(
        '未找到 opus_mt_server.py 脚本！\n'
        '请确保 scripts/opus_mt_server.py 存在于项目目录中。',
      );
    }

    final pythonPath = await _findPython();
    if (pythonPath == null) {
      throw StateError(
        '未找到 Python！\n'
        '请安装 Python 3.8+ 并确保 python 命令可用。\n'
        '安装后运行: pip install transformers torch',
      );
    }

    debugPrint('[OpusMt] Starting Python server: $pythonPath $scriptPath');

    _process = await Process.start(
      pythonPath,
      [scriptPath],
      environment: {
        'PYTHONIOENCODING': 'utf-8',
        'PYTHONUNBUFFERED': '1',
      },
    );

    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleResponse);

    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      debugPrint('[OpusMt:stderr] $line');
    });

    _process!.exitCode.then((code) {
      debugPrint('[OpusMt] Process exited with code $code');
      _process = null;
      _isLoaded = false;
      for (final completer in _pendingRequests) {
        if (!completer.isCompleted) {
          completer.completeError('Process exited');
        }
      }
      _pendingRequests.clear();
    });
  }

  void _handleResponse(String line) {
    if (line.isEmpty) return;
    try {
      final response = jsonDecode(line) as Map<String, dynamic>;
      if (_pendingRequests.isNotEmpty) {
        final completer = _pendingRequests.removeAt(0);
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      }
    } catch (e) {
      debugPrint('[OpusMt] Error parsing response: $e, line: $line');
    }
  }

  Future<Map<String, dynamic>> _sendCommand(Map<String, dynamic> command) async {
    if (_process == null) {
      throw StateError('Python process not running');
    }

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests.add(completer);

    _process!.stdin.writeln(jsonEncode(command));

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _pendingRequests.remove(completer);
        return {'error': 'Request timed out'};
      },
    );
  }

  @override
  Stream<String> generate(String prompt, {InferenceParams? params}) {
    if (_isDisposed) return Stream.error(StateError('DataSource is disposed'));
    if (!_isLoaded) return Stream.error(StateError('Model not loaded'));

    final controller = StreamController<String>();

    _sendCommand({
      'cmd': 'translate',
      'text': prompt,
    }).then((result) {
      if (result.containsKey('error')) {
        controller.addError(Exception(result['error']));
      } else {
        final translation = result['translation'] as String? ?? '';
        controller.add(translation);
      }
      controller.close();
    }).catchError((error) {
      controller.addError(error);
      controller.close();
    });

    return controller.stream;
  }

  @override
  Future<void> releaseContext() async {
    debugPrint('[OpusMt] releaseContext (no-op)');
  }

  @override
  Future<void> restoreContext() async {
    debugPrint('[OpusMt] restoreContext (no-op)');
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    if (_process != null) {
      try {
        _process!.stdin.writeln(jsonEncode({'cmd': 'quit'}));
        await _process!.stdin.flush();
        await _process!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            _process!.kill();
            return -1;
          },
        );
      } catch (e) {
        debugPrint('[OpusMt] Error disposing: $e');
        _process?.kill();
      }
      _process = null;
    }

    _isLoaded = false;
    _modelPath = null;

    for (final completer in _pendingRequests) {
      if (!completer.isCompleted) {
        completer.completeError('DataSource disposed');
      }
    }
    _pendingRequests.clear();
    debugPrint('[OpusMt] disposed');
  }

  Future<String?> _findPython() async {
    final candidates = ['python', 'python3', 'python.exe', 'python3.exe'];

    for (final name in candidates) {
      try {
        final result = await Process.run(name, ['--version']);
        if (result.exitCode == 0) {
          debugPrint('[OpusMt] Found Python: $name');
          return name;
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Future<String?> _findServerScript() async {
    final appDir = await getApplicationDocumentsDirectory();
    final scriptPath = path.join(appDir.path, 'scripts', 'opus_mt_server.py');
    if (File(scriptPath).existsSync()) return scriptPath;

    final currentDir = Directory.current.path;
    final currentScriptPath = path.join(currentDir, 'scripts', 'opus_mt_server.py');
    if (File(currentScriptPath).existsSync()) return currentScriptPath;

    final parentScriptPath = path.join(Directory(currentDir).parent.path, 'scripts', 'opus_mt_server.py');
    if (File(parentScriptPath).existsSync()) return parentScriptPath;

    return null;
  }
}
