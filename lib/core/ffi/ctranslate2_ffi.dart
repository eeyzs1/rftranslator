import 'dart:ffi';
import 'dart:io' show Directory, File, Platform;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

final class CTranslator extends Opaque {}
final class CTranslatorOptions extends Opaque {}
final class CTranslationOptions extends Opaque {}
final class CTranslationResult extends Opaque {}
final class CStringVector extends Opaque {}

typedef CTranslatorNewNative = Pointer<CTranslator> Function(
  Pointer<Utf8> modelPath,
  Pointer<Utf8> device,
  Int32 deviceIndex,
  Pointer<CTranslatorOptions> options,
);
typedef CTranslatorNewDart = Pointer<CTranslator> Function(
  Pointer<Utf8> modelPath,
  Pointer<Utf8> device,
  int deviceIndex,
  Pointer<CTranslatorOptions> options,
);

typedef CTranslatorDeleteNative = Void Function(Pointer<CTranslator>);
typedef CTranslatorDeleteDart = void Function(Pointer<CTranslator>);

typedef CTranslatorSetTargetPrefixNative = Void Function(
  Pointer<CTranslator> translator,
  Pointer<Utf8> targetPrefix,
);
typedef CTranslatorSetTargetPrefixDart = void Function(
  Pointer<CTranslator> translator,
  Pointer<Utf8> targetPrefix,
);

typedef CTranslatorTranslateBatchNative = Pointer<Pointer<CTranslationResult>> Function(
  Pointer<CTranslator> translator,
  Pointer<Pointer<CStringVector>> input,
  IntPtr inputSize,
  Pointer<CTranslationOptions> options,
);
typedef CTranslatorTranslateBatchDart = Pointer<Pointer<CTranslationResult>> Function(
  Pointer<CTranslator> translator,
  Pointer<Pointer<CStringVector>> input,
  int inputSize,
  Pointer<CTranslationOptions> options,
);

typedef CTranslationResultGetOutputNative = Pointer<CStringVector> Function(
  Pointer<CTranslationResult> result,
  IntPtr index,
);
typedef CTranslationResultGetOutputDart = Pointer<CStringVector> Function(
  Pointer<CTranslationResult> result,
  int index,
);

typedef CTranslationResultDeleteNative = Void Function(Pointer<CTranslationResult>);
typedef CTranslationResultDeleteDart = void Function(Pointer<CTranslationResult>);

typedef CStringVectorNewNative = Pointer<CStringVector> Function();
typedef CStringVectorNewDart = Pointer<CStringVector> Function();

typedef CStringVectorDeleteNative = Void Function(Pointer<CStringVector>);
typedef CStringVectorDeleteDart = void Function(Pointer<CStringVector>);

typedef CStringVectorPushBackNative = Void Function(
  Pointer<CStringVector> vector,
  Pointer<Utf8> str,
);
typedef CStringVectorPushBackDart = void Function(
  Pointer<CStringVector> vector,
  Pointer<Utf8> str,
);

typedef CStringVectorAtNative = Pointer<Utf8> Function(
  Pointer<CStringVector> vector,
  IntPtr index,
);
typedef CStringVectorAtDart = Pointer<Utf8> Function(
  Pointer<CStringVector> vector,
  int index,
);

typedef CStringVectorSizeNative = IntPtr Function(Pointer<CStringVector>);
typedef CStringVectorSizeDart = int Function(Pointer<CStringVector>);

typedef CTranslatorOptionsNewNative = Pointer<CTranslatorOptions> Function();
typedef CTranslatorOptionsNewDart = Pointer<CTranslatorOptions> Function();

typedef CTranslatorOptionsDeleteNative = Void Function(Pointer<CTranslatorOptions>);
typedef CTranslatorOptionsDeleteDart = void Function(Pointer<CTranslatorOptions>);

typedef CTranslatorOptionsSetComputeTypeNative = Void Function(
  Pointer<CTranslatorOptions> options,
  Pointer<Utf8> computeType,
);
typedef CTranslatorOptionsSetComputeTypeDart = void Function(
  Pointer<CTranslatorOptions> options,
  Pointer<Utf8> computeType,
);

typedef CTranslatorOptionsSetIntraThreadsNative = Void Function(
  Pointer<CTranslatorOptions> options,
  IntPtr numThreads,
);
typedef CTranslatorOptionsSetIntraThreadsDart = void Function(
  Pointer<CTranslatorOptions> options,
  int numThreads,
);

