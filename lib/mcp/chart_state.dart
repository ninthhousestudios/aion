import 'package:chart_db_core/chart_db_core.dart';

sealed class ChartState {
  const ChartState();
}

class ChartLoading extends ChartState {
  const ChartLoading();
}

class ChartLoaded extends ChartState {
  final String id;
  final ChartDoc doc;
  const ChartLoaded({required this.id, required this.doc});

  ChartLoaded copyWith({String? id, ChartDoc? doc}) =>
      ChartLoaded(
        id: id ?? this.id,
        doc: doc ?? this.doc,
      );
}

class ChartError extends ChartState {
  final Object error;
  const ChartError(this.error);
}
