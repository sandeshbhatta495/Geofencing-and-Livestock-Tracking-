import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'utils/mbtiles_tile_provider.dart';

/// Starts the app, initializes the desktop-friendly SQLite engine, and then
/// launches the Riverpod app shell.
void main() {
  // Flutter needs to be initialized before we touch assets or plugin-backed
  // services like sqflite_common_ffi.
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const ProviderScope(child: MyApp()));
}

/// The root widget for the app.
///
/// It creates the first screen and keeps the app structure intentionally small
/// for now so we can swap the map source without changing the live collar demo.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final LatLng _mapCenter = LatLng(27.678663520802694, 85.28961181640625);

  static final LatLngBounds _mapBounds = LatLngBounds(
    LatLng(27.673798957817624, 85.2813720703125),
    LatLng(27.683528083787767, 85.2978515625),
  );

  /// Builds the app shell and places the offline map on the home screen.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Livestock Tracker')),
        body: FlutterMap(
          options: MapOptions(
            initialCenter: _mapCenter,
            initialZoom: 13,
            maxZoom: 16,
            cameraConstraint: CameraConstraint.containCenter(bounds: _mapBounds),
          ),
          children: [
            // This tile layer now reads from the bundled MBTiles database,
            // so the map works without an internet connection.
            TileLayer(
              tileProvider: MbTilesTileProvider(),
              maxZoom: 16,
              maxNativeZoom: 16,
              tileBounds: _mapBounds,
            ),
          ],
        ),
      ),
    );
  }
}