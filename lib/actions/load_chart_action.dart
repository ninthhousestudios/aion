import 'package:chart_db_core/chart_db_core.dart';
import 'package:file_selector/file_selector.dart';

import '../mcp/chart_store.dart';

sealed class LoadChartResult {
  const LoadChartResult();
}

class ChartLoadedOk extends LoadChartResult {
  final String chartId;
  final ChartDoc doc;
  const ChartLoadedOk(this.chartId, this.doc);
}

class ChartLoadCancelled extends LoadChartResult {
  const ChartLoadCancelled();
}

class ChartLoadFailed extends LoadChartResult {
  final String message;
  const ChartLoadFailed(this.message);
}

Future<LoadChartResult> loadChartFromFile(ChartStore store) async {
  const typeGroup = XTypeGroup(label: 'Chart files', extensions: ['toml']);
  final file = await openFile(acceptedTypeGroups: [typeGroup]);
  if (file == null) return const ChartLoadCancelled();

  try {
    final doc = TomlChartCodec.decodeFile(file.path);
    final chartId = file.path;
    store.loadChart(chartId, doc);
    return ChartLoadedOk(chartId, doc);
  } on FormatException catch (e) {
    return ChartLoadFailed(e.message);
  }
}