typedef CTranslationOptionsNewNative = Pointer<CTranslationOptions> Function();
typedef CTranslationOptionsNewDart = Pointer<CTranslationOptions> Function();

typedef CTranslationOptionsDeleteNative = Void Function(Pointer<CTranslationOptions>);
typedef CTranslationOptionsDeleteDart = void Function(Pointer<CTranslationOptions>);

typedef CTranslationOptionsSetBeamSizeNative = Void Function(
  Pointer<CTranslationOptions> options,
  IntPtr beamSize,
);
typedef CTranslationOptionsSetBeamSizeDart = void Function(
  Pointer<CTranslationOptions> options,
  int beamSize,
);

typedef CTranslationOptionsSetMaxDecodingLengthNative = Void Function(
  Pointer<CTranslationOptions> options,
  IntPtr length,
);
typedef CTranslationOptionsSetMaxDecodingLengthDart = void Function(
  Pointer<CTranslationOptions> options,
  int length,
);

typedef CTranslationOptionsSetReturnScoresNative = Void Function(
  Pointer<CTranslationOptions> options,
  Bool returnScores,
);
typedef CTranslationOptionsSetReturnScoresDart = void Function(
  Pointer<CTranslationOptions> options,
  bool returnScores,
);

typedef CTranslationOptionsSetRepetitionPenaltyNative = Void Function(
  Pointer<CTranslationOptions> options,
  Float penalty,
);
typedef CTranslationOptionsSetRepetitionPenaltyDart = void Function(
  Pointer<CTranslationOptions> options,
  double penalty,
);

class CTranslate2FFI {
  static CTranslate2FFI? _instance;
  static DynamicLibrary? _dylib;

  late final CTranslatorNewDart translatorNew;
  late final CTranslatorDeleteDart translatorDelete;
  late final CTranslatorSetTargetPrefixDart translatorSetTargetPrefix;
  late final CTranslatorTranslateBatchDart translatorTranslateBatch;
  late final CTranslationResultGetOutputDart translationResultGetOutput;
  late final CTranslationResultDeleteDart translationResultDelete;
  late final CStringVectorNewDart stringVectorNew;
  late final CStringVectorDeleteDart stringVectorDelete;
  late final CStringVectorPushBackDart stringVectorPushBack;
  late final CStringVectorAtDart stringVectorAt;
  late final CStringVectorSizeDart stringVectorSize;
  late final CTranslatorOptionsNewDart translatorOptionsNew;
  late final CTranslatorOptionsDeleteDart translatorOptionsDelete;
  late final CTranslatorOptionsSetComputeTypeDart translatorOptionsSetComputeType;
  late final CTranslatorOptionsSetIntraThreadsDart translatorOptionsSetIntraThreads;
  late final CTranslationOptionsNewDart translationOptionsNew;
  late final CTranslationOptionsDeleteDart translationOptionsDelete;
  late final CTranslationOptionsSetBeamSizeDart translationOptionsSetBeamSize;
  late final CTranslationOptionsSetMaxDecodingLengthDart translationOptionsSetMaxDecodingLength;
  late final CTranslationOptionsSetReturnScoresDart translationOptionsSetReturnScores;
  late final CTranslationOptionsSetRepetitionPenaltyDart translationOptionsSetRepetitionPenalty;

