import 'package:aion/canvas/background_layer.dart';
import 'package:aion/theme/preset_store.dart';
import 'package:aion/theme/theme_preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _bgColoredBox() => find.descendant(
  of: find.byType(BackgroundLayer),
  matching: find.byType(ColoredBox),
);

Widget _harness(PresetStore store) {
  return ProviderScope(
    overrides: [
      presetStoreProvider.overrideWith(() => _FixedPresetNotifier(store)),
    ],
    child: const MaterialApp(home: SizedBox.expand(child: BackgroundLayer())),
  );
}

class _FixedPresetNotifier extends AsyncNotifier<PresetStore>
    implements PresetStoreNotifier {
  _FixedPresetNotifier(this._store);
  final PresetStore _store;

  @override
  Future<PresetStore> build() async => _store;

  @override
  void setActive(String name) {}

  @override
  Future<void> saveUserPreset(ThemePreset preset) async {}
}

void main() {
  group('BackgroundLayer', () {
    testWidgets('renders solid color for dark preset', (tester) async {
      final store = PresetStore(configDir: '/tmp');
      await tester.pumpWidget(_harness(store));
      await tester.pumpAndSettle();

      final box = tester.widget<ColoredBox>(_bgColoredBox());
      expect(box.color, equals(ThemePreset.dark.backgroundColor));
    });

    testWidgets('renders solid color for light preset', (tester) async {
      final store = PresetStore(configDir: '/tmp');
      store.setActive('light');
      await tester.pumpWidget(_harness(store));
      await tester.pumpAndSettle();

      final box = tester.widget<ColoredBox>(_bgColoredBox());
      expect(box.color, equals(ThemePreset.light.backgroundColor));
    });
  });
}
