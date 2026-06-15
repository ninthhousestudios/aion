import 'package:collection/collection.dart';

class CardDisplayOverrides {
  const CardDisplayOverrides({
    this.useSignGlyphs,
    this.usePlanetGlyphs,
    this.showOuterPlanets,
    this.signNames,
  });

  final bool? useSignGlyphs;
  final bool? usePlanetGlyphs;
  final bool? showOuterPlanets;
  final List<String>? signNames;

  static const empty = CardDisplayOverrides();

  bool get isEmpty =>
      useSignGlyphs == null &&
      usePlanetGlyphs == null &&
      showOuterPlanets == null &&
      signNames == null;

  static const Object _unset = Object();

  CardDisplayOverrides copyWith({
    Object? useSignGlyphs = _unset,
    Object? usePlanetGlyphs = _unset,
    Object? showOuterPlanets = _unset,
    Object? signNames = _unset,
  }) {
    return CardDisplayOverrides(
      useSignGlyphs: identical(useSignGlyphs, _unset)
          ? this.useSignGlyphs
          : useSignGlyphs as bool?,
      usePlanetGlyphs: identical(usePlanetGlyphs, _unset)
          ? this.usePlanetGlyphs
          : usePlanetGlyphs as bool?,
      showOuterPlanets: identical(showOuterPlanets, _unset)
          ? this.showOuterPlanets
          : showOuterPlanets as bool?,
      signNames: identical(signNames, _unset)
          ? this.signNames
          : signNames as List<String>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardDisplayOverrides &&
          useSignGlyphs == other.useSignGlyphs &&
          usePlanetGlyphs == other.usePlanetGlyphs &&
          showOuterPlanets == other.showOuterPlanets &&
          const ListEquality<String>().equals(signNames, other.signNames);

  @override
  int get hashCode => Object.hash(
    useSignGlyphs,
    usePlanetGlyphs,
    showOuterPlanets,
    signNames == null ? null : Object.hashAll(signNames!),
  );
}
