import 'package:chart_db_core/chart_db_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chartLibraryProvider = Provider<ChartLibrary>((ref) {
  return ChartLibrary(ChartLibrary.defaultRoot());
});