  CTranslate2FFI._() {
    final lib = _dylib!;
    translatorNew = lib.lookupFunction<CTranslatorNewNative, CTranslatorNewDart>(
      'ctranslate2_Translator_new',
    );
    translatorDelete = lib.lookupFunction<CTranslatorDeleteNative, CTranslatorDeleteDart>(
      'ctranslate2_Translator_delete',
    );
    translatorSetTargetPrefix = lib.lookupFunction<CTranslatorSetTargetPrefixNative, CTranslatorSetTargetPrefixDart>(
      'ctranslate2_Translator_set_target_prefix',
    );
    translatorTranslateBatch = lib.lookupFunction<CTranslatorTranslateBatchNative, CTranslatorTranslateBatchDart>(
      'ctranslate2_Translator_translate_batch',
    );
    translationResultGetOutput = lib.lookupFunction<CTranslationResultGetOutputNative, CTranslationResultGetOutputDart>(
      'ctranslate2_TranslationResult_get_output',
    );
    translationResultDelete = lib.lookupFunction<CTranslationResultDeleteNative, CTranslationResultDeleteDart>(
      'ctranslate2_TranslationResult_delete',
    );
    stringVectorNew = lib.lookupFunction<CStringVectorNewNative, CStringVectorNewDart>(
      'ctranslate2_StringVector_new',
    );
    stringVectorDelete = lib.lookupFunction<CStringVectorDeleteNative, CStringVectorDeleteDart>(
      'ctranslate2_StringVector_delete',
    );
    stringVectorPushBack = lib.lookupFunction<CStringVectorPushBackNative, CStringVectorPushBackDart>(
      'ctranslate2_StringVector_push_back',
    );
    stringVectorAt = lib.lookupFunction<CStringVectorAtNative, CStringVectorAtDart>(
      'ctranslate2_StringVector_at',
    );
    stringVectorSize = lib.lookupFunction<CStringVectorSizeNative, CStringVectorSizeDart>(
      'ctranslate2_StringVector_size',
    );
    translatorOptionsNew = lib.lookupFunction<CTranslatorOptionsNewNative, CTranslatorOptionsNewDart>(
      'ctranslate2_TranslatorOptions_new',
    );
    translatorOptionsDelete = lib.lookupFunction<CTranslatorOptionsDeleteNative, CTranslatorOptionsDeleteDart>(
      'ctranslate2_TranslatorOptions_delete',
    );
    translatorOptionsSetComputeType = lib.lookupFunction<CTranslatorOptionsSetComputeTypeNative, CTranslatorOptionsSetComputeTypeDart>(
      'ctranslate2_TranslatorOptions_set_compute_type',
    );
    translatorOptionsSetIntraThreads = lib.lookupFunction<CTranslatorOptionsSetIntraThreadsNative, CTranslatorOptionsSetIntraThreadsDart>(
      'ctranslate2_TranslatorOptions_set_intra_threads',
    );
    translationOptionsNew = lib.lookupFunction<CTranslationOptionsNewNative, CTranslationOptionsNewDart>(
      'ctranslate2_TranslationOptions_new',
    );
    translationOptionsDelete = lib.lookupFunction<CTranslationOptionsDeleteNative, CTranslationOptionsDeleteDart>(
      'ctranslate2_TranslationOptions_delete',
    );
    translationOptionsSetBeamSize = lib.lookupFunction<CTranslationOptionsSetBeamSizeNative, CTranslationOptionsSetBeamSizeDart>(
      'ctranslate2_TranslationOptions_set_beam_size',
    );
    translationOptionsSetMaxDecodingLength = lib.lookupFunction<CTranslationOptionsSetMaxDecodingLengthNative, CTranslationOptionsSetMaxDecodingLengthDart>(
      'ctranslate2_TranslationOptions_set_max_decoding_length',
    );
    translationOptionsSetReturnScores = lib.lookupFunction<CTranslationOptionsSetReturnScoresNative, CTranslationOptionsSetReturnScoresDart>(
      'ctranslate2_TranslationOptions_set_return_scores',
    );
    translationOptionsSetRepetitionPenalty = lib.lookupFunction<CTranslationOptionsSetRepetitionPenaltyNative, CTranslationOptionsSetRepetitionPenaltyDart>(
      'ctranslate2_TranslationOptions_set_repetition_penalty',
    );
  }

  static CTranslate2FFI? get instance => _instance;

  static bool get isAvailable => _dylib != null;

  static Future<bool> initialize() async {
    return initializeSync();
  }

  static bool initializeSync() {
    if (_dylib != null) return true;

    try {
      final libPath = _findLibrary();
      if (libPath == null) {
        debugPrint('[CTranslate2FFI] Library not found in any search path');
        return false;
      }

      debugPrint('[CTranslate2FFI] Loading library from: $libPath');
      _dylib = DynamicLibrary.open(libPath);
      _instance = CTranslate2FFI._();
      debugPrint('[CTranslate2FFI] Library loaded successfully');
      return true;
    } catch (e) {
      debugPrint('[CTranslate2FFI] Failed to load library: $e');
      return false;
    }
  }

