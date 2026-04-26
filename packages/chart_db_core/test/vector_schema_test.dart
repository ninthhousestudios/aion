import 'package:test/test.dart';
import 'package:chart_db_core/chart_db_core.dart';

void main() {
  late ChartDatabase chartDb;
  late VectorSchemaRepository repo;

  setUp(() {
    chartDb = ChartDatabase(); // in-memory
    repo = VectorSchemaRepository(chartDb.db);
  });

  tearDown(() {
    chartDb.close();
  });

  group('ensureDefaults', () {
    test('creates western-13 and vedic-13 with correct dims', () {
      repo.ensureDefaults();
      final schemas = repo.list();

      expect(schemas, hasLength(2));

      final names = schemas.map((s) => s.name).toSet();
      expect(names, containsAll(['western-13', 'vedic-13']));

      final western = schemas.firstWhere((s) => s.name == 'western-13');
      expect(western.dims, equals(101));

      final vedic = schemas.firstWhere((s) => s.name == 'vedic-13');
      expect(vedic.dims, equals(127));
    });
  });

  group('computeDims', () {
    test('western-13 spec yields 101 dims', () {
      expect(computeDims(westernSpec), equals(101));
    });

    test('vedic-13 spec yields 127 dims', () {
      expect(computeDims(vedicSpec), equals(127));
    });

    test('minimal spec: bodies only', () {
      final spec = {
        'bodies': ['sun', 'moon'],
        'features': {
          'longitudes': true,
        },
      };
      // 2 bodies × 2 = 4
      expect(computeDims(spec), equals(4));
    });

    test('all features enabled for 3 bodies', () {
      final spec = {
        'bodies': ['sun', 'moon', 'mars'],
        'features': {
          'longitudes': true,
          'house_cusps': true,
          'swe_aux': ['armc', 'vertex'],
          'house_placements': true,
          'nakshatras': true,
          'retrogrades': true,
        },
      };
      // longitudes: 3×2=6, cusps: 12×2=24, swe_aux: 2×2=4,
      // house_placements: 3×2=6, nakshatras: 3×2=6, retrogrades: 3×1=3
      // Total = 49
      expect(computeDims(spec), equals(49));
    });
  });

  group('idempotent registration', () {
    test('registering the same spec twice returns the same id', () {
      final first = repo.register('western-13', westernSpec);
      final second = repo.register('western-13', westernSpec);

      expect(first.id, equals(second.id));
      expect(first.dims, equals(second.dims));

      // Only one row in the table.
      final all = repo.list();
      expect(all.where((s) => s.name == 'western-13'), hasLength(1));
    });
  });

  group('spec validation', () {
    test('rejects missing bodies', () {
      expect(
        () => repo.register('bad', {'features': {}}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty bodies list', () {
      expect(
        () => repo.register('bad', {
          'bodies': <String>[],
          'features': {'longitudes': true},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects unrecognized body name', () {
      expect(
        () => repo.register('bad', {
          'bodies': ['sun', 'vulcan'],
          'features': {'longitudes': true},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects missing features', () {
      expect(
        () => repo.register('bad', {
          'bodies': ['sun'],
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects unknown feature key', () {
      expect(
        () => repo.register('bad', {
          'bodies': ['sun'],
          'features': {'longitudes': true, 'warp_drive': true},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects unknown swe_aux value', () {
      expect(
        () => repo.register('bad', {
          'bodies': ['sun'],
          'features': {'swe_aux': ['armc', 'bogus']},
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts valid minimal spec', () {
      final schema = repo.register('minimal', {
        'bodies': ['sun'],
        'features': {'longitudes': true},
      });
      expect(schema.dims, equals(2));
    });
  });

  group('hash determinism', () {
    test('same spec always produces the same hash', () {
      final hash1 = specHash(westernSpec);
      final hash2 = specHash(westernSpec);
      expect(hash1, equals(hash2));
    });

    test('key order does not affect hash', () {
      final specA = {
        'bodies': ['sun', 'moon'],
        'features': {'longitudes': true, 'retrogrades': true},
      };
      final specB = {
        'features': {'retrogrades': true, 'longitudes': true},
        'bodies': ['sun', 'moon'],
      };
      expect(specHash(specA), equals(specHash(specB)));
    });

    test('different specs produce different hashes', () {
      expect(specHash(westernSpec), isNot(equals(specHash(vedicSpec))));
    });
  });

  group('get and delete', () {
    test('get returns null for missing id', () {
      expect(repo.get('nonexistent'), isNull);
    });

    test('get returns registered schema', () {
      final registered = repo.register('western-13', westernSpec);
      final fetched = repo.get(registered.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('western-13'));
      expect(fetched.dims, equals(101));
    });

    test('delete removes schema', () {
      final schema = repo.register('western-13', westernSpec);
      repo.delete(schema.id);
      expect(repo.get(schema.id), isNull);
    });

    test('delete blocked when config references schema', () {
      final schema = repo.register('western-13', westernSpec);

      // Insert a config row that references this schema via raw SQL.
      chartDb.db.execute(
        'INSERT INTO configs (id, name, preset, vector_schema_id) '
        'VALUES (?, ?, ?, ?);',
        ['cfg-1', 'test-config', 'default', schema.id],
      );

      expect(
        () => repo.delete(schema.id),
        throwsA(isA<StateError>()),
      );

      // Schema still exists.
      expect(repo.get(schema.id), isNotNull);
    });
  });

  group('canonicalJson', () {
    test('produces deterministic output regardless of insertion order', () {
      final a = canonicalJson({'z': 1, 'a': 2});
      final b = canonicalJson({'a': 2, 'z': 1});
      expect(a, equals(b));
      expect(a, equals('{"a":2,"z":1}'));
    });

    test('sorts nested maps', () {
      final json = canonicalJson({
        'outer': {'z': true, 'a': false},
      });
      expect(json, equals('{"outer":{"a":false,"z":true}}'));
    });
  });
}
