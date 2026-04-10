import 'package:hive/hive.dart';

part 'favorite_word.g.dart';

@HiveType(typeId: 0)
class FavoriteWord extends HiveObject {
  @HiveField(0)
  late String word;

  @HiveField(1)
  late String briefDefinition;

  @HiveField(2)
  late DateTime addedAt;

  FavoriteWord();

  FavoriteWord.create({
    required this.word,
    required this.briefDefinition,
    required this.addedAt,
  });
}
