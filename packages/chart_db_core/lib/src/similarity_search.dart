import 'dart:math';
import 'dart:typed_data';

import 'config_repository.dart';
import 'vec_store.dart';
import 'vector_schema.dart';

/// A chart that is similar to a query chart, with its distance score.
class SimilarChart {
  SimilarChart({required this.chartId, required this.distance});

  /// The id of the similar chart.
  final String chartId;

  /// Distance from the query chart (0.0 = identical, higher = more different).
  final double distance;
}

/// Finds charts similar to a given query chart using vector similarity search.
///
/// Coordinates between [ConfigRepository], [VectorSchemaRepository], and
/// [VecStore] to look up the query chart's vector, optionally apply dimension
/// weights, and return ranked results.
class SimilaritySearch {
  SimilaritySearch({
    required ConfigRepository configRepository,
    required VectorSchemaRepository vectorSchemaRepository,
    required VecStore vecStore,
  })  : _configRepo = configRepository,
        _schemaRepo = vectorSchemaRepository,
        _vecStore = vecStore;

  final ConfigRepository _configRepo;
  final VectorSchemaRepository _schemaRepo;
  final VecStore _vecStore;

  /// Finds charts similar to [chartId] under the given [configId].
  ///
  /// If [weights] is provided, each dimension of the query vector is multiplied
  /// by its corresponding weight (defaulting to 1.0 for unspecified dims) and
  /// the result is re-normalized before searching. This lets callers emphasize
  /// or suppress specific features.
  ///
  /// Returns up to [k] results, excluding the query chart itself.
  ///
  /// Throws [StateError] if the config or its vector schema is not found.
  /// Returns an empty list if the query chart has no stored vector.
  List<SimilarChart> findSimilar(
    String chartId,
    String configId, {
    Map<int, double>? weights,
    int k = 20,
  }) {
    // 1. Look up config to get the vector schema id.
    final config = _configRepo.get(configId);
    if (config == null) {
      throw StateError('Config "$configId" not found');
    }
    final schemaId = config.vectorSchemaId;
    if (schemaId == null) {
      throw StateError(
        'Config "$configId" has no vector schema assigned',
      );
    }

    // 2. Look up schema (validates it exists).
    final schema = _schemaRepo.get(schemaId);
    if (schema == null) {
      throw StateError('Vector schema "$schemaId" not found');
    }

    // 3. Load the query chart's vector.
    final queryVector = _vecStore.getVector(schemaId, chartId, configId);
    if (queryVector == null) {
      return [];
    }

    // 4. Apply weights if provided.
    final searchVector =
        weights != null ? _applyWeights(queryVector, weights) : queryVector;

    // 5. KNN search (k+1 because the query chart will appear in results).
    final results = _vecStore.knn(schemaId, configId, searchVector, k + 1);

    // 6. Filter out the query chart and take top-k.
    return results
        .where((r) => r.chartId != chartId)
        .take(k)
        .map((r) => SimilarChart(chartId: r.chartId, distance: r.distance))
        .toList();
  }

  /// Multiplies each dimension by its weight and re-normalizes to unit length.
  Float64List _applyWeights(Float64List vector, Map<int, double> weights) {
    final weighted = Float64List(vector.length);
    for (var i = 0; i < vector.length; i++) {
      weighted[i] = vector[i] * (weights[i] ?? 1.0);
    }
    // Re-normalize to unit length.
    var norm = 0.0;
    for (var i = 0; i < weighted.length; i++) {
      norm += weighted[i] * weighted[i];
    }
    norm = sqrt(norm);
    if (norm > 0) {
      for (var i = 0; i < weighted.length; i++) {
        weighted[i] /= norm;
      }
    }
    return weighted;
  }
}
