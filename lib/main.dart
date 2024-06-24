import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'map_screen.dart';

final startLocationProvider = StateProvider<String?>((ref) => null);
final endLocationProvider = StateProvider<String?>((ref) => null);

void main() async {
  await dotenv.load(fileName: ".env");
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
