import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MapMode { none, settingBoundary, adjustingBoundary }

class MapModeNotifier extends Notifier<MapMode> {
  @override
  MapMode build() => MapMode.none;

  @override
  set state(MapMode value) => super.state = value;
}

final mapModeProvider = NotifierProvider<MapModeNotifier, MapMode>(MapModeNotifier.new);

/// Holds boundary points while the user is actively drawing (before they
/// press "Done"). Kept separate from the saved boundaryProvider so
/// cancelling mid-draw doesn't affect the saved boundary.
class DraftBoundaryNotifier extends Notifier<List<dynamic>> {
  @override
  List<dynamic> build() => [];

  @override
  set state(List<dynamic> value) => super.state = value;
}

final draftBoundaryProvider = NotifierProvider<DraftBoundaryNotifier, List<dynamic>>(DraftBoundaryNotifier.new);