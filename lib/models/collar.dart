class Collar {
  final String id;
  final double lat;
  final double lon;
  final int battery;
  final int rssi;
  final DateTime lastSeen;

  bool get isConnected => DateTime.now().difference(lastSeen) <= const Duration(minutes: 5);

  Collar({
    required this.id,
    required this.lat,
    required this.lon,
    required this.battery,
    required this.rssi,
    required this.lastSeen,
  });

  factory Collar.fromJson(Map<String, dynamic> j) => Collar(
        id: j['id'],
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        battery: j['battery'],
        rssi: j['rssi'],
        lastSeen: DateTime.fromMillisecondsSinceEpoch((j['last_seen'] as int) * 1000),
      );
}