import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../canvas/workspace_notifier.dart';
import '../slots/slot_state.dart';
import '../theme/theme_preset.dart';
import 'starter_workspaces.dart';
import 'workspace.dart';

/// Persists user workspaces as TOML files in the config directory
/// (`<app support>/workspaces/`), alongside theme presets.
class WorkspaceStore {
  WorkspaceStore({String? configDir}) : _configDirOverride = configDir;

  final String? _configDirOverride;

  Future<String> _dirPath() async {
    if (_configDirOverride case final dir?) return dir;
    final appSupport = await getApplicationSupportDirectory();
    return '${appSupport.path}/workspaces';
  }

  String _fileName(String name) => '${ThemePreset.slugify(name)}.toml';

  /// All readable workspaces; malformed files are skipped.
  Future<List<Workspace>> loadAll() async {
    final dir = Directory(await _dirPath());
    if (!await dir.exists()) return const [];
    final out = <Workspace>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.toml')) continue;
      try {
        out.add(Workspace.fromToml(await entity.readAsString()));
      } on Object {
        // Skip malformed workspace files.
      }
    }
    return out..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> save(Workspace workspace) async {
    final dir = Directory(await _dirPath());
    if (!await dir.exists()) await dir.create(recursive: true);
    await File(
      '${dir.path}/${_fileName(workspace.name)}',
    ).writeAsString(workspace.toToml());
  }

  /// Remembers the last active workspace (plain text, not `.toml`, so
  /// [loadAll] ignores it).
  Future<void> saveActiveName(String name) async {
    final dir = Directory(await _dirPath());
    if (!await dir.exists()) await dir.create(recursive: true);
    await File('${dir.path}/active.txt').writeAsString(name);
  }

  Future<String?> loadActiveName() async {
    final file = File('${await _dirPath()}/active.txt');
    if (!await file.exists()) return null;
    final name = (await file.readAsString()).trim();
    return name.isEmpty ? null : name;
  }

  Future<void> delete(String name) async {
    final file = File('${await _dirPath()}/${_fileName(name)}');
    if (await file.exists()) await file.delete();
  }
}

/// Starter and user workspaces plus which one is active.
class WorkspaceLibrary {
  const WorkspaceLibrary({
    this.starters = const [],
    this.user = const [],
    this.activeName,
  });

  final List<Workspace> starters;
  final List<Workspace> user;
  final String? activeName;

  List<Workspace> get all => [...starters, ...user];

  Workspace? byName(String name) =>
      all.where((w) => w.name == name).firstOrNull;

  bool isStarter(String name) => starters.any((w) => w.name == name);

  static const Object _unset = Object();

  WorkspaceLibrary copyWith({
    List<Workspace>? user,
    Object? activeName = _unset,
  }) => WorkspaceLibrary(
    starters: starters,
    user: user ?? this.user,
    activeName: identical(activeName, _unset)
        ? this.activeName
        : activeName as String?,
  );
}

/// Workspace to open at startup: the remembered one if it still exists,
/// else the first starter (else the first user workspace).
String? initialWorkspaceName(WorkspaceLibrary library, String? remembered) {
  if (remembered != null && library.byName(remembered) != null) {
    return remembered;
  }
  return library.all.firstOrNull?.name;
}

/// Why a save/rename was refused.
enum WorkspaceNameError { empty, starter, exists }

WorkspaceNameError? validateWorkspaceName(
  WorkspaceLibrary library,
  String name,
) {
  if (name.trim().isEmpty) return WorkspaceNameError.empty;
  if (library.isStarter(name.trim())) return WorkspaceNameError.starter;
  return null;
}

class WorkspaceLibraryNotifier extends AsyncNotifier<WorkspaceLibrary> {
  WorkspaceStore get _store => ref.read(workspaceStoreProvider);

  String? _rememberedActive;

  @override
  Future<WorkspaceLibrary> build() async {
    final user = await _store.loadAll();
    _rememberedActive = await _store.loadActiveName();
    return WorkspaceLibrary(
      starters: ref.read(starterWorkspacesProvider),
      user: user,
    );
  }

