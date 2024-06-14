import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'location_input_screen.dart';
import 'settings_screen.dart';
import 'map_screen.dart';

void main() {
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EV Route Optimizer',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: MapScreen(),
    );
  }
}
