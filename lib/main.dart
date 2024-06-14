import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'open_charge_map_api.dart';


void main() {
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EV Path Optimizer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends ConsumerWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargePointsAsyncValue = ref.watch(chargePointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EV Path Optimizer Home Page'),
      ),
      body: chargePointsAsyncValue.when(
        data: (chargePoints) => GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(39.9334, 32.8597),
            zoom: 10,
          ),
          markers: chargePoints.map<Marker>((station) {
            return Marker(
              markerId: MarkerId(station['ID'].toString()),
              position: LatLng(
                station['AddressInfo']['Latitude'],
                station['AddressInfo']['Longitude'],
              ),
              infoWindow: InfoWindow(
                title: station['AddressInfo']['Title'],
                snippet: station['AddressInfo']['AddressLine1'],
              ),
            );
          }).toSet(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}