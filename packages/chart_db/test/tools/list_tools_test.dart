import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

import 'package:chart_db/src/tools/list_collections.dart';
import 'package:chart_db/src/tools/list_configs.dart';
import 'package:chart_db/src/tools/list_schemas.dart';

void main() {
  late ChartDatabase db;

  setUp(() {
    db = ChartDatabase();
  });

  tearDown(() => db.close());

  group('list_collections', () {
    late CollectionRepository repo;

    setUp(() {
      repo = CollectionRepository(db.db);
    });

    test('returns empty list on fresh db', () {
      final result = handleListCollections(repo);

      expect(result.isError, isFalse);
      expect(result.structuredContent!['count'], 0);
      expect(result.structuredContent!['collections'], isEmpty);
    });

    test('returns collections after creation', () {
      repo.create('Test Collection', note: 'a note');

      final result = handleListCollections(repo);

      expect(result.structuredContent!['count'], 1);
      final coll =
          (result.structuredContent!['collections'] as List).first as Map;
      expect(coll['name'], 'Test Collection');
      expect(coll['note'], 'a note');
      expect(coll.containsKey('chart_count'), isTrue);
    });
  });

  group('list_configs', () {
    late ConfigRepository repo;

    setUp(() {
      repo = ConfigRepository(db.db);
    });

    test('returns empty list on fresh db', () {
      final result = handleListConfigs(repo);

      expect(result.isError, isFalse);
      expect(result.structuredContent!['count'], 0);
      expect(result.structuredContent!['configs'], isEmpty);
    });

    test('returns configs after registration', () {
      repo.register('tropical', '{"bodies":["Sun"]}');

      final result = handleListConfigs(repo);

      expect(result.structuredContent!['count'], 1);
      final cfg = (result.structuredContent!['configs'] as List).first as Map;
      expect(cfg['name'], 'tropical');
      expect(cfg['preset'], '{"bodies":["Sun"]}');
    });
  });

  group('list_schemas', () {
    late VectorSchemaRepository repo;

    setUp(() {
      repo = VectorSchemaRepository(db.db);
    });

    test('returns empty list before ensureDefaults', () {
      final result = handleListSchemas(repo);

      expect(result.isError, isFalse);
      expect(result.structuredContent!['count'], 0);
    });

    test('returns schemas after ensureDefaults', () {
      repo.ensureDefaults();

      final result = handleListSchemas(repo);

      expect(result.structuredContent!['count'], greaterThan(0));
      final schema =
          (result.structuredContent!['schemas'] as List).first as Map;
      expect(schema.containsKey('id'), isTrue);
      expect(schema.containsKey('name'), isTrue);
      expect(schema.containsKey('dims'), isTrue);
    });
  });
}
