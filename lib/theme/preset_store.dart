import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'theme_preset.dart';

class PresetStore {
  PresetStore({String? configDir}) : _configDirOverride = configDir;

  final String? _configDirOverride;
  final Map<String, ThemePreset> _userPresets = {};
  String _activePresetName = 'dark';

  List<ThemePreset> get presets => [
    ...ThemePreset.builtIn,
    ..._userPresets.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
  ];

  String get activePresetName => _activePresetName;

  ThemePreset get activePreset {
    final builtIn = ThemePreset.builtIn.where(
      (p) => p.name == _activePresetName,
    );
    if (builtIn.isNotEmpty) return builtIn.first;
    return _userPresets[_activePresetName] ?? ThemePreset.dark;
  }

  Future<void> loadUserPresets() async {
    final dir = Directory(await _presetsPath());
    if (!await dir.exists()) return;

    _userPresets.clear();
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.toml')) continue;
      try {
        final source = await entity.readAsString();
        final preset = ThemePreset.fromToml(source);
        _userPresets[preset.name] = preset;
      } on Object {
        // Skip malformed preset files.
      }
    }
  }

  void setActive(String name) {
    final all = {
      for (final p in ThemePreset.builtIn) p.name: p,
      ..._userPresets,
    };
    if (all.containsKey(name)) {
      _activePresetName = name;
    }
  }

  Future<void> saveUserPreset(ThemePreset preset) async {
    final dir = Directory(await _presetsPath());
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final slug = ThemePreset.slugify(preset.name);
    final file = File('${dir.path}/$slug.toml');
    await file.writeAsString(preset.toToml());
    _userPresets[preset.name] = preset;
  }

  Future<String> _presetsPath() async {
    if (_configDirOverride != null) return _configDirOverride!;
    final appSupport = await getApplicationSupportDirectory();
    return '${appSupport.path}/presets';
  }
}

class PresetStoreNotifier extends AsyncNotifier<PresetStore> {
  @override
  Future<PresetStore> build() async {
    final store = PresetStore();
    await store.loadUserPresets();
    return store;
  }

  void setActive(String name) {
    final store = state.valueOrNull;
    if (store == null) return;
    store.setActive(name);
    state = AsyncData(store);
  }

  Future<void> saveUserPreset(ThemePreset preset) async {
    final store = state.valueOrNull;
    if (store == null) return;
    await store.saveUserPreset(preset);
    state = AsyncData(store);
  }
}

final presetStoreProvider =
    AsyncNotifierProvider<PresetStoreNotifier, PresetStore>(
      PresetStoreNotifier.new,
    );
