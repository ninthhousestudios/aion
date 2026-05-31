import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp/chart_store.dart';
import 'plugin_host_provider.dart';

final chartStoreProvider = Provider<ChartStore>((ref) {
  final host = ref.read(pluginHostProvider);
  final store = ChartStore(host);
  ref.onDispose(store.dispose);
  return store;
});
