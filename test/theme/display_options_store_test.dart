import 'dart:io';

import 'package:aion/theme/display_options.dart';
import 'package:aion/theme/display_options_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;
  late DisplayOptionsStore store;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('aion_display_test_');
    store = DisplayOptionsStore(configDir: tmpDir.path);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  test('defaults to defaultOptions before load', () {
    expect(store.options, equals(DisplayOptions.defaultOptions));
  });

  test('load from empty dir keeps defaults', () async {
    await store.load();
    expect(store.options, equals(DisplayOptions.defaultOptions));
  });

  test('save creates display.toml', () async {
    await store.save();
    final file = File('${tmpDir.path}/display.toml');
    expect(file.existsSync(), isTrue);
  });

  test('save then load round-trips', () async {
    final custom = DisplayOptions(
      signNames: DisplayOptions.signNamePresets['aditya']!,
      signPresetSource: 'aditya',
      planetNames: DisplayOptions.planetNamePresets['zodiac-sanskrit']!,
      planetPresetSource: 'zodiac-sanskrit',
      useSignGlyphs: true,
      usePlanetGlyphs: false,
      showOuterPlanets: false,
    );
    store.setOptions(custom);
    await store.save();

    final freshStore = DisplayOptionsStore(configDir: tmpDir.path);
    await freshStore.load();
    expect(freshStore.options, equals(custom));
  });

  test('load skips malformed file', () async {
    final file = File('${tmpDir.path}/display.toml');
    file.writeAsStringSync('not [valid toml = ');

    await store.load();
    expect(store.options, equals(DisplayOptions.defaultOptions));
  });

  test('save creates directory if missing', () async {
    final nested = DisplayOptionsStore(configDir: '${tmpDir.path}/sub/dir');
    await nested.save();

    final file = File('${tmpDir.path}/sub/dir/display.toml');
    expect(file.existsSync(), isTrue);
  });

  test('update replaces options', () {
    final custom = DisplayOptions(
      signNames: DisplayOptions.signNamePresets['zodiac-sanskrit']!,
      signPresetSource: 'zodiac-sanskrit',
      planetNames: DisplayOptions.defaultOptions.planetNames,
      showOuterPlanets: false,
    );
    store.setOptions(custom);
    expect(store.options, equals(custom));
  });
}
