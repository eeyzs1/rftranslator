import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rftranslator/core/di/providers.dart';
import 'package:rftranslator/features/dictionary/data/datasources/stardict_datasource.dart';
import 'package:rftranslator/features/dictionary/domain/dictionary_manager.dart';
import 'package:rftranslator/features/dictionary/domain/dictionary_repository.dart';
import 'package:rftranslator/features/dictionary/domain/entities/word_entry.dart';
import 'package:rftranslator/features/llm/data/datasources/python_llm_datasource.dart';
import 'package:rftranslator/features/llm/domain/llm_service.dart';
import 'package:rftranslator/features/llm/domain/model_manager.dart';
import 'package:rftranslator/features/translation/domain/entities/language.dart';
import 'package:rftranslator/features/translation/domain/entities/translation_result.dart';
import 'package:rftranslator/features/translation/domain/entities/translation_source.dart';
import 'package:rftranslator/features/translation/domain/translation_history_provider.dart';

const _unset = Object();

class TranslationState {
  final String sourceText;
  final String targetText;
  final Language sourceLang;
  final Language targetLang;
  final bool isTranslating;
  final bool isTranslatingWithLLM;
  final String? error;
  final bool hasDictionaryResult;
  final bool hasLLMResult;
  final TranslationResult? result;
  final String? phonetic;
  final List<String>? definitions;
  final List<String>? examples;
  final bool isWordOrPhrase;
  final String? llmTranslation;

  TranslationState({
    this.sourceText = '',
    this.targetText = '',
    this.sourceLang = Language.english,
    this.targetLang = Language.chinese,
    this.isTranslating = false,
    this.isTranslatingWithLLM = false,
    this.error,
    this.hasDictionaryResult = false,
    this.hasLLMResult = false,
    this.result,
    this.phonetic,
    this.definitions,
    this.examples,
    this.isWordOrPhrase = false,
    this.llmTranslation,
  });

  TranslationState copyWith({
    String? sourceText,
    String? targetText,
    Language? sourceLang,
    Language? targetLang,
    bool? isTranslating,
    bool? isTranslatingWithLLM,
    Object? error = _unset,
    bool? hasDictionaryResult,
    bool? hasLLMResult,
    TranslationResult? result,
    String? phonetic,
    List<String>? definitions,
    List<String>? examples,
    bool? isWordOrPhrase,
    Object? llmTranslation = _unset,
  }) {
    return TranslationState(
      sourceText: sourceText ?? this.sourceText,
      targetText: targetText ?? this.targetText,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      isTranslating: isTranslating ?? this.isTranslating,
      isTranslatingWithLLM: isTranslatingWithLLM ?? this.isTranslatingWithLLM,
      error: identical(error, _unset) ? this.error : error as String?,
      hasDictionaryResult: hasDictionaryResult ?? this.hasDictionaryResult,
      hasLLMResult: hasLLMResult ?? this.hasLLMResult,
      result: result ?? this.result,
      phonetic: phonetic ?? this.phonetic,
      definitions: definitions ?? this.definitions,
      examples: examples ?? this.examples,
      isWordOrPhrase: isWordOrPhrase ?? this.isWordOrPhrase,
      llmTranslation: identical(llmTranslation, _unset) ? this.llmTranslation : llmTranslation as String?,
    );
  }
}

DictionaryType? _findDictionaryTypeForLangPair(
  Set<DictionaryType> selected,
  Language source,
  Language target,
) {
  for (final dict in selected) {
    final pair = dict.languagePair;
    if (pair == null) continue;
    final pairSource = _languagePairToSource(pair);
    final pairTarget = _languagePairToTarget(pair);
    if (pairSource == source && pairTarget == target) {
      return dict;
    }
  }
  return null;
}

Language _languagePairToSource(LanguagePair pair) {
  return switch (pair) {
    LanguagePair.englishChinese => Language.english,
    LanguagePair.englishFrench => Language.english,
    LanguagePair.englishGerman => Language.english,
    LanguagePair.englishSpanish => Language.english,
    LanguagePair.englishItalian => Language.english,
    LanguagePair.englishPortuguese => Language.english,
    LanguagePair.englishRussian => Language.english,
    LanguagePair.englishArabic => Language.english,
    LanguagePair.englishJapanese => Language.english,
    LanguagePair.englishKorean => Language.english,
    LanguagePair.chineseEnglish => Language.chinese,
    LanguagePair.frenchEnglish => Language.french,
    LanguagePair.germanEnglish => Language.german,
    LanguagePair.spanishEnglish => Language.spanish,
    LanguagePair.italianEnglish => Language.italian,
    LanguagePair.portugueseEnglish => Language.portuguese,
    LanguagePair.russianEnglish => Language.russian,
  };
}

