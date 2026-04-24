sealed class SlotState {
  const SlotState();
}

class SlotIdle extends SlotState {
  const SlotIdle();
}

class SlotLoading extends SlotState {
  final Map<String, dynamic> options;
  const SlotLoading(this.options);
}

class SlotReady extends SlotState {
  final Map<String, dynamic> data;
  final Map<String, dynamic> options;
  const SlotReady(this.data, this.options);
}

class SlotError extends SlotState {
  final Object error;
  final Map<String, dynamic> options;
  const SlotError(this.error, this.options);
}
