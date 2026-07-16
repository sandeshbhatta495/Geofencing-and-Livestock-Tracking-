import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Holds the current virtual boundary polygon (empty = no boundary set).
class BoundaryNotifier extends Notifier<List<LatLng>> {
  @override
  List<LatLng> build() => [];

  void setBoundary(List<LatLng> points) => state = points;

  void removeBoundary() => state = [];

  void adjustPoint(int index, LatLng newPoint) {
    final updated = [...state];
    if (index < updated.length) {
      updated[index] = newPoint;
      state = updated;
    }
  }
}

final boundaryProvider =
    NotifierProvider<BoundaryNotifier, List<LatLng>>(
  BoundaryNotifier.new,
);