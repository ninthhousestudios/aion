import 'dart:io';

import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

import 'package:chart_db/src/tools/import_charts.dart';

import 'test_helpers.dart';

void main() {
  late ChartDatabase db;
  late ChartRepository repo;

  setUp(() {
    db = ChartDatabase();
    repo = ChartRepository(db.db);
  });

  tearDown(() => db.close());

  test('imports a single toml chart file', () {
    final chartFiles = Directory('/home/josh/charts/mine')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.toml'))
        .toList();
    if (chartFiles.isEmpty) {
      markTestSkipped('No .toml chart files available');
      return;
    }

    final result = handleImportCharts({'path': chartFiles.first.path}, repo);

    expect(result.isError, isFalse);
    final data = result.structuredContent!;
    expect(data['imported'], 1);
    final results = data['results'] as List;
    expect(results.first['chart_id'], isA<String>());
    expect(results.first['name'], isA<String>());
  });

  test('imports directory of chart files', () {
    final result = handleImportCharts({
      'path': '/home/josh/charts/mine',
      'extensions': ['.toml'],
    }, repo);

    expect(result.isError, isFalse);
    final data = result.structuredContent!;
    expect(data['imported'], greaterThan(0));
  });

  test('re-import same file creates second entry (duplicates allowed)', () {
    final chartFiles = Directory('/home/josh/charts/mine')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.toml'))
        .toList();
    if (chartFiles.isEmpty) {
      markTestSkipped('No .toml chart files available');
      return;
    }

    final path = chartFiles.first.path;
    handleImportCharts({'path': path}, repo);
    final result = handleImportCharts({'path': path}, repo);

    expect(result.isError, isFalse);
    expect(result.structuredContent!['imported'], 1);
  });

  test('returns error for missing path', () {
    final result = handleImportCharts({}, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('path'));
  });

  test('returns error for empty path', () {
    final result = handleImportCharts({'path': ''}, repo);

    expect(result.isError, isTrue);
  });

  test('returns error for non-string path', () {
    final result = handleImportCharts({'path': 42}, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('path'));
  });

  test('returns error for nonexistent path', () {
    final result = handleImportCharts({
      'path': '/no/such/path/chart.toml',
    }, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('not found'));
  });

  test('returns error for non-array extensions', () {
    final result = handleImportCharts({
      'path': '/home/josh/charts/mine',
      'extensions': '.toml',
    }, repo);

    expect(result.isError, isTrue);
    expect(errorText(result), contains('extensions'));
  });
}
