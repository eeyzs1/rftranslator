import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:rftranslator/core/utils/platform_utils.dart';
import 'package:rftranslator/features/dictionary/domain/dictionary_repository.dart';
import 'package:rftranslator/features/dictionary/domain/entities/word_entry.dart';

class DictionaryLocalDataSource implements DictionaryRepository {
  Database? _db;
  static const String _defaultDbName = 'stardict.db';
  static const int _cacheSizeDesktop = 32768;
  static const int _cacheSizeMobile = 4096;
  String? _customDbPath;

  String? _cachedTableName;
  String? _cachedWordColumn;
  String? _cachedTranslationColumn;
  int? _cachedDbPathHash;

  void setCustomPath(String? path) {
    _customDbPath = path;
    _db = null;
    _cachedTableName = null;
    _cachedWordColumn = null;
    _cachedTranslationColumn = null;
    _cachedDbPathHash = null;
  }

  @override
  Future<void> setPath(String? path) async {
    debugPrint('[SQLite] setPath: $path (previous: $_customDbPath)');
    setCustomPath(path);
  }

  Future<Database> get db async {
    _db ??= await _openDatabase();
    return _db!;
  }

  static Stream<double> initDatabaseIfNeeded() async* {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, _defaultDbName);

    if (File(dbPath).existsSync()) {
      try {
        final db = await openDatabase(dbPath, readOnly: true);
        final result = await db.rawQuery('PRAGMA integrity_check');
        await db.close();
        if (result.first.values.first == 'ok') {
          yield 1.0;
          return;
        }
      } catch (_) {
      }
      await File(dbPath).delete();
    }

