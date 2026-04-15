import 'package:flutter/foundation.dart';
import 'package:rftranslator/features/dictionary/data/datasources/stardict_native_datasource.dart';
import 'package:rftranslator/features/dictionary/domain/dictionary_repository.dart';
import 'package:rftranslator/features/dictionary/domain/entities/word_entry.dart';

class StarDictDataSource implements DictionaryRepository {
  final StarDictNativeDataSource _nativeDataSource;
  bool _isDictionaryLoaded = false;
  bool _isLoading = false;
  String? _lastPath;

  StarDictDataSource({required StarDictNativeDataSource nativeDataSource})
      : _nativeDataSource = nativeDataSource;

  bool get isDictionaryLoaded => _isDictionaryLoaded;
  bool get isLoading => _isLoading;

  @override
  Future<void> setPath(String? path) async {
    if (path == _lastPath && _isDictionaryLoaded) {
      debugPrint('[StarDict] setPath: $path (already loaded, skipping)');
      return;
    }
    debugPrint('[StarDict] setPath: $path (wasLoaded: $_isDictionaryLoaded)');
    await _nativeDataSource.setPath(path);
    _isDictionaryLoaded = false;
    _lastPath = path;
  }

  Future<bool> loadDictionary() async {
    _isLoading = true;
    final success = await _nativeDataSource.loadDictionary();
    _isLoading = false;
    if (success) {
      _isDictionaryLoaded = true;
    }
    return success;
  }

  @override
  Future<WordEntry?> getWord(String word) async {
    if (!_isDictionaryLoaded) {
      debugPrint('[StarDict] getWord: "$word", loading dictionary...');
      final loaded = await loadDictionary();
      debugPrint('[StarDict]   loadDictionary result: $loaded');
      if (!loaded) return null;
    }

    try {
      final result = await _nativeDataSource.getWord(word);
      debugPrint('[StarDict]   result: ${result != null ? "found ${result.definitions.length} definitions" : "not found"}');
      return result;
    } catch (e, stackTrace) {
      debugPrint('[StarDict]   EXCEPTION: $e');
      debugPrint('[StarDict]   StackTrace: $stackTrace');
      return null;
    }
  }
}
