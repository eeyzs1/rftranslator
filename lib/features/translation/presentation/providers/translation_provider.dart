import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rftranslator/core/di/providers.dart';
import 'package:rftranslator/features/dictionary/domain/dictionary_manager.dart';
import 'package:rftranslator/features/dictionary/domain/entities/word_entry.dart';
import 'package:rftranslator/features/llm/domain/llm_service.dart';
import 'package:rftranslator/features/llm/domain/model_manager.dart';
import 'package:rftranslator/features/llm/data/datasources/ctranslate2_datasource.dart';
import 'package:rftranslator/features/translation/domain/entities/language.dart';
import 'package:rftranslator/features/translation/domain/entities/translation_result.dart';
import 'package:rftranslator/features/translation/domain/entities/translation_source.dart';
import 'package:rftranslator/features/translation/data/models/translation_history.dart';
import 'package:rftranslator/features/translation/domain/translation_history_provider.dart';

const _unset = Object();

class DictionaryTranslationResult {
  final String dictionaryId;
  final String dictionaryName;
  final String targetText;
  final String? phonetic;
  final List<String> definitions;
  final List<String> examples;
  final String dictionaryExplanation;

  const DictionaryTranslationResult({
    required this.dictionaryId,
    required this.dictionaryName,
    required this.targetText,
    this.phonetic,
    this.definitions = const [],
    this.examples = const [],
    this.dictionaryExplanation = '',
  });
}

class ModelTranslationResult {
  final String modelId;
  final String modelName;
  final String targetText;

  const ModelTranslationResult({
    required this.modelId,
    required this.modelName,
    required this.targetText,
  });
}

class TranslationState {
  final String sourceText;
  final String targetText;
  final Language sourceLang;
  final Language targetLang;
  final bool isTranslating;
  final bool isTranslatingWithLLM;
  final bool isLoadingDictionary;
  final String? error;
  final bool hasDictionaryResult;
  final bool hasLLMResult;
  final TranslationResult? result;
  final String? phonetic;
  final List<String>? definitions;
  final List<String>? examples;
  final bool isWordOrPhrase;
  final String? llmTranslation;
  final List<DictionaryTranslationResult> dictionaryResults;
  final List<ModelTranslationResult> modelResults;
  final String? translatingModelName;
  final int translatingModelIndex;
  final int translatingModelTotal;

  TranslationState({
    this.sourceText = '',
    this.targetText = '',
    this.sourceLang = Language.english,
    this.targetLang = Language.chinese,
    this.isTranslating = false,
    this.isTranslatingWithLLM = false,
    this.isLoadingDictionary = false,
    this.error,
    this.hasDictionaryResult = false,
    this.hasLLMResult = false,
    this.result,
    this.phonetic,
    this.definitions,
    this.examples,
    this.isWordOrPhrase = false,
    this.llmTranslation,
    this.dictionaryResults = const [],
    this.modelResults = const [],
    this.translatingModelName,
    this.translatingModelIndex = 0,
    this.translatingModelTotal = 0,
  });

  TranslationState copyWith({
    String? sourceText,
    String? targetText,
    Language? sourceLang,
    Language? targetLang,
    bool? isTranslating,
    bool? isTranslatingWithLLM,
    bool? isLoadingDictionary,
    Object? error = _unset,
    bool? hasDictionaryResult,
    bool? hasLLMResult,
    TranslationResult? result,
    String? phonetic,
    List<String>? definitions,
    List<String>? examples,
    bool? isWordOrPhrase,
    Object? llmTranslation = _unset,
    List<DictionaryTranslationResult>? dictionaryResults,
    List<ModelTranslationResult>? modelResults,
    Object? translatingModelName = _unset,
    int? translatingModelIndex,
    int? translatingModelTotal,
  }) {
    return TranslationState(
      sourceText: sourceText ?? this.sourceText,
      targetText: targetText ?? this.targetText,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      isTranslating: isTranslating ?? this.isTranslating,
      isTranslatingWithLLM: isTranslatingWithLLM ?? this.isTranslatingWithLLM,
      isLoadingDictionary: isLoadingDictionary ?? this.isLoadingDictionary,
      error: identical(error, _unset) ? this.error : error as String?,
      hasDictionaryResult: hasDictionaryResult ?? this.hasDictionaryResult,
      hasLLMResult: hasLLMResult ?? this.hasLLMResult,
      result: result ?? this.result,
      phonetic: phonetic ?? this.phonetic,
      definitions: definitions ?? this.definitions,
      examples: examples ?? this.examples,
      isWordOrPhrase: isWordOrPhrase ?? this.isWordOrPhrase,
      llmTranslation: identical(llmTranslation, _unset) ? this.llmTranslation : llmTranslation as String?,
      dictionaryResults: dictionaryResults ?? this.dictionaryResults,
      modelResults: modelResults ?? this.modelResults,
      translatingModelName: identical(translatingModelName, _unset) ? this.translatingModelName : translatingModelName as String?,
      translatingModelIndex: translatingModelIndex ?? this.translatingModelIndex,
      translatingModelTotal: translatingModelTotal ?? this.translatingModelTotal,
    );
  }
}

