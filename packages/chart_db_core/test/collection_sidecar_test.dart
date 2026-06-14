import 'dart:convert';
import 'dart:io';

import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('collection_sidecar_test_');
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  test('load returns empty list when file missing', () {
    expect(CollectionSidecar.load(tmpDir.path), isEmpty);
  });

  test('create and load round-trip', () {
    final id = CollectionSidecar.create(tmpDir.path, 'Natal', note: 'personal');

    final loaded = CollectionSidecar.load(tmpDir.path);
    expect(loaded, hasLength(1));
    expect(loaded.first.id, id);
    expect(loaded.first.name, 'Natal');
    expect(loaded.first.note, 'personal');
    expect(loaded.first.charts, isEmpty);
  });

  test('rename updates name on disk', () {
    final id = CollectionSidecar.create(tmpDir.path, 'Old');
    CollectionSidecar.rename(tmpDir.path, id, 'New');

    final loaded = CollectionSidecar.load(tmpDir.path);
    expect(loaded.first.name, 'New');
  });

  test('rename throws for missing id', () {
    expect(
      () => CollectionSidecar.rename(tmpDir.path, 'missing', 'X'),
      throwsStateError,
    );
  });

  test('delete removes collection from disk', () {
    final id = CollectionSidecar.create(tmpDir.path, 'Doomed');
    CollectionSidecar.delete(tmpDir.path, id);

    expect(CollectionSidecar.load(tmpDir.path), isEmpty);
  });

  test('addChart and removeChart', () {
    final id = CollectionSidecar.create(tmpDir.path, 'Favorites');

    CollectionSidecar.addChart(tmpDir.path, id, 'gandhi.toml');
    CollectionSidecar.addChart(tmpDir.path, id, 'einstein.toml');

    var loaded = CollectionSidecar.load(tmpDir.path);
    expect(loaded.first.charts, ['gandhi.toml', 'einstein.toml']);

    CollectionSidecar.removeChart(tmpDir.path, id, 'gandhi.toml');

    loaded = CollectionSidecar.load(tmpDir.path);
    expect(loaded.first.charts, ['einstein.toml']);
  });

  test('addChart is idempotent', () {
    final id = CollectionSidecar.create(tmpDir.path, 'Dupes');
    CollectionSidecar.addChart(tmpDir.path, id, 'chart.toml');
    CollectionSidecar.addChart(tmpDir.path, id, 'chart.toml');

    final loaded = CollectionSidecar.load(tmpDir.path);
    expect(loaded.first.charts, ['chart.toml']);
  });

  test('save writes valid JSON', () {
    CollectionSidecar.create(tmpDir.path, 'Test');
    final raw = File(
      '${tmpDir.path}/${CollectionSidecar.fileName}',
    ).readAsStringSync();
    final decoded = jsonDecode(raw);
    expect(decoded, isList);
    expect((decoded as List).first['name'], 'Test');
  });

  test('multiple collections coexist', () {
    CollectionSidecar.create(tmpDir.path, 'A');
    CollectionSidecar.create(tmpDir.path, 'B');
    CollectionSidecar.create(tmpDir.path, 'C');

    final loaded = CollectionSidecar.load(tmpDir.path);
    expect(loaded, hasLength(3));
    expect(loaded.map((c) => c.name), containsAll(['A', 'B', 'C']));
  });
}
