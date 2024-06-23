import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_input_screen.dart';
import 'settings_screen.dart';

final startLocationProvider = StateProvider<String?>((ref) => null);
final endLocationProvider = StateProvider<String?>((ref) => null);
final polylineProvider = StateProvider<Set<Polyline>>((ref) => {});

class MapScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startLocation = ref.watch(startLocationProvider);
    final endLocation = ref.watch(endLocationProvider);
    final polylines = ref.watch(polylineProvider);

    Future<void> _drawRoute() async {
      if (startLocation == null || endLocation == null) return;

      List<Location> startPlacemark = await locationFromAddress(startLocation);
      List<Location> endPlacemark = await locationFromAddress(endLocation);

      if (startPlacemark.isEmpty || endPlacemark.isEmpty) return;

      LatLng startLatLng = LatLng(startPlacemark.first.latitude, startPlacemark.first.longitude);
      LatLng endLatLng = LatLng(endPlacemark.first.latitude, endPlacemark.first.longitude);

      List<LatLng> routeCoords = [startLatLng, endLatLng];

      ref.read(polylineProvider.notifier).state = {
        Polyline(
          polylineId: PolylineId('route'),
          points: routeCoords,
          color: Colors.blue,
          width: 5,
        ),
      };
    }

    if (startLocation != null && endLocation != null) {
      _drawRoute();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('EV Route Optimizer'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(39.9396351, 32.815569),
          zoom: 14,
        ),
        polylines: polylines,
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FloatingActionButton(
            onPressed: () => _openBottomSheet(context),
            child: Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  void _openBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => LocationInputScreen()),
                );
              },
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions, size: 36.0),
                  SizedBox(width: 8.0),
                  Text('Nereden -> Nereye', style: TextStyle(fontSize: 18.0)),
                ],
              ),
            ),
            ListTile(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.settings, size: 36.0),
                  SizedBox(width: 8.0),
                  Text('Hesaplama Ayarları', style: TextStyle(fontSize: 18.0)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}