import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'display_options.dart';

class DisplayOptionsStore {
  DisplayOptionsStore({String? configDir}) : _configDirOverride = configDir;

  final String? _configDirOverride;
  DisplayOptions _options = DisplayOptions.defaultOptions;

  DisplayOptions get options => _options;

  Future<void> load() async {
    final file = File(await _filePath());
    if (!await file.exists()) return;
    try {
      final source = await file.readAsString();
      _options = DisplayOptions.fromToml(source);
    } on Object {
      // Keep defaults on malformed file.
    }
  }

  Future<void> save() async {
    final path = await _filePath();
    final file = File(path);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await file.writeAsString(_options.toToml());
  }

  void setOptions(DisplayOptions options) {
    _options = options;
  }

  Future<String> _filePath() async {
    if (_configDirOverride != null) {
      return '$_configDirOverride/display.toml';
    }
    final appSupport = await getApplicationSupportDirectory();
    return '${appSupport.path}/display.toml';
  }
}

class DisplayOptionsNotifier extends AsyncNotifier<DisplayOptionsStore> {
  @override
  Future<DisplayOptionsStore> build() async {
    final store = DisplayOptionsStore();
    await store.load();
    return store;
  }

  Future<void> setOptions(DisplayOptions options) async {
    final store = state.valueOrNull;
    if (store == null) return;
    store.setOptions(options);
    await store.save();
    state = AsyncData(store);
  }
}

final displayOptionsProvider =
    AsyncNotifierProvider<DisplayOptionsNotifier, DisplayOptionsStore>(
      DisplayOptionsNotifier.new,
    );
