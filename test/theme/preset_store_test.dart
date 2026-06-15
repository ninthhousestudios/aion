import 'dart:io';
import 'dart:ui';

import 'package:aion/theme/preset_store.dart';
import 'package:aion/theme/theme_preset.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;
  late PresetStore store;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('aion_preset_test_');
    store = PresetStore(configDir: tmpDir.path);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('listing', () {
    test('lists built-in presets before loading', () {
      final names = store.presets.map((p) => p.name).toList();
      expect(names, contains('dark'));
      expect(names, contains('light'));
      expect(names, contains('immersive'));
    });

    test('built-in presets come first', () {
      final names = store.presets.map((p) => p.name).toList();
      expect(names.indexOf('dark'), lessThan(3));
      expect(names.indexOf('light'), lessThan(3));
      expect(names.indexOf('immersive'), lessThan(3));
    });
  });

  group('active preset', () {
    test('defaults to dark', () {
      expect(store.activePresetName, 'dark');
      expect(store.activePreset, equals(ThemePreset.dark));
    });

    test('setActive switches to built-in', () {
      store.setActive('light');
      expect(store.activePresetName, 'light');
      expect(store.activePreset, equals(ThemePreset.light));
    });

    test('setActive ignores unknown name', () {
      store.setActive('nonexistent');
      expect(store.activePresetName, 'dark');
    });
  });

  group('save and load', () {
    const custom = ThemePreset(
      name: 'midnight',
      backgroundColor: Color(0xFF050510),
      surfaceCard: Color(0xFF101020),
      surfacePanel: Color(0xFF0A0A18),
      surfaceBorderIdle: Color(0x33FFFFFF),
      surfaceBorderHovered: Color(0x66FFFFFF),
      surfaceBorderSelected: Color(0xFFFFFFFF),
      textPrimary: Color(0xFFE0E0E0),
      textSecondary: Color(0xAAE0E0E0),
      textMuted: Color(0x55E0E0E0),
      accentSeed: Color(0xFF3B82F6),
      accentLink: Color(0xFF60A5FA),
      cardOpacity: 0.9,
      statusStripHeight: 5.0,
    );

    test('save writes toml file to config dir', () async {
      await store.saveUserPreset(custom);
      final file = File('${tmpDir.path}/midnight.toml');
      expect(file.existsSync(), isTrue);
    });

    test('load reads saved presets', () async {
      await store.saveUserPreset(custom);

      final freshStore = PresetStore(configDir: tmpDir.path);
      await freshStore.loadUserPresets();

      final names = freshStore.presets.map((p) => p.name).toList();
      expect(names, contains('midnight'));
    });

    test('saved preset round-trips through load', () async {
      await store.saveUserPreset(custom);

      final freshStore = PresetStore(configDir: tmpDir.path);
      await freshStore.loadUserPresets();

      final loaded = freshStore.presets.firstWhere((p) => p.name == 'midnight');
      expect(loaded, equals(custom));
    });

    test('setActive works with user preset after load', () async {
      await store.saveUserPreset(custom);

      final freshStore = PresetStore(configDir: tmpDir.path);
      await freshStore.loadUserPresets();
      freshStore.setActive('midnight');

      expect(freshStore.activePresetName, 'midnight');
      expect(freshStore.activePreset, equals(custom));
    });

    test('load skips malformed toml files', () async {
      final bad = File('${tmpDir.path}/broken.toml');
      bad.writeAsStringSync('this is not [valid toml = ');

      await store.loadUserPresets();
      final userNames = store.presets
          .where((p) => !ThemePreset.builtIn.contains(p))
          .map((p) => p.name);
      expect(userNames, isEmpty);
    });

    test('load handles empty directory', () async {
      await store.loadUserPresets();
      expect(store.presets.length, equals(ThemePreset.builtIn.length));
    });

    test('load handles nonexistent directory', () async {
      final noDir = PresetStore(configDir: '${tmpDir.path}/nope');
      await noDir.loadUserPresets();
      expect(noDir.presets.length, equals(ThemePreset.builtIn.length));
    });

    test('save creates directory if missing', () async {
      final nested = PresetStore(configDir: '${tmpDir.path}/sub/presets');
      await nested.saveUserPreset(custom);

      final file = File('${tmpDir.path}/sub/presets/midnight.toml');
      expect(file.existsSync(), isTrue);
    });
  });

  group('slugify integration', () {
    test('saves with slugified filename', () async {
      const fancy = ThemePreset(
        name: 'My Cool Theme',
        backgroundColor: Color(0xFF000000),
        surfaceCard: Color(0xFF111111),
        surfacePanel: Color(0xFF111111),
        surfaceBorderIdle: Color(0x33FFFFFF),
        surfaceBorderHovered: Color(0x66FFFFFF),
        surfaceBorderSelected: Color(0xFFFFFFFF),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xAAFFFFFF),
        textMuted: Color(0x66FFFFFF),
        accentSeed: Color(0xFF6366F1),
        accentLink: Color(0xFF818CF8),
      );
      await store.saveUserPreset(fancy);

      final file = File('${tmpDir.path}/my-cool-theme.toml');
      expect(file.existsSync(), isTrue);

      final freshStore = PresetStore(configDir: tmpDir.path);
      await freshStore.loadUserPresets();
      final loaded = freshStore.presets.firstWhere(
        (p) => p.name == 'My Cool Theme',
      );
      expect(loaded, equals(fancy));
    });
  });

  group('slug collision', () {
    ThemePreset _makePreset(String name) => ThemePreset(
      name: name,
      backgroundColor: const Color(0xFF000000),
      surfaceCard: const Color(0xFF111111),
      surfacePanel: const Color(0xFF111111),
      surfaceBorderIdle: const Color(0x33FFFFFF),
      surfaceBorderHovered: const Color(0x66FFFFFF),
      surfaceBorderSelected: const Color(0xFFFFFFFF),
      textPrimary: const Color(0xFFFFFFFF),
      textSecondary: const Color(0xAAFFFFFF),
      textMuted: const Color(0x66FFFFFF),
      accentSeed: const Color(0xFF6366F1),
      accentLink: const Color(0xFF818CF8),
    );

    test('two names with same slug get distinct files', () async {
      await store.saveUserPreset(_makePreset('My Theme'));
      await store.saveUserPreset(_makePreset('My-Theme'));

      final freshStore = PresetStore(configDir: tmpDir.path);
      await freshStore.loadUserPresets();

      final names = freshStore.presets
          .map((p) => p.name)
          .where((n) => n.contains('Theme'));
      expect(names, containsAll(['My Theme', 'My-Theme']));
    });

    test('both presets survive reload', () async {
      await store.saveUserPreset(_makePreset('My Theme'));
      await store.saveUserPreset(_makePreset('My-Theme'));

      final freshStore = PresetStore(configDir: tmpDir.path);
      await freshStore.loadUserPresets();

      final userPresets = freshStore.presets
          .where((p) => !ThemePreset.builtIn.contains(p))
          .toList();
      expect(userPresets, hasLength(2));
    });
  });
}
