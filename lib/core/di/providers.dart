import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rftranslator/features/dictionary/data/datasources/dictionary_local_datasource.dart';
import 'package:rftranslator/features/dictionary/data/datasources/mdict_datasource.dart';
import 'package:rftranslator/features/dictionary/data/datasources/stardict_datasource.dart';
import 'package:rftranslator/features/dictionary/data/datasources/stardict_native_datasource.dart';

final dictionaryLocalDataSourceProvider = Provider<DictionaryLocalDataSource>((ref) {
  return DictionaryLocalDataSource();
});

final starDictDataSourceProvider = Provider<StarDictDataSource>((ref) {
  final nativeSource = ref.watch(starDictNativeDataSourceProvider);
  return StarDictDataSource(nativeDataSource: nativeSource);
});

final starDictNativeDataSourceProvider = Provider<StarDictNativeDataSource>((ref) {
  return StarDictNativeDataSource();
});

final mdictDataSourceProvider = Provider<MDictDataSource>((ref) {
  return MDictDataSource();
});
