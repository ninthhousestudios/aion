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

    final planets = planetsRaw
        .cast<Map<String, dynamic>>()
        .map(Planet.fromJson)
        .toList();
    final houses = housesRaw
        .cast<Map<String, dynamic>>()
        .map(House.fromJson)
        .toList();

    if (houses.length != 12) {
      throw FormatException('Expected exactly 12 houses, got ${houses.length}');
    }
    final houseNumbers = houses.map((h) => h.number).toSet();
    if (houseNumbers.length != 12 || houseNumbers.any((n) => n < 1 || n > 12)) {
      throw FormatException(
        'House numbers must be exactly 1-12 with no duplicates',
      );
    }

    final planetIds = <String>{};
    for (final p in planets) {
      if (!planetIds.add(p.id)) {
        throw FormatException('Duplicate planet id "${p.id}"');
      }
    }

    return ChartExpression(
      planets: planets,
      ascendant: Ascendant.fromJson(ascendantRaw),
      houses: houses,
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
    final signIndex = json['sign_index'] as int;
    if (signIndex < 0 || signIndex > 11) {
      throw FormatException('Planet sign_index must be 0-11, got $signIndex');
    }
    final nakshatraPada = json['nakshatra_pada'] as int;
    if (nakshatraPada < 1 || nakshatraPada > 4) {
      throw FormatException(
        'Planet nakshatra_pada must be 1-4, got $nakshatraPada',
      );
    }
    return Planet(
      id: json['id'] as String,
      name: json['name'] as String,
      longitude: (json['longitude'] as num).toDouble(),
      sign: (json['sign_name'] ?? json['sign']) as String,
      signIndex: signIndex,
      degreeInSign: (json['degree_in_sign'] as num).toDouble(),
      retrograde: json['retrograde'] as bool,
      nakshatra: (json['nakshatra_name'] ?? json['nakshatra']) as String,
      nakshatraPada: nakshatraPada,
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
    final signIndex = json['sign_index'] as int;
    if (signIndex < 0 || signIndex > 11) {
      throw FormatException(
        'Ascendant sign_index must be 0-11, got $signIndex',
      );
    }
    return Ascendant(
      signIndex: signIndex,
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
    final signIndex = json['sign_index'] as int;
    if (signIndex < 0 || signIndex > 11) {
      throw FormatException('House sign_index must be 0-11, got $signIndex');
    }
    return House(
      number: json['number'] as int,
      signIndex: signIndex,
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
