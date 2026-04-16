// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_word.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FavoriteWordAdapter extends TypeAdapter<FavoriteWord> {
  @override
  final int typeId = 0;

  @override
  FavoriteWord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FavoriteWord()
      ..word = fields[0] as String
      ..briefDefinition = fields[1] as String
      ..addedAt = fields[2] as DateTime;
  }

  @override
  void write(BinaryWriter writer, FavoriteWord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.word)
      ..writeByte(1)
      ..write(obj.briefDefinition)
      ..writeByte(2)
      ..write(obj.addedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteWordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
