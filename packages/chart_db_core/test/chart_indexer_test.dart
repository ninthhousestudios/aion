import 'dart:io';

import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;
  late ChartDatabase chartDb;
  late ChartRepository repo;
  late CollectionRepository collectionRepo;
  late ChartIndexer indexer;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('chart_indexer_test_');
    chartDb = ChartDatabase();
    repo = ChartRepository(chartDb.db);
    collectionRepo = CollectionRepository(chartDb.db);
    indexer = ChartIndexer(chartDb.db, repo, collectionRepo: collectionRepo);
  });

  tearDown(() {
    chartDb.close();
    tmpDir.deleteSync(recursive: true);
  });

  void writeChart(String filename, ChartDoc doc) {
    File(
      '${tmpDir.path}/$filename',
    ).writeAsStringSync(TomlChartCodec.encode(doc));
  }

  final newton = ChartDoc(
    jd: 2324767.5,
    lat: 52.8065,
    lon: -0.6396,
    name: 'Isaac Newton',
    placename: 'Woolsthorpe',
    country: 'England',
    notes: 'discovered gravity',
  );

  final einstein = ChartDoc(
    jd: 2411497.0,
    lat: 48.4011,
    lon: 9.9876,
    name: 'Albert Einstein',
    placename: 'Ulm',
    country: 'Germany',
    notes: 'relativity',
  );

  final curie = ChartDoc(
    jd: 2405854.5,
    lat: 52.2297,
    lon: 21.0122,
    name: 'Marie Curie',
    placename: 'Warsaw',
    country: 'Poland',
  );

  group('full build', () {
    test('indexes all .toml files in directory', () {
      writeChart('newton.toml', newton);
      writeChart('einstein.toml', einstein);
      writeChart('curie.toml', curie);

      final result = indexer.reindex(tmpDir.path);
      expect(result.added, 3);
      expect(result.updated, 0);
      expect(result.removed, 0);
      expect(result.skipped, 0);
      expect(result.errors, isEmpty);
    });

    test('ignores non-toml files', () {
      writeChart('newton.toml', newton);
      File('${tmpDir.path}/readme.txt').writeAsStringSync('not a chart');

      final result = indexer.reindex(tmpDir.path);
      expect(result.added, 1);
    });

    test('FTS search works after indexing', () {
      writeChart('newton.toml', newton);
      writeChart('einstein.toml', einstein);

      indexer.reindex(tmpDir.path);

      final results = repo.search(query: 'gravity');
      expect(results, hasLength(1));
      expect(results.first.name, 'Isaac Newton');
    });
  });

  group('incremental reindex', () {
    test('unchanged files are skipped', () {
      writeChart('newton.toml', newton);
      writeChart('einstein.toml', einstein);

      indexer.reindex(tmpDir.path);
      final result = indexer.reindex(tmpDir.path);

      expect(result.added, 0);
      expect(result.updated, 0);
      expect(result.removed, 0);
      expect(result.skipped, 2);
    });

    test('changed file is re-parsed', () {
      writeChart('newton.toml', newton);
      indexer.reindex(tmpDir.path);

      final updated = ChartDoc(
        jd: newton.jd,
        lat: newton.lat,
        lon: newton.lon,
        name: 'Sir Isaac Newton',
        placename: 'Woolsthorpe',
        country: 'England',
        notes: 'discovered gravity and calculus',
      );
      writeChart('newton.toml', updated);

      final result = indexer.reindex(tmpDir.path);
      expect(result.updated, 1);
      expect(result.skipped, 0);

      final charts = repo.search(query: 'calculus');
      expect(charts, hasLength(1));
      expect(charts.first.name, 'Sir Isaac Newton');
    });

    test('vanished file is removed from index', () {
      writeChart('newton.toml', newton);
      writeChart('einstein.toml', einstein);
      indexer.reindex(tmpDir.path);

      File('${tmpDir.path}/newton.toml').deleteSync();

      final result = indexer.reindex(tmpDir.path);
      expect(result.removed, 1);
      expect(result.skipped, 1);

      final all = repo.search(limit: 100);
      expect(all, hasLength(1));
      expect(all.first.name, 'Albert Einstein');
    });
  });

  group('idempotent rebuild', () {
    test('same directory produces same index state', () {
      writeChart('newton.toml', newton);
      writeChart('einstein.toml', einstein);
      writeChart('curie.toml', curie);

      indexer.reindex(tmpDir.path);
      final firstCharts = repo.search(limit: 100);

      indexer.reindex(tmpDir.path);
      final secondCharts = repo.search(limit: 100);

      expect(secondCharts.length, firstCharts.length);
      for (var i = 0; i < firstCharts.length; i++) {
        expect(secondCharts[i].name, firstCharts[i].name);
        expect(secondCharts[i].jd, firstCharts[i].jd);
        expect(secondCharts[i].contentHash, firstCharts[i].contentHash);
      }
    });
  });

  group('error handling', () {
    test('bad TOML file is collected as error, others still indexed', () {
      writeChart('newton.toml', newton);
      File('${tmpDir.path}/bad.toml').writeAsStringSync('not valid chart toml');

      final result = indexer.reindex(tmpDir.path);
      expect(result.added, 1);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.$1, contains('bad.toml'));
    });
  });

  group('content_hash', () {
    test('stored hash matches SHA-256 of file bytes', () {
      writeChart('newton.toml', newton);
      indexer.reindex(tmpDir.path);

      final chart = repo.search(query: 'Newton').first;
      final bytes = File('${tmpDir.path}/newton.toml').readAsBytesSync();
      expect(chart.contentHash, contentHash(bytes));
    });
  });

  group('tag indexing', () {
    test('tags from TOML are indexed into chart_tags', () {
      final tagged = ChartDoc(
        jd: newton.jd,
        lat: newton.lat,
        lon: newton.lon,
        name: 'Tagged Newton',
        tags: ['natal', 'famous'],
      );
      writeChart('tagged.toml', tagged);

      indexer.reindex(tmpDir.path);

      final charts = repo.search(limit: 100);
      expect(charts, hasLength(1));
      expect(
        collectionRepo.tagsFor(charts.first.id),
        equals({'famous', 'natal'}),
      );
    });

    test('tag changes are reflected after reindex', () {
      final v1 = ChartDoc(
        jd: newton.jd,
        lat: newton.lat,
        lon: newton.lon,
        name: 'Newton',
        tags: ['natal', 'famous'],
      );
      writeChart('newton.toml', v1);
      indexer.reindex(tmpDir.path);

      final v2 = v1.copyWith(tags: ['natal', 'scientist']);
      writeChart('newton.toml', v2);
      indexer.reindex(tmpDir.path);

      final charts = repo.search(limit: 100);
      expect(
        collectionRepo.tagsFor(charts.first.id),
        equals({'natal', 'scientist'}),
      );
    });

    test('tags are synced for skipped (unchanged) charts on upgrade', () {
      final tagged = ChartDoc(
        jd: newton.jd,
        lat: newton.lat,
        lon: newton.lon,
        name: 'Newton',
        tags: ['natal', 'famous'],
      );
      writeChart('newton.toml', tagged);

      // First reindex without collectionRepo — simulates pre-upgrade indexer.
      final oldIndexer = ChartIndexer(chartDb.db, repo);
      oldIndexer.reindex(tmpDir.path);
      final charts = repo.search(limit: 100);
      expect(collectionRepo.tagsFor(charts.first.id), isEmpty);

      // Second reindex with collectionRepo — file unchanged, should still sync tags.
      final result = indexer.reindex(tmpDir.path);
      expect(result.skipped, 1);
      expect(
        collectionRepo.tagsFor(charts.first.id),
        equals({'famous', 'natal'}),
      );
    });

    test('untagged charts have no tags', () {
      writeChart('newton.toml', newton);
      indexer.reindex(tmpDir.path);

      final charts = repo.search(limit: 100);
      expect(collectionRepo.tagsFor(charts.first.id), isEmpty);
    });
  });

  group('collection sidecar sync', () {
    void writeSidecar(List<SidecarCollection> collections) {
      CollectionSidecar.save(tmpDir.path, collections);
    }

    test('sidecar collections are synced into sqlite on reindex', () {
      writeChart('newton.toml', newton);
      writeChart('einstein.toml', einstein);

      final colId = 'col-1';
      writeSidecar([
        SidecarCollection(
          id: colId,
          name: 'Scientists',
          charts: [
            '${tmpDir.path}/newton.toml',
            '${tmpDir.path}/einstein.toml',
          ],
        ),
      ]);

      indexer.reindex(tmpDir.path);

      final col = collectionRepo.get(colId);
      expect(col, isNotNull);
      expect(col!.name, 'Scientists');
      expect(collectionRepo.chartsIn(colId), hasLength(2));
    });

    test('stale source paths in sidecar are skipped', () {
      writeChart('newton.toml', newton);

      writeSidecar([
        SidecarCollection(
          id: 'col-1',
          name: 'Mixed',
          charts: ['${tmpDir.path}/newton.toml', '${tmpDir.path}/missing.toml'],
        ),
      ]);

      indexer.reindex(tmpDir.path);

      expect(collectionRepo.chartsIn('col-1'), hasLength(1));
    });

    test('removed sidecar collection is deleted from sqlite', () {
      writeChart('newton.toml', newton);

      writeSidecar([SidecarCollection(id: 'col-1', name: 'Temp')]);
      indexer.reindex(tmpDir.path);
      expect(collectionRepo.get('col-1'), isNotNull);

      writeSidecar([]);
      indexer.reindex(tmpDir.path);
      expect(collectionRepo.get('col-1'), isNull);
    });

    test('membership changes are synced on reindex', () {
      writeChart('newton.toml', newton);
      writeChart('einstein.toml', einstein);

      writeSidecar([
        SidecarCollection(
          id: 'col-1',
          name: 'Faves',
          charts: ['${tmpDir.path}/newton.toml'],
        ),
      ]);
      indexer.reindex(tmpDir.path);
      expect(collectionRepo.chartsIn('col-1'), hasLength(1));

      writeSidecar([
        SidecarCollection(
          id: 'col-1',
          name: 'Faves',
          charts: [
            '${tmpDir.path}/newton.toml',
            '${tmpDir.path}/einstein.toml',
          ],
        ),
      ]);
      indexer.reindex(tmpDir.path);
      expect(collectionRepo.chartsIn('col-1'), hasLength(2));
    });

    test('relative sidecar paths resolve against directory', () {
      writeChart('newton.toml', newton);

      writeSidecar([
        SidecarCollection(
          id: 'col-1',
          name: 'Relative',
          charts: ['newton.toml'],
        ),
      ]);

      indexer.reindex(tmpDir.path);

      expect(collectionRepo.chartsIn('col-1'), hasLength(1));
    });

    test('sidecar metadata changes are synced on reindex', () {
      writeChart('newton.toml', newton);

      writeSidecar([
        SidecarCollection(id: 'col-1', name: 'Original', note: 'v1'),
      ]);
      indexer.reindex(tmpDir.path);
      expect(collectionRepo.get('col-1')!.name, 'Original');

      writeSidecar([
        SidecarCollection(id: 'col-1', name: 'Renamed', note: 'v2'),
      ]);
      indexer.reindex(tmpDir.path);
      expect(collectionRepo.get('col-1')!.name, 'Renamed');
    });
  });

  group('duplicate natural keys', () {
    test('two charts with identical (jd, lat, lon) can coexist', () {
      final twin = ChartDoc(
        jd: newton.jd,
        lat: newton.lat,
        lon: newton.lon,
        name: 'Newton Twin',
      );
      writeChart('newton.toml', newton);
      writeChart('twin.toml', twin);

      final result = indexer.reindex(tmpDir.path);
      expect(result.added, 2);
      expect(result.errors, isEmpty);

      final all = repo.search(limit: 100);
      expect(all, hasLength(2));
    });
  });
}
