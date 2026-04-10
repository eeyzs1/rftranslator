import 'package:hive/hive.dart';
import 'package:rfdictionary/features/translation/domain/entities/language.dart';

part 'translation_history.g.dart';

@HiveType(typeId: 2)
class TranslationHistory extends HiveObject {
  @HiveField(0)
  late String sourceText;

  @HiveField(1)
  late String targetText;

  @HiveField(2)
  late int sourceLangIndex;

  @HiveField(3)
  late int targetLangIndex;

  @HiveField(4)
  late DateTime translatedAt;

  @HiveField(5)
  late bool isFavorite;

  TranslationHistory();

  TranslationHistory.create({
    required this.sourceText,
    required this.targetText,
    required Language sourceLang,
    required Language targetLang,
    required this.translatedAt,
    this.isFavorite = false,
  })  : sourceLangIndex = sourceLang.index,
        targetLangIndex = targetLang.index;

  Language get sourceLang => Language.values[sourceLangIndex];
  Language get targetLang => Language.values[targetLangIndex];
}
