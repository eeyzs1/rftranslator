import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rftranslator/features/dictionary/domain/dictionary_manager.dart';
import 'package:rftranslator/core/localization/app_localizations.dart';
import 'package:rftranslator/core/utils/app_toast.dart';
import 'package:rftranslator/features/translation/domain/entities/language.dart';

class DictionaryManagerScreen extends ConsumerStatefulWidget {
  const DictionaryManagerScreen({super.key});

  @override
  ConsumerState<DictionaryManagerScreen> createState() => _DictionaryManagerScreenState();
}

class _DictionaryManagerScreenState extends ConsumerState<DictionaryManagerScreen> {
  @override
  void initState() {
    super.initState();
    _loadDictionaryStatus();
  }

  Future<void> _loadDictionaryStatus() async {
    final manager = ref.read(dictionaryManagerProvider.notifier);
    await manager.getDictionaryPath();
    await manager.isDictionaryAvailable();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startDownload() async {
    final l10n = AppLocalizations.of(context);
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.downloadDictionary,
    );

    final manager = ref.read(dictionaryManagerProvider.notifier);
    await manager.startDownload(customDirectory: selectedDirectory);
  }

  void _cancelDownload() {
    final manager = ref.read(dictionaryManagerProvider.notifier);
    manager.cancelDownload();
  }

  void _resetDownload() {
    final manager = ref.read(dictionaryManagerProvider.notifier);
    manager.resetDownload();
  }

