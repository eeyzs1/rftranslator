import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rftranslator/core/di/providers.dart';
import 'package:rftranslator/core/localization/app_localizations.dart';
import 'package:rftranslator/core/utils/app_toast.dart';
import 'package:rftranslator/features/dictionary/domain/entities/word_entry.dart';

class WordDetailScreen extends ConsumerStatefulWidget {
  final String word;

  const WordDetailScreen({super.key, required this.word});

  @override
  ConsumerState<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends ConsumerState<WordDetailScreen> {
  WordEntry? _wordEntry;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFavorite = false;
  String _decodedWord = '';

  @override
  void initState() {
    super.initState();
    _decodedWord = Uri.decodeComponent(widget.word);
    _loadWordEntry();
  }

  Future<void> _loadWordEntry() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final starDictSource = ref.read(starDictDataSourceProvider);
      final entry = await starDictSource.getWord(_decodedWord);

      if (mounted) {
        setState(() {
          _wordEntry = entry;
          _isLoading = false;
          if (entry == null) {
            _errorMessage = '\u672A\u627E\u5230 "$_decodedWord" \u7684\u8BCD\u5178\u6761\u76EE';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '\u67E5\u8BE2\u51FA\u9519: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_decodedWord),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
            onPressed: () {
              setState(() {
                _isFavorite = !_isFavorite;
              });
              AppToast.show(
                context,
                _isFavorite ? '已添加到收藏' : '已取消收藏',
              );
            },
            tooltip: '收藏',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'copy':
                  if (_wordEntry != null) {
                    final text = _formatForCopy();
                    Clipboard.setData(ClipboardData(text: text));
                    AppToast.show(context, l10n.copiedToClipboard);
                  }
                  break;
                case 'share':
                  _shareWord();
                  break;
                case 'speak':
                  _speakWord();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    const Icon(Icons.copy, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.copy),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'speak',
                child: Row(
                  children: [
                    Icon(Icons.volume_up, size: 20),
                    SizedBox(width: 8),
                    Text('\u64AD\u653E'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 8),
                    Text('\u5206\u4EAB'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null || _wordEntry == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? '\u672A\u627E\u5230\u8BCD\u5178\u6761\u76EE',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadWordEntry,
              icon: const Icon(Icons.refresh),
              label: const Text('\u91CD\u8BD5'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _wordEntry!.word,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          if (_wordEntry!.phonetic != null) ...[
            const SizedBox(height: 8),
            Text(
              '/${_wordEntry!.phonetic}/',
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFFE8002D),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ..._wordEntry!.definitions.asMap().entries.map((entry) {
            final index = entry.key;
            final definition = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (definition.partOfSpeech.isNotEmpty)
                      Text(
                        '${index + 1}. ${definition.partOfSpeech}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    else
                      Text(
                        '${index + 1}.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      definition.chinese,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (definition.english != null && definition.english!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        definition.english!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          if (_wordEntry!.examples.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              '\u4F8B\u53E5',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            ..._wordEntry!.examples.map((example) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 15)),
                      Expanded(
                        child: Text(
                          example.english,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  if (example.chinese != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2),
                      child: Text(
                        example.chinese!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),),
          ],
        ],
      ),
    );
  }

  String _formatForCopy() {
    final sb = StringBuffer();
    sb.writeln(_wordEntry!.word);
    if (_wordEntry!.phonetic != null) {
      sb.writeln('/${_wordEntry!.phonetic}/');
    }
    for (final def in _wordEntry!.definitions) {
      if (def.partOfSpeech.isNotEmpty) {
        sb.write('${def.partOfSpeech} ');
      }
      sb.writeln(def.chinese);
    }
    return sb.toString().trim();
  }

  void _shareWord() {
    final text = _formatForCopy();
  }

  void _speakWord() {}
}