    try {
      yield 0.0;
      final data = await rootBundle.load('assets/$_defaultDbName');
      final bytes = data.buffer.asUint8List();
      final total = bytes.length;
      const chunkSize = 65536;
      int written = 0;

      final sink = File(dbPath).openWrite(mode: FileMode.write);
      while (written < total) {
        final end = (written + chunkSize).clamp(0, total);
        sink.add(bytes.sublist(written, end));
        written = end;
        yield written / total;
        await Future.delayed(const Duration(milliseconds: 1));
      }
      await sink.flush();
      await sink.close();
      yield 1.0;
    } catch (e) {
      yield 1.0;
    }
  }

  Future<Database> _openDatabase() async {
    String dbPath;

    if (_customDbPath != null && File(_customDbPath!).existsSync()) {
      dbPath = _customDbPath!;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dbPath = path.join(dir.path, _defaultDbName);
    }

    debugPrint('[SQLite] _openDatabase: dbPath=$dbPath, exists=${File(dbPath).existsSync()}');

    if (!File(dbPath).existsSync()) {
      debugPrint('[SQLite]   DB file does not exist!');
      throw StateError('\u8BCD\u5178\u6570\u636E\u5E93\u6587\u4EF6\u4E0D\u5B58\u5728');
    }

    return openDatabase(
      dbPath,
      readOnly: true,
      onOpen: (db) async {
        final cacheSize = PlatformUtils.isDesktop ? _cacheSizeDesktop : _cacheSizeMobile;
        await db.execute('PRAGMA cache_size = $cacheSize');
      },
    );
  }

  Future<bool> isDatabaseAvailable() async {
    try {
      final database = await db;
      await database.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      return false;
    }
  }

  String _cleanDefinition(String text) {
    String cleaned = text;

    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\uFF08[^\uFF09]*\uFF09'), '');

    cleaned = cleaned.replaceAll(RegExp(r'^[a-zA-Z]+\u7684*$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^.*\u7684'), '');

    cleaned = cleaned.replaceAll(RegExp(r'[a-z]+\.'), '');

    final chineseMatch = RegExp(r'[\u4e00-\u9fa5]+(?:\u3001[\u4e00-\u9fa5]+)*').firstMatch(cleaned);
    if (chineseMatch != null) {
      cleaned = chineseMatch.group(0)!;
    }

    cleaned = cleaned.trim();

    return cleaned;
  }

  @override
  Future<WordEntry?> getWord(String word) async {
    try {
      final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase().trim();
      debugPrint('[SQLite] getWord: input="$word", cleanWord="$cleanWord"');
      if (cleanWord.isEmpty) {
        debugPrint('[SQLite]   cleanWord is empty, returning null');
        return null;
      }

      final database = await db;
      await _ensureSchemaCached(database);

      debugPrint('[SQLite]   schema: tableName=$_cachedTableName, wordColumn=$_cachedWordColumn, transColumn=$_cachedTranslationColumn, customPath=$_customDbPath');
      if (_cachedTableName == null) {
        debugPrint('[SQLite]   tableName is null, returning null');
        return null;
      }

      final results = await database.query(
        _cachedTableName!,
        where: '$_cachedWordColumn = ?',
        whereArgs: [cleanWord],
        limit: 1,
      );

      debugPrint('[SQLite]   query result count: ${results.length}');
      if (results.isEmpty) return null;

      final row = results.first;
      debugPrint('[SQLite]   row keys: ${row.keys.toList()}');

      final definitions = <Definition>[];
      if (row.containsKey(_cachedTranslationColumn!) && row[_cachedTranslationColumn!] != null) {
        final trans = row[_cachedTranslationColumn!] as String;
        debugPrint('[SQLite]   raw translation (${trans.length} chars): "${trans.substring(0, trans.length > 200 ? 200 : trans.length)}"');
        final parts = trans.split('\n');
        for (final part in parts) {
          if (part.trim().isNotEmpty) {
            final cleaned = _cleanDefinition(part.trim());
            debugPrint('[SQLite]     part="${part.trim().substring(0, part.trim().length > 80 ? 80 : part.trim().length)}" -> cleaned="$cleaned"');
            if (cleaned.isNotEmpty) {
              definitions.add(Definition(
                partOfSpeech: '',
                chinese: cleaned,
              ),);
            }
          }
        }
      } else {
        debugPrint('[SQLite]   no translation column found or value is null, key=$_cachedTranslationColumn');
      }

      if (definitions.isEmpty) {
        debugPrint('[SQLite]   definitions empty after first pass, trying fallback');
        for (final entry in row.entries) {
          if (entry.value is String && (entry.value as String).isNotEmpty) {
            final cleaned = _cleanDefinition(entry.value as String);
            if (cleaned.isNotEmpty) {
              debugPrint('[SQLite]   fallback found in column "${entry.key}": "$cleaned"');
              definitions.add(Definition(
                partOfSpeech: '',
                chinese: cleaned,
              ),);
              break;
            }
          }
        }
      }

      if (definitions.isEmpty && RegExp(r'^[\u4e00-\u9fa5]+$').hasMatch(cleanWord)) {
        definitions.add(Definition(
          partOfSpeech: '',
          chinese: cleanWord,
        ),);
      }

      debugPrint('[SQLite]   final definitions count: ${definitions.length}');
      return WordEntry(
        word: row[_cachedWordColumn!] as String? ?? word,
        phonetic: null,
        definitions: definitions,
        examples: [],
        exchanges: {},
      );
    } catch (e, stackTrace) {
      debugPrint('[SQLite]   EXCEPTION: $e');
      debugPrint('[SQLite]   StackTrace: $stackTrace');
      return null;
    }
  }

  Future<void> _ensureSchemaCached(Database database) async {
    final currentPathHash = _customDbPath?.hashCode ?? 0;
    if (_cachedDbPathHash == currentPathHash && _cachedTableName != null) {
      return;
    }

    final tables = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    if (tables.isEmpty) {
      _cachedDbPathHash = currentPathHash;
      _cachedTableName = null;
      return;
    }

    final bool hasWordsTable = tables.any((t) => t['name'] == 'words');
    _cachedTableName = hasWordsTable ? 'words' : (tables.first['name'] as String);

    final schema = await database.rawQuery('PRAGMA table_info($_cachedTableName)');
    _cachedWordColumn = 'word';
    _cachedTranslationColumn = 'translation';

    for (var col in schema) {
      final colName = col['name'] as String;
      if (colName.toLowerCase().contains('word')) {
        _cachedWordColumn = colName;
      }
      if (colName.toLowerCase().contains('translation') ||
          colName.toLowerCase().contains('trans') ||
          colName.toLowerCase() == 'zh' ||
          colName.toLowerCase() == 'chinese') {
        _cachedTranslationColumn = colName;
      }
    }

    _cachedDbPathHash = currentPathHash;
  }

  Future<List<String>> getSuggestions(String prefix, {int limit = 8}) async {
    if (prefix.isEmpty) return [];

    try {
      final database = await db;
      final results = await database.query(
        'words',
        columns: ['word'],
        where: 'word LIKE ?',
        whereArgs: ['${prefix.toLowerCase()}%'],
        orderBy: 'frq DESC, bnc DESC',
        limit: limit,
      );

      return results.map((r) => r['word'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getExamples(int wordId, {int limit = 10}) async {
    try {
      final database = await db;
      return database.query(
        'examples',
        where: 'word_id = ?',
        whereArgs: [wordId],
        limit: limit,
      );
    } catch (e) {
      return [];
    }
  }
}
