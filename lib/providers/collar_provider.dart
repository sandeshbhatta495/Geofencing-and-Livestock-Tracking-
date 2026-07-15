import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/collar.dart';
import '../services/esp_comm_service.dart';

final espCommServiceProvider = Provider((ref) => EspCommService());

final collarStreamProvider = StreamProvider<List<Collar>>((ref) async* {
  final service = ref.watch(espCommServiceProvider);
  while (true) {
    yield await service.fetchCollars();
    await Future.delayed(const Duration(seconds: 3));
  }
});