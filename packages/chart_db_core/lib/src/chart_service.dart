import 'chart_repository.dart';
import 'config_repository.dart';
import 'vec_store.dart';
import 'vector_extractor.dart';
import 'vector_schema.dart';

/// Callback type for computing a chart given ephemeris inputs.
///
/// Injected by the caller — either vayu in-process or drishti via MCP.
/// Returns the chart JSON map (same format as drishti formatter output).
typedef CalculateChart = Future<Map<String, dynamic>> Function(
  double jd,
  double lat,
  double lon,
  String presetJson,
);

/// Orchestrates chart lifecycle operations that span multiple repositories.
///
/// Write-side coordinator: create/delete charts with automatic vector
/// management, recompute vectors after config changes, and migrate schemas.
/// For read-side queries, use [ChartRepository.search] directly.
class ChartService {
  ChartService({
    required ChartRepository chartRepository,
    required ConfigRepository configRepository,
    required VectorSchemaRepository vectorSchemaRepository,
    required VecStore vecStore,
    required CalculateChart calculateChart,
  })  : _chartRepo = chartRepository,
        _configRepo = configRepository,
        _schemaRepo = vectorSchemaRepository,
        _vecStore = vecStore,
        _calculateChart = calculateChart;

  final ChartRepository _chartRepo;
  final ConfigRepository _configRepo;
  final VectorSchemaRepository _schemaRepo;
  final VecStore _vecStore;
  final CalculateChart _calculateChart;

  /// Creates a chart and computes vectors for the specified (or all) configs.
  ///
  /// 1. Inserts the chart via [ChartRepository.insert].
  /// 2. For each config that has a vector schema, computes the chart,
  ///    extracts a vector, and stores it.
  ///
  /// If [configIds] is null, uses all registered configs.
  /// Configs without a vector schema are silently skipped.
  ///
  /// Returns the chart id.
  Future<String> createChart(Chart chart, {List<String>? configIds}) async {
    final chartId = _chartRepo.insert(chart);

    final configs = _resolveConfigs(configIds);

    for (final config in configs) {
      if (config.vectorSchemaId == null) continue;

      final schema = _schemaRepo.get(config.vectorSchemaId!);
      if (schema == null) continue;

      final chartJson = await _calculateChart(
        chart.jd,
        chart.lat,
        chart.lon,
        config.preset,
      );

      final vector = extractVector(chartJson, schema.spec);

      _vecStore.ensureTable(schema);
      _vecStore.insertVector(schema.id, chartId, config.id, vector);
    }

    return chartId;
  }

  /// Deletes a chart and removes all associated vectors.
  ///
  /// Iterates over all configs with a vector schema to clean up vec tables,
  /// then deletes the chart (which cascades tags and collection memberships).
  Future<void> deleteChart(String chartId) async {
    final configs = _resolveConfigs(null);

    for (final config in configs) {
      if (config.vectorSchemaId == null) continue;

      final schema = _schemaRepo.get(config.vectorSchemaId!);
      if (schema == null) continue;

      _vecStore.deleteVectors(schemaId: schema.id, chartId: chartId);
    }

    _chartRepo.delete(chartId);
  }

  /// Recomputes all vectors for a specific config.
  ///
  /// Deletes existing vectors for the config, then recomputes from scratch
  /// for every chart in the database. Useful after a preset change or
  /// when vector extraction logic has been updated.
  ///
  /// Throws [StateError] if the config or its schema is not found.
  Future<void> recomputeVectors(String configId) async {
    final config = _configRepo.get(configId);
    if (config == null) {
      throw StateError('Config "$configId" not found');
    }
    final schemaId = config.vectorSchemaId;
    if (schemaId == null) {
      throw StateError('Config "$configId" has no vector schema assigned');
    }
    final schema = _schemaRepo.get(schemaId);
    if (schema == null) {
      throw StateError('Vector schema "$schemaId" not found');
    }

    // Ensure the table exists before attempting to delete or insert.
    _vecStore.ensureTable(schema);

    // Delete all existing vectors for this config.
    _vecStore.deleteVectors(schemaId: schema.id, configId: configId);

    // Recompute for every chart.
    final charts = _chartRepo.search(limit: 1 << 30);

    for (final chart in charts) {
      final chartJson = await _calculateChart(
        chart.jd,
        chart.lat,
        chart.lon,
        config.preset,
      );

      final vector = extractVector(chartJson, schema.spec);
      _vecStore.insertVector(schema.id, chart.id, configId, vector);
    }
  }

  /// Migrates a config from its current vector schema to [newSchemaId].
  ///
  /// 1. Updates the config's schema FK (returns old schema id).
  /// 2. Deletes vectors under the old schema for this config.
  /// 3. Recomputes vectors with the new schema.
  /// 4. Drops the old schema's vec table if no other vectors remain.
  Future<void> migrateSchema(String configId, String newSchemaId) async {
    final oldSchemaId = _configRepo.updateSchema(configId, newSchemaId);

    // Clean up old vectors if there was a previous schema.
    if (oldSchemaId != null) {
      _vecStore.deleteVectors(schemaId: oldSchemaId, configId: configId);
    }

    // Recompute vectors with the new schema.
    await recomputeVectors(configId);

    // Drop old table if it's now empty.
    if (oldSchemaId != null) {
      _dropTableIfEmpty(oldSchemaId);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Resolves config ids to Config objects. If [configIds] is null, returns
  /// all configs.
  List<Config> _resolveConfigs(List<String>? configIds) {
    if (configIds == null) {
      return _configRepo.list().map((cws) => cws.config).toList();
    }
    final configs = <Config>[];
    for (final id in configIds) {
      final config = _configRepo.get(id);
      if (config != null) {
        configs.add(config);
      }
    }
    return configs;
  }

  /// Drops a vec table if no config still references the given schema.
  void _dropTableIfEmpty(String schemaId) {
    final allConfigs = _configRepo.list();
    final stillReferenced = allConfigs.any(
      (cws) => cws.config.vectorSchemaId == schemaId,
    );
    if (!stillReferenced) {
      _vecStore.dropTable(schemaId);
    }
  }
}
