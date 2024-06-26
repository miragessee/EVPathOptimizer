import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_screen.dart';

class CMVOAlgorithm {
  final List<dynamic> routes;
  final double batteryCapacity;
  final double energyConsumption;
  final double batteryPercentage;
  final List<dynamic> chargePoints;
  final String endLocation;
  final WidgetRef ref;
  List<LatLng> bestRoutePoints = [];

  CMVOAlgorithm({
    required this.routes,
    required this.batteryCapacity,
    required this.energyConsumption,
    required this.batteryPercentage,
    required this.chargePoints,
    required this.endLocation,
    required this.ref,
  });

  Future<void> run() async {
    // İlk başlangıç evreni oluştur
    List<Map<String, Object>> universe = _initializeUniverse();

    // Kaotik harita fonksiyonu (Logistic Map)
    double chaoticMap(double x) => 4.0 * x * (1 - x);

    // CMVO algoritması (tek iterasyon)
    for (var element in universe) {
      double r = chaoticMap(Random().nextDouble());

      if (element['chargeNeeded'] as bool) {
        await _handleBlackHole(element);
      } else {
        _handleWhiteHole(element, universe, r);
      }
    }

    // En iyi rotayı seç ve sonlandır
    var bestRoute = universe.reduce((a, b) => (a['fitness'] as double) < (b['fitness'] as double) ? a : b);
    await _finalizeRoute(bestRoute);

    // En iyi rotanın noktalarını kaydet
    bestRoutePoints = bestRoute['decodedPoints'] as List<LatLng>;
  }

  List<Map<String, Object>> _initializeUniverse() {
    return routes.map((route) {
      double distance = route['legs'][0]['distance']['value'] / 1000.0;
      List<LatLng> decodedPoints = _decodePolyline(route['overview_polyline']['points']);
      bool chargeNeeded = distance > _maxTravelDistance();

      return {
        'distance': distance,
        'decodedPoints': decodedPoints,
        'chargeNeeded': chargeNeeded,
        'fitness': chargeNeeded ? double.infinity : distance,
      };
    }).toList();
  }

  double _maxTravelDistance() {
    return (batteryCapacity * (batteryPercentage / 100) / energyConsumption) * 1000;
  }

  Future<void> _handleBlackHole(Map<String, Object> element) async {
    dynamic closestChargePoint = _findClosestChargePoint(element['decodedPoints'] as List<LatLng>);
    if (closestChargePoint != null) {
      element['fitness'] = _calculateDistance(
        (element['decodedPoints'] as List<LatLng>).first,
        LatLng(
          closestChargePoint['AddressInfo']['Latitude'],
          closestChargePoint['AddressInfo']['Longitude'],
        ),
      );
    }
  }

  void _handleWhiteHole(Map<String, Object> element, List<Map<String, Object>> universe, double r) {
    // Beyaz delik: Diğer evrenlerin bilgilerini paylaş
    int index = (r * universe.length).floor();
    var otherElement = universe[index];

    if (!(otherElement['chargeNeeded'] as bool)) {
      element['decodedPoints'] = otherElement['decodedPoints']!;
      element['fitness'] = otherElement['fitness']!;
    }
  }

  Future<void> _finalizeRoute(Map<String, Object> bestRoute) async {
    // Mevcut polylines'ları temizle
    ref.read(polylineProvider.notifier).state = {};

    if (bestRoute['chargeNeeded'] as bool) {
      dynamic closestChargePoint = _findClosestChargePoint(bestRoute['decodedPoints'] as List<LatLng>);
      List<LatLng> routeToChargeStation = await _drawRouteToChargeStation(bestRoute['decodedPoints'] as List<LatLng>, closestChargePoint);
      List<LatLng> remainingRoute = await _drawRemainingRoute(closestChargePoint, endLocation);
      bestRoutePoints = [...routeToChargeStation, ...remainingRoute];
    } else {
      bestRoutePoints = bestRoute['decodedPoints'] as List<LatLng>;
      _drawDirectRoute(bestRoutePoints);
    }
  }

  void _drawDirectRoute(List<LatLng> points) {
    _drawPolyline(points, Colors.green);
  }

  void _drawPolyline(List<LatLng> points, Color color) {
    var drawPoly = ref.read(polylineProvider.notifier);
    drawPoly.update((state) => {
      ...state,
      Polyline(
        polylineId: PolylineId('route_${UniqueKey().toString()}'),
        points: points,
        color: color,
        width: 5,
      ),
    });
  }

  Future<List<LatLng>> _drawRouteToChargeStation(List<LatLng> routePoints, dynamic chargeStation) async {
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

      // Orange polyline çizin
      var drawPoly = ref.read(polylineProvider.notifier);
      drawPoly.update((state) => {
        ...state,
        Polyline(
          polylineId: PolylineId('routeToChargeStation_${UniqueKey().toString()}'),
          points: decodedPoints,
          color: Colors.orange,
          width: 5,
        ),
      });

      return decodedPoints;
    }
    return [];
  }

  Future<List<LatLng>> _drawRemainingRoute(dynamic chargeStation, String endLocation) async {
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

      // Green polyline çizin
      var drawPoly = ref.read(polylineProvider.notifier);
      drawPoly.update((state) => {
        ...state,
        Polyline(
          polylineId: PolylineId('remainingRoute_${UniqueKey().toString()}'),
          points: decodedPoints,
          color: Colors.green,
          width: 5,
        ),
      });

      return decodedPoints;
    }
    return [];
  }

  dynamic _findClosestChargePoint(List<LatLng> routePoints) {
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

  double _calculateDistance(LatLng start, LatLng end) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((end.latitude - start.latitude) * p) / 2 +
        c(start.latitude * p) * c(end.latitude * p) *
            (1 - c((end.longitude - start.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  List<LatLng> _decodePolyline(String poly) {
    var list = poly.codeUnits;
    var lList = <double>[];
    int index = 0;
    int len = poly.length;
    int c = 0;

    do {
      var shift = 0;
      int result = 0;
      do {
        c = list[index] - 63;
        result |= (c & 0x1F) << (shift * 5);
        index++;
        shift++;
      } while (c >= 32);
      if (result & 1 == 1) {
        result = ~result;
      }
      var result1 = (result >> 1) * 0.00001;
      lList.add(result1);
    } while (index < len);

    for (var i = 2; i < lList.length; i++) lList[i] += lList[i - 2];

    List<LatLng> decodedPoly = [];
    for (var i = 0; i < lList.length; i += 2) {
      decodedPoly.add(LatLng(lList[i], lList[i + 1]));
    }
    return decodedPoly;
  }
}