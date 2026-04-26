import 'dart:io';

import 'package:aion/import/chart_importer.dart';
import 'package:test/test.dart';

void main() {
  final fixtureDir = '${Directory.current.path}/test/import/fixtures';

  group('dateTimeToJd', () {
    test('J2000.0 epoch: 2000-01-01T12:00:00Z = JD 2451545.0', () {
      final dt = DateTime.utc(2000, 1, 1, 12, 0, 0);
      final jd = ChartImporter.dateTimeToJd(dt);
      expect(jd, closeTo(2451545.0, 0.0001));
    });

    test('Unix epoch: 1970-01-01T00:00:00Z = JD 2440587.5', () {
      final dt = DateTime.utc(1970, 1, 1, 0, 0, 0);
      final jd = ChartImporter.dateTimeToJd(dt);
      expect(jd, closeTo(2440587.5, 0.0001));
    });

    test('known date: 1985-02-17T06:00:00Z', () {
      // JD 2446113.75 (Feb is month <= 2, exercises the y-1/m+12 branch)
      final dt = DateTime.utc(1985, 2, 17, 6, 0, 0);
      final jd = ChartImporter.dateTimeToJd(dt);
      expect(jd, closeTo(2446113.75, 0.0001));
    });
  });

  group('importFile', () {
    final importer = ChartImporter();

    test('imports .toml fixture with correct fields', () {
      final chart = importer.importFile('$fixtureDir/test-chart.toml');

      expect(chart.name, 'Test Person');
      expect(chart.lat, closeTo(40.7128, 0.001));
      expect(chart.lon, closeTo(-74.006, 0.001));
      expect(chart.alt, closeTo(10.0, 0.1));
      expect(chart.gender, 'male');
      expect(chart.placename, 'New York, NY');
      expect(chart.country, 'USA');
      expect(chart.utcOffset, -5.0);
      // The toml fixture has JD 2451545.0 (J2000.0) — the importer
      // re-derives JD from utcDateTime, which round-trips through
      // the JD → DateTime → JD conversion. Check it's close.
      expect(chart.jd, closeTo(2451545.0, 0.001));
      expect(chart.sourcePath, contains('test-chart.toml'));
    });

    test('imports .json fixture with correct fields', () {
      final chart = importer.importFile('$fixtureDir/test-chart.json');

      expect(chart.name, 'Jane Doe');
      expect(chart.lat, closeTo(51.5074, 0.001));
      expect(chart.lon, closeTo(-0.1278, 0.001));
      expect(chart.alt, 0); // no altitude in JSON format
      expect(chart.gender, 'female');
      expect(chart.placename, 'London');
      expect(chart.country, 'UK');
      expect(chart.utcOffset, 1.0);
      expect(chart.dstOffset, 1.0);
      expect(chart.notes, 'Test chart');
      expect(chart.rodden, 'AA');
      // 1990-06-15T14:30:00 local, UTC offset 1h + DST 1h = UTC 12:30
      // JD for 1990-06-15T12:30:00Z
      final expectedJd = ChartImporter.dateTimeToJd(
        DateTime.utc(1990, 6, 15, 12, 30, 0),
      );
      expect(chart.jd, closeTo(expectedJd, 0.001));
    });

    test('throws on unsupported extension', () {
      final tmpFile = File('$fixtureDir/bad.xyz')
        ..createSync()
        ..writeAsStringSync('garbage');
      addTearDown(() => tmpFile.deleteSync());

      expect(
        () => importer.importFile(tmpFile.path),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('importDirectory', () {
    final importer = ChartImporter();

    test('imports all charts in fixture directory', () {
      final charts = importer.importDirectory(fixtureDir);
      // We have at least the .toml and .json fixtures
      expect(charts.length, greaterThanOrEqualTo(2));
      final names = charts.map((c) => c.name).toSet();
      expect(names, contains('Test Person'));
      expect(names, contains('Jane Doe'));
    });

    test('filters by extension', () {
      final charts = importer.importDirectory(
        fixtureDir,
        extensions: ['.toml'],
      );
      expect(charts.length, 1);
      expect(charts.first.name, 'Test Person');
    });

    test('collects errors for bad files', () {
      // Create a corrupt .json file
      final badFile = File('$fixtureDir/corrupt.json')
        ..createSync()
        ..writeAsStringSync('not valid json {{{');
      addTearDown(() => badFile.deleteSync());

      final errors = <(String, Object)>[];
      final charts = importer.importDirectory(
        fixtureDir,
        extensions: ['.json'],
        errors: errors,
      );
      // Should still import the good .json
      expect(charts.any((c) => c.name == 'Jane Doe'), isTrue);
      // Should have one error for corrupt.json
      expect(errors.length, 1);
      expect(errors.first.$1, contains('corrupt.json'));
    });

    test('throws on non-existent directory', () {
      expect(
        () => importer.importDirectory('/tmp/nonexistent-dir-xyz'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
