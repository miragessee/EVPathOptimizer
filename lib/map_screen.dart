import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'cmvo_algorithm.dart';
import 'location_input_screen.dart';
import 'main.dart';
import 'open_charge_map_api.dart';
import 'settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

final polylineProvider = StateProvider<Set<Polyline>>((ref) => {});
final markerProvider = StateProvider<Set<Marker>>((ref) => {});
final selectedRouteProvider = StateProvider<Polyline?>((ref) => null);

class MapScreen extends ConsumerStatefulWidget {
  MapScreen({
    Key? key,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? mapController;
  bool isRouteDrawn = false;
  List<LatLng> currentRoutePoints = [];

  @override
  Widget build(BuildContext context) {
    final startLocation = ref.watch(startLocationProvider);
    final endLocation = ref.watch(endLocationProvider);
    final polylines = ref.watch(polylineProvider);
    final markers = ref.watch(markerProvider);
    final selectedRoute = ref.watch(selectedRouteProvider);
    final batteryCapacity = ref.watch(batteryCapacityProvider);
    final energyConsumption = ref.watch(energyConsumptionProvider);
    final batteryPercentage = ref.watch(batteryPercentageProvider);
    final chargePointsAsyncValue = ref.watch(chargePointsProvider);

    Future<void> _drawRoutes() async {
      if (startLocation == null || endLocation == null || isRouteDrawn) return;

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
        var cmvo = CMVOAlgorithm(
          routes: response.data['routes'],
          batteryCapacity: batteryCapacity,
          energyConsumption: energyConsumption,
          batteryPercentage: batteryPercentage,
          chargePoints: chargePointsAsyncValue.asData!.value,
          endLocation: endLocation!,
          ref: ref,
        );

        await cmvo.run();
        // En iyi rotanın noktalarını kaydedin
        currentRoutePoints = cmvo.bestRoutePoints;
        isRouteDrawn = true; // Algoritmanın tekrar çalışmaması için bayrağı ayarla
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
        onTap: (LatLng point) {
          // Eğer tıklanan nokta bir polyline üzerindeyse navigasyonu başlat
          // for (var polyline in polylines) {
          //   if (_isPointOnPolyline(point, polyline.points)) {
          //     _launchNavigation(currentRoutePoints);
          //     break;
          //   }
          // }

          _launchNavigation(currentRoutePoints);
        },
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

  void _launchNavigation(List<LatLng> routePoints) async {
    if (routePoints.isEmpty) return;
    final startLat = routePoints.first.latitude;
    final startLng = routePoints.first.longitude;
    final endLat = routePoints.last.latitude;
    final endLng = routePoints.last.longitude;

    // Waypoints oluştur
    List<String> waypoints = routePoints.skip(1).take(routePoints.length - 2).map((point) => '${point.latitude},${point.longitude}').toList();
    String waypointsString = waypoints.join('|');

    // Google Maps URL oluşturma
    final url = Uri.encodeFull(
        'https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLng&destination=$endLat,$endLng&travelmode=driving&waypoints=$waypointsString'
    );

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yol tarifi başlatılamadı, URL kontrol edin veya Google Maps yüklü olup olmadığını kontrol edin.'))
      );
    }
  }

  bool _isPointOnPolyline(LatLng point, List<LatLng> polylinePoints) {
    // Polyline üzerinde bir noktayı kontrol etme algoritması
    for (int i = 0; i < polylinePoints.length - 1; i++) {
      LatLng p1 = polylinePoints[i];
      LatLng p2 = polylinePoints[i + 1];
      double distance = _distanceToLineSegment(point, p1, p2);
      if (distance < 0.0001) { // Tolerans aralığı
        return true;
      }
    }
    return false;
  }

  double _distanceToLineSegment(LatLng p, LatLng p1, LatLng p2) {
    double x = p.latitude;
    double y = p.longitude;
    double x1 = p1.latitude;
    double y1 = p1.longitude;
    double x2 = p2.latitude;
    double y2 = p2.longitude;

    double A = x - x1;
    double B = y - y1;
    double C = x2 - x1;
    double D = y2 - y1;

    double dot = A * C + B * D;
    double len_sq = C * C + D * D;
    double param = (len_sq != 0) ? dot / len_sq : -1;

    double xx, yy;

    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * C;
      yy = y1 + param * D;
    }

    double dx = x - xx;
    double dy = y - yy;
    return sqrt(dx * dx + dy * dy);
  }
}