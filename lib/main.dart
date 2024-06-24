import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_screen.dart';

final startLocationProvider = StateProvider<String?>((ref) => null);
final endLocationProvider = StateProvider<String?>((ref) => null);
final batteryCapacityProvider = StateProvider<double>((ref) => 50.0);
final energyConsumptionProvider = StateProvider<double>((ref) => 150.0);
final batteryPercentageProvider = StateProvider<double>((ref) => 100.0);

void main() async {
  await dotenv.load(fileName: ".env");

  runApp(
    ProviderScope(
      child: MyApp(
      ),
    ),
  );
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EV Route Optimizer',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: FutureBuilder(
        future: _loadInitialData(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return MapScreen();
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Future<void> _loadInitialData(BuildContext context) async {
    // Initialize shared preferences or other asynchronous resources here
    // SharedPreferences örneğini al
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Kaydedilen değerleri yükle
    final batteryCapacity = prefs.getDouble('batteryCapacity') ?? 50.0;
    final energyConsumption = prefs.getDouble('energyConsumption') ?? 150.0;
    final batteryPercentage = prefs.getDouble('batteryPercentage') ?? 100.0;
    // Additional setup like loading initial data or settings

    // Sağlayıcıları güncelle
    final container = ProviderScope.containerOf(context);
    container.read(batteryCapacityProvider.notifier).state = batteryCapacity;
    container.read(energyConsumptionProvider.notifier).state = energyConsumption;
    container.read(batteryPercentageProvider.notifier).state = batteryPercentage;
  }
}
