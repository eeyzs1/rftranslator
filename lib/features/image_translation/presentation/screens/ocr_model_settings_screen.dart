// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rftranslator/core/localization/app_localizations.dart';
import 'package:rftranslator/core/utils/app_toast.dart';
import 'package:rftranslator/features/image_translation/data/datasources/rapidocr_model_manager.dart';
import 'package:rftranslator/features/image_translation/domain/ocr_model_manager_provider.dart';

class OcrModelSettingsScreen extends ConsumerStatefulWidget {
  const OcrModelSettingsScreen({super.key});

  @override
  ConsumerState<OcrModelSettingsScreen> createState() =>
      _OcrModelSettingsScreenState();
}

class _OcrModelSettingsScreenState
    extends ConsumerState<OcrModelSettingsScreen> {
  String _selectedSource = 'auto';
  Map<String, bool>? _sourceAvailability;
  bool _isCheckingSources = false;

  @override
  void initState() {
    super.initState();
    _checkSources();
    _loadState();
  }

  Future<void> _loadState() async {
    await ref.read(ocrModelManagerProvider.notifier).loadState();
  }

  Future<void> _checkSources() async {
    setState(() {
      _isCheckingSources = true;
    });

    final availability = <String, bool>{};
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    try {
      availability['auto'] = true;

      try {
        await dio.head('https://huggingface.co');
        availability['huggingface'] = true;
      } catch (_) {
        availability['huggingface'] = false;
      }

      try {
        await dio.head('https://modelscope.cn');
        availability['modelscope'] = true;
      } catch (_) {
        availability['modelscope'] = false;
      }

      if (mounted) {
        setState(() {
          _sourceAvailability = availability;
        });
      }
    } catch (e) {
      debugPrint('Error checking sources: $e');
      if (mounted) {
        setState(() {
          _sourceAvailability = {
            'auto': true,
            'huggingface': true,
            'modelscope': true,
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSources = false;
        });
      }
    }
  }

  Future<void> _startDownload() async {
    final l10n = AppLocalizations.of(context);
    final manager = ref.read(ocrModelManagerProvider.notifier);

    final source = _selectedSource;
    final hfAvailable = _sourceAvailability?['huggingface'] ?? false;
    final scopeAvailable = _sourceAvailability?['modelscope'] ?? false;

    if (source == 'huggingface' && !hfAvailable) {
      if (mounted) {
        AppToast.show(context, l10n.huggingFaceUnavailableToast);
      }
      return;
    }

    if (source == 'modelscope' && !scopeAvailable) {
      if (mounted) {
        AppToast.show(context, l10n.modelScopeUnavailable);
      }
      return;
    }

    final String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select OCR Model Download Path',
    );

    if (selectedDirectory == null) return;

    try {
      await manager.startDownload(
        customDirectory: selectedDirectory,
        downloadSource: source,
        huggingFaceAvailable: hfAvailable,
        modelScopeAvailable: scopeAvailable,
      );
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '${l10n.downloadError}$e');
      }
    }
  }

  Future<void> _importLocalModels() async {
    final l10n = AppLocalizations.of(context);
    final String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select OCR Model Folder',
    );
    if (selectedDirectory == null) return;

    final manager = ref.read(ocrModelManagerProvider.notifier);
    await manager.importFromDirectory(selectedDirectory);

    final available = await manager.isAnyModelDownloaded();
    if (mounted) {
      if (available) {
        AppToast.show(context, l10n.modelImportedSuccess);
        setState(() {});
      } else {
        AppToast.show(
          context,
          'Required OCR model files not found in the selected folder.\n'
          'Expected subfolders: pp-ocrv5-server/ or pp-ocrv5-mobile/ with .onnx files inside',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(ocrModelManagerProvider);
    final isDownloading =
        state.downloadStatus == OcrModelDownloadStatus.downloading;
    final isFailed = state.downloadStatus == OcrModelDownloadStatus.failed;

    ref.listen(ocrModelManagerProvider, (previous, next) {
      if (previous?.downloadStatus != OcrModelDownloadStatus.completed &&
          next.downloadStatus == OcrModelDownloadStatus.completed) {
        if (mounted) {
          AppToast.show(context, l10n.modelDownloadCompletedToast);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              ref.read(ocrModelManagerProvider.notifier).resetDownload();
              setState(() {});
            }
          });
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Model Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isCheckingSources ? null : _checkSources,
            tooltip: l10n.refreshSources,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildModelListCard(state),
          const SizedBox(height: 16),
          _buildSourceCard(l10n, state),
          const SizedBox(height: 16),
          _buildLocalImportCard(l10n),
          const SizedBox(height: 16),
          if (!isDownloading && !isFailed) _buildDownloadCard(l10n, state),
          if (isDownloading) _buildDownloadingCard(state),
          if (isFailed) _buildFailedCard(l10n, state),
          const SizedBox(height: 16),
          if (state.downloadedVariants.isNotEmpty)
            _buildInstalledCard(l10n, state),
          const SizedBox(height: 16),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildModelListCard(OcrModelManagerState state) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OCR Models',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'RapidOCR (PaddleOCR PP-OCRv5) for image text recognition',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            ...OcrModelVariant.values.map((variant) {
              final isDownloaded = state.isVariantDownloaded(variant);
              final isSelected = state.selectedVariant == variant;
              final isDownloading =
                  state.downloadStatus == OcrModelDownloadStatus.downloading;

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 16),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          variant.displayName,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isDownloaded)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.installed,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(variant.description),
                      const SizedBox(height: 4),
                      Text(
                        '${variant.sizeInfo}'
                        ' · ModelScope ✓ · HuggingFace ✓',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  trailing: isDownloaded
                      ? null
                      : IconButton(
                          icon: Icon(
                            Icons.download_outlined,
                            size: 20,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          onPressed: isDownloading
                              ? null
                              : () {
                                  ref
                                      .read(ocrModelManagerProvider.notifier)
                                      .selectVariant(variant);
                                },
                          tooltip: l10n.selectToDownloadTooltip,
                        ),
                  onTap: isDownloading
                      ? null
                      : () {
                          ref
                              .read(ocrModelManagerProvider.notifier)
                              .selectVariant(variant);
                        },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(AppLocalizations l10n, OcrModelManagerState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.downloadSourceTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                if (_isCheckingSources)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...[
              ('auto', l10n.autoDetectOption, l10n.autoDetectOptionDesc),
              ('huggingface', l10n.huggingfaceOption, l10n.huggingfaceOptionDesc),
              ('modelscope', l10n.modelscopeOption, l10n.modelscopeOptionDesc),
            ].map((entry) {
              final (value, label, description) = entry;
              final isAvailable = _sourceAvailability?[value] ?? false;
              final isDownloading =
                  state.downloadStatus == OcrModelDownloadStatus.downloading;

              return RadioGroup<String>(
                groupValue: _selectedSource,
                onChanged: isDownloading
                    ? (_) {}
                    : (v) {
                        setState(() {
                          _selectedSource = v ?? 'auto';
                        });
                      },
                child: RadioListTile<String>(
                  title: Row(
                    children: [
                      Text(label),
                      const SizedBox(width: 8),
                      if (_sourceAvailability != null && value != 'auto')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isAvailable ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isAvailable
                                ? l10n.statusAvailable
                                : l10n.statusUnavailable,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(description),
                  value: value,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalImportCard(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.localImportTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import OCR models from a local folder. Expected subfolders: pp-ocrv5-server/ or pp-ocrv5-mobile/ with .onnx files inside',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importLocalModels,
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.selectModelFolder),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadCard(AppLocalizations l10n, OcrModelManagerState state) {
    final source = _selectedSource;
    final hfAvailable = _sourceAvailability?['huggingface'] ?? true;
    final scopeAvailable = _sourceAvailability?['modelscope'] ?? true;
    final isAlreadyDownloaded =
        state.isVariantDownloaded(state.selectedVariant);

    String? warning;
    bool canDownload = !isAlreadyDownloaded;
    IconData? warningIcon;

    if (isAlreadyDownloaded) {
      warning = l10n.modelAlreadyInstalled;
      warningIcon = Icons.check_circle;
    } else {
      if (source == 'huggingface' && !hfAvailable) {
        warning = l10n.huggingFaceConnectionUnavailable;
        warningIcon = Icons.cloud_off_rounded;
        canDownload = false;
      } else if (source == 'modelscope' && !scopeAvailable) {
        warning = l10n.modelScopeConnectionUnavailable;
        warningIcon = Icons.cloud_off_rounded;
        canDownload = false;
      } else if (source == 'auto' && !hfAvailable && !scopeAvailable) {
        warning = l10n.allSourcesUnavailable;
        warningIcon = Icons.cloud_off_rounded;
        canDownload = false;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.downloadModel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Selected: ${state.selectedVariant.displayName} (${state.selectedVariant.sizeInfo})',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (warning != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAlreadyDownloaded
                      ? Colors.green.withValues(alpha: 0.1)
                      : Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAlreadyDownloaded
                        ? Colors.green.withValues(alpha: 0.3)
                        : Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      warningIcon,
                      color: isAlreadyDownloaded
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(
                          color: isAlreadyDownloaded
                              ? Colors.green
                              : Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 13,
                          fontWeight: isAlreadyDownloaded
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                l10n.downloadingInBackground,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canDownload ? _startDownload : null,
                icon: const Icon(Icons.download),
                label: Text(l10n.startDownload),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadingCard(OcrModelManagerState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Downloading ${state.selectedVariant.displayName}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${(state.downloadProgress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: state.downloadProgress),
            const SizedBox(height: 12),
            if (state.currentFile != null)
              Text(
                'File: ${state.currentFile}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Text(
              '${_formatBytes(state.downloadedBytes)} / ${_formatBytes(state.totalBytes)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  ref.read(ocrModelManagerProvider.notifier).cancelDownload();
                },
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedCard(AppLocalizations l10n, OcrModelManagerState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.downloadFailed,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.red,
                      ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(ocrModelManagerProvider.notifier).resetDownload(),
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: l10n.retry,
                ),
              ],
            ),
            if (state.downloadError != null) ...[
              const SizedBox(height: 8),
              Text(
                state.downloadError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _startDownload,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ref
                        .read(ocrModelManagerProvider.notifier)
                        .resetDownload(),
                    icon: const Icon(Icons.close),
                    label: Text(l10n.closeButton),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstalledCard(
    AppLocalizations l10n,
    OcrModelManagerState state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.installedModelsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.installedModelsDesc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            ...state.downloadedVariants.map((variant) {
              final isEnabled = state.isVariantEnabled(variant);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        value: isEnabled,
                        onChanged: state.downloadStatus ==
                                OcrModelDownloadStatus.downloading
                            ? null
                            : (value) {
                                ref
                                    .read(ocrModelManagerProvider.notifier)
                                    .toggleVariantEnabled(variant);
                              },
                        title: Text(variant.displayName),
                        subtitle: FutureBuilder<String?>(
                          future: ref
                              .read(ocrModelManagerProvider.notifier)
                              .getVariantPath(variant),
                          builder: (context, snapshot) {
                            return Text(
                              snapshot.data ?? '',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: state.downloadStatus ==
                              OcrModelDownloadStatus.downloading
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(l10n.deleteModel),
                                  content: Text(
                                    'Delete ${variant.displayName}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(
                                        l10n.delete,
                                        style:
                                            const TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await ref
                                    .read(ocrModelManagerProvider.notifier)
                                    .deleteVariant(variant);
                                if (mounted) {
                                  setState(() {});
                                }
                              }
                            },
                      tooltip: l10n.delete,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Instructions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'RapidOCR uses PaddleOCR PP-OCRv5 models for text detection and recognition.\n\n'
              '• Server variant: Best accuracy, ~166MB\n'
              '• Mobile variant: Lightweight, ~22MB\n\n'
              'Both variants can be installed simultaneously.\n'
              'Use the checkbox to enable/disable a variant.\n\n'
              'The OCR pipeline consists of 3 models:\n'
              '1. Detection model (det) - finds text regions\n'
              '2. Recognition model (rec) - reads text content\n'
              '3. Classification model (cls) - determines text direction',
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
