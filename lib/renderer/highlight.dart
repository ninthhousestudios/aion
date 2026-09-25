/// Entities a renderer can highlight. Part of the renderer contract:
/// painters receive the set of highlighted entities and render emphasis.
sealed class HighlightEntity {
  const HighlightEntity();
}

class PlanetEntity extends HighlightEntity {
  const PlanetEntity(this.planetId);

  final String planetId;

  @override
  bool operator ==(Object other) =>
      other is PlanetEntity && other.planetId == planetId;

  @override
  int get hashCode => Object.hash('planet', planetId);

  @override
  String toString() => 'PlanetEntity($planetId)';
}

class HouseEntity extends HighlightEntity {
  const HouseEntity(this.houseNumber);

  /// 1-based.
  final int houseNumber;

  @override
  bool operator ==(Object other) =>
      other is HouseEntity && other.houseNumber == houseNumber;

  @override
  int get hashCode => Object.hash('house', houseNumber);

  @override
  String toString() => 'HouseEntity($houseNumber)';
}

class SignEntity extends HighlightEntity {
  const SignEntity(this.signIndex);

  /// 0 = Aries.
  final int signIndex;

  @override
  bool operator ==(Object other) =>
      other is SignEntity && other.signIndex == signIndex;

  @override
  int get hashCode => Object.hash('sign', signIndex);

  @override
  String toString() => 'SignEntity($signIndex)';
}