  static String? _findLibrary() {
    if (Platform.isWindows) {
      final candidates = <String>[
        'ctranslate2.dll',
        '${Directory.current.path}\\windows\\libs\\ctranslate2.dll',
      ];

      final exePath = Platform.resolvedExecutable;
      final exeDir = exePath.substring(0, exePath.lastIndexOf('\\'));
      candidates.add('$exeDir\\ctranslate2.dll');

      for (final path in candidates) {
        final file = File(path);
        if (file.existsSync()) return path;
      }
    } else if (Platform.isAndroid) {
      return 'libctranslate2.so';
    } else if (Platform.isLinux) {
      final candidates = <String>[
        'libctranslate2.so',
        '/usr/local/lib/libctranslate2.so',
      ];
      for (final path in candidates) {
        final file = File(path);
        if (file.existsSync()) return path;
      }
    }
    return null;
  }
}

class CTranslate2Translator {
  final CTranslate2FFI _ffi;
  Pointer<CTranslator>? _ptr;

  CTranslate2Translator(this._ffi);

  bool get isLoaded => _ptr != null;

  void load(String modelPath, {int numThreads = 4, String computeType = 'float32', String? targetPrefix}) {
    debugPrint('[CT2 FFI] load() called: modelPath=$modelPath, numThreads=$numThreads, computeType=$computeType, targetPrefix=$targetPrefix');
    if (_ptr != null) {
      debugPrint('[CT2 FFI] Deleting old translator...');
      _ffi.translatorDelete(_ptr!);
      _ptr = null;
      debugPrint('[CT2 FFI] Old translator deleted');
    }

    final modelPathC = modelPath.toNativeUtf8();
    final deviceC = 'cpu'.toNativeUtf8();

    final options = _ffi.translatorOptionsNew();
    final computeTypeC = computeType.toNativeUtf8();
    _ffi.translatorOptionsSetComputeType(options, computeTypeC);
    _ffi.translatorOptionsSetIntraThreads(options, numThreads);

    try {
      debugPrint('[CT2 FFI] Calling translatorNew...');
      _ptr = _ffi.translatorNew(modelPathC, deviceC, 0, options);
      debugPrint('[CT2 FFI] translatorNew returned: ptr=$_ptr');
      if (_ptr == nullptr) {
        throw Exception('Failed to create CTranslate2 translator for: $modelPath');
      }

      if (targetPrefix != null && targetPrefix.isNotEmpty) {
        debugPrint('[CT2 FFI] Setting target prefix: $targetPrefix');
        final prefixC = targetPrefix.toNativeUtf8();
        _ffi.translatorSetTargetPrefix(_ptr!, prefixC);
        calloc.free(prefixC);
        debugPrint('[CT2 FFI] Target prefix set');
      }
    } finally {
      calloc.free(modelPathC);
      calloc.free(deviceC);
      calloc.free(computeTypeC);
      _ffi.translatorOptionsDelete(options);
    }
    debugPrint('[CT2 FFI] load() completed successfully');
  }

  String translate(String text, {int beamSize = 4, int maxLength = 512, double repetitionPenalty = 1.1}) {
    if (_ptr == null) throw StateError('Translator not loaded');

    final inputVec = _ffi.stringVectorNew();
    final textC = text.toNativeUtf8();
    _ffi.stringVectorPushBack(inputVec, textC);
    calloc.free(textC);

    final inputPtr = calloc<Pointer<CStringVector>>();
    inputPtr.value = inputVec;

    final options = _ffi.translationOptionsNew();
    _ffi.translationOptionsSetBeamSize(options, beamSize);
    _ffi.translationOptionsSetMaxDecodingLength(options, maxLength);
    _ffi.translationOptionsSetReturnScores(options, false);
    _ffi.translationOptionsSetRepetitionPenalty(options, repetitionPenalty);

    try {
      final results = _ffi.translatorTranslateBatch(_ptr!, inputPtr, 1, options);
      final result = results[0];

      final outputVec = _ffi.translationResultGetOutput(result, 0);
      final outputSize = _ffi.stringVectorSize(outputVec);

      final sb = StringBuffer();
      for (var i = 0; i < outputSize; i++) {
        if (i > 0) sb.write(' ');
        final strPtr = _ffi.stringVectorAt(outputVec, i);
        sb.write(strPtr.toDartString());
      }

      _ffi.translationResultDelete(result);
      _ffi.stringVectorDelete(outputVec);

      return sb.toString();
    } finally {
      _ffi.stringVectorDelete(inputVec);
      calloc.free(inputPtr);
      _ffi.translationOptionsDelete(options);
    }
  }

  void dispose() {
    if (_ptr != null) {
      _ffi.translatorDelete(_ptr!);
      _ptr = null;
    }
  }
}
