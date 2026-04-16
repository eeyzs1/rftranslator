// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translation_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TranslationHistoryAdapter extends TypeAdapter<TranslationHistory> {
  @override
  final int typeId = 2;

  @override
  TranslationHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TranslationHistory()
      ..sourceText = fields[0] as String
      ..targetText = fields[1] as String
      ..sourceLangIndex = fields[2] as int
      ..targetLangIndex = fields[3] as int
      ..translatedAt = fields[4] as DateTime;
  }

  @override
  void write(BinaryWriter writer, TranslationHistory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.sourceText)
      ..writeByte(1)
      ..write(obj.targetText)
      ..writeByte(2)
      ..write(obj.sourceLangIndex)
      ..writeByte(3)
      ..write(obj.targetLangIndex)
      ..writeByte(4)
      ..write(obj.translatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
