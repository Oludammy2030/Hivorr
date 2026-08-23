import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hivorr/core/database/adapters/hive_storage_engine.dart';
import 'package:hivorr/core/database/local_store.dart';
import 'package:hivorr/core/database/storage_engine.dart';
import 'package:hivorr/core/database/storage_exception.dart';

/// Sample model for typed [LocalStore] round-trip testing.
class SampleModel {
  const SampleModel({required this.id, required this.name});
  final int id;
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};
  factory SampleModel.fromJson(Map<String, dynamic> json) =>
      SampleModel(id: json['id'] as int, name: json['name'] as String);
}

void main() {
  late Directory tempDir;
  late HiveStorageEngine engine;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hivorr_db_test');
    engine = HiveStorageEngine();
    await engine.initialize(basePath: tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('HiveStorageEngine — single ops', () {
    const String box = 'single_ops_box';

    setUp(() async => engine.clearBox(box));

    test('put then get returns the stored map', () async {
      await engine.put(box, 'k1', <String, dynamic>{'a': 1, 'b': 'two'});
      final Map<String, dynamic>? result = await engine.get(box, 'k1');
      expect(result, <String, dynamic>{'a': 1, 'b': 'two'});
    });

    test('get on missing key returns null', () async {
      expect(await engine.get(box, 'absent'), isNull);
    });

    test('delete removes a key', () async {
      await engine.put(box, 'k2', <String, dynamic>{'x': 1});
      await engine.delete(box, 'k2');
      expect(await engine.get(box, 'k2'), isNull);
    });

    test('clearBox empties the box but not others', () async {
      await engine.put(box, 'k3', <String, dynamic>{'v': 1});
      await engine.put('other_box', 'k3', <String, dynamic>{'v': 2});
      await engine.clearBox(box);
      expect(await engine.get(box, 'k3'), isNull);
      expect(await engine.get('other_box', 'k3'), <String, dynamic>{'v': 2});
    });

    test('keys returns all present keys', () async {
      await engine.put(box, 'ka', <String, dynamic>{});
      await engine.put(box, 'kb', <String, dynamic>{});
      final List<String> keys = await engine.keys(box);
      expect(keys, containsAll(<String>['ka', 'kb']));
      expect(keys.length, 2);
    });
  });

  group('HiveStorageEngine — box isolation', () {
    const String boxA = 'isolation_a';
    const String boxB = 'isolation_b';

    setUp(() async {
      await engine.clearBox(boxA);
      await engine.clearBox(boxB);
    });

    test('same key in different boxes is independent', () async {
      await engine.put(boxA, 'same', <String, dynamic>{'v': 'a'});
      await engine.put(boxB, 'same', <String, dynamic>{'v': 'b'});
      expect(await engine.get(boxA, 'same'),
          <String, dynamic>{'v': 'a'});
      expect(await engine.get(boxB, 'same'),
          <String, dynamic>{'v': 'b'});
    });
  });

  group('HiveStorageEngine — writeBatch atomicity', () {
    const String box = 'batch_box';

    setUp(() async => engine.clearBox(box));

    test('applies all operations', () async {
      await engine.put(box, 'seed', <String, dynamic>{'v': 0});
      await engine.writeBatch(box, <WriteOp>[
        const PutOp('a', <String, dynamic>{'v': 1}),
        const PutOp('b', <String, dynamic>{'v': 2}),
        const DeleteOp('seed'),
      ]);
      expect(await engine.get(box, 'a'), <String, dynamic>{'v': 1});
      expect(await engine.get(box, 'b'), <String, dynamic>{'v': 2});
      expect(await engine.get(box, 'seed'), isNull);
    });

    test('mid-batch failure rolls back affected keys', () async {
      await engine.put(box, 'protected', <String, dynamic>{'v': 1});
      // A value containing a closure is not storable by Hive and forces a
      // mid-batch failure, exercising the rollback path.
      final List<WriteOp> ops = <WriteOp>[
        PutOp('protected', <String, dynamic>{'v': 999}),
        PutOp('bad', <String, dynamic>{'fn': () {}}),
      ];
      await expectLater(
        engine.writeBatch(box, ops),
        throwsA(isA<StorageException>()),
      );
      // The pre-batch value must be preserved (rollback).
      expect(await engine.get(box, 'protected'), <String, dynamic>{'v': 1});
    });
  });

  group('LocalStore — typed access', () {
    const String box = 'local_store_box';

    setUp(() async => engine.clearBox(box));

    test('write then read round-trips a typed model', () async {
      final LocalStore store = LocalStore(engine);
      const SampleModel model = SampleModel(id: 7, name: 'Ada');
      await store.write<SampleModel>(
        box,
        'm1',
        model,
        (SampleModel m) => m.toJson(),
      );
      final SampleModel? read = await store.read<SampleModel>(
        box,
        'm1',
        SampleModel.fromJson,
      );
      expect(read, isNotNull);
      expect(read?.id, 7);
      expect(read?.name, 'Ada');
    });

    test('read on missing key returns null', () async {
      final LocalStore store = LocalStore(engine);
      expect(
        await store.read<SampleModel>(box, 'ghost', SampleModel.fromJson),
        isNull,
      );
    });
  });
}
