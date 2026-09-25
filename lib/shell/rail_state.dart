import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rail sections that open a flyout. Only one flyout is open at a time.
enum RailSection { catalog, slots, workspaces, time, settings }

/// Tapping the open section closes it; tapping another switches to it.
RailSection? toggleRailSection(RailSection? open, RailSection tapped) =>
    open == tapped ? null : tapped;

class RailNotifier extends Notifier<RailSection?> {
  @override
  RailSection? build() => null;

  void toggle(RailSection section) => state = toggleRailSection(state, section);

  void close() => state = null;
}

/// The currently open rail flyout, or null.
final railProvider = NotifierProvider<RailNotifier, RailSection?>(
  RailNotifier.new,
);
