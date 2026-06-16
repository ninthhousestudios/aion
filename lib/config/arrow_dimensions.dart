import 'config_dimension.dart';

// ---------------------------------------------------------------------------
// Groups (ordered by UI display intent)
// ---------------------------------------------------------------------------

const ayanamsaZodiacGroup = ConfigGroup(
  key: 'ayanamsa_zodiac',
  label: 'Ayanamsa & Zodiac',
  sortOrder: 0,
);

const housesGroup = ConfigGroup(key: 'houses', label: 'Houses', sortOrder: 1);

const bodiesGroup = ConfigGroup(key: 'bodies', label: 'Bodies', sortOrder: 2);

const vedicGroup = ConfigGroup(
  key: 'vedic',
  label: 'Vedic Options',
  sortOrder: 3,
);

const advancedGroup = ConfigGroup(
  key: 'advanced',
  label: 'Advanced',
  sortOrder: 4,
);

const kGroups = [
  ayanamsaZodiacGroup,
  housesGroup,
  bodiesGroup,
  vedicGroup,
  advancedGroup,
];

// ---------------------------------------------------------------------------
// Choice lists
// ---------------------------------------------------------------------------

const _ayanamsaChoices = [
  ConfigChoice(value: 'tropical', label: 'Tropical'),
  ConfigChoice(value: 'fagan', label: 'Fagan/Bradley'),
  ConfigChoice(value: 'lahiri', label: 'Lahiri'),
  ConfigChoice(value: 'deLuce', label: 'De Luce'),
  ConfigChoice(value: 'raman', label: 'Raman'),
  ConfigChoice(value: 'ushashashi', label: 'Usha/Shashi'),
  ConfigChoice(value: 'krishnamurti', label: 'Krishnamurti'),
  ConfigChoice(value: 'djwhalKhul', label: 'Djwhal Khul'),
  ConfigChoice(value: 'yukteswar', label: 'Yukteshwar'),
  ConfigChoice(value: 'jnBhasin', label: 'JN Bhasin'),
  ConfigChoice(value: 'babylKugler1', label: 'Babylonian/Kugler 1'),
  ConfigChoice(value: 'babylKugler2', label: 'Babylonian/Kugler 2'),
  ConfigChoice(value: 'babylKugler3', label: 'Babylonian/Kugler 3'),
  ConfigChoice(value: 'babylHuber', label: 'Babylonian/Huber'),
  ConfigChoice(value: 'babylEtaPsc', label: 'Babylonian/Eta Psc'),
  ConfigChoice(value: 'aldebaran15Tau', label: 'Aldebaran 15 Tau'),
  ConfigChoice(value: 'hipparchus', label: 'Hipparchos'),
  ConfigChoice(value: 'sassanian', label: 'Sassanian'),
  ConfigChoice(value: 'galcent0Sag', label: 'Galactic Center 0 Sag'),
  ConfigChoice(value: 'j2000', label: 'J2000'),
  ConfigChoice(value: 'j1900', label: 'J1900'),
  ConfigChoice(value: 'b1950', label: 'B1950'),
  ConfigChoice(value: 'suryaSiddhanta', label: 'Surya Siddhanta'),
  ConfigChoice(
    value: 'suryaSiddhantaMeanSun',
    label: 'Surya Siddhanta (mean Sun)',
  ),
  ConfigChoice(value: 'aryabhata', label: 'Aryabhata'),
  ConfigChoice(value: 'aryabhataMeanSun', label: 'Aryabhata (mean Sun)'),
  ConfigChoice(value: 'ssRevati', label: 'SS Revati'),
  ConfigChoice(value: 'ssCitra', label: 'SS Citra'),
  ConfigChoice(value: 'trueCitra', label: 'True Citra'),
  ConfigChoice(value: 'trueRevati', label: 'True Revati'),
  ConfigChoice(value: 'truePushya', label: 'True Pushya'),
  ConfigChoice(value: 'galcentRgilbrand', label: 'Galactic Center (Gil Brand)'),
  ConfigChoice(value: 'galequIau1958', label: 'Galactic Equator IAU 1958'),
  ConfigChoice(value: 'galequTrue', label: 'Galactic Equator (true)'),
  ConfigChoice(value: 'galequMula', label: 'Galactic Equator Mula'),
  ConfigChoice(value: 'galalignMardyks', label: 'Galactic Alignment (Mardyks)'),
  ConfigChoice(value: 'trueMula', label: 'True Mula'),
  ConfigChoice(value: 'galCenterMula', label: 'GC Mula (Wilhelm)'),
  ConfigChoice(value: 'aryabhata522', label: 'Aryabhata 522'),
  ConfigChoice(value: 'babylBritton', label: 'Babylonian/Britton'),
  ConfigChoice(value: 'trueSheoran', label: 'True Sheoran'),
  ConfigChoice(value: 'galcentCochrane', label: 'Galactic Center (Cochrane)'),
  ConfigChoice(value: 'galequFiorenza', label: 'Galactic Equator (Fiorenza)'),
  ConfigChoice(value: 'valensMoon', label: 'Vettius Valens Moon'),
  ConfigChoice(value: 'lahiri1940', label: 'Lahiri 1940'),
  ConfigChoice(value: 'lahiriVp285', label: 'Lahiri VP285'),
  ConfigChoice(value: 'krishnamurtiVp291', label: 'Krishnamurti VP291'),
  ConfigChoice(value: 'lahiriIcrc', label: 'Lahiri ICRC'),
  ConfigChoice(value: 'trueSidereal', label: 'True Sidereal'),
  ConfigChoice(value: 'dhruva', label: 'Dhruva GC mid-Mula Equatorial'),
  ConfigChoice(
    value: 'eclipticVedangaJyotisha',
    label: 'Ecliptic Vedanga Jyotisha',
  ),
  ConfigChoice(
    value: 'equatorialVedangaJyotisha',
    label: 'Equatorial Vedanga Jyotisha',
  ),
  ConfigChoice(value: 'equal28Nakshatras', label: '28 Equal Nakshatras'),
];

