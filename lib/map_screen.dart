import 'package:flutter/material.dart';
import 'location_input_screen.dart';
import 'settings_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EV Route Optimizer'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(37.7749, -122.4194), // San Francisco koordinatları
          zoom: 12,
        ),
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: FloatingActionButton(
            onPressed: () => _openBottomSheet(context),
            child: Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
