import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Reads tiles from a bundled MBTiles SQLite database instead of making HTTP
/// requests, which is what lets the map keep working completely offline.
class MbTilesTileProvider extends TileProvider {
  /// Creates a tile provider that reads from the bundled pastures map.
  MbTilesTileProvider({
    this.assetPath = 'assets/maps/pasture_region.mbtiles',
    DatabaseFactory? databaseFactory,
  }) : _databaseFactory = databaseFactory ?? databaseFactoryFfi;

  final String assetPath;
  final DatabaseFactory _databaseFactory;

  Database? _database;
  Future<Database>? _openingDatabase;
  Directory? _tempDirectory;

  /// Returns an image provider that knows how to fetch the tile bytes for the
  /// requested zoom/x/y position.
  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return _MbTilesImageProvider(this, coordinates, options);
  }

  /// Reads a single tile from the MBTiles database and returns its raw bytes.
  ///
  /// MBTiles stores rows in TMS order, so the Y coordinate must be flipped
  /// before we query the `tiles` table.
  Future<Uint8List?> readTileBytes(TileCoordinates coordinates) async {
    final database = await _openDatabase();
    final tileRow = (1 << coordinates.z) - 1 - coordinates.y;

    final rows = await database.query(
      'tiles',
      columns: ['tile_data'],
      where: 'zoom_level = ? AND tile_column = ? AND tile_row = ?',
      whereArgs: [coordinates.z, coordinates.x, tileRow],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final tileData = rows.first['tile_data'];
    if (tileData is Uint8List) {
      return tileData;
    }
    if (tileData is List<int>) {
      return Uint8List.fromList(tileData);
    }

    return null;
  }

  /// Opens the bundled MBTiles file once and keeps the database handle around
  /// so repeated tile lookups stay fast while the map is on screen.
  Future<Database> _openDatabase() {
    final database = _database;
    if (database != null) {
      return Future.value(database);
    }

    return _openingDatabase ??= _loadDatabase();
  }

  /// Copies the bundled asset to a persistent app-support file (only if it
  /// isn't already there) and opens it in read-only mode.
  Future<Database> _loadDatabase() async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'livestock_tracker_mbtiles_',
    );
    _tempDirectory = tempDirectory;

    final databaseFile = File(p.join(tempDirectory.path, p.basename(assetPath)));

    if (!await databaseFile.exists()) {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      await databaseFile.writeAsBytes(bytes, flush: true);
    }

    final database = await _databaseFactory.openDatabase(
      databaseFile.path,
      options: OpenDatabaseOptions(
        readOnly: true,
        singleInstance: false,
      ),
    );

    _database = database;
    return database;
  }

  /// Closes the opened database and removes the temp copy when the tile
  /// layer is disposed.
  @override
  void dispose() {
    _database?.close();
    _tempDirectory?.delete(recursive: true).ignore();
  }
}

/// A small image provider that turns one MBTiles row into a map tile image.
class _MbTilesImageProvider extends ImageProvider<_MbTilesImageProvider> {
  /// Stores the tile request and the provider that can read the bytes.
  const _MbTilesImageProvider(
    this.provider,
    this.coordinates,
    this.options,
  );

  final MbTilesTileProvider provider;
  final TileCoordinates coordinates;
  final TileLayer options;

  /// Uses the current object itself as the cache key because the tile request
  /// is fully defined by the coordinates and layer settings already stored on
  /// the instance.
  @override
  Future<_MbTilesImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  /// Loads the tile bytes, decodes them into an image, and hands that image to
  /// flutter_map for rendering.
  @override
  ImageStreamCompleter loadImage(
    _MbTilesImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadCodec(decode),
      scale: 1,
      debugLabel:
          'mbtiles://${coordinates.z}/${coordinates.x}/${coordinates.y}',
      informationCollector: () => [
        DiagnosticsProperty<String>(
          'MBTiles tile',
          '${coordinates.z}/${coordinates.x}/${coordinates.y}',
        ),
        DiagnosticsProperty<String>(
          'Tile layer',
          options.runtimeType.toString(),
        ),
      ],
    );
  }

  /// Loads the raw tile bytes from SQLite and converts them into a codec that
  /// Flutter can paint on the screen.
  Future<Codec> _loadCodec(ImageDecoderCallback decode) async {
    final bytes = await provider.readTileBytes(coordinates);
    if (bytes == null) {
      return _decodeTransparentTile(decode);
    }

    final buffer = await ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  /// Returns a 1x1 transparent image so the map can keep rendering cleanly
  /// when the view extends beyond the sparse offline bundle.
  Future<Codec> _decodeTransparentTile(ImageDecoderCallback decode) async {
    const transparentPngBytes = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ];

    final buffer = await ImmutableBuffer.fromUint8List(
      Uint8List.fromList(transparentPngBytes),
    );
    return decode(buffer);
  }
}