import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:rftranslator/features/dictionary/domain/dictionary_repository.dart';
import 'package:rftranslator/features/dictionary/domain/entities/word_entry.dart';

class StarDictInfo {
  final String bookname;
  final int wordCount;
  final int idxFileSize;
  final int synWordCount;
  final String version;
  final String? dictType;
  final String ifoPath;
  final String idxPath;
  final String dictPath;

  const StarDictInfo({
    required this.bookname,
    required this.wordCount,
    required this.idxFileSize,
    this.synWordCount = 0,
    this.version = '2.4.2',
    this.dictType,
    required this.ifoPath,
    required this.idxPath,
    required this.dictPath,
  });
}

class _IndexEntry {
  final String word;
  final int offset;
  final int size;

  const _IndexEntry({
    required this.word,
    required this.offset,
    required this.size,
  });
}

class StarDictNativeDataSource implements DictionaryRepository {
  StarDictInfo? _info;
  List<_IndexEntry>? _index;
  RandomAccessFile? _dictFile;
  String? _currentIfoPath;
  bool _isLoaded = false;
  bool _isLoading = false;

  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get currentPath => _currentIfoPath;

  @override
  Future<void> setPath(String? ifoPath) async {
    if (ifoPath == _currentIfoPath && _isLoaded) return;

    await _close();
    _currentIfoPath = ifoPath;
    _isLoaded = false;

    if (ifoPath != null) {
      debugPrint('[StarDictNative] setPath: $ifoPath');
    }
  }

  Future<void> _close() async {
    await _dictFile?.close();
    _dictFile = null;
    _index = null;
    _info = null;
  }

  Future<bool> loadDictionary() async {
    if (_isLoading) return false;
    if (_isLoaded) return true;
    if (_currentIfoPath == null) return false;

    _isLoading = true;
    try {
      final ifoPath = _currentIfoPath!;
      debugPrint('[StarDictNative] loadDictionary: loading from $ifoPath');

      if (!File(ifoPath).existsSync()) {
        debugPrint('[StarDictNative]   .ifo file not found');
        return false;
      }

      _info = await _parseIfoFile(ifoPath);
      if (_info == null) {
        debugPrint('[StarDictNative]   failed to parse .ifo file');
        return false;
      }
      debugPrint('[StarDictNative]   bookname="${_info!.bookname}", wordCount=${_info!.wordCount}');

      if (!File(_info!.idxPath).existsSync()) {
        debugPrint('[StarDictNative]   .idx file not found: ${_info!.idxPath}');
        return false;
      }

      _index = await _loadIndex(_info!);
      if (_index == null || _index!.isEmpty) {
        debugPrint('[StarDictNative]   failed to load index or index is empty');
        return false;
      }
      debugPrint('[StarDictNative]   loaded ${_index!.length} index entries');

      if (!File(_info!.dictPath).existsSync()) {
        debugPrint('[StarDictNative]   .dict file not found: ${_info!.dictPath}');
        return false;
      }

      _dictFile = await File(_info!.dictPath).open();

      _isLoaded = true;
      debugPrint('[StarDictNative]   dictionary loaded successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[StarDictNative]   ERROR loading dictionary: $e');
      debugPrint('[StarDictNative]   StackTrace: $stackTrace');
      return false;
    } finally {
      _isLoading = false;
    }
  }

