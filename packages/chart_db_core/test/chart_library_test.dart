import 'dart:io';

import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;
  late ChartLibrary library;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('chart_library_test_');
    library = ChartLibrary(tmpDir.path);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  final doc = ChartDoc(
    jd: 2447679.3388888887,
    lat: 40.7128,
    lon: -74.0060,
    name: 'Jane Doe',
    utcOffset: -5,
    dstOffset: 0,
    timezone: 'EST',
  );

  group('listChartPaths', () {
    test('returns .toml files only', () {
      File(
        '${tmpDir.path}/chart1.toml',
      ).writeAsStringSync(TomlChartCodec.encode(doc));
      File(
        '${tmpDir.path}/chart2.toml',
      ).writeAsStringSync(TomlChartCodec.encode(doc));
      File('${tmpDir.path}/readme.txt').writeAsStringSync('not a chart');

      final paths = library.listChartPaths();
      expect(paths.length, 2);
      expect(paths.every((p) => p.endsWith('.toml')), isTrue);
    });

    test('returns empty list for empty directory', () {
      expect(library.listChartPaths(), isEmpty);
    });
  });

  group('loadChart', () {
    test('decodes a valid .toml file', () {
      final path = '${tmpDir.path}/test.toml';
      TomlChartCodec.encodeFile(path, doc);

      final loaded = library.loadChart(path);
      expect(loaded, doc);
    });

    test('canonicalizes a file missing moment.jd', () {
      final civilOnly = '''
spec = "open-astrology-chart"
spec_version = 1
name = "Civil Only"

[location]
lat = 40.7128
lon = -74.006

[civil]
date = "1989-12-14"
time = "20:08:00"
utc_offset = -5.0
dst_offset = 0.0
''';
      final path = '${tmpDir.path}/civil.toml';
      File(path).writeAsStringSync(civilOnly);

      final loaded = library.loadChart(path);
      expect(loaded.name, 'Civil Only');
      expect(loaded.jd, isNonZero);

      // File should have been rewritten with [moment].jd
      final rewritten = File(path).readAsStringSync();
      expect(rewritten, contains('[moment]'));
      expect(rewritten, contains('jd ='));
    });

    test('does not rewrite a file that already has moment.jd', () {
      final path = '${tmpDir.path}/complete.toml';
      TomlChartCodec.encodeFile(path, doc);
      final original = File(path).readAsStringSync();

      library.loadChart(path);

      final after = File(path).readAsStringSync();
      expect(after, original);
    });
  });

  group('saveChart', () {
    test('writes to an explicit path', () {
      final path = '${tmpDir.path}/explicit.toml';
      final returned = library.saveChart(doc, path: path);
      expect(returned, path);

      final loaded = TomlChartCodec.decodeFile(path);
      expect(loaded, doc);
    });

    test('generates filename from name', () {
      final path = library.saveChart(doc);
      expect(path, contains('jane-doe.toml'));

      final loaded = TomlChartCodec.decodeFile(path);
      expect(loaded, doc);
    });

    test('handles filename collision with counter', () {
      final first = library.saveChart(doc);
      expect(first, endsWith('jane-doe.toml'));

      final second = library.saveChart(doc);
      expect(second, endsWith('jane-doe-1.toml'));

      final third = library.saveChart(doc);
      expect(third, endsWith('jane-doe-2.toml'));
    });

    test('uses "chart" for empty name', () {
      const unnamed = ChartDoc(jd: 2451545.0, lat: 51.5, lon: -0.12);
      final path = library.saveChart(unnamed);
      expect(path, contains('chart.toml'));
    });
  });

  group('loadAll', () {
    test('loads all charts from directory', () {
      final doc2 = doc.copyWith(name: 'John Smith', lat: 51.5);
      TomlChartCodec.encodeFile('${tmpDir.path}/a.toml', doc);
      TomlChartCodec.encodeFile('${tmpDir.path}/b.toml', doc2);

      final all = library.loadAll();
      expect(all.length, 2);
      expect(all.values.map((d) => d.name).toSet(), {'Jane Doe', 'John Smith'});
    });

    test('collects errors for bad files', () {
      TomlChartCodec.encodeFile('${tmpDir.path}/good.toml', doc);
      File('${tmpDir.path}/bad.toml').writeAsStringSync('not valid toml {{{');

      final errors = <(String, Object)>[];
      final all = library.loadAll(errors: errors);
      expect(all.length, 1);
      expect(errors.length, 1);
      expect(errors.first.$1, contains('bad.toml'));
    });
  });

  group('sanitizeName', () {
    test('lowercases and replaces non-alphanumeric', () {
      expect(ChartLibrary.sanitizeName('Jane Doe'), 'jane-doe');
    });

    test('trims leading/trailing hyphens', () {
      expect(ChartLibrary.sanitizeName('--Hello--'), 'hello');
    });

    test('collapses runs of special chars', () {
      expect(ChartLibrary.sanitizeName('a   b!!!c'), 'a-b-c');
    });
  });

  group('defaultRoot', () {
    test('returns a path under .local/share/aion', () {
      final root = ChartLibrary.defaultRoot();
      expect(root, contains('aion/charts'));
    });
  });
}