const _houseSystemChoices = [
  ConfigChoice(value: 'placidus', label: 'Placidus'),
  ConfigChoice(value: 'koch', label: 'Koch'),
  ConfigChoice(value: 'porphyrius', label: 'Porphyrius'),
  ConfigChoice(value: 'regiomontanus', label: 'Regiomontanus'),
  ConfigChoice(value: 'campanus', label: 'Campanus'),
  ConfigChoice(value: 'equalAsc', label: 'Equal (Asc)'),
  ConfigChoice(value: 'vehlowEqual', label: 'Vehlow Equal'),
  ConfigChoice(value: 'wholeSigns', label: 'Whole Sign'),
  ConfigChoice(value: 'meridian', label: 'Meridian'),
  ConfigChoice(value: 'horizon', label: 'Horizon'),
  ConfigChoice(value: 'topocentric', label: 'Polich/Page'),
  ConfigChoice(value: 'alcabitus', label: 'Alcabitus'),
  ConfigChoice(value: 'morinus', label: 'Morinus'),
  ConfigChoice(value: 'krusinski', label: 'Krusinski'),
  ConfigChoice(value: 'equalAries', label: 'Equal (0 Aries)'),
];

const _bodyChoices = [
  ConfigChoice(value: 'sun', label: 'Sun'),
  ConfigChoice(value: 'moon', label: 'Moon'),
  ConfigChoice(value: 'mercury', label: 'Mercury'),
  ConfigChoice(value: 'venus', label: 'Venus'),
  ConfigChoice(value: 'mars', label: 'Mars'),
  ConfigChoice(value: 'jupiter', label: 'Jupiter'),
  ConfigChoice(value: 'saturn', label: 'Saturn'),
  ConfigChoice(value: 'uranus', label: 'Uranus'),
  ConfigChoice(value: 'neptune', label: 'Neptune'),
  ConfigChoice(value: 'pluto', label: 'Pluto'),
  ConfigChoice(value: 'chiron', label: 'Chiron'),
  ConfigChoice(value: 'rahu', label: 'Rahu'),
  ConfigChoice(value: 'ketu', label: 'Ketu'),
];

