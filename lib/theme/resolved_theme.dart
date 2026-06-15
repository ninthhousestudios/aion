import 'aion_theme.dart';
import 'display_options.dart';

class ResolvedTheme {
  const ResolvedTheme({
    required this.theme,
    required this.displayOptions,
    required this.cardOpacity,
  });

  final AionTheme theme;
  final DisplayOptions displayOptions;
  final double cardOpacity;
}