class TranslationNotifier extends StateNotifier<TranslationState> {
  final Ref _ref;

  TranslationNotifier(this._ref) : super(TranslationState());

  void updateSourceText(String text) {
    state = state.copyWith(sourceText: text);
  }

  void updateSourceLang(Language lang) {
    state = state.copyWith(sourceLang: lang);
  }

  void updateTargetLang(Language lang) {
    state = state.copyWith(targetLang: lang);
  }

  void swapLanguages() {
    state = state.copyWith(
      sourceLang: state.targetLang,
      targetLang: state.sourceLang,
      sourceText: state.targetText,
      targetText: state.sourceText,
    );
  }

  Future<void> translate() async {
    if (state.sourceText.trim().isEmpty) return;

    debugPrint('[Translation] ===== START TRANSLATION =====');
    debugPrint('[Translation] sourceText: "${state.sourceText}"');
    debugPrint('[Translation] sourceLang: ${state.sourceLang} (${state.sourceLang.code})');
    debugPrint('[Translation] targetLang: ${state.targetLang} (${state.targetLang.code})');

    state = state.copyWith(
      isTranslating: true,
      isTranslatingWithLLM: false,
      error: null,
      hasDictionaryResult: false,
      hasLLMResult: false,
      llmTranslation: null,
      targetText: '',
      phonetic: null,
      definitions: null,
      examples: null,
      dictionaryResults: [],
      modelResults: [],
      translatingModelName: null,
      translatingModelIndex: 0,
      translatingModelTotal: 0,
    );

    try {
      final llmService = _ref.read(llmServiceProvider.notifier);
      final isWordOrPhrase = llmService.isWordOrPhrase(state.sourceText);
      debugPrint('[Translation] isWordOrPhrase: $isWordOrPhrase');
      state = state.copyWith(isWordOrPhrase: isWordOrPhrase);

      if (isWordOrPhrase) {
        await _translateWordOrPhrase();
      } else {
        await _translateSentence();
      }
    } catch (e, stackTrace) {
      debugPrint('[Translation] EXCEPTION: $e');
      debugPrint('[Translation] StackTrace: $stackTrace');
      state = state.copyWith(
        isTranslating: false,
        isTranslatingWithLLM: false,
        error: '\u7FFB\u8BD1\u5931\u8D25\uFF1A${e.toString()}',
      );
    }
  }

