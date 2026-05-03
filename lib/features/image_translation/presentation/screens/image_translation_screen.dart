import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rftranslator/core/localization/app_localizations.dart';
import 'package:rftranslator/core/utils/app_toast.dart';
import 'package:rftranslator/features/image_translation/data/datasources/ocr_text_corrector.dart';
import 'package:rftranslator/features/image_translation/data/datasources/sentence_splitter.dart';
import 'package:rftranslator/features/image_translation/data/datasources/term_glossary.dart';
import 'package:rftranslator/features/image_translation/domain/language_detector.dart';
import 'package:rftranslator/features/image_translation/presentation/providers/image_translation_provider.dart';
import 'package:rftranslator/features/llm/data/datasources/ctranslate2_datasource.dart';
import 'package:rftranslator/features/llm/domain/model_manager.dart';
import 'package:rftranslator/features/translation/domain/entities/language.dart';

class ImageTranslationScreen extends ConsumerStatefulWidget {
  const ImageTranslationScreen({super.key});

  @override
  ConsumerState<ImageTranslationScreen> createState() =>
      _ImageTranslationScreenState();
}

class _ImageTranslationScreenState
    extends ConsumerState<ImageTranslationScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final notifier = ref.read(imageTranslationProvider.notifier);
    notifier.clearImage();

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2560,
        maxHeight: 2560,
        imageQuality: 95,
      );
      if (picked != null) {
        notifier.setImage(File(picked.path));
        Future.microtask(() => _performOcrAndTranslate());
      }
    } catch (e) {
      debugPrint('[ImageTranslation] Pick image error: $e');
    }
  }

  Future<void> _performOcrAndTranslate() async {
    debugPrint('[ImageTranslation] _performOcrAndTranslate: starting...');
    final imageNotifier = ref.read(imageTranslationProvider.notifier);

    final modelManager = ref.read(modelManagerProvider.notifier);
    final currentSource = ref.read(imageTranslationProvider).sourceLang;
    final currentTarget = ref.read(imageTranslationProvider).targetLang;

    final preCheckModels = modelManager.getEnabledModelsForLangPair(
      currentSource.code,
      currentTarget.code,
    );
    if (preCheckModels.isEmpty) {
      imageNotifier.setError(
        'No translation model available for ${currentSource.displayName}→${currentTarget.displayName}. Please download a model first.',
      );
      return;
    }

    await imageNotifier.performOcr();
    debugPrint('[ImageTranslation] _performOcrAndTranslate: OCR done');

    final updatedState = ref.read(imageTranslationProvider);
    debugPrint('[ImageTranslation] _performOcrAndTranslate: status=${updatedState.status}, error=${updatedState.errorMessage}');
    if (updatedState.status == ImageTranslationStatus.error) {
      return;
    }

    var ocrText = updatedState.ocrResult?.fullText ?? '';
    debugPrint('[ImageTranslation] _performOcrAndTranslate: ocrText length=${ocrText.length}');
    if (ocrText.isEmpty) {
      imageNotifier.setError('No text recognized in the image.');
      return;
    }

    await OcrTextCorrector.initialize();
    ocrText = OcrTextCorrector.correct(ocrText);
    debugPrint('[ImageTranslation] After correction: "$ocrText"');

    imageNotifier.setTranslatedText('');

    final detectedLang = LanguageDetector.detect(ocrText);
    debugPrint('[ImageTranslation] Detected language: ${detectedLang.displayName}');

    final sourceLang = detectedLang;
    Language targetLang;
    if (currentTarget != sourceLang) {
      targetLang = currentTarget;
    } else {
      targetLang = sourceLang == Language.chinese
          ? Language.english
          : Language.chinese;
    }

    imageNotifier.updateSourceLang(sourceLang);
    imageNotifier.updateTargetLang(targetLang);

    final matchedModels = modelManager.getEnabledModelsForLangPair(
      sourceLang.code,
      targetLang.code,
    );
    if (matchedModels.isEmpty) {
      imageNotifier.setError(
        'No translation model available for ${sourceLang.displayName}→${targetLang.displayName}. Please download a model first.',
      );
      return;
    }

    final correctedOcrResult = updatedState.ocrResult!.copyWithFullText(ocrText);
    imageNotifier.setOcrResult(correctedOcrResult);

    await TermGlossary.initialize();

    final matchedTerms = sourceLang == Language.english
        ? TermGlossary.findTermsInSource(ocrText)
        : <TermMatch>[];
    if (matchedTerms.isNotEmpty) {
      debugPrint('[ImageTranslation] Matched ${matchedTerms.length} terms: ${matchedTerms.map((t) => '${t.sourceTerm}→${t.targetTerm}').join(", ")}');
    }

    await _translateBySentences(ocrText, sourceLang, targetLang, matchedTerms);
  }

  Future<void> _translateBySentences(
    String text,
    Language sourceLang,
    Language targetLang,
    List<TermMatch> matchedTerms,
  ) async {
    final imageNotifier = ref.read(imageTranslationProvider.notifier);

    final modelManager = ref.read(modelManagerProvider.notifier);
    final matchedModels = modelManager.getEnabledModelsForLangPair(
      sourceLang.code,
      targetLang.code,
    );

    if (matchedModels.isEmpty) {
      imageNotifier.setError('No translation model available for ${sourceLang.code}→${targetLang.code}');
      return;
    }

    if (!await CTranslate2DataSource.isAvailable()) {
      imageNotifier.setError('CTranslate2 runtime library not found.');
      return;
    }

    final sentences = SentenceSplitter.split(text);
    debugPrint('[ImageTranslation] Split into ${sentences.length} sentences');
    for (var i = 0; i < sentences.length; i++) {
      debugPrint('[ImageTranslation]   Sentence $i: "${sentences[i]}"');
    }

    imageNotifier.setTranslating();

    final translatedParts = <String>[];
    final modelPath = await modelManager.getValidModelPath(matchedModels.first);
    if (modelPath == null) {
      imageNotifier.setError('Model path not found for ${matchedModels.first.displayName}');
      return;
    }

    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      if (sentence.trim().isEmpty) continue;

      debugPrint('[ImageTranslation] Translating sentence ${i + 1}/${sentences.length}: "$sentence"');

      try {
        final result = await CTranslate2DataSource.translateInIsolate(
          modelPath: modelPath,
          text: sentence,
          beamSize: 4,
          maxLength: 256,
          repetitionPenalty: 1.2,
        );

        if (result != null && result.isNotEmpty) {
          translatedParts.add(result);
          debugPrint('[ImageTranslation]   Result: "$result"');
        } else {
          translatedParts.add(sentence);
          debugPrint('[ImageTranslation]   No result, keeping original');
        }
      } catch (e) {
        debugPrint('[ImageTranslation]   Translation error: $e');
        translatedParts.add(sentence);
      }
    }

    final fullTranslation = translatedParts.join('\n');

    final processedTranslation = targetLang == Language.chinese
        ? TermGlossary.postProcessTranslation(fullTranslation, matchedTerms)
        : fullTranslation;

    debugPrint('[ImageTranslation] Full translation: "$fullTranslation"');
    if (processedTranslation != fullTranslation) {
      debugPrint('[ImageTranslation] After term post-processing: "$processedTranslation"');
    }
    imageNotifier.setTranslatedText(processedTranslation);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(imageTranslationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.imageTranslation),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!state.isModelAvailable) ...[
                _buildModelDownloadCard(l10n, state),
                const SizedBox(height: 16),
              ],
              _buildImagePickerArea(l10n, state),
              const SizedBox(height: 16),
              if (state.selectedImage != null) ...[
                _buildLanguageSelector(l10n, state),
                const SizedBox(height: 16),
                _buildActionButton(l10n, state),
                const SizedBox(height: 16),
              ],
              if (state.status == ImageTranslationStatus.downloadingModel)
                _buildModelDownloadProgress(l10n, state),
              if (state.status == ImageTranslationStatus.ocrInProgress ||
                  state.status == ImageTranslationStatus.translating)
                _buildProgressIndicator(l10n, state),
              if (state.ocrResult != null) _buildOcrResult(l10n, state),
              if (state.translatedText != null &&
                  state.translatedText!.isNotEmpty)
                _buildTranslationResult(l10n, state),
              if (state.errorMessage != null) _buildError(state.errorMessage!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerArea(
    AppLocalizations l10n,
    ImageTranslationState state,
  ) {
    if (state.selectedImage != null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Image.file(
                state.selectedImage!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 280,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  onPressed: () {
                    ref.read(imageTranslationProvider.notifier).clearImage();
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showImageSourceSheet(l10n),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.tapToSelectImage,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageSourceSheet(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.fromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.fromCamera),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(
    AppLocalizations l10n,
    ImageTranslationState state,
  ) {
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
                value: state.sourceLang,
                onChanged: (lang) {
                  if (lang != null) {
                    ref
                        .read(imageTranslationProvider.notifier)
                        .updateSourceLang(lang);
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () {
                final currentSource = state.sourceLang;
                final currentTarget = state.targetLang;
                ref
                    .read(imageTranslationProvider.notifier)
                    .updateSourceLang(currentTarget);
                ref
                    .read(imageTranslationProvider.notifier)
                    .updateTargetLang(currentSource);
              },
              icon: const Icon(Icons.swap_horiz),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLanguageDropdown(
                value: state.targetLang,
                onChanged: (lang) {
                  if (lang != null) {
                    ref
                        .read(imageTranslationProvider.notifier)
                        .updateTargetLang(lang);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown({
    required Language value,
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
          items: Language.values.map((lang) {
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

  Widget _buildActionButton(
    AppLocalizations l10n,
    ImageTranslationState state,
  ) {
    final isBusy = state.status == ImageTranslationStatus.ocrInProgress ||
        state.status == ImageTranslationStatus.translating;

    if (!state.isModelAvailable) {
      return FilledButton.icon(
        onPressed: () {
          context.push('/settings/ocr-model');
        },
        icon: const Icon(Icons.download),
        label: const Text('Download OCR Models First'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: isBusy ? null : _performOcrAndTranslate,
      icon: isBusy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.document_scanner),
      label: Text(isBusy ? l10n.processing : l10n.recognizeAndTranslate),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(
    AppLocalizations l10n,
    ImageTranslationState state,
  ) {
    String message;
    if (state.status == ImageTranslationStatus.ocrInProgress) {
      message = l10n.recognizingText;
    } else {
      message = l10n.translating;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrResult(
    AppLocalizations l10n,
    ImageTranslationState state,
  ) {
    final ocrText = state.ocrResult?.fullText ?? '';
    if (ocrText.isEmpty) return const SizedBox.shrink();

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
                  l10n.recognizedText,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: ocrText));
                    AppToast.show(context, l10n.copiedToClipboard);
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: l10n.copy,
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
                ocrText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationResult(
    AppLocalizations l10n,
    ImageTranslationState state,
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
                  l10n.translationResult,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: state.translatedText!),
                    );
                    AppToast.show(context, l10n.copiedToClipboard);
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: l10n.copy,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                state.translatedText!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.errorContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelDownloadCard(
    AppLocalizations l10n,
    ImageTranslationState state,
  ) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.primaryContainer,
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
                Icon(
                  Icons.download,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'OCR Models Required',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Download RapidOCR models to enable image text recognition. Models are downloaded from HuggingFace or ModelScope.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                context.push('/settings/ocr-model');
              },
              icon: const Icon(Icons.settings),
              label: const Text('Go to Download'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelDownloadProgress(
    AppLocalizations l10n,
    ImageTranslationState state,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Downloading OCR models...'),
            if (state.modelDownloadFile != null) ...[
              const SizedBox(height: 8),
              Text(
                state.modelDownloadFile!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: state.modelDownloadProgress > 0
                  ? state.modelDownloadProgress
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