const _starChoices = [
  // Nakshatra junction stars (yogatara)
  ConfigChoice(value: 'sheratan', label: 'Sheratan'),
  ConfigChoice(value: 'fortyOneArietis', label: '41 Arietis'),
  ConfigChoice(value: 'alcyone', label: 'Alcyone'),
  ConfigChoice(value: 'aldebaran', label: 'Aldebaran'),
  ConfigChoice(value: 'meissa', label: 'Meissa'),
  ConfigChoice(value: 'betelgeuse', label: 'Betelgeuse'),
  ConfigChoice(value: 'pollux', label: 'Pollux'),
  ConfigChoice(value: 'asellus', label: 'Asellus'),
  ConfigChoice(value: 'epsilonHydrae', label: 'Epsilon Hydrae'),
  ConfigChoice(value: 'regulus', label: 'Regulus'),
  ConfigChoice(value: 'zosma', label: 'Zosma'),
  ConfigChoice(value: 'denebola', label: 'Denebola'),
  ConfigChoice(value: 'algorab', label: 'Algorab'),
  ConfigChoice(value: 'spica', label: 'Spica'),
  ConfigChoice(value: 'arcturus', label: 'Arcturus'),
  ConfigChoice(value: 'zubenelgenubi', label: 'Zubenelgenubi'),
  ConfigChoice(value: 'dschubba', label: 'Dschubba'),
  ConfigChoice(value: 'antares', label: 'Antares'),
  ConfigChoice(value: 'shaula', label: 'Shaula'),
  ConfigChoice(value: 'kausMedia', label: 'Kaus Media'),
  ConfigChoice(value: 'nunki', label: 'Nunki'),
  ConfigChoice(value: 'altair', label: 'Altair'),
  ConfigChoice(value: 'rotanev', label: 'Rotanev'),
  ConfigChoice(value: 'lambdaAquarii', label: 'Lambda Aquarii'),
  ConfigChoice(value: 'markab', label: 'Markab'),
  ConfigChoice(value: 'algenib', label: 'Algenib'),
  ConfigChoice(value: 'zetaPiscium', label: 'Zeta Piscium'),
  // Bright/navigational stars
  ConfigChoice(value: 'sirius', label: 'Sirius'),
  ConfigChoice(value: 'canopus', label: 'Canopus'),
  ConfigChoice(value: 'rigel', label: 'Rigel'),
  ConfigChoice(value: 'procyon', label: 'Procyon'),
  ConfigChoice(value: 'achernar', label: 'Achernar'),
  ConfigChoice(value: 'capella', label: 'Capella'),
  ConfigChoice(value: 'vega', label: 'Vega'),
  ConfigChoice(value: 'rigilKentaurus', label: 'Rigil Kentaurus'),
  ConfigChoice(value: 'castor', label: 'Castor'),
  ConfigChoice(value: 'fomalhaut', label: 'Fomalhaut'),
  ConfigChoice(value: 'deneb', label: 'Deneb'),
  ConfigChoice(value: 'mimosa', label: 'Mimosa'),
  ConfigChoice(value: 'acrux', label: 'Acrux'),
  ConfigChoice(value: 'hamal', label: 'Hamal'),
  ConfigChoice(value: 'polaris', label: 'Polaris'),
  ConfigChoice(value: 'bellatrix', label: 'Bellatrix'),
  ConfigChoice(value: 'elNath', label: 'El Nath'),
  ConfigChoice(value: 'alnilam', label: 'Alnilam'),
  ConfigChoice(value: 'alnitak', label: 'Alnitak'),
  ConfigChoice(value: 'mintaka', label: 'Mintaka'),
  ConfigChoice(value: 'alhena', label: 'Alhena'),
  ConfigChoice(value: 'alphard', label: 'Alphard'),
  ConfigChoice(value: 'rasalhague', label: 'Rasalhague'),
  ConfigChoice(value: 'sabik', label: 'Sabik'),
  ConfigChoice(value: 'zubeneschamali', label: 'Zubeneschamali'),
  // 13-constellation boundary stars
  ConfigChoice(value: 'mesarthim', label: 'Mesarthim'),
  ConfigChoice(value: 'botein', label: 'Botein'),
  ConfigChoice(value: 'omicronTauri', label: 'Omicron Tauri'),
  ConfigChoice(value: 'zetaTauri', label: 'Zeta Tauri'),
  ConfigChoice(value: 'oneGeminorum', label: '1 Geminorum'),
  ConfigChoice(value: 'kappaGeminorum', label: 'Kappa Geminorum'),
  ConfigChoice(value: 'chiCancri', label: 'Chi Cancri'),
  ConfigChoice(value: 'acubens', label: 'Acubens'),
  ConfigChoice(value: 'kappaLeonis', label: 'Kappa Leonis'),
  ConfigChoice(value: 'nuVirginis', label: 'Nu Virginis'),
  ConfigChoice(value: 'muVirginis', label: 'Mu Virginis'),
  ConfigChoice(value: 'fortyEightLibrae', label: '48 Librae'),
  ConfigChoice(value: 'tauScorpii', label: 'Tau Scorpii'),
  ConfigChoice(value: 'fortyFiveOphiuchi', label: '45 Ophiuchi'),
  ConfigChoice(value: 'nash', label: 'Nash'),
  ConfigChoice(value: 'omegaSagittarii', label: 'Omega Sagittarii'),
  ConfigChoice(value: 'dabih', label: 'Dabih'),
  ConfigChoice(value: 'denebAlgedi', label: 'Deneb Algedi'),
  ConfigChoice(value: 'iotaAquarii', label: 'Iota Aquarii'),
  ConfigChoice(value: 'phiAquarii', label: 'Phi Aquarii'),
  ConfigChoice(value: 'gammaPiscium', label: 'Gamma Piscium'),
  ConfigChoice(value: 'alrescha', label: 'Alrescha'),
  // Deep-sky/special
  ConfigChoice(value: 'galacticCenter', label: 'Galactic Center'),
];

