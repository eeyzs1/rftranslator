import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rftranslator/features/llm/domain/model_manager.dart';
import 'package:rftranslator/features/translation/domain/entities/language.dart';
import 'package:rftranslator/core/localization/app_localizations.dart';
import 'package:rftranslator/core/utils/app_toast.dart';

class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  String? _selectedSource;
  Map<String, bool>? _sourceAvailability;
  bool _isCheckingSources = false;
  final Set<String> _expandedLangs = {};

  @override
  void initState() {
    super.initState();
    _selectedSource = 'auto';
    _checkSources();
  }

  Future<void> _importLocalModel() async {
    final l10n = AppLocalizations.of(context);
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.selectModelFolder,
    );
    if (selectedDirectory == null) return;

    final modelManager = ref.read(modelManagerProvider.notifier);
    final error = await modelManager.importLocalModel(selectedDirectory);
    if (mounted) {
      if (error != null) {
        AppToast.show(context, error);
      } else {
        AppToast.show(context, l10n.modelImportedSuccess);
        setState(() {});
      }
    }
  }

  Future<void> _checkSources() async {
    setState(() {
      _isCheckingSources = true;
    });

    final availability = <String, bool>{};
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),);

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
          _sourceAvailability = {'auto': true, 'huggingface': true, 'modelscope': true};
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
    final modelManager = ref.read(modelManagerProvider.notifier);
    final modelState = ref.read(modelManagerProvider);

    final source = _selectedSource ?? 'auto';
    if (source == 'modelscope' && modelState.type.modelScopeUrl == null) {
      if (mounted) {
        AppToast.show(context,
          l10n.modelScopeUnavailable,
        );
      }
      return;
    }

    if (source != 'auto' && source != 'modelscope') {
      final hfAvailable = _sourceAvailability?['huggingface'] ?? false;
      if (!hfAvailable) {
        if (mounted) {
          AppToast.show(context,
            l10n.huggingFaceUnavailableToast,
          );
        }
        return;
      }
    }

    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.downloadModel,
    );

    try {
      await modelManager.startDownload(
        customDirectory: selectedDirectory,
        downloadSource: source,
        huggingFaceAvailable: _sourceAvailability?['huggingface'],
        modelScopeAvailable: _sourceAvailability?['modelscope'],
      );
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '${l10n.downloadError}$e');
      }
    }
  }

  Map<String, List<ModelType>> _groupModelsBySourceLang() {
    final groups = <String, List<ModelType>>{};
    for (final type in ModelType.values) {
      final srcLang = type.languagePair.$1;
      groups.putIfAbsent(srcLang, () => []).add(type);
    }
    return groups;
  }

  static const Map<String, Language> _langCodeToEnum = {
    'en': Language.english,
    'zh': Language.chinese,
    'de': Language.german,
    'fr': Language.french,
    'es': Language.spanish,
    'it': Language.italian,
    'ru': Language.russian,
    'ar': Language.arabic,
    'ja': Language.japanese,
    'ko': Language.korean,
    'vi': Language.vietnamese,
    'fi': Language.finnish,
    'sv': Language.swedish,
    'bg': Language.bulgarian,
    'he': Language.hebrew,
    'ms': Language.malay,
    'nl': Language.dutch,
    'uk': Language.ukrainian,
  };

  String _langDisplayName(String code, String localeCode) {
    final lang = _langCodeToEnum[code];
    if (lang != null) {
      return localeCode == 'zh' ? lang.displayName : lang.displayName;
    }
    return code.toUpperCase();
  }

  Widget _buildSourceOption(String value, String label, String description, AppLocalizations l10n) {
    final isAvailable = _sourceAvailability?[value] ?? false;
    final modelState = ref.read(modelManagerProvider);
    final isDownloading = modelState.downloadStatus == ModelDownloadStatus.downloading;

    return RadioGroup<String>(
      groupValue: _selectedSource,
      onChanged: isDownloading
          ? (_) {}
          : (value) {
              setState(() {
                _selectedSource = value;
              });
            },
      child: RadioListTile<String>(
        title: Row(
          children: [
            Text(label),
            const SizedBox(width: 8),
            if (_sourceAvailability != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isAvailable ? l10n.statusAvailable : l10n.statusUnavailable,
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final modelState = ref.watch(modelManagerProvider);
    final modelManager = ref.read(modelManagerProvider.notifier);
    final isDownloading = modelState.downloadStatus == ModelDownloadStatus.downloading;
    final isFailed = modelState.downloadStatus == ModelDownloadStatus.failed;

    ref.listen(modelManagerProvider, (previous, next) {
      if (previous?.downloadStatus != ModelDownloadStatus.completed &&
          next.downloadStatus == ModelDownloadStatus.completed) {
        if (mounted) {
          AppToast.show(context, l10n.modelDownloadCompletedToast);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              ref.read(modelManagerProvider.notifier).resetDownload();
              setState(() {});
            }
          });
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiModel),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isCheckingSources ? null : _checkSources,
            tooltip: l10n.refreshSources,
          ),
        ],
      ),
      body: FutureBuilder<Map<ModelType, bool>>(
        future: _getDownloadedModels(modelManager),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final downloadedModels = snapshot.data!;
          final downloadedModelTypes = ModelType.values.where((type) => downloadedModels[type] ?? false).toList();
          final grouped = _groupModelsBySourceLang();

          final sortedLangCodes = grouped.keys.toList()..sort((a, b) {
            final aIsZh = a == 'zh' ? 0 : (a == 'en' ? 1 : 2);
            final bIsZh = b == 'zh' ? 0 : (b == 'en' ? 1 : 2);
            final cmp = aIsZh.compareTo(bIsZh);
            if (cmp != 0) return cmp;
            return _langDisplayName(a, localeCode).compareTo(_langDisplayName(b, localeCode));
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translationModelsTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.modelsGroupedByLangDesc,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...sortedLangCodes.map((langCode) {
                        final models = grouped[langCode]!;
                        final langName = _langDisplayName(langCode, localeCode);
                        final isExpanded = _expandedLangs.contains(langCode);
                        final downloadedCount = models.where((t) => downloadedModels[t] ?? false).length;

                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  langCode.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              title: Text(
                                langName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '$downloadedCount/${models.length} ${l10n.installedCount}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              trailing: Icon(
                                isExpanded ? Icons.expand_less : Icons.expand_more,
                              ),
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedLangs.remove(langCode);
                                  } else {
                                    _expandedLangs.add(langCode);
                                  }
                                });
                              },
                            ),
                            if (isExpanded) ...[
                              const Divider(height: 1),
                              ...models.map((type) {
                                final isDownloaded = downloadedModels[type] ?? false;
                                final isEnabled = modelState.enabledModelTypes.contains(type);
                                final tgtLang = type.languagePair.$2;
                                final tgtName = _langDisplayName(tgtLang, localeCode);
                                final isSelected = modelState.type == type;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.only(left: 16),
                                    leading: isDownloaded
                                        ? Checkbox(
                                            value: isEnabled,
                                            onChanged: isDownloading
                                                ? null
                                                : (value) {
                                                    modelManager.toggleModelEnabled(type);
                                                  },
                                          )
                                        : null,
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '$langName → $tgtName',
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (isDownloaded)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                        if (!isDownloaded && type.modelHubUrl == null && type.modelScopeUrl == null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade700,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              l10n.localOnlyLabel,
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
                                        Text(
                                          '${type.sizeInfo}'
                                                '${type.modelScopeUrl != null ? " · ModelScope ✓" : ""}'
                                                '${type.modelHubUrl != null ? " · HuggingFace ✓" : ""}',
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
                                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                            onPressed: isDownloading
                                                ? null
                                                : () {
                                                    modelManager.selectModel(type);
                                                  },
                                            tooltip: l10n.selectToDownloadTooltip,
                                          ),
                                    onTap: isDownloading
                                        ? null
                                        : () {
                                            if (isDownloaded) {
                                              modelManager.toggleModelEnabled(type);
                                            } else {
                                              modelManager.selectModel(type);
                                            }
                                          },
                                  ),
                                );
                              }),
                              const SizedBox(height: 4),
                            ],
                            const Divider(height: 1),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
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
                      _buildSourceOption(
                        'auto',
                        l10n.autoDetectOption,
                        l10n.autoDetectOptionDesc,
                        l10n,
                      ),
                      _buildSourceOption(
                        'huggingface',
                        l10n.huggingfaceOption,
                        l10n.huggingfaceOptionDesc,
                        l10n,
                      ),
                      _buildSourceOption(
                        'modelscope',
                        l10n.modelscopeOption,
                        l10n.modelscopeOptionDesc,
                        l10n,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
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
                        l10n.localImportDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _importLocalModel,
                          icon: const Icon(Icons.folder_open),
                          label: Text(l10n.selectModelFolder),
                        ),
                      ),
                      if (ref.read(modelManagerProvider.notifier).customModels.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          l10n.importedCustomModelsTitle,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...ref.read(modelManagerProvider.notifier).customModels.map((entry) {
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.translate, size: 20),
                            title: Text(entry.displayName),
                            subtitle: Text(
                              entry.localPath,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () async {
                                await ref.read(modelManagerProvider.notifier).removeCustomModel(entry.folderName);
                                if (mounted) setState(() {});
                              },
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (!isDownloading && !isFailed)
                _buildDownloadCard(context, l10n, modelState, downloadedModels),

              if (isDownloading)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.downloadingTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${(modelState.downloadProgress * 100).toStringAsFixed(1)}%',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: modelState.downloadProgress),
                        const SizedBox(height: 12),
                        Text(
                          '${_formatBytes(modelState.downloadedBytes)} / ${_formatBytes(modelState.totalBytes)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (isFailed)
                Card(
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
                              onPressed: () => modelManager.resetDownload(),
                              icon: const Icon(Icons.refresh, size: 20),
                              tooltip: l10n.retry,
                            ),
                          ],
                        ),
                        if (modelState.downloadError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            modelState.downloadError!,
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
                                onPressed: () => modelManager.resetDownload(),
                                icon: const Icon(Icons.close),
                                label: Text(l10n.closeButton),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              Card(
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
                      if (downloadedModelTypes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            l10n.pleaseSelectModel,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      else
                        ...downloadedModelTypes.map((type) {
                          final isEnabled = modelState.enabledModelTypes.contains(type);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: CheckboxListTile(
                                    value: isEnabled,
                                    onChanged: isDownloading
                                        ? null
                                        : (value) {
                                            modelManager.toggleModelEnabled(type);
                                          },
                                    title: Text(type.displayName),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(type.description),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${l10n.fileSize}: ${type.sizeInfo}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.secondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    dense: true,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: isDownloading
                                      ? null
                                      : () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text(l10n.deleteModel),
                                              content: Text('${l10n.deleteModelConfirm} ${type.displayName}?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: Text(l10n.cancel),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            await modelManager.deleteModel(type);
                                            await Future.delayed(const Duration(milliseconds: 100));
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
              ),

              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.usageInstructions,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.architectureOverviewText,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All OPUS-MT models by Helsinki-NLP (Language Technology Research Group at the University of Helsinki) '
                        'are licensed under CC BY 4.0. '
                        'To view a copy of this license, visit https://creativecommons.org/licenses/by/4.0/',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<ModelType, bool>> _getDownloadedModels(ModelManager manager) async {
    final downloaded = <ModelType, bool>{};
    for (final type in ModelType.values) {
      downloaded[type] = await manager.isModelDownloaded(type);
    }
    return downloaded;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildDownloadCard(BuildContext context, AppLocalizations l10n, ModelState modelState, Map<ModelType, bool> downloadedModels) {
    final source = _selectedSource ?? 'auto';
    final theme = Theme.of(context);
    final hasScope = modelState.type.modelScopeUrl != null;
    final hfAvailable = _sourceAvailability?['huggingface'] ?? true;
    final scopeAvailable = _sourceAvailability?['modelscope'] ?? true;
    final isDownloaded = downloadedModels[modelState.type] ?? false;

    String? warning;
    bool canDownload = !isDownloaded;
    IconData? warningIcon;

    if (isDownloaded) {
      warning = l10n.modelAlreadyInstalled;
      warningIcon = Icons.check_circle;
    } else {
      switch (source) {
        case 'modelscope':
          if (!hasScope) {
            warning = l10n.modelScopeModelUnavailable;
            warningIcon = Icons.warning_amber_rounded;
            canDownload = false;
          } else if (!scopeAvailable) {
            warning = l10n.modelScopeConnectionUnavailable;
            warningIcon = Icons.cloud_off_rounded;
            canDownload = false;
          }
          break;
        case 'huggingface':
          if (!hfAvailable) {
            warning = l10n.huggingFaceConnectionUnavailable;
            warningIcon = Icons.cloud_off_rounded;
            canDownload = false;
          }
          break;
        default:
          if (!hfAvailable && !hasScope) {
            warning = l10n.noDownloadSourceAvailable;
            warningIcon = Icons.block_rounded;
            canDownload = false;
          } else if (!hfAvailable && !scopeAvailable && hasScope) {
            warning = l10n.allSourcesUnavailable;
            warningIcon = Icons.cloud_off_rounded;
            canDownload = false;
          }
          break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.downloadModel, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (warning != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDownloaded
                      ? Colors.green.withValues(alpha: 0.1)
                      : theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDownloaded
                        ? Colors.green.withValues(alpha: 0.3)
                        : theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      warningIcon,
                      color: isDownloaded ? Colors.green : theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(
                          color: isDownloaded ? Colors.green : theme.colorScheme.onErrorContainer,
                          fontSize: 13,
                          fontWeight: isDownloaded ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(l10n.downloadingInBackground, style: theme.textTheme.bodyMedium),
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
}
