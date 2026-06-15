import 'package:collection/collection.dart';
import 'package:toml/toml.dart';

class DisplayOptions {
  const DisplayOptions({
    required this.signNames,
    this.signPresetSource,
    required this.planetNames,
    this.planetPresetSource,
    this.useSignGlyphs = false,
    this.usePlanetGlyphs = false,
    this.showOuterPlanets = true,
  });

  final List<String> signNames;
  final String? signPresetSource;

  final Map<String, String> planetNames;
  final String? planetPresetSource;

  final bool useSignGlyphs;
  final bool usePlanetGlyphs;
  final bool showOuterPlanets;

  static const defaultOptions = DisplayOptions(
    signNames: _tropicalWesternSigns,
    signPresetSource: 'tropical-western',
    planetNames: _tropicalWesternPlanets,
    planetPresetSource: 'tropical-western',
  );

  String signName(int index) {
    if (index < 0 || index >= signNames.length) return '?';
    return signNames[index];
  }

  String planetName(String id) {
    return planetNames[id] ?? id;
  }

  // -- Sign name presets ---------------------------------------------------

  static const signNamePresets = <String, List<String>>{
    'tropical-western': _tropicalWesternSigns,
    'aditya': _adityaSigns,
    'zodiac-sanskrit': _zodiacSanskritSigns,
  };

  static const _tropicalWesternSigns = [
    'Aries',
    'Taurus',
    'Gemini',
    'Cancer',
    'Leo',
    'Virgo',
    'Libra',
    'Scorpio',
    'Sagittarius',
    'Capricorn',
    'Aquarius',
    'Pisces',
  ];

  static const _adityaSigns = [
    'Dhata',
    'Aryama',
    'Mitra',
    'Varuna',
    'Indra',
    'Vivasvan',
    'Tvashta',
    'Vishnu',
    'Amshu',
    'Bhaga',
    'Pusha',
    'Parjanya',
  ];

  static const _zodiacSanskritSigns = [
    'Meṣa',
    'Vṛṣabha',
    'Mithuna',
    'Karkaṭa',
    'Siṃha',
    'Kanyā',
    'Tulā',
    'Vṛścika',
    'Dhanus',
    'Makara',
    'Kumbha',
    'Mīna',
  ];

  // -- Planet name presets -------------------------------------------------

  static const planetNamePresets = <String, Map<String, String>>{
    'tropical-western': _tropicalWesternPlanets,
    'zodiac-sanskrit': _zodiacSanskritPlanets,
  };

  static const _defaultPlanetIds = [
    'sun',
    'moon',
    'mercury',
    'venus',
    'mars',
    'jupiter',
    'saturn',
    'rahu',
    'ketu',
    'uranus',
    'neptune',
    'pluto',
    'chiron',
  ];

  static const _tropicalWesternPlanets = {
    'sun': 'Sun',
    'moon': 'Moon',
    'mercury': 'Mercury',
    'venus': 'Venus',
    'mars': 'Mars',
    'jupiter': 'Jupiter',
    'saturn': 'Saturn',
    'rahu': 'Rahu',
    'ketu': 'Ketu',
    'uranus': 'Uranus',
    'neptune': 'Neptune',
    'pluto': 'Pluto',
    'chiron': 'Chiron',
  };

  static const _zodiacSanskritPlanets = {
    'sun': 'Sūrya',
    'moon': 'Candra',
    'mercury': 'Budha',
    'venus': 'Śukra',
    'mars': 'Maṅgala',
    'jupiter': 'Guru',
    'saturn': 'Śani',
    'rahu': 'Rāhu',
    'ketu': 'Ketu',
    'uranus': 'Uranus',
    'neptune': 'Neptune',
    'pluto': 'Pluto',
    'chiron': 'Chiron',
  };

  // -- TOML ----------------------------------------------------------------

  factory DisplayOptions.fromToml(String source) {
    final doc = TomlDocument.parse(source).toMap();

    final signPresetSource = doc['sign_preset'] as String?;
    final planetPresetSource = doc['planet_preset'] as String?;

    List<String> signNames;
    final signSection = doc['sign_names'] as Map<String, dynamic>?;
    if (signSection != null && signSection['names'] is List) {
      final raw = (signSection['names'] as List).cast<String>();
      signNames = (raw.length == 12 && raw.every((n) => n.isNotEmpty))
          ? raw
          : _tropicalWesternSigns;
    } else if (signPresetSource != null &&
        signNamePresets.containsKey(signPresetSource)) {
      signNames = signNamePresets[signPresetSource]!;
    } else {
      signNames = _tropicalWesternSigns;
    }

    Map<String, String> planetNameMap;
    final planetSection = doc['planet_names'] as Map<String, dynamic>?;
    if (planetSection != null && planetSection.isNotEmpty) {
      planetNameMap = planetSection.map((k, v) => MapEntry(k, v.toString()));
    } else if (planetPresetSource != null &&
        planetNamePresets.containsKey(planetPresetSource)) {
      planetNameMap = planetNamePresets[planetPresetSource]!;
    } else {
      planetNameMap = _tropicalWesternPlanets;
    }

    return DisplayOptions(
      signNames: signNames,
      signPresetSource: signPresetSource,
      planetNames: planetNameMap,
      planetPresetSource: planetPresetSource,
      useSignGlyphs: doc['use_sign_glyphs'] as bool? ?? false,
      usePlanetGlyphs: doc['use_planet_glyphs'] as bool? ?? false,
      showOuterPlanets: doc['show_outer_planets'] as bool? ?? true,
    );
  }

  String toToml() {
    final buf = StringBuffer();

    if (signPresetSource != null) {
      buf.writeln('sign_preset = "${_esc(signPresetSource!)}"');
    }
    if (planetPresetSource != null) {
      buf.writeln('planet_preset = "${_esc(planetPresetSource!)}"');
    }
    buf.writeln('use_sign_glyphs = $useSignGlyphs');
    buf.writeln('use_planet_glyphs = $usePlanetGlyphs');
    buf.writeln('show_outer_planets = $showOuterPlanets');

    buf.writeln();
    buf.writeln('[sign_names]');
    buf.write('names = [');
    buf.write(signNames.map((n) => '"${_esc(n)}"').join(', '));
    buf.writeln(']');

    buf.writeln();
    buf.writeln('[planet_names]');
    for (final id in _defaultPlanetIds) {
      if (planetNames.containsKey(id)) {
        buf.writeln('"${_esc(id)}" = "${_esc(planetNames[id]!)}"');
      }
    }
    for (final id in planetNames.keys) {
      if (!_defaultPlanetIds.contains(id)) {
        buf.writeln('"${_esc(id)}" = "${_esc(planetNames[id]!)}"');
      }
    }

    return buf.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayOptions &&
          const ListEquality<String>().equals(signNames, other.signNames) &&
          signPresetSource == other.signPresetSource &&
          const MapEquality<String, String>().equals(
            planetNames,
            other.planetNames,
          ) &&
          planetPresetSource == other.planetPresetSource &&
          useSignGlyphs == other.useSignGlyphs &&
          usePlanetGlyphs == other.usePlanetGlyphs &&
          showOuterPlanets == other.showOuterPlanets;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(signNames),
    signPresetSource,
    Object.hashAll(planetNames.entries.map((e) => Object.hash(e.key, e.value))),
    planetPresetSource,
    useSignGlyphs,
    usePlanetGlyphs,
    showOuterPlanets,
  );

  static String _esc(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
  }
}
