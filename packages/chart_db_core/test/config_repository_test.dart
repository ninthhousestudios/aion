import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:chart_db_core/chart_db_core.dart';

/// Helper: builds a minimal preset JSON with the given bodies.
String _preset(List<String> bodies) {
  return jsonEncode({
    'sweConfig': {
      'bodies': bodies,
    },
  });
}

/// SHA-256 of a raw string — mirrors the repo's hashing.
String _sha256(String input) {
  return sha256.convert(utf8.encode(input)).toString();
}

void main() {
  late ChartDatabase chartDb;
  late ConfigRepository repo;
  late VectorSchemaRepository schemaRepo;

  setUp(() {
    chartDb = ChartDatabase(); // in-memory
    repo = ConfigRepository(chartDb.db);
    schemaRepo = VectorSchemaRepository(chartDb.db);
  });

  tearDown(() {
    chartDb.close();
  });

  group('register', () {
    test('content hash computed correctly and config stored', () {
      final presetJson = _preset(['sun', 'moon', 'mercury']);
      final expectedId = _sha256(presetJson);

      final config = repo.register('tropical', presetJson);

      expect(config.id, equals(expectedId));
      expect(config.name, equals('tropical'));
      expect(config.preset, equals(presetJson));
      expect(config.vectorSchemaId, isNull);
      expect(config.createdAt, isNotNull);
    });

    test('idempotent: same preset JSON returns same id', () {
      final presetJson = _preset(['sun', 'moon']);

      final first = repo.register('tropical', presetJson);
      final second = repo.register('tropical', presetJson);

      expect(first.id, equals(second.id));
      expect(first.name, equals(second.name));

      // Only one row in the table.
      final all = repo.list();
      expect(all, hasLength(1));
    });

    test('different presets produce different ids', () {
      final a = repo.register('a', _preset(['sun']));
      final b = repo.register('b', _preset(['moon']));

      expect(a.id, isNot(equals(b.id)));
    });

    test('register with valid vectorSchemaId succeeds', () {
      schemaRepo.ensureDefaults();
      final schemas = schemaRepo.list();
      final schemaId = schemas.first.id;

      final presetJson = _preset(['sun', 'moon']);
      final config = repo.register('with-schema', presetJson,
          vectorSchemaId: schemaId);

      expect(config.vectorSchemaId, equals(schemaId));
    });

    test('register with non-existent vectorSchemaId throws', () {
      expect(
        () => repo.register('bad', _preset(['sun']),
            vectorSchemaId: 'no-such-id'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('get', () {
    test('returns null for missing id', () {
      expect(repo.get('nonexistent'), isNull);
    });

    test('round-trips config data', () {
      final presetJson = _preset(['sun', 'moon', 'mars']);
      final registered = repo.register('test-config', presetJson);

      final fetched = repo.get(registered.id);

      expect(fetched, isNotNull);
      expect(fetched!.id, equals(registered.id));
      expect(fetched.name, equals('test-config'));
      expect(fetched.preset, equals(presetJson));
      expect(fetched.vectorSchemaId, isNull);
    });
  });

  group('list', () {
    test('lists all configs with schema info', () {
      schemaRepo.ensureDefaults();
      final schemas = schemaRepo.list();
      final western = schemas.firstWhere((s) => s.name == 'western-13');

      repo.register('alpha', _preset(['sun']));
      repo.register('beta', _preset(['moon']),
          vectorSchemaId: western.id);

      final all = repo.list();
      expect(all, hasLength(2));

      // Sorted by name.
      expect(all[0].config.name, equals('alpha'));
      expect(all[0].schemaName, isNull);

      expect(all[1].config.name, equals('beta'));
      expect(all[1].schemaName, equals('western-13'));
      expect(all[1].schemaDims, equals(101));
    });

    test('empty list when no configs', () {
      expect(repo.list(), isEmpty);
    });
  });

  group('updateSchema', () {
    test('updates FK and returns old schema id', () {
      schemaRepo.ensureDefaults();
      final schemas = schemaRepo.list();
      final western = schemas.firstWhere((s) => s.name == 'western-13');
      final vedic = schemas.firstWhere((s) => s.name == 'vedic-13');

      // Register with all 13 bodies so both schemas are valid subsets.
      final allBodies = [
        'sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn',
        'uranus', 'neptune', 'pluto', 'chiron', 'rahu', 'ketu',
      ];
      final config = repo.register('full', _preset(allBodies),
          vectorSchemaId: western.id);

      final oldId = repo.updateSchema(config.id, vedic.id);

      expect(oldId, equals(western.id));

      // Verify the update persisted.
      final updated = repo.get(config.id);
      expect(updated!.vectorSchemaId, equals(vedic.id));
    });

    test('returns null when config had no prior schema', () {
      schemaRepo.ensureDefaults();
      final schemas = schemaRepo.list();
      final western = schemas.firstWhere((s) => s.name == 'western-13');

      final allBodies = [
        'sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn',
        'uranus', 'neptune', 'pluto', 'chiron', 'rahu', 'ketu',
      ];
      final config = repo.register('no-schema', _preset(allBodies));

      final oldId = repo.updateSchema(config.id, western.id);
      expect(oldId, isNull);
    });

    test('throws StateError for non-existent config', () {
      schemaRepo.ensureDefaults();
      final schemas = schemaRepo.list();

      expect(
        () => repo.updateSchema('no-such-config', schemas.first.id),
        throwsA(isA<StateError>()),
      );
    });

    test('throws ArgumentError for non-existent schema id', () {
      final config = repo.register('test', _preset(['sun']));

      expect(
        () => repo.updateSchema(config.id, 'no-such-schema'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('body validation', () {
    test('rejects schema whose bodies exceed config preset bodies', () {
      // Schema needs all 13 bodies; config only has sun and moon.
      schemaRepo.ensureDefaults();
      final schemas = schemaRepo.list();
      final western = schemas.firstWhere((s) => s.name == 'western-13');

      final config = repo.register('minimal', _preset(['sun', 'moon']));

      expect(
        () => repo.updateSchema(config.id, western.id),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('not present in config preset bodies'),
        )),
      );
    });

    test('accepts schema whose bodies are a subset of config bodies', () {
      // Register a small schema with only sun and moon.
      final smallSpec = {
        'bodies': ['sun', 'moon'],
        'features': {'longitudes': true},
      };
      final smallSchema = schemaRepo.register('small-2', smallSpec);

      // Config has sun, moon, mars — superset of schema.
      final config =
          repo.register('bigger', _preset(['sun', 'moon', 'mars']));

      // Should not throw.
      final oldId = repo.updateSchema(config.id, smallSchema.id);
      expect(oldId, isNull);

      final updated = repo.get(config.id);
      expect(updated!.vectorSchemaId, equals(smallSchema.id));
    });

    test('accepts exact body match between schema and config', () {
      final spec = {
        'bodies': ['sun', 'moon'],
        'features': {'longitudes': true},
      };
      final schema = schemaRepo.register('exact-2', spec);
      final config = repo.register('exact', _preset(['sun', 'moon']));

      final oldId = repo.updateSchema(config.id, schema.id);
      expect(oldId, isNull);
    });
  });

  group('delete', () {
    test('removes config', () {
      final config = repo.register('doomed', _preset(['sun']));

      expect(repo.get(config.id), isNotNull);

      repo.delete(config.id);

      expect(repo.get(config.id), isNull);
    });

    test('delete non-existent id is a no-op', () {
      // Should not throw.
      repo.delete('no-such-id');
    });
  });

  group('extractBodies', () {
    test('extracts bodies from valid preset', () {
      final bodies = extractBodies(_preset(['sun', 'moon', 'mars']));
      expect(bodies, equals({'sun', 'moon', 'mars'}));
    });

    test('returns empty set for malformed JSON', () {
      expect(extractBodies('not json'), isEmpty);
    });

    test('returns empty set when sweConfig is missing', () {
      expect(extractBodies(jsonEncode({'other': 'stuff'})), isEmpty);
    });

    test('returns empty set when bodies is not a list', () {
      final json = jsonEncode({
        'sweConfig': {'bodies': 'not-a-list'},
      });
      expect(extractBodies(json), isEmpty);
    });
  });
}
