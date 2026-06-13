import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../renderer/data_table/data_table_renderer.dart';
import '../renderer/renderer_registry.dart';
import '../renderer/south_indian/south_indian_renderer.dart';

final rendererRegistryProvider = Provider<RendererRegistry>((ref) {
  return RendererRegistry()
    ..register(SouthIndianRenderer())
    ..register(DataTableRenderer());
});
