import 'dart:io';

import 'package:chart_db/chart_db.dart';
import 'package:logging/logging.dart';

void main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stderr.writeln('Usage: chart_db [--db-path <path>]');
    stderr.writeln('  --db-path  Path to SQLite database file');
    stderr.writeln('             (or set CHART_DB_PATH env var)');
    exit(0);
  }

  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    stderr.writeln(
        '[${record.level.name}] ${record.loggerName}: ${record.message}');
  });

  String? dbPath;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--db-path' && i + 1 < args.length) {
      dbPath = args[++i];
    }
  }
  dbPath ??= Platform.environment['CHART_DB_PATH'];

  await startServer(dbPath: dbPath);
}
