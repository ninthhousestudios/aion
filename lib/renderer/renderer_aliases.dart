/// Domain alias table for view search: the shorthand astrologers type.
///
/// Renderers attach aliases through `RendererMeta.aliases`, usually by
/// spreading entries from here, so "d9" finds a Navamsa renderer and "vim"
/// a Vimshottari one as soon as those renderers exist.
library;

/// Divisional charts (vargas): code → names.
const kVargaAliases = <String, List<String>>{
  'd1': ['rasi', 'rashi', 'lagna', 'natal'],
  'd2': ['hora'],
  'd3': ['drekkana', 'drekkanamsa'],
  'd4': ['chaturthamsa', 'turyamsa'],
  'd5': ['panchamsa'],
  'd6': ['shashthamsa'],
  'd7': ['saptamsa'],
  'd8': ['ashtamsa'],
  'd9': ['navamsa', 'navamsha'],
  'd10': ['dasamsa', 'dashamsha'],
  'd11': ['rudramsa', 'ekadasamsa'],
  'd12': ['dwadasamsa', 'dvadashamsha'],
  'd16': ['shodasamsa', 'kalamsa'],
  'd20': ['vimsamsa'],
  'd24': ['chaturvimsamsa', 'siddhamsa'],
  'd27': ['bhamsa', 'saptavimsamsa', 'nakshatramsa'],
  'd30': ['trimsamsa'],
  'd40': ['khavedamsa'],
  'd45': ['akshavedamsa'],
  'd60': ['shashtiamsa', 'shashtyamsa'],
};

/// Dasha systems: name → abbreviations.
const kDashaAliases = <String, List<String>>{
  'vimshottari': ['vim', 'vimsottari', 'vd'],
  'ashtottari': ['ash', 'asht'],
  'yogini': ['yog'],
  'chara': ['char', 'jaimini'],
  'kalachakra': ['kal', 'kcd'],
  'narayana': ['nar'],
  'shoola': ['shool'],
  'moola': ['mool'],
};

/// Aliases for varga [code] ("d9"): the code itself plus its names.
List<String> vargaAliases(String code) => [
  code,
  ...?kVargaAliases[code.toLowerCase()],
];

/// Aliases for dasha system [name]: the name plus its abbreviations.
List<String> dashaAliases(String name) => [
  name,
  ...?kDashaAliases[name.toLowerCase()],
];
