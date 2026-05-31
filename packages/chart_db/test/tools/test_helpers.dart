import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

Chart makeChart({
  String id = '',
  double jd = 2451545.0,
  double lat = 51.5074,
  double lon = -0.1278,
  double alt = 0,
  String name = 'Test Chart',
  String? gender = 'M',
  String? placename = 'London',
  String? country = 'England',
  double? utcOffset = 0,
  double? dstOffset = 0,
  String? notes,
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
    createdAt: DateTime.utc(2025, 1, 1),
    updatedAt: DateTime.utc(2025, 1, 1),
  );
}

String errorText(CallToolResult result) {
  return (result.content.first as TextContent).text;
}
