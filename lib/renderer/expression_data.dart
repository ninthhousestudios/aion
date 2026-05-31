/// Expression data key constants.
///
/// Renderers read expression data as `Map<String, dynamic>`. This file
/// documents the expected shape so that MCP integration (aion/7) maps
/// drishti output to match.
///
/// Top-level keys:
///   'planets' - List<Map>: each has id, name, longitude, sign, sign_index,
///               degree_in_sign, retrograde, nakshatra, nakshatra_pada, house
///   'ascendant' - Map: sign_index, longitude
///   'houses' - List<Map>: each has number (1-12), sign_index, cusp_longitude
abstract final class ExpressionKeys {
  static const planets = 'planets';
  static const ascendant = 'ascendant';
  static const houses = 'houses';

  static const id = 'id';
  static const name = 'name';
  static const longitude = 'longitude';
  static const sign = 'sign';
  static const signIndex = 'sign_index';
  static const degreeInSign = 'degree_in_sign';
  static const retrograde = 'retrograde';
  static const nakshatra = 'nakshatra';
  static const nakshatraPada = 'nakshatra_pada';
  static const house = 'house';
}
