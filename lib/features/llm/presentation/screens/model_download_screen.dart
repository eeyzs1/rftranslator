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
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择模型文件夹 (Select Model Folder)',
    );
    if (selectedDirectory == null) return;

    final modelManager = ref.read(modelManagerProvider.notifier);
    final error = await modelManager.importLocalModel(selectedDirectory);
    if (mounted) {
      if (error != null) {
        AppToast.show(context, error);
      } else {
        AppToast.show(context, '模型导入成功 / Model imported successfully');
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
          '此模型在 ModelScope 上不可用，请切换到 HuggingFace 或 Auto Detect',
        );
      }
      return;
    }

    if (source != 'auto' && source != 'modelscope') {
      final hfAvailable = _sourceAvailability?['huggingface'] ?? false;
      if (!hfAvailable) {
        if (mounted) {
          AppToast.show(context,
            'HuggingFace 不可用，请切换到 ModelScope 或 Auto Detect',
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
      );
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '下载出错: $e');
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

  Widget _buildSourceOption(String value, String label, String description) {
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
                  isAvailable ? '可用 / OK' : '不可用 / Down',
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
    final isCompleted = modelState.downloadStatus == ModelDownloadStatus.completed;
    final isFailed = modelState.downloadStatus == ModelDownloadStatus.failed;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiModel),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isCheckingSources ? null : _checkSources,
            tooltip: '刷新 / Refresh',
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
                        '翻译模型 / Translation Models',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localeCode == 'zh'
                            ? '按源语言分组，点击展开查看可下载的语对模型'
                            : 'Grouped by source language. Tap to expand and see available language pairs.',
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
                                localeCode == 'zh'
                                    ? '$downloadedCount/${models.length} 已安装'
                                    : '$downloadedCount/${models.length} installed',
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
                                final tgtLang = type.languagePair.$2;
                                final tgtName = _langDisplayName(tgtLang, localeCode);
                                final isSelected = modelState.type == type;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  child: RadioGroup<ModelType>(
                                    groupValue: modelState.type,
                                    onChanged: isDownloading
                                        ? (_) {}
                                        : (value) {
                                            if (value != null) {
                                              modelManager.selectModel(value);
                                            }
                                          },
                                    child: RadioListTile<ModelType>(
                                      dense: true,
                                      contentPadding: const EdgeInsets.only(left: 16),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${langName} → $tgtName',
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
                                                localeCode == 'zh' ? '仅本地' : 'Local only',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${type.sizeInfo}'
                                        '${type.modelScopeUrl != null ? " · ModelScope ✓" : ""}'
                                        '${type.modelHubUrl != null ? " · HuggingFace ✓" : ""}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.secondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      value: type,
                                    ),
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
                            '下载源 / Download Source',
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
                        '自动检测 / Auto Detect',
                        '自动选择最佳下载源',
                      ),
                      _buildSourceOption(
                        'huggingface',
                        'Hugging Face',
                        '官方源（可能需要代理）',
                      ),
                      _buildSourceOption(
                        'modelscope',
                        'ModelScope（阿里）',
                        '阿里云模型库（国内推荐）',
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
                        '本地导入 / Local Import',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '从本地磁盘导入 OPUS-MT 模型文件夹\n'
                        '文件夹名需为 opus-mt-[l1]-[l2] 格式（如 opus-mt-zh-de）\n'
                        '需包含: config.json, pytorch_model.bin, source.spm, target.spm, vocab.json',
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
                          label: const Text('选择模型文件夹 / Select Model Folder'),
                        ),
                      ),
                      if (ref.read(modelManagerProvider.notifier).customModels.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          '已导入的自定义模型 / Imported Custom Models',
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

              if (!isDownloading && !isCompleted)
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
                              '正在下载 / Downloading...',
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

              if (isCompleted || isFailed)
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
                              isCompleted
                                  ? l10n.downloadCompleted
                                  : l10n.downloadFailed,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: isCompleted ? Colors.green : Colors.red,
                                  ),
                            ),
                            if (!isCompleted)
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
                        if (isCompleted) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('完成 / Done'),
                            ),
                          ),
                        ],
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
                        l10n.selectModel,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
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
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: RadioGroup<ModelType>(
                                    groupValue: modelState.type,
                                    onChanged: isDownloading
                                        ? (_) {}
                                        : (value) {
                                            if (value != null) {
                                              modelManager.selectModel(value);
                                            }
                                          },
                                    child: RadioListTile<ModelType>(
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
                                      value: type,
                                    ),
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
                      const Text(
                        '架构说明 / Architecture Overview\n\n'
                        '• Encoder-Decoder 架构模型，专为长句翻译优化\n\n'
                        '翻译流程 / Translation Flow:\n'
                        '1. 单词/短语 → StarDict 词典\n'
                        '2. 长句/段落 → Encoder-Decoder 模型\n'
                        '3. 词典未找到 → Encoder-Decoder 模型兜底',
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

    if (isDownloaded) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.downloadModel, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.modelAlreadyInstalled,
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    String? warning;
    bool canDownload = true;
    IconData? warningIcon;

    switch (source) {
      case 'modelscope':
        if (!hasScope) {
          warning = '此模型 ${modelState.type.displayName} 在 ModelScope 上不可用，请切换到 HuggingFace 或 Auto Detect';
          warningIcon = Icons.warning_amber_rounded;
          canDownload = false;
        } else if (!scopeAvailable) {
          warning = 'ModelScope 连接不可用，请检查网络';
          warningIcon = Icons.cloud_off_rounded;
          canDownload = false;
        }
        break;
      case 'huggingface':
        if (!hfAvailable) {
          warning = 'HuggingFace 连接不可用，请切换到 ModelScope 或 Auto Detect';
          warningIcon = Icons.cloud_off_rounded;
          canDownload = false;
        }
        break;
      default:
        if (!hfAvailable && !hasScope) {
          warning = '此模型 ${modelState.type.displayName} 无可用下载源：HuggingFace 不可用且 ModelScope 上无此模型';
          warningIcon = Icons.block_rounded;
          canDownload = false;
        } else if (!hfAvailable && !scopeAvailable && hasScope) {
          warning = '所有下载源均不可用，请检查网络';
          warningIcon = Icons.cloud_off_rounded;
          canDownload = false;
        }
        break;
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
                  color: theme.colorScheme.errorContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(warningIcon, color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 13),
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
