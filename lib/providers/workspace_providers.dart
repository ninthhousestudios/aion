import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp/slot_state.dart';
import '../mcp/workspace_store.dart';
import 'plugin_host_provider.dart';

final workspaceStoreProvider = Provider<WorkspaceStore>((ref) {
  final store = WorkspaceStore(ref.read(pluginHostProvider));
  ref.onDispose(() => store.dispose());
  return store;
});

final slotProvider = StreamProvider.family<SlotState, String>(
  (ref, name) => ref.watch(workspaceStoreProvider).watch(name),
);
