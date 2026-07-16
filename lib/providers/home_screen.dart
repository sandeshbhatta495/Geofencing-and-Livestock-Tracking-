import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../providers/collar_provider.dart';
import '../providers/boundary_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/map_mode_provider.dart';
import '../utils/mbtiles_tile_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();
  int? _selectedPointIndex; // used only in adjust mode

  static final LatLng _mapCenter = LatLng(27.678663520802694, 85.28961181640625);
  static final LatLngBounds _mapBounds = LatLngBounds(
    LatLng(27.673798957817624, 85.2813720703125),
    LatLng(27.683528083787767, 85.2978515625),
  );

  @override
  Widget build(BuildContext context) {
    final collarsAsync = ref.watch(collarStreamProvider);
    final boundary = ref.watch(boundaryProvider);
    final notifications = ref.watch(notificationProvider);
    final mode = ref.watch(mapModeProvider);
    final draftPoints = ref.watch(draftBoundaryProvider).cast<LatLng>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForMode(mode)),
        actions: mode != MapMode.none
            ? [
                TextButton(
                  onPressed: _cancelMode,
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                ),
              ]
            : null,
      ),
      drawer: mode == MapMode.none ? _buildDrawer(context, collarsAsync) : null,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 13,
              maxZoom: 16,
              cameraConstraint: CameraConstraint.containCenter(bounds: _mapBounds),
              onLongPress: (tapPosition, point) => _onMapLongPress(point),
              onTap: (tapPosition, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                tileProvider: MbTilesTileProvider(),
                maxZoom: 16,
                maxNativeZoom: 16,
              ),
              // Saved boundary (hidden while actively drawing a new one)
              if (boundary.isNotEmpty && mode != MapMode.settingBoundary)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: boundary,
                      color: Colors.green.withValues(alpha: 0.2),
                      borderColor: Colors.green,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              // Draft boundary while drawing
              if (draftPoints.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: draftPoints,
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderColor: Colors.orange,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              // Draft point markers (tap to remove last, or just visualize)
              if (draftPoints.isNotEmpty)
                MarkerLayer(
                  markers: draftPoints
                      .map((p) => Marker(
                            point: p,
                            width: 16,
                            height: 16,
                            child: const CircleAvatar(
                              radius: 6,
                              backgroundColor: Colors.orange,
                            ),
                          ))
                      .toList(),
                ),
              // Adjustable boundary points (tap a point, then tap new spot)
              if (mode == MapMode.adjustingBoundary)
                MarkerLayer(
                  markers: boundary.asMap().entries.map((entry) {
                    final isSelected = entry.key == _selectedPointIndex;
                    return Marker(
                      point: entry.value,
                      width: 24,
                      height: 24,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPointIndex = entry.key),
                        child: CircleAvatar(
                          radius: isSelected ? 10 : 7,
                          backgroundColor: isSelected ? Colors.red : Colors.blue,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              collarsAsync.when(
                data: (collars) => MarkerLayer(
                  markers: collars
                      .map((c) => Marker(
                            point: LatLng(c.lat, c.lon),
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.pets,
                              color: c.isConnected ? Colors.blue : Colors.grey,
                            ),
                          ))
                      .toList(),
                ),
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),
            ],
          ),
          // Instructions banner during drawing/adjusting
          if (mode != MapMode.none)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Card(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    mode == MapMode.settingBoundary
                        ? 'Tap map to add boundary points. Press Done when finished.'
                        : 'Tap a red/blue point, then tap map to move it. Press Done to save.',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          // Done button while drawing/adjusting
          if (mode != MapMode.none)
            Positioned(
              bottom: 20,
              left: 20,
              child: FloatingActionButton.extended(
                onPressed: _finishMode,
                label: const Text('Done'),
                icon: const Icon(Icons.check),
              ),
            ),
          // Bottom-right round notification button
          if (mode == MapMode.none)
            Positioned(
              bottom: 20,
              right: 20,
              child: Stack(
                children: [
                  FloatingActionButton(
                    shape: const CircleBorder(),
                    onPressed: () => _showNotifications(context, notifications),
                    child: const Icon(Icons.notifications),
                  ),
                  if (notifications.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.red,
                        child: Text(
                          '${notifications.length}',
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _titleForMode(MapMode mode) {
    switch (mode) {
      case MapMode.settingBoundary:
        return 'Set Boundary';
      case MapMode.adjustingBoundary:
        return 'Adjust Boundary';
      case MapMode.none:
        return 'Livestock Tracker';
    }
  }

  /// Handles taps depending on current mode: adds a draft boundary point,
  /// moves a selected point during adjustment, or does nothing normally
  /// (long-press is used for the plain "check location" feature instead).
  void _onMapTap(LatLng point) {
    final mode = ref.read(mapModeProvider);

    if (mode == MapMode.settingBoundary) {
      final points = ref.read(draftBoundaryProvider).cast<LatLng>();
      ref.read(draftBoundaryProvider.notifier).state = [...points, point];
    } else if (mode == MapMode.adjustingBoundary && _selectedPointIndex != null) {
      ref.read(boundaryProvider.notifier).adjustPoint(_selectedPointIndex!, point);
      setState(() => _selectedPointIndex = null);
    }
  }

  /// Long-press still shows the plain "location info" dialog, per your
  /// original requirement, but only when not in a boundary-editing mode.
  void _onMapLongPress(LatLng point) {
    final mode = ref.read(mapModeProvider);
    if (mode != MapMode.none) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location selected'),
        content: Text('Lat: ${point.latitude}\nLon: ${point.longitude}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _finishMode() {
    final mode = ref.read(mapModeProvider);

    if (mode == MapMode.settingBoundary) {
      final points = ref.read(draftBoundaryProvider).cast<LatLng>();
      if (points.length >= 3) {
        ref.read(boundaryProvider.notifier).setBoundary(points);
        ref.read(notificationProvider.notifier).add('New boundary set');
      }
      ref.read(draftBoundaryProvider.notifier).state = [];
    } else if (mode == MapMode.adjustingBoundary) {
      ref.read(notificationProvider.notifier).add('Boundary adjusted');
    }

    setState(() => _selectedPointIndex = null);
    ref.read(mapModeProvider.notifier).state = MapMode.none;
  }

  void _cancelMode() {
    ref.read(draftBoundaryProvider.notifier).state = [];
    setState(() => _selectedPointIndex = null);
    ref.read(mapModeProvider.notifier).state = MapMode.none;
  }

  Widget _buildDrawer(BuildContext context, AsyncValue collarsAsync) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Text('Menu')),
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('Live Location'),
            onTap: () {
              Navigator.pop(context);
              _showLiveLocation(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.crop_free),
            title: const Text('Virtual Boundary'),
            onTap: () {
              Navigator.pop(context);
              _showBoundaryOptions(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sensors),
            title: const Text('Device Status'),
            onTap: () {
              Navigator.pop(context);
              _showDeviceStatus(context);
            },
          ),
        ],
      ),
    );
  }

  void _showLiveLocation(BuildContext context) {
    final collars = ref.read(collarStreamProvider).value ?? [];
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: collars
            .map((c) => ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: c.isConnected ? Colors.blue : Colors.grey,
                  ),
                  title: Text('Collar ${c.id}'),
                  subtitle: Text('Lat: ${c.lat}, Lon: ${c.lon}'),
                  onTap: () {
                    _mapController.move(LatLng(c.lat, c.lon), 15);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }

  void _showBoundaryOptions(BuildContext context) {
    final boundary = ref.read(boundaryProvider);
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_location_alt),
            title: const Text('Set Boundary'),
            onTap: () {
              Navigator.pop(context);
              ref.read(mapModeProvider.notifier).state = MapMode.settingBoundary;
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Remove Current Boundary'),
            onTap: () {
              ref.read(boundaryProvider.notifier).removeBoundary();
              ref.read(notificationProvider.notifier).add('Boundary removed');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_location_alt),
            title: const Text('Adjust Current Boundary'),
            enabled: boundary.isNotEmpty,
            onTap: boundary.isEmpty
                ? null
                : () {
                    Navigator.pop(context);
                    ref.read(mapModeProvider.notifier).state = MapMode.adjustingBoundary;
                  },
          ),
        ],
      ),
    );
  }

  void _showDeviceStatus(BuildContext context) {
    final collars = ref.read(collarStreamProvider).value ?? [];
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: collars
            .map((c) => ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 12,
                    color: c.isConnected ? Colors.green : Colors.red,
                  ),
                  title: Text('Collar ${c.id}'),
                  subtitle: Text(c.isConnected ? 'Connected' : 'Not in range'),
                ))
            .toList(),
      ),
    );
  }

  void _showNotifications(BuildContext context, List notifications) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: notifications
            .map((n) => ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: Text(n.message),
                  subtitle: Text(_timeAgo(n.time)),
                ))
            .toList(),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours} hr ago';
  }
}