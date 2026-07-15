import 'dart:math';
import '../models/collar.dart';

class EspCommService {
  final _rand = Random();
  final double _baseLat = 27.7089;
  final double _baseLon = 85.3206;

  // Simulates polling http://192.168.4.1/data
  // Swap this out for a real http.get() call in Step 4.
  Future<List<Collar>> fetchCollars() async {
    await Future.delayed(const Duration(milliseconds: 300)); // simulate network delay

    return [
      Collar(
        id: 'C1',
        lat: _baseLat + (_rand.nextDouble() - 0.5) * 0.002,
        lon: _baseLon + (_rand.nextDouble() - 0.5) * 0.002,
        battery: 70 + _rand.nextInt(30),
        rssi: -90 + _rand.nextInt(20),
        lastSeen: DateTime.now(),
      ),
      Collar(
        id: 'C2',
        lat: _baseLat + (_rand.nextDouble() - 0.5) * 0.002,
        lon: _baseLon + (_rand.nextDouble() - 0.5) * 0.002,
        battery: 60 + _rand.nextInt(30),
        rssi: -90 + _rand.nextInt(20),
        lastSeen: DateTime.now(),
      ),
    ];
  }
}