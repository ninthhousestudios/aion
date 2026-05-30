/// The portable, on-disk representation of a single Chart, mirroring the
/// `open-astrology-chart` TOML format (see docs/open-astrology-chart-format.md).
///
/// This is the value [TomlChartCodec] encodes to and decodes from. It carries
/// exactly the fields a `.toml` file holds — including [tags], which the DB
/// keeps in a separate join table. It deliberately omits storage bookkeeping
/// (id, timestamps, source path): those belong to the DB row, not the file.
///
/// The natural key is `(jd, lat, lon)`; [jd] is the canonical, authoritative
/// instant (Julian Day, UT). Civil date/time is advisory and is not stored on
/// this type — it is rendered from [jd] on encode and only consulted to derive
/// [jd] when a file omits it.
class ChartDoc {
  const ChartDoc({
    required this.jd,
    required this.lat,
    required this.lon,
    this.alt = 0,
    this.name = '',
    this.gender,
    this.placename,
    this.country,
    this.utcOffset,
    this.dstOffset,
    this.timezone,
    this.notes,
    this.rodden,
    this.tags = const [],
  });

  /// Julian Day (UT). Canonical, authoritative instant.
  final double jd;

  /// Latitude in decimal degrees (positive = north).
  final double lat;

  /// Longitude in decimal degrees (positive = east).
  final double lon;

  /// Altitude in metres above sea level. Not part of the natural key.
  final double alt;

  final String name;
  final String? gender;
  final String? placename;
  final String? country;

  /// Base offset from UTC in hours, east-positive. Advisory.
  final double? utcOffset;

  /// Additional daylight-saving offset in hours. Advisory.
  final double? dstOffset;

  /// Named time-zone label (e.g. "EST", "PDT"). Display-only; never the
  /// source of the numeric offset.
  final String? timezone;

  final String? notes;

  /// Rodden rating of data reliability (e.g. "AA", "A", "DD").
  final String? rodden;

  /// Freeform user labels.
  final List<String> tags;

  /// The natural key identifying the astronomical moment.
  (double, double, double) get naturalKey => (jd, lat, lon);

  ChartDoc copyWith({
    double? jd,
    double? lat,
    double? lon,
    double? alt,
    String? name,
    String? gender,
    String? placename,
    String? country,
    double? utcOffset,
    double? dstOffset,
    String? timezone,
    String? notes,
    String? rodden,
    List<String>? tags,
  }) {
    return ChartDoc(
      jd: jd ?? this.jd,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      alt: alt ?? this.alt,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      placename: placename ?? this.placename,
      country: country ?? this.country,
      utcOffset: utcOffset ?? this.utcOffset,
      dstOffset: dstOffset ?? this.dstOffset,
      timezone: timezone ?? this.timezone,
      notes: notes ?? this.notes,
      rodden: rodden ?? this.rodden,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChartDoc &&
        other.jd == jd &&
        other.lat == lat &&
        other.lon == lon &&
        other.alt == alt &&
        other.name == name &&
        other.gender == gender &&
        other.placename == placename &&
        other.country == country &&
        other.utcOffset == utcOffset &&
        other.dstOffset == dstOffset &&
        other.timezone == timezone &&
        other.notes == notes &&
        other.rodden == rodden &&
        _listEquals(other.tags, tags);
  }

  @override
  int get hashCode => Object.hash(
        jd,
        lat,
        lon,
        alt,
        name,
        gender,
        placename,
        country,
        utcOffset,
        dstOffset,
        timezone,
        notes,
        rodden,
        Object.hashAll(tags),
      );

  @override
  String toString() => 'ChartDoc($name, jd=$jd, lat=$lat, lon=$lon)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
