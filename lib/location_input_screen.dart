import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_location_picker/map_location_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'main.dart';
import 'map_screen.dart';

class LocationInputScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startLocation = ref.watch(startLocationProvider);
    final endLocation = ref.watch(endLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Nereden -> Nereye'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  var result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MapLocationPicker(
                        apiKey: dotenv.env['GOOGLE_API_KEY']!,
                        popOnNextButtonTaped: true,
                        currentLatLng: LatLng(39.9396351, 32.815569),
                        language: 'tr',
                      ),
                    ),
                  );
                  if (result != null) {
                    ref.read(startLocationProvider.notifier).state = result.formattedAddress;
                  }
                },
                child: Text(startLocation ?? 'Nereden', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                ),
              ),
            ),
            SizedBox(height: 32.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  var result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MapLocationPicker(
                        apiKey: dotenv.env['GOOGLE_API_KEY']!,
                        popOnNextButtonTaped: true,
                        currentLatLng: LatLng(39.9396351, 32.815569),
                        language: 'tr',
                      ),
                    ),
                  );
                  if (result != null) {
                    ref.read(endLocationProvider.notifier).state = result.formattedAddress;
                  }
                },
                child: Text(endLocation ?? 'Nereye', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                ),
              ),
            ),
            SizedBox(height: 32.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Yolu Çiz', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}