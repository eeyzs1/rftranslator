import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:rftranslator/features/translation/data/models/translation_history.dart';

class HistoryRepository {
  static const String _boxName = 'translation_history';
  Box<TranslationHistory>? _box;

  Future<Box<TranslationHistory>> get box async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<TranslationHistory>(_boxName);
    }
    return _box!;
  }

  Future<void> addEntry(TranslationHistory entry) async {
    final historyBox = await box;

    final existingIndex = historyBox.values.toList().indexWhere((h) =>
        h.sourceText == entry.sourceText &&
        h.sourceLang == entry.sourceLang &&
        h.targetLang == entry.targetLang,);

    if (existingIndex >= 0) {
      final existing = historyBox.getAt(existingIndex);
      if (existing != null) {
        existing.targetText = entry.targetText;
        existing.translatedAt = entry.translatedAt;
        await existing.save();
        debugPrint('[HistoryRepo] Updated existing entry: "${entry.sourceText}"');
      }
    } else {
      await historyBox.add(entry);
      debugPrint('[HistoryRepo] Added new entry: "${entry.sourceText}"');
    }
  }

  Future<List<TranslationHistory>> getAll() async {
    final historyBox = await box;
    final all = historyBox.values.toList();
    all.sort((a, b) => b.translatedAt.compareTo(a.translatedAt));
    return all;
  }

  Future<void> delete(TranslationHistory entry) async {
    await entry.delete();
  }

  Future<void> clearAll() async {
    final historyBox = await box;
    await historyBox.clear();
  }
}
