import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'providers/home_screen.dart';

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
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Builds the app shell and places the offline map on the home screen.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Livestock Tracker',
      home: HomeScreen(),
    );
  }
}