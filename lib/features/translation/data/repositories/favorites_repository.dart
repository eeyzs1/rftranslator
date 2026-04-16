import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:rftranslator/features/translation/data/models/translation_history.dart';
import 'package:rftranslator/features/translation/domain/entities/language.dart';

class FavoritesRepository {
  static const String _boxName = 'translation_favorites';
  Box<TranslationHistory>? _box;

  Future<Box<TranslationHistory>> get box async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<TranslationHistory>(_boxName);
    }
    return _box!;
  }

  Future<bool> isFavorite(String sourceText, Language sourceLang, Language targetLang) async {
    final favBox = await box;
    return favBox.values.any((h) =>
        h.sourceText == sourceText &&
        h.sourceLang == sourceLang &&
        h.targetLang == targetLang);
  }

  Future<void> addFavorite(TranslationHistory entry) async {
    final favBox = await box;

    final exists = favBox.values.any((h) =>
        h.sourceText == entry.sourceText &&
        h.sourceLang == entry.sourceLang &&
        h.targetLang == entry.targetLang);

    if (!exists) {
      await favBox.add(entry);
      debugPrint('[FavRepo] Added favorite: "${entry.sourceText}"');
    }
  }

  Future<void> removeFavorite(String sourceText, Language sourceLang, Language targetLang) async {
    final favBox = await box;
    final toRemove = favBox.values.where((h) =>
        h.sourceText == sourceText &&
        h.sourceLang == sourceLang &&
        h.targetLang == targetLang).toList();

    for (final item in toRemove) {
      await item.delete();
    }
    debugPrint('[FavRepo] Removed favorite: "$sourceText" (${toRemove.length} items)');
  }

  Future<List<TranslationHistory>> getAll() async {
    final favBox = await box;
    final all = favBox.values.toList();
    all.sort((a, b) => b.translatedAt.compareTo(a.translatedAt));
    return all;
  }

  Future<void> delete(TranslationHistory entry) async {
    await entry.delete();
  }

  Future<void> clearAll() async {
    final favBox = await box;
    await favBox.clear();
  }
}
