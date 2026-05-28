sealed class ChartState {
  const ChartState();
}

class ChartLoading extends ChartState {
  const ChartLoading();
}

class ChartLoaded extends ChartState {
  final String id;
  final Map<String, dynamic> birthData;
  const ChartLoaded({required this.id, required this.birthData});

  ChartLoaded copyWith({String? id, Map<String, dynamic>? birthData}) =>
      ChartLoaded(
        id: id ?? this.id,
        birthData: birthData ?? this.birthData,
      );
}

class ChartError extends ChartState {
  final Object error;
  const ChartError(this.error);
}