  /// Startup: if the canvas is empty, open the last active workspace, or
  /// the first starter on first launch — so aion opens as a working
  /// instrument, not an empty canvas.
  Future<void> openInitial() async {
    final lib = await future;
    if (ref.read(workspaceProvider).cards.isNotEmpty) return;
    final name = initialWorkspaceName(lib, _rememberedActive);
    if (name != null) load(name);
  }

  WorkspaceLibrary get _lib =>
      state.valueOrNull ??
      WorkspaceLibrary(starters: ref.read(starterWorkspacesProvider));

  /// Saves the current canvas as a user workspace named [name]
  /// (overwriting a user workspace of that name). Starter names are
  /// refused — save-as forks under a new name instead.
  Future<WorkspaceNameError?> saveCurrentAs(String name) async {
    final error = validateWorkspaceName(_lib, name);
    if (error != null) return error;
    final trimmed = name.trim();
    final ws = Workspace.fromCards(trimmed, ref.read(workspaceProvider).cards);
    await _store.save(ws);
    state = AsyncData(
      _lib.copyWith(
        user: [..._lib.user.where((w) => w.name != trimmed), ws]
          ..sort((a, b) => a.name.compareTo(b.name)),
        activeName: trimmed,
      ),
    );
    return null;
  }

  /// Renames user workspace [from] to [to]. Starters can't be renamed, and
  /// [to] must not clash with another workspace.
  Future<WorkspaceNameError?> rename(String from, String to) async {
    final lib = _lib;
    final ws = lib.user.where((w) => w.name == from).firstOrNull;
    if (ws == null) return WorkspaceNameError.starter;
    final error = validateWorkspaceName(lib, to);
    if (error != null) return error;
    final name = to.trim();
    if (name == from) return null;
    if (lib.byName(name) != null) return WorkspaceNameError.exists;
    final renamed = ws.copyWith(name: name);
    await _store.save(renamed);
    await _store.delete(from);
    state = AsyncData(
      lib.copyWith(
        user: [
          for (final w in lib.user)
            if (w.name == from) renamed else w,
        ]..sort((a, b) => a.name.compareTo(b.name)),
        activeName: lib.activeName == from ? name : lib.activeName,
      ),
    );
    return null;
  }

  /// Deletes user workspace [name] (starters are read-only). The canvas is
  /// left as is.
  Future<void> delete(String name) async {
    final lib = _lib;
    if (!lib.user.any((w) => w.name == name)) return;
    await _store.delete(name);
    state = AsyncData(
      lib.copyWith(
        user: lib.user.where((w) => w.name != name).toList(),
        activeName: lib.activeName == name ? null : lib.activeName,
      ),
    );
  }

  /// Replaces the canvas with workspace [name]. Slots are untouched, so
  /// loaded charts flow into the new layout.
  void load(String name) {
    final ws = _lib.byName(name);
    if (ws == null) return;
    applyWorkspace(ref, ws);
    state = AsyncData(_lib.copyWith(activeName: name));
    _store.saveActiveName(name).ignore();
  }
}

/// Lays [ws] out on the canvas, resolving its cards against live slots.
void applyWorkspace(Ref ref, Workspace ws) {
  final slots = ref.read(slotsProvider);
  ref.read(workspaceProvider.notifier).replaceCards([
    for (var i = 0; i < ws.cards.length; i++)
      ws.cards[i].toCard(id: 'ws_$i', zOrder: i, slots: slots),
  ]);
}

final workspaceStoreProvider = Provider<WorkspaceStore>(
  (ref) => WorkspaceStore(),
);

/// Read-only starter workspaces.
final starterWorkspacesProvider = Provider<List<Workspace>>(
  (ref) => kStarterWorkspaces,
);

final workspaceLibraryProvider =
    AsyncNotifierProvider<WorkspaceLibraryNotifier, WorkspaceLibrary>(
      WorkspaceLibraryNotifier.new,
    );
