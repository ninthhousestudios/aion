import 'package:chart_db_core/chart_db_core.dart';
import 'package:test/test.dart';

void main() {
  group('dateTimeToJd', () {
    test('J2000.0 epoch: 2000-01-01T12:00:00Z = JD 2451545.0', () {
      expect(
        dateTimeToJd(DateTime.utc(2000, 1, 1, 12)),
        closeTo(2451545.0, 1e-9),
      );
    });

    test('Unix epoch: 1970-01-01T00:00:00Z = JD 2440587.5', () {
      expect(
        dateTimeToJd(DateTime.utc(1970, 1, 1)),
        closeTo(2440587.5, 1e-9),
      );
    });

    test('Feb date exercises the y-1/m+12 branch', () {
      expect(
        dateTimeToJd(DateTime.utc(1985, 2, 17, 6)),
        closeTo(2446113.75, 1e-9),
      );
    });

    test('reads wall-clock fields as UT, ignoring the isUtc flag', () {
      // A local-flagged DateTime and a UTC one with the same wall-clock
      // fields must yield the same JD — no timezone shift is applied.
      expect(
        dateTimeToJd(DateTime(2000, 1, 1, 12)),
        dateTimeToJd(DateTime.utc(2000, 1, 1, 12)),
      );
    });
  });

  group('dateTimeFromJd', () {
    test('inverts J2000.0', () {
      expect(dateTimeFromJd(2451545.0), DateTime.utc(2000, 1, 1, 12));
    });

    test('inverts Unix epoch', () {
      expect(dateTimeFromJd(2440587.5), DateTime.utc(1970, 1, 1));
    });
  });

  group('round-trip', () {
    final samples = [
      DateTime.utc(1989, 12, 14, 20, 8, 0),
      DateTime.utc(1, 1, 1, 0, 0, 0),
      DateTime.utc(2026, 5, 30, 4, 0, 0),
      DateTime.utc(1582, 10, 15, 12, 0, 0),
      DateTime.utc(2000, 2, 29, 23, 59, 59),
    ];

    for (final dt in samples) {
      test('datetime -> jd -> datetime preserves $dt to the second', () {
        final back = dateTimeFromJd(dateTimeToJd(dt));
        // Meeus is second-resolution; allow 1s slack for rounding.
        expect(
          back.difference(dt).inSeconds.abs(),
          lessThanOrEqualTo(1),
        );
      });
    }
  });
}
