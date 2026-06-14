import 'package:chart_db_core/chart_db_core.dart';

import '../mcp/chart_store.dart';

void saveChartEdit(
  ChartStore store,
  ChartLibrary library,
  String chartId,
  ChartDoc doc,
) {
  store.updateChart(chartId, doc);
  library.saveChart(doc, path: chartId);
}
