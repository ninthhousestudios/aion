import 'package:chart_db_core/chart_db_core.dart';
import 'package:mcp_dart/mcp_dart.dart';

CallToolResult errorResult(String message) => CallToolResult(
      content: [TextContent(text: message)],
      isError: true,
    );

Map<String, dynamic> chartToMap(Chart chart) => {
      'id': chart.id,
      'name': chart.name,
      'jd': chart.jd,
      'lat': chart.lat,
      'lon': chart.lon,
      'alt': chart.alt,
      if (chart.gender != null) 'gender': chart.gender,
      if (chart.placename != null) 'placename': chart.placename,
      if (chart.country != null) 'country': chart.country,
      if (chart.utcOffset != null) 'utc_offset': chart.utcOffset,
      if (chart.dstOffset != null) 'dst_offset': chart.dstOffset,
      if (chart.notes != null) 'notes': chart.notes,
      if (chart.rodden != null) 'rodden': chart.rodden,
      if (chart.sourcePath != null) 'source_path': chart.sourcePath,
      'created_at': chart.createdAt.toIso8601String(),
      'updated_at': chart.updatedAt.toIso8601String(),
    };
