import 'dart:io';
import 'package:mdict_reader/mdict_reader.dart';
import 'package:rftranslator/features/dictionary/domain/dictionary_repository.dart';
import 'package:rftranslator/features/dictionary/domain/entities/word_entry.dart';

class MDictDataSource implements DictionaryRepository {
  MdictReader? _reader;
  String? _currentPath;

  @override
  Future<void> setPath(String? path) async {
    if (path == _currentPath && _reader != null) return;
    _currentPath = path;
    _reader = null;
    if (path != null && File(path).existsSync()) {
      try {
        _reader = MdictReader(path);
      } catch (e) {
        _reader = null;
      }
    }
  }

  @override
  Future<WordEntry?> getWord(String word) async {
    if (_reader == null) return null;

    try {
      final result = _reader!.query(word);
      if (result == null) return null;

      String definitionText;
      if (result is List) {
        definitionText = result.join('\n');
      } else {
        definitionText = result.toString();
      }

      if (definitionText.isEmpty) return null;

      return _parseMDictResult(word, definitionText);
    } catch (e) {
      return null;
    }
  }

  WordEntry _parseMDictResult(String word, String definition) {
    final definitions = <Definition>[];
    final examples = <ExampleSentence>[];

    String cleanedDef = definition;

    cleanedDef = cleanedDef.replaceAll(RegExp(r'<[^>]*>'), '');
    cleanedDef = cleanedDef.replaceAll(RegExp(r'&[a-zA-Z]+;'), ' ');
    cleanedDef = cleanedDef.replaceAll(RegExp(r'&#\d+;'), ' ');
    cleanedDef = cleanedDef.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleanedDef.isEmpty) {
      cleanedDef = definition
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final lines = cleanedDef.split(RegExp(r'\n|<br\s*/?>|\\n'));
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final posMatch = RegExp(r'^([a-z]+\.|n\.|v\.|adj\.|adv\.|prep\.|conj\.|pron\.|det\.)\s*(.*)').firstMatch(trimmed);
      if (posMatch != null) {
        definitions.add(Definition(
          partOfSpeech: posMatch.group(1)!.replaceAll('.', ''),
          chinese: posMatch.group(2)!.trim(),
        ),);
      } else if (trimmed.startsWith(RegExp(r'^[\u4e00-\u9fa5]'))) {
        definitions.add(Definition(
          partOfSpeech: '',
          chinese: trimmed,
        ),);
      } else if (definitions.isEmpty) {
        definitions.add(Definition(
          partOfSpeech: '',
          chinese: trimmed,
        ),);
      }
    }

    if (definitions.isEmpty && cleanedDef.isNotEmpty) {
      definitions.add(Definition(
        partOfSpeech: '',
        chinese: cleanedDef,
      ),);
    }

    return WordEntry(
      word: word,
      phonetic: null,
      definitions: definitions,
      examples: examples,
      exchanges: {},
    );
  }

  Future<String?> readHeader(String mdxPath) async {
    try {
      final reader = MdictReader(mdxPath);
      return reader.query('__mdx_header_info__')?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> getHeadwords(String mdxPath, {int limit = 20}) async {
    try {
      final reader = MdictReader(mdxPath);
      final allKeys = reader.keys();
      return allKeys.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> isValidMDictFile(String path) async {
    try {
      MdictReader(path);
      return true;
    } catch (e) {
      return false;
    }
  }
}
