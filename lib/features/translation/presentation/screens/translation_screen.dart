import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rftranslator/core/localization/app_localizations.dart';
import 'package:rftranslator/core/utils/app_toast.dart';
import 'package:rftranslator/features/dictionary/domain/dictionary_manager.dart';
import 'package:rftranslator/features/translation/data/models/translation_history.dart';
import 'package:rftranslator/features/translation/domain/entities/language.dart';
import 'package:rftranslator/features/translation/domain/translation_history_provider.dart';
import 'package:rftranslator/features/translation/presentation/providers/translation_provider.dart';

class TranslationScreen extends ConsumerStatefulWidget {
  const TranslationScreen({super.key});

  @override
  ConsumerState<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends ConsumerState<TranslationScreen> {
  final TextEditingController _sourceTextController = TextEditingController();
  bool _isUpdatingFromState = false;

  @override
  void initState() {
    super.initState();
    _sourceTextController.addListener(() {
      if (!_isUpdatingFromState) {
        ref.read(translationProvider.notifier).updateSourceText(_sourceTextController.text);
      }
    });
    final state = ref.read(translationProvider);
    _isUpdatingFromState = true;
    _sourceTextController.text = state.sourceText;
    _isUpdatingFromState = false;
  }

  @override
  void dispose() {
    _sourceTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(translationProvider);
    final notifier = ref.read(translationProvider.notifier);

    ref.listen(translationProvider, (prev, next) {
      if (prev?.sourceText != next.sourceText && _sourceTextController.text != next.sourceText) {
        _isUpdatingFromState = true;
        _sourceTextController.text = next.sourceText;
        _isUpdatingFromState = false;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLanguageSelector(l10n, state, notifier),
              const SizedBox(height: 16),
              _buildSourceTextField(l10n, state, notifier),
              const SizedBox(height: 16),
              _buildTranslateButton(l10n, state, notifier),
              const SizedBox(height: 16),
              _buildResultArea(l10n, state, notifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(
    AppLocalizations l10n,
    TranslationState state,
    TranslationNotifier notifier,
  ) {
    final dictState = ref.watch(dictionaryManagerProvider);
    final availableSourceLangs = _getAvailableSourceLanguages(dictState);
    final availableTargetLangs = _getAvailableTargetLanguages(dictState, state.sourceLang);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: _buildLanguageDropdown(
                value: availableSourceLangs.contains(state.sourceLang)
                    ? state.sourceLang
                    : availableSourceLangs.first,
                availableLanguages: availableSourceLangs,
                onChanged: (lang) {
                  if (lang != null) {
                    notifier.updateSourceLang(lang);
                    if (lang == state.targetLang) {
                      final newTarget = availableTargetLangs
                          .where((l) => l != lang)
                          .firstOrNull;
                      if (newTarget != null) {
                        notifier.updateTargetLang(newTarget);
                      }
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () => notifier.swapLanguages(),
              icon: const Icon(Icons.swap_horiz),
              tooltip: l10n.swapLanguages,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLanguageDropdown(
                value: availableTargetLangs.contains(state.targetLang) &&
                        state.targetLang != state.sourceLang
                    ? state.targetLang
                    : availableTargetLangs
                        .where((l) => l != state.sourceLang)
                        .firstOrNull ??
                    availableTargetLangs.first,
                availableLanguages: availableTargetLangs,
                onChanged: (lang) {
                  if (lang != null) notifier.updateTargetLang(lang);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Language> _getAvailableSourceLanguages(DictionaryState dictState) {
    final langs = <Language>{};
    for (final id in dictState.selectedDictionaryIds) {
      final meta = findDictionaryById(id);
      if (meta != null && meta.sourceLanguage != null) {
        langs.add(meta.sourceLanguage!);
      }
    }
    if (langs.isEmpty) {
      return Language.values;
    }
    return langs.toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  List<Language> _getAvailableTargetLanguages(DictionaryState dictState, Language sourceLang) {
    final langs = <Language>{};
    for (final id in dictState.selectedDictionaryIds) {
      final meta = findDictionaryById(id);
      if (meta != null && meta.sourceLanguage == sourceLang && meta.targetLanguage != null) {
        langs.add(meta.targetLanguage!);
      }
    }
    if (langs.isEmpty) {
      return Language.values.where((l) => l != sourceLang).toList();
    }
    return langs.toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  Widget _buildLanguageDropdown({
    required Language value,
    required List<Language> availableLanguages,
    required ValueChanged<Language?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Language>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: availableLanguages.map((lang) {
            return DropdownMenuItem<Language>(
              value: lang,
              child: Text(lang.displayName),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSourceTextField(
    AppLocalizations l10n,
    TranslationState state,
    TranslationNotifier notifier,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.sourceText,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.targetText.isNotEmpty && !state.isTranslating)
                      _FavoriteButton(
                        sourceText: state.sourceText,
                        targetText: state.targetText,
                        sourceLang: state.sourceLang,
                        targetLang: state.targetLang,
                      ),
                    if (state.sourceText.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _sourceTextController.clear();
                          notifier.clear();
                        },
                        icon: const Icon(Icons.close),
                        tooltip: l10n.clearText,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sourceTextController,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: l10n.inputToTranslate,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onSubmitted: (_) => notifier.translate(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslateButton(
    AppLocalizations l10n,
    TranslationState state,
    TranslationNotifier notifier,
  ) {
    return FilledButton.icon(
      onPressed: state.isTranslating || state.sourceText.trim().isEmpty
          ? null
          : () => notifier.translate(),
      icon: state.isTranslating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.translate),
      label: Text(state.isTranslating ? l10n.translating : l10n.translate),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildResultArea(
    AppLocalizations l10n,
    TranslationState state,
    TranslationNotifier notifier,
  ) {
    if (state.error != null) {
      return Card(
        elevation: 2,
        color: Theme.of(context).colorScheme.errorContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                state.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => notifier.translate(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (state.targetText.isEmpty && !state.isTranslating) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Icon(Icons.translate_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                l10n.translationResultWillAppear,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final children = <Widget>[];

    if (state.hasDictionaryResult) {
      if (state.dictionaryResults.length > 1) {
        for (final dictResult in state.dictionaryResults) {
          children.add(_buildSingleDictionaryCard(l10n, state, dictResult));
          children.add(const SizedBox(height: 12));
        }
      } else {
        children.add(_buildDictionaryResult(l10n, state));
      }
    } else if (state.targetText.isNotEmpty && !state.hasLLMResult) {
      children.add(_buildSimpleResult(l10n, state));
    }

    if (state.isTranslatingWithLLM) {
      children.add(const SizedBox(height: 12));
      children.add(_buildLLMLoadingCard(l10n, state));
    } else if (state.hasLLMResult && state.modelResults.isNotEmpty) {
      for (int i = 0; i < state.modelResults.length; i++) {
        children.add(const SizedBox(height: 12));
        children.add(_buildModelResultCard(l10n, state.modelResults[i]));
      }
    } else if (state.hasLLMResult && state.llmTranslation != null) {
      children.add(const SizedBox(height: 12));
      children.add(_buildLLMResultCard(l10n, state));
    }

    return Column(children: children);
  }

  Widget _buildResultActions(AppLocalizations l10n, TranslationState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: state.targetText));
            AppToast.show(context, l10n.copiedToClipboard);
          },
          icon: const Icon(Icons.copy),
          tooltip: l10n.copy,
        ),
      ],
    );
  }

  Widget _buildSourceBadge(AppLocalizations l10n, TranslationState state) {
    final sourceLabel = state.hasDictionaryResult
        ? l10n.sourceDictionary
        : state.hasLLMResult
            ? l10n.sourceOpusMt
            : '';
    if (sourceLabel.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        sourceLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
      ),
    );
  }

  Widget _buildSingleDictionaryCard(AppLocalizations l10n, TranslationState state, DictionaryTranslationResult dictResult) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dictResult.dictionaryName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    if (dictResult.phonetic != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '/${dictResult.phonetic}/',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'Courier',
                            color: const Color(0xFFE8002D),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                _buildSingleDictActions(l10n, state, dictResult),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                dictResult.targetText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (dictResult.definitions.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...dictResult.definitions.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key + 1}. ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          entry.value,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSingleDictActions(AppLocalizations l10n, TranslationState state, DictionaryTranslationResult dictResult) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: dictResult.targetText));
            AppToast.show(context, l10n.copiedToClipboard);
          },
          icon: const Icon(Icons.copy, size: 18),
          tooltip: l10n.copy,
        ),
      ],
    );
  }

  Widget _buildDictionaryResult(AppLocalizations l10n, TranslationState state) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.detailedDefinition,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    _buildSourceBadge(l10n, state),
                  ],
                ),
                _buildResultActions(l10n, state),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                state.targetText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (state.phonetic != null) ...[
              Row(
                children: [
                  Icon(Icons.record_voice_over, size: 20, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.phonetic,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  state.phonetic!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Courier',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (state.definitions != null && state.definitions!.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.description, size: 20, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.definition,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...state.definitions!.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key + 1}. ',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          entry.value,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            if (state.examples != null && state.examples!.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.format_quote, size: 20, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.example,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...state.examples!.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}. ',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            entry.value,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleResult(AppLocalizations l10n, TranslationState state) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.translationResult,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    _buildSourceBadge(l10n, state),
                  ],
                ),
                _buildResultActions(l10n, state),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                state.targetText,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLLMLoadingCard(AppLocalizations l10n, TranslationState state) {
    final modelName = state.translatingModelName ?? l10n.sourceOpusMt;
    final progress = state.translatingModelTotal > 1
        ? ' (${state.translatingModelIndex}/${state.translatingModelTotal})'
        : '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$modelName ${l10n.translating}...$progress',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (state.translatingModelTotal > 1) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: state.translatingModelIndex / state.translatingModelTotal,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModelResultCard(AppLocalizations l10n, ModelTranslationResult modelResult) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.translationResult,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        modelResult.modelName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: modelResult.targetText));
                        AppToast.show(context, l10n.copiedToClipboard);
                      },
                      icon: const Icon(Icons.copy),
                      tooltip: l10n.copy,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                modelResult.targetText,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLLMResultCard(AppLocalizations l10n, TranslationState state) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.smart_toy_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l10n.sourceOpusMt,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: state.llmTranslation!));
                        AppToast.show(context, l10n.copiedToClipboard);
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: l10n.copy,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                state.llmTranslation!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteButton extends ConsumerStatefulWidget {
  final String sourceText;
  final String targetText;
  final Language sourceLang;
  final Language targetLang;

  const _FavoriteButton({
    required this.sourceText,
    required this.targetText,
    required this.sourceLang,
    required this.targetLang,
  });

  @override
  ConsumerState<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<_FavoriteButton> {
  bool _isFavorite = false;
  bool _checked = false;

  @override
  void didUpdateWidget(covariant _FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceText != widget.sourceText ||
        oldWidget.targetText != widget.targetText) {
      _checked = false;
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final favRepo = ref.read(favoritesRepositoryProvider);
    final isFav = await favRepo.isFavorite(widget.sourceText, widget.sourceLang, widget.targetLang);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _checked = true;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final l10n = AppLocalizations.of(context);
    final favRepo = ref.read(favoritesRepositoryProvider);

    if (_isFavorite) {
      await favRepo.removeFavorite(widget.sourceText, widget.sourceLang, widget.targetLang);
    } else {
      final entry = TranslationHistory.create(
        sourceText: widget.sourceText,
        targetText: widget.targetText,
        sourceLang: widget.sourceLang,
        targetLang: widget.targetLang,
        translatedAt: DateTime.now(),
      );
      await favRepo.addFavorite(entry);
    }

    ref.invalidate(translationFavoriteListProvider);

    if (mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
      });
      AppToast.show(
        context,
        _isFavorite ? l10n.addToFavorites : l10n.removeFromFavorites,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      _checkFavoriteStatus();
    }
    final l10n = AppLocalizations.of(context);
    return IconButton(
      onPressed: _toggleFavorite,
      icon: Icon(
        _isFavorite ? Icons.star : Icons.star_border,
        color: _isFavorite ? Colors.amber : null,
      ),
      tooltip: _isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
    );
  }
}