  Future<void> _translateWordOrPhrase() async {
    final dictState = _ref.read(dictionaryManagerProvider);

    debugPrint('[Translation] selectedDictionaryIds: ${dictState.selectedDictionaryIds}');
    debugPrint('[Translation] allDownloadedPaths: $allDownloadedPaths');

    final matchedDicts = findAllDictionariesForLangPair(
      dictState.selectedDictionaryIds,
      state.sourceLang,
      state.targetLang,
    );

    debugPrint('[Translation] matchedDicts count: ${matchedDicts.length}');
    for (final d in matchedDicts) {
      debugPrint('[Translation]   matched: id=${d.id}, isStarDict=${d.isStarDict}, isMDict=${d.isMDict}, sourceLang=${d.sourceLang}, targetLang=${d.targetLang}, localDirName=${d.localDirName}, originalName=${d.originalName}');
    }

    final dictResults = <DictionaryTranslationResult>[];

    for (final matchedDictMeta in matchedDicts) {
      debugPrint('[Translation] --- Looking up in dictionary: ${matchedDictMeta.id} (${matchedDictMeta.originalName ?? matchedDictMeta.displayName('zh')}) ---');

      try {
        final wordEntry = await _lookupWordInDictionary(matchedDictMeta);
        if (wordEntry != null && wordEntry.definitions.isNotEmpty) {
          debugPrint('[Translation]   FOUND: ${wordEntry.definitions.length} definitions, first="${wordEntry.definitions.first.chinese}"');
          final dictName = matchedDictMeta.originalName ?? matchedDictMeta.displayName('zh');
          final translationResult = wordEntry.definitions.first.chinese;
          final definitions = wordEntry.definitions.map((d) => d.chinese).toList();
          final examples = wordEntry.examples.map((e) => e.english).toList();
          final dictionaryExplanation = wordEntry.definitions.map((d) => '${d.partOfSpeech} ${d.chinese}').join('\n');

          dictResults.add(DictionaryTranslationResult(
            dictionaryId: matchedDictMeta.id,
            dictionaryName: dictName,
            targetText: translationResult,
            phonetic: wordEntry.phonetic,
            definitions: definitions,
            examples: examples,
            dictionaryExplanation: dictionaryExplanation,
          ),);
          debugPrint('[Translation]   Added result from ${matchedDictMeta.id}, total results: ${dictResults.length}');
        } else {
          debugPrint('[Translation]   NOT FOUND or empty definitions (wordEntry=${wordEntry != null ? "has ${wordEntry.definitions.length} defs" : "null"})');
        }
      } catch (e, stackTrace) {
        debugPrint('[Translation]   ERROR looking up in ${matchedDictMeta.id}: $e');
        debugPrint('[Translation]   StackTrace: $stackTrace');
      }
    }
    
    state = state.copyWith(isLoadingDictionary: false);

    debugPrint('[Translation] Dictionary lookup completed: ${dictResults.length} results from ${matchedDicts.length} dictionaries');
    for (var i = 0; i < dictResults.length; i++) {
      debugPrint('[Translation]   Result ${i + 1}: ${dictResults[i].dictionaryId} - "${dictResults[i].targetText}"');
    }

    if (dictResults.isNotEmpty) {
      final primary = dictResults.first;
      debugPrint('[Translation] Setting hasDictionaryResult=true, targetText="${primary.targetText}"');
      state = state.copyWith(
        targetText: primary.targetText,
        hasDictionaryResult: true,
        phonetic: primary.phonetic,
        definitions: primary.definitions,
        examples: primary.examples,
        dictionaryResults: dictResults,
        isTranslating: false,
        result: TranslationResult(
          sourceText: state.sourceText,
          targetText: primary.targetText,
          sourceLang: state.sourceLang,
          targetLang: state.targetLang,
          translatedAt: DateTime.now(),
          source: TranslationSource.dictionary,
          dictionaryExplanation: primary.dictionaryExplanation,
          phonetic: primary.phonetic,
          definitions: primary.definitions,
          examples: primary.examples,
          isWordOrPhrase: true,
        ),
      );
      await _saveToHistory();
    } else {
      debugPrint('[Translation] No dictionary results found for any matched dictionary');
      await _tryOpusMtTranslation();
    }
  }

