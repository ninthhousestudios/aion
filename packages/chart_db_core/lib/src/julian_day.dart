/// Julian Day conversions (Meeus, *Astronomical Algorithms* ch. 7).
///
/// These operate on **UT-based** Julian Days: the [DateTime] is treated as
/// Universal Time (UTC), with no delta-T / ephemeris-time correction. That
/// correction is the consumer's responsibility at calculation time (e.g. Swiss
/// Ephemeris applies it internally via `swe_calc_ut`).
///
/// Accurate for dates after the Gregorian reform (15 Oct 1582). This is the
/// single canonical home for JD math in aion — importers and the TOML codec
/// both use it (do not re-implement).
library;

/// Convert a [DateTime] to its Julian Day number.
///
/// The DateTime's **wall-clock fields are taken to be UT** as-is — no timezone
/// conversion is applied, so the `isUtc` flag is irrelevant. Callers pass a
/// value whose fields already represent Universal Time.
double dateTimeToJd(DateTime dt) {
  var y = dt.year;
  var m = dt.month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  // The Gregorian calendar took effect 1582-10-15; dates on or after it use the
  // Gregorian correction, earlier dates are Julian (b = 0). This must match the
  // historical switch in [dateTimeFromJd] so the pair round-trips.
  final isGregorian = dt.year > 1582 ||
      (dt.year == 1582 && (dt.month > 10 || (dt.month == 10 && dt.day >= 15)));
  int b;
  if (isGregorian) {
    final a = y ~/ 100;
    b = 2 - a + (a ~/ 4);
  } else {
    b = 0;
  }
  final dayFrac = (dt.hour +
          dt.minute / 60.0 +
          dt.second / 3600.0 +
          dt.millisecond / 3600000.0) /
      24.0;
  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      dt.day +
      dayFrac +
      b -
      1524.5;
}

/// Convert a Julian Day number to a UTC [DateTime] (inverse of [dateTimeToJd]).
DateTime dateTimeFromJd(double jd) {
  final z = (jd + 0.5).floor();
  final f = jd + 0.5 - z;
  int a;
  if (z < 2299161) {
    a = z;
  } else {
    final alpha = ((z - 1867216.25) / 36524.25).floor();
    a = z + 1 + alpha - (alpha ~/ 4);
  }
  final b = a + 1524;
  final c = ((b - 122.1) / 365.25).floor();
  final d = (365.25 * c).floor();
  final e = ((b - d) / 30.6001).floor();

  final day = b - d - (30.6001 * e).floor();
  final month = e < 14 ? e - 1 : e - 13;
  final year = month > 2 ? c - 4716 : c - 4715;

  final totalHours = f * 24.0;
  final hour = totalHours.floor();
  final totalMinutes = (totalHours - hour) * 60.0;
  final minute = totalMinutes.floor();
  final second = ((totalMinutes - minute) * 60.0).round();

  // Normalise via Duration so a rounded 60s rolls over cleanly.
  return DateTime.utc(year, month, day, hour, minute)
      .add(Duration(seconds: second));
}
