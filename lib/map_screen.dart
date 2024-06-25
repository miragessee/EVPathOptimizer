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
        var cmvo = CMVOAlgorithm(
          routes: response.data['routes'],
          batteryCapacity: batteryCapacity,
          energyConsumption: energyConsumption,
          batteryPercentage: batteryPercentage,
          chargePoints: chargePointsAsyncValue.asData!.value,
          endLocation: endLocation!,
          ref: ref,
        );

        cmvo.run();
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

  // Kaotik Çoklu Evren Algoritması ile en uygun yolu bulma
  // En yakın şarj istasyonunu bulma ve rotaya ekleme fonksiyonu
  void _findOptimalRoute(List<dynamic> routes, double batteryCapacity, double batteryPercentage, double energyConsumption, List<dynamic> chargePoints, String endLocation) {
    double availableEnergy = batteryCapacity * (batteryPercentage / 100);
    double maxTravelDistance = (availableEnergy / energyConsumption) * 1000; // km cinsinden

    List<Map<String, dynamic>> universe = routes.map((route) {
      double distance = route['legs'][0]['distance']['value'] / 1000.0; // metreyi km'ye çevir
      return {
        'distance': distance,
        'points': route['overview_polyline']['points'],
        'chargeNeeded': distance > maxTravelDistance,
        'fitness': distance > maxTravelDistance ? double.infinity : distance, // CMVO için fitness değeri
      };
    }).toList();

    // Logistic Map kullanarak kaotik harita oluşturma
    double chaoticMap(double x) => 4.0 * x * (1 - x);

    // Kaotik Çoklu Evren Algoritması (CMVO)
    for (int t = 0; t < 100; t++) {
      for (var element in universe) {
        double r = chaoticMap(Random().nextDouble()); // Kaotik harita
        if (element['chargeNeeded']) {
          // Solucan deliği: En yakın şarj istasyonunu bul ve rotayı ekle
          dynamic closestChargePoint = _findClosestChargePoint(chargePoints, _decodePolyline(element['points']));
          if (closestChargePoint != null) {
            // Şarj istasyonuna rota çiz
            _drawRouteToChargeStation(_decodePolyline(element['points']), closestChargePoint);
            // Şarj istasyonundan sonraki hedefe rota çiz
            _drawRemainingRoute(closestChargePoint, endLocation);
            element['fitness'] = _calculateDistance(_decodePolyline(element['points']).first, LatLng(closestChargePoint['AddressInfo']['Latitude'], closestChargePoint['AddressInfo']['Longitude']));
          }
        } else {
          // Beyaz delik: Doğrudan rota çiz
          //_drawPolyline(_decodePolyline(element['points']), Colors.green);
          element['fitness'] = element['distance'];
        }
      }
    }

    // En uygun rota seçimi
    var bestRoute = universe.reduce((a, b) => a['fitness'] < b['fitness'] ? a : b);
    if (bestRoute['chargeNeeded']) {
      // Şarj istasyonuna rota ve şarj istasyonundan sonra rota
      dynamic closestChargePoint = _findClosestChargePoint(chargePoints, _decodePolyline(bestRoute['points']));
      _drawRouteToChargeStation(_decodePolyline(bestRoute['points']), closestChargePoint);
      _drawRemainingRoute(closestChargePoint, endLocation);
    } else {
      // Doğrudan rota
      _drawPolyline(_decodePolyline(bestRoute['points']), Colors.green);
    }
  }

// En yakın şarj istasyonunu bulma ve rotaya ekleme fonksiyonları aynı kalır
  void _drawPolyline(List<LatLng> points, Color color) {
    ref.read(polylineProvider.notifier).state.add(
      Polyline(
        polylineId: PolylineId('route_${UniqueKey().toString()}'),
        points: points,
        color: color,
        width: 5,
      ),
    );
  }

  // Şarj istasyonuna giden yolun rota çizgilerini çizen fonksiyon
  void _drawRouteToChargeStation(List<LatLng> routePoints, dynamic chargeStation) async {
    var response = await Dio().get(
      'https://maps.googleapis.com/maps/api/directions/json',
      queryParameters: {
        'origin': '${routePoints.first.latitude},${routePoints.first.longitude}',
        'destination': '${chargeStation['AddressInfo']['Latitude']},${chargeStation['AddressInfo']['Longitude']}',
        'key': dotenv.env['GOOGLE_API_KEY'],
      },
    );

    if (response.data['routes'].isNotEmpty) {
      var points = response.data['routes'][0]['overview_polyline']['points'];
      var decodedPoints = _decodePolyline(points);

      ref.read(polylineProvider.notifier).state.add(
        Polyline(
          polylineId: PolylineId('toChargeStation'),
          points: decodedPoints,
          color: Colors.orange,
          width: 5,
        ),
      );
    }
  }

  // Şarj istasyonundan hedefe giden yolun rota çizgilerini çizen fonksiyon
  void _drawRemainingRoute(dynamic chargeStation, String? endLocation) async {
    var response = await Dio().get(
      'https://maps.googleapis.com/maps/api/directions/json',
      queryParameters: {
        'origin': '${chargeStation['AddressInfo']['Latitude']},${chargeStation['AddressInfo']['Longitude']}',
        'destination': endLocation,
        'key': dotenv.env['GOOGLE_API_KEY'],
      },
    );

    if (response.data['routes'].isNotEmpty) {
      var points = response.data['routes'][0]['overview_polyline']['points'];
      var decodedPoints = _decodePolyline(points);

      ref.read(polylineProvider.notifier).state.add(
        Polyline(
          polylineId: PolylineId('remainingRoute'),
          points: decodedPoints,
          color: Colors.green,
          width: 5,
        ),
      );
    }
  }

// Şarj istasyonuna giden yolun rota çizgilerini çizen fonksiyon
  void _routeToChargeStation(List<LatLng> routePoints, LatLng stationPosition) {
    // Burada, başlangıç noktasından şarj istasyonuna giden yolu hesaplayıp çizin
    List<LatLng> pathToStation = [routePoints.first, stationPosition]; // Basit bir örnek
    ref.read(polylineProvider.notifier).state.add(
      Polyline(
        polylineId: PolylineId('toChargeStation'),
        points: pathToStation,
        color: Colors.orange,
        width: 5,
      ),
    );
  }

  // İki nokta arası en kısa mesafeyi hesaplayan fonksiyon
  dynamic _findClosestChargePoint(List<dynamic> chargePoints, List<LatLng> routePoints) {
    dynamic closest = null;
    double minDistance = double.infinity;

    for (var point in chargePoints) {
      var stationLat = point['AddressInfo']['Latitude'];
      var stationLng = point['AddressInfo']['Longitude'];
      var stationPosition = LatLng(stationLat, stationLng);

      for (var routePoint in routePoints) {
        double distance = _calculateDistance(routePoint, stationPosition);
        if (distance < minDistance) {
          minDistance = distance;
          closest = point;
        }
      }
    }

    return closest;
  }

  // İki nokta arası mesafeyi hesaplama
  double _calculateDistance(LatLng start, LatLng end) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((end.latitude - start.latitude) * p)/2 +
        c(start.latitude * p) * c(end.latitude * p) *
            (1 - c((end.longitude - start.longitude) * p))/2;
    return 12742 * asin(sqrt(a)); // 2*R*asin...
  }
}