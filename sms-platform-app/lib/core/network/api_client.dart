import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';

class ApiClient {
  late final Dio _dio;
  String? _token;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Dynamic JWT request header interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Global error handling, e.g. token expiration checks
          return handler.next(e);
        },
      ),
    );
  }

  /// Sets the dynamic authentication token in memory
  void setToken(String? token) {
    _token = token;
  }

  bool get isAuthenticated => _token != null;

  /// General POST request handler
  asyncMapPost(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _parseDioError(e);
    }
  }

  /// General GET request handler
  asyncMapGet(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      throw _parseDioError(e);
    }
  }

  /// Exception parser translating HTTP codes into readable error messages
  Exception _parseDioError(DioException error) {
    final response = error.response;
    if (response != null) {
      final data = response.data;
      if (data is Map && data.containsKey('message')) {
        return Exception(data['message']);
      }
      return Exception('Server Error (Status: ${response.statusCode})');
    }
    if (error.type == DioExceptionType.connectionTimeout) {
      return Exception('Connection timed out. Please check your network.');
    }
    return Exception('An unexpected network error occurred.');
  }
}

// Single instance exposed for application-wide dependency injection
final ApiClient api = ApiClient();
