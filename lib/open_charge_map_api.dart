import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dio_provider.dart';

// API'den veri çekmek için FutureProvider
final chargePointsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);

  try {
    final response = await dio.get(
      'https://api.openchargemap.io/v3/poi/',
      options: Options(
        headers: {
          'User-Agent': 'EVPathOptimizer/1.0 (miragessee@gmail.com)',
        },
      ),
      queryParameters: {
        'output': 'json',
        'countrycode': 'TR',
        'maxresults': 50,
        'compact': true,
        'verbose': false,
        'key': 'bce29668-57a8-41df-9dc0-ef67dc9af85e',
        'latitude': 39.9334,
        'longitude': 32.8597,
      },
    );

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to load charge points');
    }
  } on DioException catch (e) {
    if (e.response?.statusCode == 503) {
      throw Exception('Service Unavailable. Please try again later.');
    } else {
      throw Exception('Failed to load charge points');
    }
  }
});