const _circleChoices = [
  ConfigChoice(value: 'aditya', label: 'Aditya'),
  ConfigChoice(value: 'zodiac', label: 'Zodiac'),
];

const _zodiacSystemChoices = [
  ConfigChoice(value: 'tropical12', label: 'Tropical 12-sign'),
  ConfigChoice(value: 'sidereal12', label: 'Sidereal 12-sign'),
  ConfigChoice(
    value: 'trueSidereal13',
    label: 'True Sidereal 13-constellation',
  ),
];

const _ephemerisSourceChoices = [
  ConfigChoice(value: 'swissEph', label: 'Swiss Ephemeris'),
  ConfigChoice(value: 'moshier', label: 'Moshier'),
  ConfigChoice(value: 'jplEph', label: 'JPL Ephemeris'),
];

const _referencePointChoices = [
  ConfigChoice(value: 'geocentric', label: 'Geocentric'),
  ConfigChoice(value: 'barycentric', label: 'Barycentric'),
  ConfigChoice(value: 'heliocentric', label: 'Heliocentric'),
];

const _dashaYearLengthChoices = [
  ConfigChoice(value: 'saura', label: 'Saura (365.24 days)'),
  ConfigChoice(value: 'nakshatra', label: 'Nakshatra (359.02 days)'),
  ConfigChoice(value: 'savana', label: 'Savana (360 days)'),
  ConfigChoice(value: 'sidereal', label: 'Sidereal (365.26 days)'),
  ConfigChoice(value: 'chandra', label: 'Chandra (364.29 days)'),
  ConfigChoice(value: 'lunar', label: 'Lunar (354.37 days)'),
];

const _charaKarakaCountChoices = [
  ConfigChoice(value: '7', label: '7 (standard)'),
  ConfigChoice(value: '8', label: '8 (with Rahu)'),
];

const _rashiAspectModeChoices = [
  ConfigChoice(value: 'quadrant', label: 'Quadrant'),
  ConfigChoice(value: 'element', label: 'Element'),
  ConfigChoice(value: 'conventional', label: 'Conventional'),
];

const _traditionChoices = [ConfigChoice(value: 'vedic', label: 'Vedic')];

// ---------------------------------------------------------------------------
// Dimensions — defaults from ArrowPresets.ernst
// ---------------------------------------------------------------------------

// -- Ayanamsa & Zodiac ------------------------------------------------------

const signAyanamsa = ConfigDimension(
  key: 'signAyanamsa',
  name: 'Sign Ayanamsa',
  group: ayanamsaZodiacGroup,
  type: ConfigDimensionType.enumPick,
  defaultValue: 'tropical',
  choices: _ayanamsaChoices,
  cost: ConfigCost.expensive,
);

const nakAyanamsa = ConfigDimension(
  key: 'nakAyanamsa',
  name: 'Nakshatra Ayanamsa',
  group: ayanamsaZodiacGroup,
  type: ConfigDimensionType.enumPick,
  defaultValue: 'dhruva',
  choices: _ayanamsaChoices,
  cost: ConfigCost.expensive,
);

const circle = ConfigDimension(
  key: 'circle',
  name: 'Circle',
  group: ayanamsaZodiacGroup,
  type: ConfigDimensionType.enumPick,
  defaultValue: 'aditya',
  choices: _circleChoices,
  cost: ConfigCost.cheap,
);

const zodiacSystem = ConfigDimension(
  key: 'zodiacSystem',
  name: 'Zodiac System',
  group: ayanamsaZodiacGroup,
  type: ConfigDimensionType.enumPick,
  defaultValue: 'tropical12',
  choices: _zodiacSystemChoices,
  cost: ConfigCost.cheap,
);