Language _languagePairToTarget(LanguagePair pair) {
  return switch (pair) {
    LanguagePair.englishChinese => Language.chinese,
    LanguagePair.englishFrench => Language.french,
    LanguagePair.englishGerman => Language.german,
    LanguagePair.englishSpanish => Language.spanish,
    LanguagePair.englishItalian => Language.italian,
    LanguagePair.englishPortuguese => Language.portuguese,
    LanguagePair.englishRussian => Language.russian,
    LanguagePair.englishArabic => Language.arabic,
    LanguagePair.englishJapanese => Language.japanese,
    LanguagePair.englishKorean => Language.korean,
    LanguagePair.chineseEnglish => Language.english,
    LanguagePair.frenchEnglish => Language.english,
    LanguagePair.germanEnglish => Language.english,
    LanguagePair.spanishEnglish => Language.english,
    LanguagePair.italianEnglish => Language.english,
    LanguagePair.portugueseEnglish => Language.english,
    LanguagePair.russianEnglish => Language.english,
  };
}

ModelType? _findModelTypeForLangPair(Language source, Language target) {
  for (final model in ModelType.values) {
    final (src, tgt) = model.languagePair;
    if (src == source.code && tgt == target.code) {
      return model;
    }
  }
  return null;
}

class TranslationNotifier extends StateNotifier<TranslationState> {
  final DictionaryRepository _dictionaryRepository;
  final Ref _ref;

