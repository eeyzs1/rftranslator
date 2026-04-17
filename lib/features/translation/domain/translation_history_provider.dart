import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rftranslator/features/translation/data/models/translation_history.dart';
import 'package:rftranslator/features/translation/data/repositories/history_repository.dart';
import 'package:rftranslator/features/translation/data/repositories/favorites_repository.dart';

part 'translation_history_provider.g.dart';

@riverpod
HistoryRepository historyRepository(HistoryRepositoryRef ref) {
  return HistoryRepository();
}

@riverpod
FavoritesRepository favoritesRepository(FavoritesRepositoryRef ref) {
  return FavoritesRepository();
}

@riverpod
class TranslationHistoryList extends _$TranslationHistoryList {
  @override
  Future<List<TranslationHistory>> build() async {
    final repo = ref.watch(historyRepositoryProvider);
    return await repo.getAll();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteEntry(TranslationHistory entry) async {
    final repo = ref.watch(historyRepositoryProvider);
    await repo.delete(entry);
    await refresh();
  }

  Future<void> clearAll() async {
    final repo = ref.watch(historyRepositoryProvider);
    await repo.clearAll();
    await refresh();
  }
}

@riverpod
class TranslationFavoriteList extends _$TranslationFavoriteList {
  @override
  Future<List<TranslationHistory>> build() async {
    final repo = ref.watch(favoritesRepositoryProvider);
    return await repo.getAll();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> toggleFavorite(TranslationHistory entry) async {
    final favRepo = ref.watch(favoritesRepositoryProvider);
    final isFav = await favRepo.isFavorite(entry.sourceText, entry.sourceLang, entry.targetLang);

    if (isFav) {
      await favRepo.removeFavorite(entry.sourceText, entry.sourceLang, entry.targetLang);
    } else {
      await favRepo.addFavorite(entry);
    }
    await refresh();
  }

  Future<void> deleteEntry(TranslationHistory entry) async {
    final repo = ref.watch(favoritesRepositoryProvider);
    await repo.delete(entry);
    await refresh();
  }

  Future<void> clearAll() async {
    final repo = ref.watch(favoritesRepositoryProvider);
    await repo.clearAll();
    await refresh();
  }
}