  Future<void> _importMDict(BuildContext context) async {
    final localeCode = Localizations.localeOf(context).languageCode;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mdx'],
      dialogTitle: localeCode == 'zh' ? '选择 MDict 词典文件' : 'Select MDict Dictionary File',
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    final manager = ref.read(dictionaryManagerProvider.notifier);
    final meta = await manager.importMDictFile(filePath);

    if (!mounted) return;

    if (meta != null) {
      AppToast.show(
        context,
        localeCode == 'zh'
            ? '成功导入: ${meta.originalName} (${langDisplayName(meta.sourceLang, localeCode)} → ${langDisplayName(meta.targetLang, localeCode)})'
            : 'Imported: ${meta.originalName} (${langDisplayName(meta.sourceLang, localeCode)} → ${langDisplayName(meta.targetLang, localeCode)})',
      );
      setState(() {});
    } else {
      AppToast.show(
        context,
        localeCode == 'zh' ? '导入失败，请确保是有效的 .mdx 文件' : 'Import failed. Please ensure it is a valid .mdx file.',
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<Map<String, bool>> _getDownloadedDictionaries() async {
    final downloaded = <String, bool>{};
    for (final meta in dictionaryCatalog) {
      final downloadedPath = getDownloadedPath(meta.id);
      if (downloadedPath != null) {
        downloaded[meta.id] = File(downloadedPath).existsSync() || Directory(downloadedPath).existsSync();
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final defaultPath = path.join(dir.path, meta.localDirName);
        downloaded[meta.id] = File(defaultPath).existsSync() || Directory(defaultPath).existsSync();
      }
    }
    for (final meta in allMDictDictionaries) {
      downloaded[meta.id] = File(meta.localDirName).existsSync();
    }
    return downloaded;
  }

  Map<String, List<DictionaryMeta>> _groupDictionariesByTargetLang() {
    final groups = <String, List<DictionaryMeta>>{};
    for (final meta in dictionaryCatalog) {
      final targetLang = meta.targetLang;
      groups.putIfAbsent(targetLang, () => []).add(meta);
    }
    for (final meta in allMDictDictionaries) {
      final targetLang = meta.targetLang;
      groups.putIfAbsent(targetLang, () => []).add(meta);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final dictState = ref.watch(dictionaryManagerProvider);
    final manager = ref.read(dictionaryManagerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dictionaryManagement),
      ),
      body: FutureBuilder<Map<String, bool>>(
        future: _getDownloadedDictionaries(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final downloadedDicts = snapshot.data!;
          final downloadedIds = <String>[
            ...dictionaryCatalog.where((m) => downloadedDicts[m.id] ?? false).map((m) => m.id),
            ...allMDictDictionaries.where((m) => downloadedDicts[m.id] ?? false).map((m) => m.id),
          ];

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
                        l10n.selectDictionary,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ..._groupDictionariesByTargetLang().entries.map((entry) {
                        final targetLang = entry.key;
                        final dicts = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '${langDisplayName(targetLang, localeCode)} ${localeCode == 'zh' ? '释义' : 'Definitions'}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            ...dicts.map((meta) {
                              final isDownloaded = downloadedDicts[meta.id] ?? false;
                              return RadioListTile<String>(
                                title: Text(meta.displayName(localeCode)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(meta.description(localeCode)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${l10n.fileSize}: ${meta.sizeInfo(localeCode)}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.secondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
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
                                      ],
                                    ),
                                  ],
                                ),
                                value: meta.id,
                                groupValue: dictState.selectedId,
                                onChanged: dictState.downloadStatus == DownloadStatus.downloading
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          manager.selectDictionary(value).then((_) => _loadDictionaryStatus());
                                        }
                                      },
                              );
                            }),
                            const Divider(),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (dictState.downloadStatus != DownloadStatus.idle)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.downloadStatus,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),

                        if (dictState.downloadStatus == DownloadStatus.downloading) ...[
                          LinearProgressIndicator(
                            value: dictState.downloadProgress,
                            minHeight: 8,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(dictState.downloadProgress * 100).toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_formatBytes(dictState.downloadedBytes)} / ${_formatBytes(dictState.totalBytes)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _cancelDownload,
                              icon: const Icon(Icons.cancel),
                              label: Text(l10n.cancelDownload),
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.error,
                                foregroundColor: Theme.of(context).colorScheme.onError,
                              ),
                            ),
                          ),
                        ] else if (dictState.downloadStatus == DownloadStatus.completed) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.downloadCompleted,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      '${l10n.fileSize}: ${_formatBytes(dictState.totalBytes)}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    _resetDownload();
                                    await _loadDictionaryStatus();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l10n.reset),
                                ),
                              ),
                            ],
                          ),
                        ] else if (dictState.downloadStatus == DownloadStatus.failed) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.error,
                                color: Theme.of(context).colorScheme.error,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.downloadFailed,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                    if (dictState.downloadError != null)
                                      Text(
                                        dictState.downloadError!,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _resetDownload,
                                  icon: const Icon(Icons.clear),
                                  label: Text(l10n.clear),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              if (dictState.downloadStatus == DownloadStatus.idle)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.downloadDictionary,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.downloadingInBackground,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: dictState.meta?.downloadUrl == null || (downloadedDicts[dictState.selectedId] ?? false)
                                ? null
                                : _startDownload,
                            icon: const Icon(Icons.download),
                            label: Text(l10n.startDownload),
                          ),
                        ),
                        if (dictState.meta?.downloadUrl == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.pleaseSelectDictionary,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (downloadedDicts[dictState.selectedId] ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.modelAlreadyInstalled,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                        localeCode == 'zh' ? '选择已安装的词典' : 'Select Installed Dictionaries',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localeCode == 'zh' ? '选择要使用的词典（可多选）' : 'Select dictionaries to use (multiple)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (downloadedIds.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            l10n.pleaseSelectDictionary,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      else
                        ...downloadedIds.map((id) {
                          final meta = findDictionaryById(id) ?? findMDictById(id);
                          if (meta == null) return const SizedBox.shrink();
                          final isSelected = dictState.selectedDictionaryIds.contains(id);
                          return CheckboxListTile(
                            title: Row(
                              children: [
                                Expanded(child: Text(meta.displayName(localeCode))),
                                if (meta.isMDict)
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                    onPressed: () async {
                                      await manager.removeMDict(id);
                                      if (mounted) {
                                        setState(() {});
                                      }
                                    },
                                    tooltip: localeCode == 'zh' ? '删除' : 'Delete',
                                  ),
                              ],
                            ),
                            subtitle: Text(meta.isMDict
                                ? (localeCode == 'zh' ? 'MDict 格式（用户导入）' : 'MDict format (imported)')
                                : meta.description(localeCode),),
                            value: isSelected,
                            onChanged: dictState.downloadStatus == DownloadStatus.downloading
                                ? null
                                : (value) async {
                                    await manager.toggleDictionarySelection(id);
                                  },
                          );
                        }),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        localeCode == 'zh' ? '导入 MDict 词典 (.mdx)' : 'Import MDict Dictionary (.mdx)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localeCode == 'zh'
                            ? '支持 .mdx 格式，导入后自动识别语言对'
                            : 'Supports .mdx format, language pairs auto-detected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _importMDict(context),
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: Text(localeCode == 'zh' ? '选择 .mdx 文件' : 'Select .mdx File'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        localeCode == 'zh' ? '可用的语言对' : 'Available Language Pairs',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      ...manager.getAvailableLanguagePairs().map((pair) {
                        final srcLang = pair.$1;
                        final tgtLang = pair.$2;
                        final src = langDisplayName(
                          srcLang.code,
                          localeCode,
                        );
                        final tgt = langDisplayName(
                          tgtLang.code,
                          localeCode,
                        );
                        return ListTile(
                          leading: const Icon(Icons.translate),
                          title: Text('$src → $tgt'),
                        );
                      }),
                      if (manager.getAvailableLanguagePairs().isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            localeCode == 'zh' ? '请先选择词典' : 'Please select dictionaries first',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
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
                        l10n.usageInstructions,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${l10n.step1SelectDictionary}\n'
                        '${l10n.step2DownloadDictionary}\n'
                        '${l10n.step3SupportedDictionaryFormats}\n\n'
                        '${l10n.dictionaryRecommendations}\n'
                        '${l10n.ecdictDesc}\n'
                        '${l10n.wiktionaryDesc}\n\n'
                        '${l10n.noDictionaryWarning}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
