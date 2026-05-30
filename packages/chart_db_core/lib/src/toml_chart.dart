import 'dart:io';

import 'package:toml/toml.dart';

import 'chart_doc.dart';
import 'julian_day.dart';

/// Reads and writes the `open-astrology-chart` TOML format.
///
/// See docs/open-astrology-chart-format.md for the normative spec. The key
/// invariants this codec upholds:
///
///  * `[moment].jd` is the canonical instant. It is always emitted at full
///    `double` precision and is the value [decode] trusts.
///  * `[civil]` is advisory. [encode] renders it from `jd` + offsets for human
///    eyes; [decode] consults `civil.date`/`civil.time` only to *derive* `jd`
///    when a file omits `[moment].jd` (authoring convenience, §6).
///  * Field order is stable, so `decode(encode(doc))` and a subsequent
///    `encode` are byte-identical (§7).
class TomlChartCodec {
  const TomlChartCodec._();

  /// The spec marker every conforming file carries.
  static const String specMarker = 'open-astrology-chart';

  /// The spec version this codec produces and is the only version it accepts.
  static const int specVersion = 1;

  /// Encode [doc] to a TOML document string.
  static String encode(ChartDoc doc) {
    final map = <String, dynamic>{
      'spec': specMarker,
      'spec_version': specVersion,
    };

    // Top-level metadata, omitted when empty.
    if (doc.name.isNotEmpty) map['name'] = doc.name;
    if (doc.gender != null) map['gender'] = doc.gender;
    if (doc.rodden != null) map['rodden'] = doc.rodden;
    if (doc.tags.isNotEmpty) map['tags'] = List<String>.from(doc.tags);
    if (doc.notes != null) map['notes'] = doc.notes;

    // Canonical moment.
    map['moment'] = <String, dynamic>{'jd': doc.jd};

    // Location.
    final location = <String, dynamic>{
      'lat': doc.lat,
      'lon': doc.lon,
    };
    if (doc.alt != 0) location['alt'] = doc.alt;
    if (doc.placename != null) location['placename'] = doc.placename;
    if (doc.country != null) location['country'] = doc.country;
    map['location'] = location;

    // Advisory civil block, rendered from the canonical jd + offsets.
    map['civil'] = _renderCivil(doc);

    return TomlDocument.fromMap(map).toString();
  }

  /// Decode a TOML document [source] into a [ChartDoc].
  ///
  /// Throws [FormatException] if the spec marker is missing or wrong, the
  /// version is unsupported, required fields are absent, or `jd` can neither
  /// be read nor derived.
  static ChartDoc decode(String source) {
    final Map<String, dynamic> map;
    try {
      map = TomlDocument.parse(source).toMap();
    } on Exception catch (e) {
      throw FormatException('Not valid TOML: $e');
    }

    final spec = map['spec'];
    if (spec != specMarker) {
      throw FormatException(
        'Not an open-astrology-chart file: spec = ${spec ?? '(missing)'}',
      );
    }
    final version = map['spec_version'];
    if (version != specVersion) {
      throw FormatException(
        'Unsupported spec_version: ${version ?? '(missing)'} '
        '(this codec supports $specVersion)',
      );
    }

    final moment = map['moment'] as Map<String, dynamic>?;
    final location = map['location'] as Map<String, dynamic>?;
    final civil = map['civil'] as Map<String, dynamic>?;

    if (location == null) {
      throw const FormatException('Missing required [location] table');
    }
    final lat = _asDouble(location['lat']);
    final lon = _asDouble(location['lon']);
    if (lat == null || lon == null) {
      throw const FormatException(
        'Missing required location.lat / location.lon',
      );
    }

    final utcOffset = _asDouble(civil?['utc_offset']);
    final dstOffset = _asDouble(civil?['dst_offset']);

    // jd is canonical; fall back to deriving it from the civil block (§6).
    var jd = _asDouble(moment?['jd']);
    jd ??= _deriveJd(civil, utcOffset, dstOffset);
    if (jd == null) {
      throw const FormatException(
        'No moment.jd and no derivable [civil] date/time to compute it',
      );
    }

    return ChartDoc(
      jd: jd,
      lat: lat,
      lon: lon,
      alt: _asDouble(location['alt']) ?? 0,
      name: (map['name'] as String?) ?? '',
      gender: map['gender'] as String?,
      placename: location['placename'] as String?,
      country: location['country'] as String?,
      utcOffset: utcOffset,
      dstOffset: dstOffset,
      timezone: civil?['timezone'] as String?,
      notes: map['notes'] as String?,
      rodden: map['rodden'] as String?,
      tags: _asStringList(map['tags']),
    );
  }

  /// Read and decode a chart file at [path].
  static ChartDoc decodeFile(String path) =>
      decode(File(path).readAsStringSync());

  /// Encode [doc] and write it to [path].
  static void encodeFile(String path, ChartDoc doc) =>
      File(path).writeAsStringSync(encode(doc));

  /// Build the advisory `[civil]` table from the canonical jd plus offsets.
  static Map<String, dynamic> _renderCivil(ChartDoc doc) {
    final totalOffsetHours = (doc.utcOffset ?? 0) + (doc.dstOffset ?? 0);
    // dateTimeFromJd yields the UT wall-clock; shift into local civil time.
    final utc = dateTimeFromJd(doc.jd);
    final local = utc.add(
      Duration(milliseconds: (totalOffsetHours * 3600000).round()),
    );

    final civil = <String, dynamic>{
      'date': '${_d4(local.year)}-${_d2(local.month)}-${_d2(local.day)}',
      'time': '${_d2(local.hour)}:${_d2(local.minute)}:${_d2(local.second)}',
    };
    if (doc.utcOffset != null) civil['utc_offset'] = doc.utcOffset;
    if (doc.dstOffset != null) civil['dst_offset'] = doc.dstOffset;
    if (doc.timezone != null) civil['timezone'] = doc.timezone;
    return civil;
  }

  /// Derive a jd from an advisory civil block (authoring convenience, §6).
  static double? _deriveJd(
    Map<String, dynamic>? civil,
    double? utcOffset,
    double? dstOffset,
  ) {
    if (civil == null) return null;
    final date = civil['date'] as String?;
    final time = civil['time'] as String?;
    if (date == null) return null;

    final dParts = date.split('-');
    if (dParts.length != 3) return null;
    final year = int.tryParse(dParts[0]);
    final month = int.tryParse(dParts[1]);
    final day = int.tryParse(dParts[2]);
    if (year == null || month == null || day == null) return null;

    var hour = 0, minute = 0, second = 0;
    if (time != null) {
      final tParts = time.split(':');
      hour = int.tryParse(tParts[0]) ?? 0;
      minute = tParts.length > 1 ? int.tryParse(tParts[1]) ?? 0 : 0;
      second = tParts.length > 2 ? int.tryParse(tParts[2]) ?? 0 : 0;
    }

    // The civil fields are local wall-clock; subtract the offset to reach UT,
    // then read those UT fields as-is via dateTimeToJd.
    final totalOffsetHours = (utcOffset ?? 0) + (dstOffset ?? 0);
    final local = DateTime.utc(year, month, day, hour, minute, second);
    final ut = local.subtract(
      Duration(milliseconds: (totalOffsetHours * 3600000).round()),
    );
    return dateTimeToJd(ut);
  }

  static double? _asDouble(Object? v) =>
      v is num ? v.toDouble() : null;

  static List<String> _asStringList(Object? v) {
    if (v is List) {
      return v.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  static String _d2(int n) => n.toString().padLeft(2, '0');
  static String _d4(int n) => n.toString().padLeft(4, '0');
}
