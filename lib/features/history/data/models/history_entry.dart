import 'package:hive/hive.dart';

part 'history_entry.g.dart';

@HiveType(typeId: 1)
class HistoryEntry extends HiveObject {
  @HiveField(0)
  late String word;

  @HiveField(1)
  late DateTime lastSearchedAt;

  @HiveField(2)
  late int searchCount;

  HistoryEntry();

  HistoryEntry.create({
    required this.word,
    required this.lastSearchedAt,
    required this.searchCount,
  });
}
