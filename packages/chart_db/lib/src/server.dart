import 'dart:async';
import 'dart:io';

import 'package:chart_db_core/chart_db_core.dart';
import 'package:logging/logging.dart';
import 'package:mcp_dart/mcp_dart.dart' hide Logger;

import 'tools/create_config.dart';
import 'tools/get_chart.dart';
import 'tools/import_charts.dart';
import 'tools/list_collections.dart';
import 'tools/list_configs.dart';
import 'tools/list_schemas.dart';
import 'tools/search_charts.dart';
import 'tools/similar_charts.dart';

final _log = Logger('ChartDb');

/// Starts the Chart DB MCP server on stdio transport.
///
/// [dbPath] is the path to the SQLite database file.
/// Returns when the server shuts down (via signal or transport close).
Future<void> startServer({String? dbPath}) async {
  final database = ChartDatabase(dbPath);

  final chartRepo = ChartRepository(database.db);
  final collectionRepo = CollectionRepository(database.db);
  final configRepo = ConfigRepository(database.db);
  final schemaRepo = VectorSchemaRepository(database.db);
  final vecStore = VecStore(database.db);
  final similaritySearch = SimilaritySearch(
    configRepository: configRepo,
    vectorSchemaRepository: schemaRepo,
    vecStore: vecStore,
  );

  // Ensure default vector schemas are present.
  schemaRepo.ensureDefaults();

  final server = McpServer(
    Implementation(name: 'chart-db', version: '0.1.0'),
  );

  registerSearchCharts(server, chartRepo);
  registerGetChart(server, chartRepo);
  registerSimilarCharts(server, similaritySearch);
  registerListCollections(server, collectionRepo);
  registerListConfigs(server, configRepo);
  registerListSchemas(server, schemaRepo);
  registerImportCharts(server, chartRepo);
  registerCreateConfig(server, configRepo);

  final transport = StdioServerTransport();
  await server.connect(transport);

  _log.info('Chart DB MCP server started on stdio');

  final done = Completer<void>();

  void shutdown(String signal) {
    if (done.isCompleted) return;
    _log.info('$signal received, shutting down');
    database.close();
    server.close();
    done.complete();
  }

  final sigint = ProcessSignal.sigint.watch().listen((_) => shutdown('SIGINT'));
  StreamSubscription<ProcessSignal>? sigterm;
  if (!Platform.isWindows) {
    sigterm =
        ProcessSignal.sigterm.watch().listen((_) => shutdown('SIGTERM'));
  }

  await done.future;

  sigint.cancel();
  sigterm?.cancel();
}