  Future<WordEntry?> _lookupWordInDictionary(DictionaryMeta meta) async {
    try {
      debugPrint('[Translation] _lookupWordInDictionary: id=${meta.id}, isMDict=${meta.isMDict}, isStarDict=${meta.isStarDict}');

      if (meta.isMDict) {
        final mdictSource = _ref.read(mdictDataSourceProvider);
        final mdxPath = meta.localDirName;
        debugPrint('[Translation]   MDict path: $mdxPath, exists=${File(mdxPath).existsSync()}');
        await mdictSource.setPath(mdxPath);
        final result = await mdictSource.getWord(state.sourceText);
        debugPrint('[Translation]   MDict result: ${result != null ? "found" : "null"}');
        return result;
      }

      if (meta.isStarDict) {
        final starDictSource = _ref.read(starDictDataSourceProvider);
        String? dictPath = getDownloadedPath(meta.id);
        debugPrint('[Translation]   StarDict downloadedPath: $dictPath');
        if (dictPath != null) {
          debugPrint('[Translation]   StarDict downloadedPath exists: ${_pathExists(dictPath)}');
        }
        if (dictPath == null || !_pathExists(dictPath)) {
          final dir = await getApplicationDocumentsDirectory();
          final defaultPath = path.join(dir.path, meta.localDirName);
          debugPrint('[Translation]   StarDict defaultPath: $defaultPath, dirExists=${Directory(defaultPath).existsSync()}, fileExists=${File(defaultPath).existsSync()}');
          if (Directory(defaultPath).existsSync()) {
            final ifoFile = _findIfoInDir(defaultPath);
            debugPrint('[Translation]   StarDict ifoFile: $ifoFile');
            if (ifoFile != null) dictPath = ifoFile;
          } else if (File(defaultPath).existsSync()) {
            dictPath = defaultPath;
          }
        }
        if (dictPath != null) {
          debugPrint('[Translation]   StarDict using path: $dictPath');
          await starDictSource.setPath(dictPath);
          final result = await starDictSource.getWord(state.sourceText);
          debugPrint('[Translation]   StarDict result: ${result != null ? "found" : "null"}');
          return result;
        }
        debugPrint('[Translation]   StarDict: no valid path found');
        return null;
      }

      debugPrint('[Translation]   SQLite dictionary (not StarDict, not MDict)');
      String? dictPath = getDownloadedPath(meta.id);
      debugPrint('[Translation]   SQLite downloadedPath: $dictPath');
      if (dictPath != null) {
        debugPrint('[Translation]   SQLite downloadedPath exists: ${_pathExists(dictPath)}');
      }
      if (dictPath == null || !_pathExists(dictPath)) {
        final dir = await getApplicationDocumentsDirectory();
        final defaultPath = path.join(dir.path, meta.localDirName);
        debugPrint('[Translation]   SQLite defaultPath: $defaultPath, fileExists=${File(defaultPath).existsSync()}');
        if (File(defaultPath).existsSync()) {
          dictPath = defaultPath;
        }
      }
      if (dictPath != null) {
        debugPrint('[Translation]   SQLite using path: $dictPath');
        final sqliteSource = _ref.read(dictionaryLocalDataSourceProvider);
        await sqliteSource.setPath(dictPath);
        final result = await sqliteSource.getWord(state.sourceText);
        debugPrint('[Translation]   SQLite result: ${result != null ? "found ${result.definitions.length} defs" : "null"}');
        return result;
      }
      debugPrint('[Translation]   SQLite: no valid path found');
    } catch (e, stackTrace) {
      debugPrint('[Translation]   EXCEPTION in _lookupWordInDictionary: $e');
      debugPrint('[Translation]   StackTrace: $stackTrace');
    }
    return null;
  }

  bool _pathExists(String p) {
    return File(p).existsSync() || Directory(p).existsSync();
  }

  Future<void> _translateSentence() async {
    await _tryOpusMtTranslation();
  }