  TranslationNotifier(this._dictionaryRepository, this._ref) : super(TranslationState());

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
    );

    try {
      final llmService = _ref.read(llmServiceProvider.notifier);
      final isWordOrPhrase = llmService.isWordOrPhrase(state.sourceText);
      state = state.copyWith(isWordOrPhrase: isWordOrPhrase);

      if (isWordOrPhrase) {
        await _translateWordOrPhrase();
      } else {
        await _translateSentence();
      }
    } catch (e) {
      state = state.copyWith(
        isTranslating: false,
        isTranslatingWithLLM: false,
        error: '\u7FFB\u8BD1\u5931\u8D25\uFF1A${e.toString()}',
      );
    }
  }

  Future<void> _translateWordOrPhrase() async {
    final dictManager = _ref.read(dictionaryManagerProvider.notifier);
    final dictState = _ref.read(dictionaryManagerProvider);
    final dictPath = await dictManager.getValidDictionaryPath();

    final matchedDictType = _findDictionaryTypeForLangPair(
      dictState.selectedDictionaries,
      state.sourceLang,
      state.targetLang,
    );

    if (matchedDictType != null && dictPath != null) {
      WordEntry? wordEntry;
      await _dictionaryRepository.setPath(dictPath);
      try {
        wordEntry = await _dictionaryRepository.getWord(state.sourceText);
      } catch (_) {}

      if (wordEntry != null && wordEntry.definitions.isNotEmpty) {
        final translationResult = wordEntry.definitions.first.chinese;
        final phonetic = wordEntry.phonetic;
        final definitions = wordEntry.definitions.map((d) => d.chinese).toList();
        final examples = wordEntry.examples.map((e) => e.english).toList();
        final dictionaryExplanation = wordEntry.definitions.map((d) => '${d.partOfSpeech} ${d.chinese}').join('\n');

        state = state.copyWith(
          targetText: translationResult,
          hasDictionaryResult: true,
          phonetic: phonetic,
          definitions: definitions,
          examples: examples,
          result: TranslationResult(
            sourceText: state.sourceText,
            targetText: translationResult,
            sourceLang: state.sourceLang,
            targetLang: state.targetLang,
            translatedAt: DateTime.now(),
            source: TranslationSource.dictionary,
            dictionaryExplanation: dictionaryExplanation,
            phonetic: phonetic,
            definitions: definitions,
            examples: examples,
            isWordOrPhrase: true,
          ),
        );
      }
    }

    await _tryOpusMtTranslation();
  }

  Future<void> _translateSentence() async {
    await _tryOpusMtTranslation();
  }

  Future<void> _tryOpusMtTranslation() async {
    final llmService = _ref.read(llmServiceProvider.notifier);
    final llmDataSource = llmService.dataSource;

    if (llmDataSource is! PythonLlmDataSource) {
      state = state.copyWith(isTranslating: false);
      return;
    }

    final modelType = _findModelTypeForLangPair(state.sourceLang, state.targetLang);
    if (modelType == null) {
      if (!state.hasDictionaryResult) {
        state = state.copyWith(
          isTranslating: false,
          targetText: '\u65E0\u53EF\u7528\u7684\u7FFB\u8BD1\u6A21\u578B',
        );
      } else {
        state = state.copyWith(isTranslating: false);
      }
      return;
    }

    final modelManager = _ref.read(modelManagerProvider.notifier);
    final isDownloaded = await modelManager.isModelDownloaded(modelType);
    if (!isDownloaded) {
      if (!state.hasDictionaryResult) {
        state = state.copyWith(
          isTranslating: false,
          targetText: '\u8BF7\u5148\u4E0B\u8F7D ${modelType.displayName} \u6A21\u578B',
        );
      } else {
        state = state.copyWith(isTranslating: false);
      }
      return;
    }

    state = state.copyWith(isTranslatingWithLLM: true);

    try {
      final llmResult = await llmDataSource.translateWithOpusMt(
        state.sourceText,
        sourceLang: state.sourceLang.code,
        targetLang: state.targetLang.code,
      );

      if (state.hasDictionaryResult) {
        state = state.copyWith(
          isTranslating: false,
          isTranslatingWithLLM: false,
          hasLLMResult: true,
          llmTranslation: llmResult,
        );
      } else {
        state = state.copyWith(
          isTranslating: false,
          isTranslatingWithLLM: false,
          hasLLMResult: true,
          targetText: llmResult ?? '',
          result: TranslationResult(
            sourceText: state.sourceText,
            targetText: llmResult ?? '',
            sourceLang: state.sourceLang,
            targetLang: state.targetLang,
            translatedAt: DateTime.now(),
            source: TranslationSource.opusMt,
            isWordOrPhrase: state.isWordOrPhrase,
          ),
        );
      }

      _saveToHistory();
    } catch (e) {
      if (!state.hasDictionaryResult) {
        state = state.copyWith(
          isTranslating: false,
          isTranslatingWithLLM: false,
          error: 'OPUS-MT \u7FFB\u8BD1\u5931\u8D25\uFF1A${e.toString()}',
        );
      } else {
        state = state.copyWith(
          isTranslating: false,
          isTranslatingWithLLM: false,
        );
      }
    }
  }

  Future<void> _saveToHistory() async {
    try {
      final effectiveTarget = state.hasLLMResult && state.llmTranslation != null
          ? state.llmTranslation!
          : state.targetText;
      final effectiveSource = state.hasLLMResult
          ? TranslationSource.opusMt
          : state.hasDictionaryResult
              ? TranslationSource.dictionary
              : TranslationSource.opusMt;

      final historyRepo = _ref.read(translationHistoryRepositoryProvider);
      await historyRepo.addHistory(TranslationResult(
        sourceText: state.sourceText,
        targetText: effectiveTarget,
        sourceLang: state.sourceLang,
        targetLang: state.targetLang,
        translatedAt: DateTime.now(),
        source: effectiveSource,
        isWordOrPhrase: state.isWordOrPhrase,
      ));
      _ref.invalidate(translationHistoryListProvider);
    } catch (_) {
      debugPrint('Failed to save translation history');
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
  final dictState = ref.watch(dictionaryManagerProvider);
  final llmDataSource = ref.watch(llmDataSourceProvider);

  DictionaryRepository repository;
  if (dictState.type.isStarDictFormat) {
    repository = StarDictDataSource(
      pythonDataSource: llmDataSource is PythonLlmDataSource ? llmDataSource : null,
    );
  } else {
    repository = ref.watch(dictionaryLocalDataSourceProvider);
  }

  return TranslationNotifier(repository, ref);
});
