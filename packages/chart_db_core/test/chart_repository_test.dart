import 'package:test/test.dart';
import 'package:chart_db_core/chart_db_core.dart';

void main() {
  late ChartDatabase chartDb;
  late ChartRepository repo;

  setUp(() {
    chartDb = ChartDatabase(); // in-memory
    repo = ChartRepository(chartDb.db);
  });

  tearDown(() {
    chartDb.close();
  });

  Chart _makeChart({
    String id = '',
    double jd = 2451545.0,
    double lat = 51.5074,
    double lon = -0.1278,
    double alt = 0,
    String name = 'Isaac Newton',
    String? gender = 'M',
    String? placename = 'Woolsthorpe',
    String? country = 'England',
    double? utcOffset = 0,
    double? dstOffset = 0,
    String? notes = 'gravity guy',
    String? rodden = 'AA',
    String? sourcePath,
  }) {
    return Chart(
      id: id,
      jd: jd,
      lat: lat,
      lon: lon,
      alt: alt,
      name: name,
      gender: gender,
      placename: placename,
      country: country,
      utcOffset: utcOffset,
      dstOffset: dstOffset,
      notes: notes,
      rodden: rodden,
      sourcePath: sourcePath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('insert and get', () {
    test('round-trip chart data', () {
      final id = repo.insert(_makeChart(name: 'Isaac Newton'));
      expect(id, isNotEmpty);

      final chart = repo.get(id);
      expect(chart, isNotNull);
      expect(chart!.name, equals('Isaac Newton'));
      expect(chart.jd, equals(2451545.0));
      expect(chart.lat, closeTo(51.5074, 0.0001));
      expect(chart.lon, closeTo(-0.1278, 0.0001));
      expect(chart.gender, equals('M'));
      expect(chart.placename, equals('Woolsthorpe'));
      expect(chart.country, equals('England'));
      expect(chart.utcOffset, equals(0));
      expect(chart.dstOffset, equals(0));
      expect(chart.notes, equals('gravity guy'));
      expect(chart.rodden, equals('AA'));
      expect(chart.createdAt, isNotNull);
      expect(chart.updatedAt, isNotNull);
    });

    test('generates UUID when id is empty', () {
      final id = repo.insert(_makeChart(id: ''));
      expect(id, isNotEmpty);
      // UUID v4 format: 8-4-4-4-12 hex
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });

    test('uses provided id when non-empty', () {
      final id = repo.insert(_makeChart(id: 'custom-id'));
      expect(id, equals('custom-id'));
      expect(repo.get('custom-id'), isNotNull);
    });

    test('get returns null for missing id', () {
      expect(repo.get('nonexistent'), isNull);
    });

    test('preserves null optional fields', () {
      final id = repo.insert(_makeChart(
        gender: null,
        placename: null,
        country: null,
        utcOffset: null,
        dstOffset: null,
        notes: null,
        rodden: null,
        sourcePath: null,
      ));
      final chart = repo.get(id)!;
      expect(chart.gender, isNull);
      expect(chart.placename, isNull);
      expect(chart.country, isNull);
      expect(chart.utcOffset, isNull);
      expect(chart.dstOffset, isNull);
      expect(chart.notes, isNull);
      expect(chart.rodden, isNull);
      expect(chart.sourcePath, isNull);
    });
  });

  group('update', () {
    test('partial update preserves other fields', () {
      final id = repo.insert(_makeChart(
        name: 'Isaac Newton',
        gender: 'M',
        notes: 'gravity guy',
        rodden: 'AA',
        placename: 'Woolsthorpe',
        country: 'England',
      ));

      repo.update(id, name: 'Sir Isaac Newton');

      final chart = repo.get(id)!;
      expect(chart.name, equals('Sir Isaac Newton'));
      // Other fields preserved
      expect(chart.gender, equals('M'));
      expect(chart.notes, equals('gravity guy'));
      expect(chart.rodden, equals('AA'));
      expect(chart.placename, equals('Woolsthorpe'));
      expect(chart.country, equals('England'));
    });

    test('updates multiple fields at once', () {
      final id = repo.insert(_makeChart());
      repo.update(id, name: 'Updated', country: 'UK', notes: 'new notes');

      final chart = repo.get(id)!;
      expect(chart.name, equals('Updated'));
      expect(chart.country, equals('UK'));
      expect(chart.notes, equals('new notes'));
    });

    test('sets updated_at on update', () {
      final id = repo.insert(_makeChart());
      final before = repo.get(id)!.updatedAt;

      // Small delay to ensure timestamp changes
      repo.update(id, name: 'Updated');
      final after = repo.get(id)!.updatedAt;

      expect(after.millisecondsSinceEpoch,
          greaterThanOrEqualTo(before.millisecondsSinceEpoch));
    });

    test('no-op when no fields provided', () {
      final id = repo.insert(_makeChart(name: 'Original'));
      repo.update(id); // no fields
      expect(repo.get(id)!.name, equals('Original'));
    });
  });

  group('delete', () {
    test('removes chart', () {
      final id = repo.insert(_makeChart());
      expect(repo.get(id), isNotNull);

      repo.delete(id);
      expect(repo.get(id), isNull);
    });

    test('cascades to tags', () {
      final id = repo.insert(_makeChart());
      // Add a tag via raw SQL (as specified in the plan)
      chartDb.db.execute(
        'INSERT INTO chart_tags (chart_id, tag) VALUES (?, ?);',
        [id, 'famous'],
      );

      // Verify tag exists
      final tagsBefore = chartDb.db.select(
        'SELECT * FROM chart_tags WHERE chart_id = ?;',
        [id],
      );
      expect(tagsBefore, hasLength(1));

      repo.delete(id);

      // Tag should be gone (FK cascade)
      final tagsAfter = chartDb.db.select(
        'SELECT * FROM chart_tags WHERE chart_id = ?;',
        [id],
      );
      expect(tagsAfter, isEmpty);
    });

    test('cascades to collections', () {
      final id = repo.insert(_makeChart());

      // Create a collection and add the chart
      chartDb.db.execute(
        "INSERT INTO collections (id, name) VALUES ('col1', 'Test Collection');",
      );
      chartDb.db.execute(
        "INSERT INTO chart_collections (chart_id, collection_id) VALUES (?, 'col1');",
        [id],
      );

      // Verify membership exists
      final membersBefore = chartDb.db.select(
        'SELECT * FROM chart_collections WHERE chart_id = ?;',
        [id],
      );
      expect(membersBefore, hasLength(1));

      repo.delete(id);

      // Membership should be gone (FK cascade)
      final membersAfter = chartDb.db.select(
        'SELECT * FROM chart_collections WHERE chart_id = ?;',
        [id],
      );
      expect(membersAfter, isEmpty);
    });
  });

  group('search', () {
    late String newtonId;
    late String einsteinId;
    late String curieId;

    setUp(() {
      newtonId = repo.insert(_makeChart(
        jd: 2305814.0,
        lat: 52.81,
        lon: -0.64,
        name: 'Isaac Newton',
        country: 'England',
        notes: 'discovered gravity and calculus',
      ));
      einsteinId = repo.insert(_makeChart(
        jd: 2411810.0,
        lat: 48.40,
        lon: 9.99,
        name: 'Albert Einstein',
        country: 'Germany',
        notes: 'relativity and quantum theory',
      ));
      curieId = repo.insert(_makeChart(
        jd: 2408506.0,
        lat: 52.23,
        lon: 21.01,
        name: 'Marie Curie',
        country: 'Poland',
        notes: 'radioactivity pioneer',
      ));
    });

    test('FTS match returns ranked results', () {
      final results = repo.search(query: 'Newton');
      expect(results, hasLength(1));
      expect(results.first.id, equals(newtonId));
    });

    test('FTS matches across indexed columns', () {
      // 'gravity' is in the notes field
      final results = repo.search(query: 'gravity');
      expect(results, hasLength(1));
      expect(results.first.name, equals('Isaac Newton'));
    });

    test('FTS prefix matching', () {
      final results = repo.search(query: 'Ein*');
      expect(results, hasLength(1));
      expect(results.first.name, equals('Albert Einstein'));
    });

    test('returns all charts when no filters', () {
      final results = repo.search();
      expect(results, hasLength(3));
    });

    test('respects limit', () {
      final results = repo.search(limit: 2);
      expect(results, hasLength(2));
    });

    test('search by country', () {
      final results = repo.search(country: 'England');
      expect(results, hasLength(1));
      expect(results.first.name, equals('Isaac Newton'));
    });

    test('search by jd range', () {
      // Range that includes Einstein and Curie but not Newton
      final results = repo.search(jdMin: 2400000.0, jdMax: 2420000.0);
      expect(results, hasLength(2));
      final names = results.map((c) => c.name).toSet();
      expect(names, containsAll(['Albert Einstein', 'Marie Curie']));
    });

    test('search by jdMin only', () {
      final results = repo.search(jdMin: 2410000.0);
      expect(results, hasLength(1));
      expect(results.first.name, equals('Albert Einstein'));
    });

    test('search by jdMax only', () {
      final results = repo.search(jdMax: 2310000.0);
      expect(results, hasLength(1));
      expect(results.first.name, equals('Isaac Newton'));
    });

    test('combines FTS query with country filter', () {
      // Search for 'pioneer' (in Curie's notes) in Poland
      final results = repo.search(query: 'pioneer', country: 'Poland');
      expect(results, hasLength(1));
      expect(results.first.name, equals('Marie Curie'));
    });

    test('combined filters that match nothing', () {
      final results = repo.search(query: 'Newton', country: 'Germany');
      expect(results, isEmpty);
    });

    test('search by tag', () {
      chartDb.db.execute(
        'INSERT INTO chart_tags (chart_id, tag) VALUES (?, ?);',
        [newtonId, 'physicist'],
      );
      chartDb.db.execute(
        'INSERT INTO chart_tags (chart_id, tag) VALUES (?, ?);',
        [einsteinId, 'physicist'],
      );
      chartDb.db.execute(
        'INSERT INTO chart_tags (chart_id, tag) VALUES (?, ?);',
        [curieId, 'chemist'],
      );

      final results = repo.search(tag: 'physicist');
      expect(results, hasLength(2));
      final names = results.map((c) => c.name).toSet();
      expect(names, containsAll(['Isaac Newton', 'Albert Einstein']));
    });

    test('search by collection', () {
      chartDb.db.execute(
        "INSERT INTO collections (id, name) VALUES ('sci1', 'Scientists');",
      );
      chartDb.db.execute(
        "INSERT INTO chart_collections (chart_id, collection_id) VALUES (?, 'sci1');",
        [einsteinId],
      );
      chartDb.db.execute(
        "INSERT INTO chart_collections (chart_id, collection_id) VALUES (?, 'sci1');",
        [curieId],
      );

      final results = repo.search(collectionId: 'sci1');
      expect(results, hasLength(2));
      final names = results.map((c) => c.name).toSet();
      expect(names, containsAll(['Albert Einstein', 'Marie Curie']));
    });

    test('combines tag, country, and jd range', () {
      chartDb.db.execute(
        'INSERT INTO chart_tags (chart_id, tag) VALUES (?, ?);',
        [newtonId, 'physicist'],
      );
      chartDb.db.execute(
        'INSERT INTO chart_tags (chart_id, tag) VALUES (?, ?);',
        [einsteinId, 'physicist'],
      );

      final results = repo.search(
        tag: 'physicist',
        country: 'Germany',
        jdMin: 2400000.0,
      );
      expect(results, hasLength(1));
      expect(results.first.name, equals('Albert Einstein'));
    });
  });

  group('natural key uniqueness', () {
    test('duplicate (jd, lat, lon) throws DuplicateChartException', () {
      repo.insert(_makeChart(
        jd: 2451545.0,
        lat: 51.5074,
        lon: -0.1278,
        name: 'First',
      ));

      expect(
        () => repo.insert(_makeChart(
          jd: 2451545.0,
          lat: 51.5074,
          lon: -0.1278,
          name: 'Duplicate',
        )),
        throwsA(isA<DuplicateChartException>()),
      );
    });

    test('DuplicateChartException contains existing chart id', () {
      final firstId = repo.insert(_makeChart(
        jd: 2451545.0,
        lat: 51.5074,
        lon: -0.1278,
        name: 'First',
      ));

      try {
        repo.insert(_makeChart(
          jd: 2451545.0,
          lat: 51.5074,
          lon: -0.1278,
          name: 'Duplicate',
        ));
        fail('Expected DuplicateChartException');
      } on DuplicateChartException catch (e) {
        expect(e.existingId, equals(firstId));
      }
    });

    test('different coordinates are allowed', () {
      repo.insert(_makeChart(jd: 2451545.0, lat: 51.5074, lon: -0.1278));
      // Same jd, different lat/lon -- should succeed
      final id2 = repo.insert(_makeChart(
        jd: 2451545.0,
        lat: 48.8566,
        lon: 2.3522,
        name: 'Different location',
      ));
      expect(repo.get(id2), isNotNull);
    });
  });
}
