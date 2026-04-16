// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation_history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$historyRepositoryHash() => r'ff88f4149c4edef92ed7b85e2ea310641ff866c5';

/// See also [historyRepository].
@ProviderFor(historyRepository)
final historyRepositoryProvider =
    AutoDisposeProvider<HistoryRepository>.internal(
  historyRepository,
  name: r'historyRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$historyRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef HistoryRepositoryRef = AutoDisposeProviderRef<HistoryRepository>;
String _$favoritesRepositoryHash() =>
    r'1cddad067922eafe25b0850b0bb6a4c4f8e0a237';

/// See also [favoritesRepository].
@ProviderFor(favoritesRepository)
final favoritesRepositoryProvider =
    AutoDisposeProvider<FavoritesRepository>.internal(
  favoritesRepository,
  name: r'favoritesRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$favoritesRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FavoritesRepositoryRef = AutoDisposeProviderRef<FavoritesRepository>;
String _$translationHistoryListHash() =>
    r'df0c9da9ab394a4dc06497bf9c4224557da138ea';

/// See also [TranslationHistoryList].
@ProviderFor(TranslationHistoryList)
final translationHistoryListProvider = AutoDisposeAsyncNotifierProvider<
    TranslationHistoryList, List<TranslationHistory>>.internal(
  TranslationHistoryList.new,
  name: r'translationHistoryListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$translationHistoryListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TranslationHistoryList
    = AutoDisposeAsyncNotifier<List<TranslationHistory>>;
String _$translationFavoriteListHash() =>
    r'1133a5769bbb833e2d3a301e0626496c7db8de3b';

/// See also [TranslationFavoriteList].
@ProviderFor(TranslationFavoriteList)
final translationFavoriteListProvider = AutoDisposeAsyncNotifierProvider<
    TranslationFavoriteList, List<TranslationHistory>>.internal(
  TranslationFavoriteList.new,
  name: r'translationFavoriteListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$translationFavoriteListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TranslationFavoriteList
    = AutoDisposeAsyncNotifier<List<TranslationHistory>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
