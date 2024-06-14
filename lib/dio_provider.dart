import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

// Dio instance'ını sağlayıcı olarak tanımlayın ve Pretty Dio Logger ekleyin
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();

  dio.interceptors.add(PrettyDioLogger(
    requestHeader: true,
    requestBody: true,
    responseBody: true,
    responseHeader: false,
    error: true,
    compact: true,
    maxWidth: 90,
  ));

  return dio;
});