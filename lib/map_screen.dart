import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_input_screen.dart';
import 'main.dart';
import 'settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

final polylineProvider = StateProvider<Set<Polyline>>((ref) => {});
final markerProvider = StateProvider<Set<Marker>>((ref) => {});
final selectedRouteProvider = StateProvider<Polyline?>((ref) => null);

class MapScreen extends ConsumerStatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? mapController;
  bool isRouteDrawn = false;

  @override
  Widget build(BuildContext context) {
    final startLocation = ref.watch(startLocationProvider);
    final endLocation = ref.watch(endLocationProvider);
    final polylines = ref.watch(polylineProvider);
    final markers = ref.watch(markerProvider);
    final selectedRoute = ref.watch(selectedRouteProvider);

    Future<void> _drawRoutes() async {
      if (startLocation == null || endLocation == null) return;

      // Google Directions API'den rota verilerini alma
      var response = await Dio().get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': startLocation,
          'destination': endLocation,
          'key': dotenv.env['GOOGLE_API_KEY'],
          'alternatives': 'true',
          'departure_time': 'now',
          'traffic_model': 'best_guess',
        },
      );

      if (response.data['routes'].isNotEmpty) {
        Set<Polyline> newPolylines = {};
        Set<Marker> newMarkers = {};

        for (int i = 0; i < response.data['routes'].length; i++) {
          var points = response.data['routes'][i]['overview_polyline']['points'];
          var decodedPoints = _decodePolyline(points);

          newPolylines.add(
            Polyline(
              polylineId: PolylineId('route$i'),
              points: decodedPoints,
              color: i == 0 ? Colors.blue : Colors.grey,
              width: 5,
              onTap: () {
                _showRouteInfo(context, response.data['routes'][i]);
              },
            ),
          );

          // Marker ekleme
          for (int j = 0; j < decodedPoints.length; j += 5) {
            newMarkers.add(
              Marker(
                markerId: MarkerId('marker$i$j'),
                position: decodedPoints[j],
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                onTap: () {
                  _showRouteInfo(context, response.data['routes'][i]);
                },
              ),
            );
          }
        }

        ref.read(polylineProvider.notifier).state = newPolylines;
        ref.read(markerProvider.notifier).state = newMarkers;

        // Kamerayı rotayı gösterecek şekilde hareket ettir
        var allLatLng = newPolylines.expand((polyline) => polyline.points).toList();
        mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                allLatLng.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
                allLatLng.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
              ),
              northeast: LatLng(
                allLatLng.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
                allLatLng.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
              ),
            ),
            50.0, // Kenar boşluğu
          ),
        );
        isRouteDrawn = true; // Rota çizildiğinde bayrağı güncelle
      }
    }

    // Konumlar ayarlandığında rotayı çiz, harita denetleyicisi oluşturulduktan sonra sadece bir kez
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mapController != null &&
          !isRouteDrawn &&
          startLocation != null &&
          endLocation != null) {
        _drawRoutes();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('EV Route Optimizer'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(39.9334, 32.8597), // Başlangıç noktası
          zoom: 12,
        ),
        polylines: polylines,
        markers: markers,
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
          if (!isRouteDrawn && startLocation != null && endLocation != null) {
            _drawRoutes();
          }
        },
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
                  MaterialPageRoute(
                      builder: (context) => LocationInputScreen()),
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

  List<LatLng> _decodePolyline(String poly) {
    var list = poly.codeUnits;
    var lList = <double>[];
    int index = 0;
    int len = poly.length;
    int c = 0;

    // repeating until all attributes are decoded
    do {
      var shift = 0;
      int result = 0;

      // for decoding value of one attribute
      do {
        c = list[index] - 63;
        result |= (c & 0x1F) << (shift * 5);
        index++;
        shift++;
      } while (c >= 32);
      /* if value is negative then bitwise not the value */
      if (result & 1 == 1) {
        result = ~result;
      }
      var result1 = (result >> 1) * 0.00001;
      lList.add(result1);
    } while (index < len);

    /*adding to previous value as done in encoding */
    for (var i = 2; i < lList.length; i++) lList[i] += lList[i - 2];

    List<LatLng> decodedPoly = [];
    for (var i = 0; i < lList.length; i += 2) {
      decodedPoly.add(LatLng(lList[i], lList[i + 1]));
    }
    return decodedPoly;
  }

  // Rota bilgisini gösteren fonksiyon
  void _showRouteInfo(BuildContext context, dynamic route) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Toplam Mesafe: ${route['legs'][0]['distance']['text']}'),
              subtitle: Text('Tahmini Süre: ${route['legs'][0]['duration_in_traffic'] != null ? route['legs'][0]['duration_in_traffic']['text'] : route['legs'][0]['duration']['text']}'),
            ),
            ListTile(
              title: ElevatedButton(
                onPressed: () {
                  _launchNavigation(
                    route['legs'][0]['start_location']['lat'],
                    route['legs'][0]['start_location']['lng'],
                    route['legs'][0]['end_location']['lat'],
                    route['legs'][0]['end_location']['lng'],
                  );
                },
                child: Text('Yol Tarifini Başlat'),
              ),
            ),
          ],
        );
      },
    );
  }

  // Google Haritalar'da yol tarifi başlatan fonksiyon
  Future<void> _launchNavigation(double startLat, double startLng, double endLat, double endLng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLng&destination=$endLat,$endLng&travelmode=driving';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yol tarifi başlatılamadı')));
    }
  }
}