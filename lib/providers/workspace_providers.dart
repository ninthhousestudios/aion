import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp/expression_ref.dart';
import '../mcp/expression_state.dart';
import '../mcp/workspace_store.dart';
import 'plugin_host_provider.dart';

final workspaceStoreProvider = Provider<WorkspaceStore>((ref) {
  final store = WorkspaceStore(ref.read(pluginHostProvider));
  ref.onDispose(() => store.dispose());
  return store;
});

final expressionProvider = StreamProvider.family<ExpressionState, ExpressionRef>(
  (ref, exprRef) => ref.watch(workspaceStoreProvider).watch(exprRef),
);