const nakEquatorial = ConfigDimension(
  key: 'nakEquatorial',
  name: 'Equatorial Nakshatras',
  group: ayanamsaZodiacGroup,
  type: ConfigDimensionType.boolean,
  defaultValue: true,
  cost: ConfigCost.cheap,
);

// -- Houses -----------------------------------------------------------------

const houseSystem = ConfigDimension(
  key: 'houseSystem',
  name: 'House System',
  group: housesGroup,
  type: ConfigDimensionType.enumPick,
  defaultValue: 'campanus',
  choices: _houseSystemChoices,
  cost: ConfigCost.expensive,
);

// -- Bodies -----------------------------------------------------------------

const bodies = ConfigDimension(
  key: 'bodies',
  name: 'Planets',
  group: bodiesGroup,
  type: ConfigDimensionType.multiSelect,
  defaultValue: <String>{
    'sun',
    'moon',
    'mercury',
    'venus',
    'mars',
    'jupiter',
    'saturn',
    'rahu',
    'ketu',
  },
  choices: _bodyChoices,
  cost: ConfigCost.expensive,
);

const trueNode = ConfigDimension(
  key: 'trueNode',
  name: 'True Node',
  group: bodiesGroup,
  type: ConfigDimensionType.boolean,
  defaultValue: true,
  cost: ConfigCost.expensive,
);

const stars = ConfigDimension(
  key: 'stars',
  name: 'Fixed Stars',
  group: bodiesGroup,
  type: ConfigDimensionType.multiSelect,
  defaultValue: <String>{},
  choices: _starChoices,
  cost: ConfigCost.expensive,
);

// -- Vedic Options ----------------------------------------------------------

const dashaYearLength = ConfigDimension(
  key: 'dashaYearLength',
  name: 'Dasha Year Length',
  group: vedicGroup,
  type: ConfigDimensionType.enumPick,
  defaultValue: 'saura',
  choices: _dashaYearLengthChoices,
  cost: ConfigCost.cheap,
);

const charaKarakaCount = ConfigDimension(
  key: 'charaKarakaCount',
  name: 'Chara Karaka Count',
  group: vedicGroup,
  type: ConfigDimensionType.enumPick,
  defaultValue: '7',
  choices: _charaKarakaCountChoices,
  cost: ConfigCost.cheap,
);

const rashiAspectMode = ConfigDimension(
  key: 'rashiAspectMode',
  name: 'Rashi Aspect Mode',
  group: vedicGroup,
  type: ConfigDimensionType.enumPick,
  defaultValue: 'quadrant',
  choices: _rashiAspectModeChoices,
  cost: ConfigCost.cheap,
);

// -- Advanced ---------------------------------------------------------------

const topocentric = ConfigDimension(
  key: 'topocentric',
  name: 'Topocentric Correction',
  group: advancedGroup,
  type: ConfigDimensionType.boolean,
  defaultValue: false,
  cost: ConfigCost.expensive,
);

const ephemerisSource = ConfigDimension(
  key: 'ephemerisSource',
  name: 'Ephemeris Source',
  group: advancedGroup,
  type: ConfigDimensionType.enumPick,
  defaultValue: 'swissEph',
  choices: _ephemerisSourceChoices,
  cost: ConfigCost.expensive,
);

const extraFrames = ConfigDimension(
  key: 'extraFrames',
  name: 'Reference Frames',
  group: advancedGroup,
  type: ConfigDimensionType.multiSelect,
  defaultValue: <String>{},
  choices: _referencePointChoices,
  cost: ConfigCost.expensive,
);

const traditions = ConfigDimension(
  key: 'traditions',
  name: 'Traditions',
  group: advancedGroup,
  type: ConfigDimensionType.multiSelect,
  defaultValue: <String>{'vedic'},
  choices: _traditionChoices,
  cost: ConfigCost.cheap,
);

// ---------------------------------------------------------------------------
// Aggregate access
// ---------------------------------------------------------------------------

const kDimensions = [
  // Ayanamsa & Zodiac
  signAyanamsa,
  nakAyanamsa,
  circle,
  zodiacSystem,
  nakEquatorial,
  // Houses
  houseSystem,
  // Bodies
  bodies,
  trueNode,
  stars,
  // Vedic Options
  dashaYearLength,
  charaKarakaCount,
  rashiAspectMode,
  // Advanced
  topocentric,
  ephemerisSource,
  extraFrames,
  traditions,
];

List<ConfigDimension> dimensionsForGroup(ConfigGroup group) =>
    kDimensions.where((d) => d.group == group).toList();
