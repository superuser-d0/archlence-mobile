// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
abstract class _$ArchlenceDatabase extends GeneratedDatabase {
  _$ArchlenceDatabase(QueryExecutor e) : super(e);
  $ArchlenceDatabaseManager get managers => $ArchlenceDatabaseManager(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [];
}

class $ArchlenceDatabaseManager {
  final _$ArchlenceDatabase _db;
  $ArchlenceDatabaseManager(this._db);
}