  Future<StarDictInfo?> _parseIfoFile(String ifoPath) async {
    try {
      final content = await File(ifoPath).readAsString();
      final lines = content.split('\n');

      String bookname = '';
      int wordCount = 0;
      int idxFileSize = 0;
      String version = '2.4.2';
      String? dictType;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eqIndex = trimmed.indexOf('=');
        if (eqIndex < 0) continue;
        final key = trimmed.substring(0, eqIndex).trim();
        final value = trimmed.substring(eqIndex + 1).trim();

        switch (key) {
          case 'bookname':
            bookname = value;
          case 'wordcount':
            wordCount = int.tryParse(value) ?? 0;
          case 'idxfilesize':
            idxFileSize = int.tryParse(value) ?? 0;
          case 'version':
            version = value;
          case 'dicttype':
            dictType = value;
        }
      }

      if (bookname.isEmpty && wordCount == 0) return null;

      final dir = path.dirname(ifoPath);
      final baseName = path.basenameWithoutExtension(ifoPath);

      String? idxPath;
      final decompressedIdxPath = path.join(dir, '$baseName.idx');
      if (File(decompressedIdxPath).existsSync()) {
        idxPath = decompressedIdxPath;
        debugPrint('[StarDictNative]   using cached decompressed .idx');
      } else {
        for (final ext in ['.idx', '.idx.gz', '.idx.dz']) {
          final candidate = path.join(dir, '$baseName$ext');
          if (File(candidate).existsSync()) {
            idxPath = candidate;
            break;
          }
        }
        if (idxPath != null && (idxPath.endsWith('.gz') || idxPath.endsWith('.dz'))) {
          debugPrint('[StarDictNative]   decompressing ${path.basename(idxPath)} to cache...');
          final rawBytes = await File(idxPath).readAsBytes();
          final decompressed = _decompressGzip(rawBytes);
          await File(decompressedIdxPath).writeAsBytes(decompressed);
          debugPrint('[StarDictNative]   cached decompressed .idx (${decompressed.length} bytes)');
          idxPath = decompressedIdxPath;
        }
      }

      String? dictPath;
      final decompressedDictPath = path.join(dir, '$baseName.dict');
      if (File(decompressedDictPath).existsSync()) {
        dictPath = decompressedDictPath;
        debugPrint('[StarDictNative]   using cached decompressed .dict');
      } else {
        for (final ext in ['.dict', '.dict.dz']) {
          final candidate = path.join(dir, '$baseName$ext');
          if (File(candidate).existsSync()) {
            dictPath = candidate;
            break;
          }
        }
        if (dictPath != null && dictPath.endsWith('.dz')) {
          debugPrint('[StarDictNative]   decompressing ${path.basename(dictPath)} to cache...');
          final rawBytes = await File(dictPath).readAsBytes();
          final decompressed = _decompressGzip(rawBytes);
          await File(decompressedDictPath).writeAsBytes(decompressed);
          debugPrint('[StarDictNative]   cached decompressed .dict (${decompressed.length} bytes)');
          dictPath = decompressedDictPath;
        }
      }

      if (idxPath == null || dictPath == null) return null;

      return StarDictInfo(
        bookname: bookname,
        wordCount: wordCount,
        idxFileSize: idxFileSize,
        version: version,
        dictType: dictType,
        ifoPath: ifoPath,
        idxPath: idxPath,
        dictPath: dictPath,
      );
    } catch (e) {
      debugPrint('[StarDictNative]   ERROR parsing .ifo: $e');
      return null;
    }
  }

  Future<List<_IndexEntry>?> _loadIndex(StarDictInfo info) async {
    try {
      Uint8List idxBytes;

      if (info.idxPath.endsWith('.gz') || info.idxPath.endsWith('.dz')) {
        debugPrint('[StarDictNative]   decompressing .idx.gz...');
        final rawBytes = await File(info.idxPath).readAsBytes();
        idxBytes = _decompressGzip(rawBytes);
      } else {
        idxBytes = await File(info.idxPath).readAsBytes();
      }

      final entries = <_IndexEntry>[];
      int pos = 0;
      final byteData = ByteData.sublistView(idxBytes);

      while (pos < idxBytes.length - 12) {
        int nullPos = pos;
        while (nullPos < idxBytes.length && idxBytes[nullPos] != 0) {
          nullPos++;
        }
        if (nullPos >= idxBytes.length - 8) break;

        final word = utf8.decode(idxBytes.sublist(pos, nullPos), allowMalformed: true);
        final offset = byteData.getUint32(nullPos + 1);
        final size = byteData.getUint32(nullPos + 5);

        entries.add(_IndexEntry(word: word, offset: offset, size: size));
        pos = nullPos + 9;
      }

      return entries;
    } catch (e, stackTrace) {
      debugPrint('[StarDictNative]   ERROR loading index: $e');
      debugPrint('[StarDictNative]   StackTrace: $stackTrace');
      return null;
    }
  }

  Uint8List _decompressGzip(Uint8List compressed) {
    final decompressed = gzip.decode(compressed);
    return Uint8List.fromList(decompressed);
  }

  @override
  Future<WordEntry?> getWord(String word) async {
    if (_currentIfoPath == null) return null;

    if (!_isLoaded) {
      final loaded = await loadDictionary();
      if (!loaded) return null;
    }

    try {
      final entry = _binarySearch(word);
      if (entry == null) return null;

      final definition = await _readDefinition(entry);
      if (definition == null) return null;

      return _parseDefinition(word, definition);
    } catch (e, stackTrace) {
      debugPrint('[StarDictNative]   ERROR in getWord: $e');
      debugPrint('[StarDictNative]   StackTrace: $stackTrace');
      return null;
    }
  }

  _IndexEntry? _binarySearch(String word) {
    if (_index == null || _index!.isEmpty) return null;

    final lowerWord = word.toLowerCase();
    int low = 0;
    int high = _index!.length - 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final midWord = _index![mid].word.toLowerCase();
      final cmp = lowerWord.compareTo(midWord);

      if (cmp == 0) {
        return _index![mid];
      } else if (cmp < 0) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    return null;
  }

  Future<String?> _readDefinition(_IndexEntry entry) async {
    try {
      if (_dictFile == null) return null;
      await _dictFile!.setPosition(entry.offset);
      final bytes = await _dictFile!.read(entry.size);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      debugPrint('[StarDictNative]   ERROR reading definition: $e');
      return null;
    }
  }

  WordEntry _parseDefinition(String word, String rawDefinition) {
    final definitions = <Definition>[];
    final examples = <ExampleSentence>[];
    String? phonetic;

    final cleaned = _stripHtmlTags(rawDefinition);
    final lines = cleaned.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final extractedPhonetic = _extractPhonetic(trimmed);
      if (extractedPhonetic != null && phonetic == null) {
        phonetic = extractedPhonetic;
        continue;
      }

      final chineseContent = _extractChineseText(trimmed);
      if (chineseContent.isNotEmpty) {
        definitions.add(Definition(partOfSpeech: '', chinese: chineseContent));
      }
    }

    if (definitions.isEmpty && cleaned.isNotEmpty) {
      definitions.add(Definition(partOfSpeech: '', chinese: cleaned));
    }

    return WordEntry(
      word: word,
      phonetic: phonetic,
      definitions: definitions,
      examples: examples,
      exchanges: {},
    );
  }

  static final _htmlTagRegex = RegExp(r'<[^>]+>');
  static final _phoneticBracketsRegex = RegExp(r'\[([^\]]+)\]');
  static final _phoneticSlashRegex = RegExp(r'/([^/]+)/');
  static final _phoneticStarRegex = RegExp(r'\*([^\s\]]+)');
  static final _chineseCharRegex = RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf]');

  String _stripHtmlTags(String text) {
    return text.replaceAll(_htmlTagRegex, '').replaceAll('&nbsp;', ' ').trim();
  }

  String? _extractPhonetic(String text) {
    final bracketMatch = _phoneticBracketsRegex.firstMatch(text);
    if (bracketMatch != null) return bracketMatch.group(1)?.trim();
    final slashMatch = _phoneticSlashRegex.firstMatch(text);
    if (slashMatch != null) return slashMatch.group(1)?.trim();
    final starMatch = _phoneticStarRegex.firstMatch(text);
    if (starMatch != null) return starMatch.group(1)?.trim();
    return null;
  }

  String _extractChineseText(String text) {
    final parts = text.split(RegExp(r'[;；,，]'));
    final chineseParts = <String>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (_chineseCharRegex.hasMatch(trimmed)) {
        final withoutCodes = trimmed.replaceAll(RegExp(r'[-]\w+$'), '').trim();
        if (withoutCodes.isNotEmpty) {
          chineseParts.add(withoutCodes);
        }
      }
    }
    return chineseParts.join('；');
  }

  Future<void> dispose() async {
    await _close();
    _currentIfoPath = null;
    _isLoaded = false;
  }
}
