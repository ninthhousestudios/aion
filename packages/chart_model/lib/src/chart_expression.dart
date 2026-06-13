class ChartExpression {
  final List<Planet> planets;
  final Ascendant ascendant;
  final List<House> houses;
  final AscMc? ascmc;

  const ChartExpression({
    required this.planets,
    required this.ascendant,
    required this.houses,
    this.ascmc,
  });

  factory ChartExpression.fromJson(Map<String, dynamic> json) {
    final planetsRaw = json['planets'];
    if (planetsRaw is! List) {
      throw FormatException('Missing or invalid "planets" in expression JSON');
    }
    final ascendantRaw = json['ascendant'];
    if (ascendantRaw is! Map<String, dynamic>) {
      throw FormatException(
        'Missing or invalid "ascendant" in expression JSON',
      );
    }
    final housesRaw = json['houses'];
    if (housesRaw is! List) {
      throw FormatException('Missing or invalid "houses" in expression JSON');
    }
    final ascmcRaw = json['ascmc'];

    return ChartExpression(
      planets: planetsRaw
          .cast<Map<String, dynamic>>()
          .map(Planet.fromJson)
          .toList(),
      ascendant: Ascendant.fromJson(ascendantRaw),
      houses: housesRaw
          .cast<Map<String, dynamic>>()
          .map(House.fromJson)
          .toList(),
      ascmc: ascmcRaw is Map<String, dynamic> ? AscMc.fromJson(ascmcRaw) : null,
    );
  }
}

class Planet {
  final String id;
  final String name;
  final double longitude;
  final String sign;
  final int signIndex;
  final double degreeInSign;
  final bool retrograde;
  final String nakshatra;
  final int nakshatraPada;
  final int house;
  final String? dignity;

  const Planet({
    required this.id,
    required this.name,
    required this.longitude,
    required this.sign,
    required this.signIndex,
    required this.degreeInSign,
    required this.retrograde,
    required this.nakshatra,
    required this.nakshatraPada,
    required this.house,
    this.dignity,
  });

  factory Planet.fromJson(Map<String, dynamic> json) {
    return Planet(
      id: json['id'] as String,
      name: json['name'] as String,
      longitude: (json['longitude'] as num).toDouble(),
      sign: json['sign'] as String,
      signIndex: json['sign_index'] as int,
      degreeInSign: (json['degree_in_sign'] as num).toDouble(),
      retrograde: json['retrograde'] as bool,
      nakshatra: json['nakshatra'] as String,
      nakshatraPada: json['nakshatra_pada'] as int,
      house: json['house'] as int,
      dignity: json['dignity'] as String?,
    );
  }
}

class Ascendant {
  final int signIndex;
  final double longitude;

  const Ascendant({required this.signIndex, required this.longitude});

  factory Ascendant.fromJson(Map<String, dynamic> json) {
    return Ascendant(
      signIndex: json['sign_index'] as int,
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class House {
  final int number;
  final int signIndex;
  final double cuspLongitude;

  const House({
    required this.number,
    required this.signIndex,
    required this.cuspLongitude,
  });

  factory House.fromJson(Map<String, dynamic> json) {
    return House(
      number: json['number'] as int,
      signIndex: json['sign_index'] as int,
      cuspLongitude: (json['cusp_longitude'] as num).toDouble(),
    );
  }
}

class AscMc {
  final double armc;
  final double vertex;
  final double equatorialAscendant;
  final double coAscendantKoch;
  final double coAscendantMunkasey;
  final double polarAscendant;

  const AscMc({
    required this.armc,
    required this.vertex,
    required this.equatorialAscendant,
    required this.coAscendantKoch,
    required this.coAscendantMunkasey,
    required this.polarAscendant,
  });

  factory AscMc.fromJson(Map<String, dynamic> json) {
    return AscMc(
      armc: (json['armc'] as num).toDouble(),
      vertex: (json['vertex'] as num).toDouble(),
      equatorialAscendant: (json['equatorial_ascendant'] as num).toDouble(),
      coAscendantKoch: (json['co_ascendant_koch'] as num).toDouble(),
      coAscendantMunkasey: (json['co_ascendant_munkasey'] as num).toDouble(),
      polarAscendant: (json['polar_ascendant'] as num).toDouble(),
    );
  }
}