  String? _findIfoInDir(String directory) {
    final dir = Directory(directory);
    if (!dir.existsSync()) return null;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.ifo')) {
        return entity.path;
      }
    }
    return null;
  }

  Future<void> _tryOpusMtTranslation() async {
    final modelManager = _ref.read(modelManagerProvider.notifier);
    final matchedModels = modelManager.getEnabledModelsForLangPair(
      state.sourceLang.code,
      state.targetLang.code,
    );

    if (matchedModels.isEmpty) {
      debugPrint('[Translation] No enabled model found for ${state.sourceLang.code}→${state.targetLang.code}');
      if (state.hasDictionaryResult || state.hasLLMResult) {
        await _saveToHistory();
      }
      state = state.copyWith(
        isTranslating: false,
        error: state.hasDictionaryResult ? null : 'No translation model available. Please download and enable the ${state.sourceLang.code}→${state.targetLang.code} model pair from the model management page.',
      );
      return;
    }

    final allModelResults = <ModelTranslationResult>[];
    String? primaryResult;

    state = state.copyWith(
      isTranslatingWithLLM: true,
      translatingModelTotal: matchedModels.length,
    );

    if (!await CTranslate2DataSource.isAvailable()) {
      debugPrint('[Translation] CTranslate2 library not available');
      state = state.copyWith(
        isTranslating: false,
        isTranslatingWithLLM: false,
        error: 'CTranslate2 runtime library not found. Please ensure it is installed correctly.',
      );
      return;
    }

    for (int i = 0; i < matchedModels.length; i++) {
      final matchedModel = matchedModels[i];
      debugPrint('[Translation] Translating with model ${i + 1}/${matchedModels.length}: ${matchedModel.displayName}');

      state = state.copyWith(
        translatingModelName: matchedModel.displayName,
        translatingModelIndex: i + 1,
      );

      final modelPath = await modelManager.getValidModelPath(matchedModel);
      if (modelPath == null) {
        debugPrint('[Translation] Model path not found for ${matchedModel.folderName}, skipping');
        continue;
      }

      debugPrint('[Translation] Starting isolate translation: modelPath=$modelPath');
      final stopwatch = Stopwatch()..start();

      String? llmResult;
      try {
        llmResult = await CTranslate2DataSource.translateInIsolate(
          modelPath: modelPath,
          text: state.sourceText,
        );
      } catch (e, stackTrace) {
        debugPrint('[Translation] Isolate translation error: $e');
        debugPrint('[Translation] StackTrace: $stackTrace');
        continue;
      }

      stopwatch.stop();
      debugPrint('[Translation] Model ${matchedModel.displayName} completed in ${stopwatch.elapsedMilliseconds}ms, result: "$llmResult"');

      if (llmResult == null || llmResult.isEmpty) {
        debugPrint('[Translation] Model ${matchedModel.displayName} returned empty result, skipping');
        continue;
      }

      final modelResult = ModelTranslationResult(
        modelId: matchedModel.folderName,
        modelName: matchedModel.displayName,
        targetText: llmResult,
      );

      allModelResults.add(modelResult);
      primaryResult ??= llmResult;

      final isLastModel = i == matchedModels.length - 1;
      final hasMoreModels = !isLastModel;

      if (state.hasDictionaryResult) {
        state = state.copyWith(
          hasLLMResult: true,
          llmTranslation: primaryResult,
          modelResults: allModelResults,
          isTranslatingWithLLM: hasMoreModels,
          isTranslating: hasMoreModels || state.isLoadingDictionary,
        );
      } else {
        state = state.copyWith(
          hasLLMResult: true,
          targetText: primaryResult!,
          llmTranslation: primaryResult,
          modelResults: allModelResults,
          result: TranslationResult(
            sourceText: state.sourceText,
            targetText: primaryResult!,
            sourceLang: state.sourceLang,
            targetLang: state.targetLang,
            translatedAt: DateTime.now(),
            source: TranslationSource.opusMt,
            isWordOrPhrase: state.isWordOrPhrase,
          ),
          isTranslatingWithLLM: hasMoreModels,
          isTranslating: hasMoreModels,
        );
      }

      debugPrint('[Translation] State updated with model ${i + 1} result, hasMoreModels=$hasMoreModels');
    }

    if (allModelResults.isEmpty) {
      if (state.hasDictionaryResult) {
        await _saveToHistory();
      }
      state = state.copyWith(
        isTranslating: false,
        isTranslatingWithLLM: false,
        error: state.hasDictionaryResult ? null : 'All models failed to translate.',
      );
      return;
    }

    state = state.copyWith(
      isTranslating: false,
      isTranslatingWithLLM: false,
      translatingModelName: null,
    );

    _saveToHistory();
  }

  Future<void> _saveToHistory() async {
    try {
      final effectiveTarget = state.hasLLMResult && state.llmTranslation != null
          ? state.llmTranslation!
          : state.targetText;

      final historyRepo = _ref.read(historyRepositoryProvider);
      await historyRepo.addEntry(TranslationHistory.create(
        sourceText: state.sourceText,
        targetText: effectiveTarget,
        sourceLang: state.sourceLang,
        targetLang: state.targetLang,
        translatedAt: DateTime.now(),
      ),);
      _ref.invalidate(translationHistoryListProvider);

      debugPrint('[Translation] Saving recent lang pair: ${state.sourceLang.code}_${state.targetLang.code}');
      final dictManager = _ref.read(dictionaryManagerProvider.notifier);
      await dictManager.saveRecentLangPair(state.sourceLang, state.targetLang);
      debugPrint('[Translation] Recent lang pair saved successfully');
    } catch (e, stackTrace) {
      debugPrint('[Translation] ERROR in _saveToHistory: $e');
      debugPrint('[Translation] StackTrace: $stackTrace');
    }
  }

  void clear() {
    state = TranslationState(
      sourceLang: state.sourceLang,
      targetLang: state.targetLang,
    );
  }
}

final translationProvider = StateNotifierProvider<TranslationNotifier, TranslationState>((ref) {
  return TranslationNotifier(ref);
});
