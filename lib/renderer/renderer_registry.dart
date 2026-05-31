import 'chart_renderer.dart';

class RendererRegistry {
  final _renderers = <String, ChartRenderer>{};

  void register(ChartRenderer renderer) {
    _renderers[renderer.meta.id] = renderer;
  }

  ChartRenderer? get(String id) => _renderers[id];

  List<ChartRenderer> forSystem(String system) => _renderers.values
      .where(
        (r) => r.meta.systems.isEmpty || r.meta.systems.contains(system),
      )
      .toList();

  List<ChartRenderer> get all => _renderers.values.toList();
}
