import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

void main() {
  // A fully-populated doc exercising every field.
  final full = ChartDoc(
    jd: 2447679.3388888887,
    lat: 40.7128,
    lon: -74.0060,
    alt: 10,
    name: 'Jane Doe',
    gender: 'female',
    placename: 'New York',
    country: 'USA',
    utcOffset: -5,
    dstOffset: 0,
    timezone: 'EST',
    notes: 'first line\nsecond line',
    rodden: 'AA',
    tags: const ['natal', 'research'],
  );

  // A minimal doc: only the required natural-key fields.
  const minimal = ChartDoc(
    jd: 2451545.0,
    lat: 51.5,
    lon: -0.12,
  );

  group('round-trip', () {
    test('encode -> decode preserves a fully-populated doc', () {
      expect(TomlChartCodec.decode(TomlChartCodec.encode(full)), full);
    });

    test('encode -> decode preserves a minimal doc', () {
      expect(TomlChartCodec.decode(TomlChartCodec.encode(minimal)), minimal);
    });

    test('write -> read -> write is byte-identical (§7)', () {
      final once = TomlChartCodec.encode(full);
      final twice = TomlChartCodec.encode(TomlChartCodec.decode(once));
      expect(twice, once);
    });

    test('jd survives at full double precision', () {
      final back = TomlChartCodec.decode(TomlChartCodec.encode(full));
      expect(back.jd, full.jd);
    });
  });

  group('encode', () {
    test('emits the spec marker and version', () {
      final out = TomlChartCodec.encode(minimal);
      expect(out, contains('open-astrology-chart'));
      expect(out, contains('spec_version = 1'));
    });

    test('omits optional fields that are absent', () {
      final out = TomlChartCodec.encode(minimal);
      expect(out, isNot(contains('name =')));
      expect(out, isNot(contains('gender =')));
      expect(out, isNot(contains('placename =')));
      expect(out, isNot(contains('country =')));
      expect(out, isNot(contains('rodden =')));
      expect(out, isNot(contains('tags =')));
      expect(out, isNot(contains('notes =')));
      expect(out, isNot(contains('alt =')));
    });

    test('emits an advisory [civil] block rendered from jd + offset', () {
      final out = TomlChartCodec.encode(full);
      // jd 2447679.3388888887 is 1989-06-01 20:08 UT; EST (-5) -> 15:08 local.
      expect(out, contains('[civil]'));
      expect(out, contains('1989-06-01'));
      expect(out, contains('15:08:00'));
      expect(out, contains('EST'));
    });

    test('renders civil in UTC when no offset is given', () {
      const utc = ChartDoc(jd: 2451545.0, lat: 0, lon: 0);
      final out = TomlChartCodec.encode(utc);
      expect(out, contains('2000-01-01'));
      expect(out, contains('12:00:00'));
    });
  });

  group('decode', () {
    test('trusts moment.jd over the advisory civil block', () {
      const src = '''
spec = "open-astrology-chart"
spec_version = 1

[moment]
jd = 2451545.0

[location]
lat = 0.0
lon = 0.0

[civil]
date = "1850-01-01"
time = "00:00:00"
''';
      // The bogus civil date must be ignored; jd wins.
      expect(TomlChartCodec.decode(src).jd, 2451545.0);
    });

    test('derives jd from [civil] when moment.jd is absent (§6)', () {
      const src = '''
spec = "open-astrology-chart"
spec_version = 1

[location]
lat = 40.0
lon = -74.0

[civil]
date = "2000-01-01"
time = "12:00:00"
''';
      // No offset -> civil is already UT -> J2000.0.
      expect(TomlChartCodec.decode(src).jd, closeTo(2451545.0, 1e-6));
    });

    test('derives jd applying utc_offset to reach UT', () {
      const src = '''
spec = "open-astrology-chart"
spec_version = 1

[location]
lat = 40.0
lon = -74.0

[civil]
date = "2000-01-01"
time = "07:00:00"
utc_offset = -5.0
''';
      // 07:00 local at -5 == 12:00 UT == J2000.0.
      expect(TomlChartCodec.decode(src).jd, closeTo(2451545.0, 1e-6));
    });

    test('tolerates unknown keys', () {
      const src = '''
spec = "open-astrology-chart"
spec_version = 1
future_field = "ignored"

[moment]
jd = 2451545.0

[location]
lat = 0.0
lon = 0.0
unknown_loc = true
''';
      expect(TomlChartCodec.decode(src).jd, 2451545.0);
    });

    test('accepts integer-typed numbers for floats', () {
      const src = '''
spec = "open-astrology-chart"
spec_version = 1

[moment]
jd = 2451545

[location]
lat = 0
lon = 0
''';
      final doc = TomlChartCodec.decode(src);
      expect(doc.jd, 2451545.0);
      expect(doc.lat, 0.0);
    });
  });

  group('conformance rejections', () {
    test('rejects a missing spec marker', () {
      const src = '''
spec_version = 1

[moment]
jd = 2451545.0

[location]
lat = 0.0
lon = 0.0
''';
      expect(() => TomlChartCodec.decode(src), throwsFormatException);
    });

    test('rejects a wrong spec marker', () {
      const src = '''
spec = "some-other-format"
spec_version = 1

[moment]
jd = 2451545.0

[location]
lat = 0.0
lon = 0.0
''';
      expect(() => TomlChartCodec.decode(src), throwsFormatException);
    });

    test('rejects an unsupported spec_version', () {
      const src = '''
spec = "open-astrology-chart"
spec_version = 2

[moment]
jd = 2451545.0

[location]
lat = 0.0
lon = 0.0
''';
      expect(() => TomlChartCodec.decode(src), throwsFormatException);
    });

    test('rejects a missing [location]', () {
      const src = '''
spec = "open-astrology-chart"
spec_version = 1

[moment]
jd = 2451545.0
''';
      expect(() => TomlChartCodec.decode(src), throwsFormatException);
    });

    test('rejects when jd is neither present nor derivable', () {
      const src = '''
spec = "open-astrology-chart"
spec_version = 1

[location]
lat = 0.0
lon = 0.0
''';
      expect(() => TomlChartCodec.decode(src), throwsFormatException);
    });

    test('rejects malformed TOML', () {
      expect(
        () => TomlChartCodec.decode('this is = = not toml'),
        throwsFormatException,
      );
    });
  });

  group('edge cases', () {
    test('preserves unicode in name and notes', () {
      const doc = ChartDoc(
        jd: 2451545.0,
        lat: 35.68,
        lon: 139.69,
        name: '田中花子',
        notes: 'café — naïve — 日本語',
      );
      expect(TomlChartCodec.decode(TomlChartCodec.encode(doc)), doc);
    });

    test('preserves a multi-line notes field', () {
      const doc = ChartDoc(
        jd: 2451545.0,
        lat: 0,
        lon: 0,
        notes: 'line one\nline two\nline three',
      );
      final back = TomlChartCodec.decode(TomlChartCodec.encode(doc));
      expect(back.notes, 'line one\nline two\nline three');
    });

    test('preserves a tags array', () {
      const doc = ChartDoc(
        jd: 2451545.0,
        lat: 0,
        lon: 0,
        tags: ['a', 'b', 'c'],
      );
      expect(TomlChartCodec.decode(TomlChartCodec.encode(doc)).tags,
          ['a', 'b', 'c']);
    });

    test('naturalKey is (jd, lat, lon)', () {
      expect(full.naturalKey, (2447679.3388888887, 40.7128, -74.0060));
    });

    test('preserves negative longitude and southern latitude', () {
      const doc = ChartDoc(jd: 2451545.0, lat: -33.87, lon: -70.66);
      expect(TomlChartCodec.decode(TomlChartCodec.encode(doc)), doc);
    });
  });
}
