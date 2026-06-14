import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

void main() {
  late ChartDatabase chartDb;
  late ChartRepository repo;

  setUp(() {
    chartDb = ChartDatabase();
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
    String name = 'Test Chart',
  }) {
    return Chart(
      id: id,
      jd: jd,
      lat: lat,
      lon: lon,
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('findDuplicates', () {
    test('exact match returns the existing chart', () {
      const jd = 2451545.0;
      const lat = 51.5074;
      const lon = -0.1278;

      repo.insert(_makeChart(jd: jd, lat: lat, lon: lon, name: 'Original'));

      final dupes = repo.findDuplicates(jd, lat, lon);
      expect(dupes, hasLength(1));
      expect(dupes.first.name, 'Original');
    });

    test('near JD match within tolerance is found', () {
      const jd = 2451545.0;
      repo.insert(_makeChart(jd: jd, name: 'Original'));

      // 0.5 seconds offset = 0.5/86400 ≈ 5.8e-6, within 1.2e-5 tolerance
      final dupes = repo.findDuplicates(jd + 5.8e-6, 51.5074, -0.1278);
      expect(dupes, hasLength(1));
    });

    test('JD beyond tolerance is not found', () {
      const jd = 2451545.0;
      repo.insert(_makeChart(jd: jd, name: 'Original'));

      // 2 seconds offset = 2/86400 ≈ 2.3e-5, beyond 1.2e-5 tolerance
      final dupes = repo.findDuplicates(jd + 2.3e-5, 51.5074, -0.1278);
      expect(dupes, isEmpty);
    });

    test('near geo match within tolerance is found', () {
      const lat = 51.5074;
      const lon = -0.1278;
      repo.insert(_makeChart(lat: lat, lon: lon, name: 'Original'));

      // ~5m offset ≈ 0.00005°, within 0.0001° tolerance
      final dupes = repo.findDuplicates(
        2451545.0,
        lat + 0.00005,
        lon - 0.00005,
      );
      expect(dupes, hasLength(1));
    });

    test('geo beyond tolerance is not found', () {
      const lat = 51.5074;
      const lon = -0.1278;
      repo.insert(_makeChart(lat: lat, lon: lon, name: 'Original'));

      // ~20m offset ≈ 0.0002°, beyond 0.0001° tolerance
      final dupes = repo.findDuplicates(2451545.0, lat + 0.0002, lon);
      expect(dupes, isEmpty);
    });

    test('multiple duplicates are all returned', () {
      const jd = 2451545.0;
      const lat = 51.5074;
      const lon = -0.1278;

      repo.insert(_makeChart(jd: jd, lat: lat, lon: lon, name: 'First'));
      repo.insert(_makeChart(jd: jd, lat: lat, lon: lon, name: 'Second'));

      final dupes = repo.findDuplicates(jd, lat, lon);
      expect(dupes, hasLength(2));
      expect(dupes.map((d) => d.name), containsAll(['First', 'Second']));
    });

    test('excludeId omits the specified chart', () {
      const jd = 2451545.0;
      const lat = 51.5074;
      const lon = -0.1278;

      final id1 = repo.insert(
        _makeChart(jd: jd, lat: lat, lon: lon, name: 'A'),
      );
      repo.insert(_makeChart(jd: jd, lat: lat, lon: lon, name: 'B'));

      final dupes = repo.findDuplicates(jd, lat, lon, excludeId: id1);
      expect(dupes, hasLength(1));
      expect(dupes.first.name, 'B');
    });

    test('custom tolerances work', () {
      const jd = 2451545.0;
      repo.insert(_makeChart(jd: jd, name: 'Original'));

      // 5 seconds offset, beyond default but within custom tolerance
      final offset = 5.0 / 86400;
      final dupes = repo.findDuplicates(
        jd + offset,
        51.5074,
        -0.1278,
        jdTolerance: 1.0e-4, // ~8.6 seconds
      );
      expect(dupes, hasLength(1));
    });

    test('no charts in db returns empty', () {
      final dupes = repo.findDuplicates(2451545.0, 51.5074, -0.1278);
      expect(dupes, isEmpty);
    });
  });
}
