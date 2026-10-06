import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // ============================================================
  // PRODUCTION BACKEND
  // ============================================================

  // Render production backend
  static const String _productionUrl =
      'https://ethio-nutri-backend.onrender.com/api/v1';

  // ============================================================
  // BACKEND MODE
  // ============================================================

  // true  = use Render production backend
  // false = use local backend
  static const bool useProductionUrl = true;

  static String get baseUrl {
    // ----------------------------------------------------------
    // Production
    // ----------------------------------------------------------
    if (useProductionUrl) {
      return _productionUrl;
    }

    // ----------------------------------------------------------
    // Local development
    // ----------------------------------------------------------

    if (kIsWeb) {
      // Flutter Web -> local PC backend
      return 'http://localhost:5000/api/v1';
    } else if (Platform.isAndroid) {
      // Android Emulator -> host PC backend
      return 'http://10.0.2.2:5000/api/v1';
    } else {
      // iOS Simulator / macOS -> local backend
      return 'http://localhost:5000/api/v1';
    }
  }

  // ============================================================
  // TOKEN MANAGEMENT
  // ============================================================

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  static Future<void> setTokens(
    String accessToken,
    String refreshToken,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }

  // ============================================================
  // LOCATION CONTEXT
  // ============================================================

  static double? _cachedLatitude;
  static double? _cachedLongitude;

  static String _cachedCity = 'Addis Ababa';
  static String _cachedTimezone = 'Africa/Addis_Ababa';

  static void setLocation({
    required double latitude,
    required double longitude,
    String? city,
    String? timezone,
  }) {
    _cachedLatitude = latitude;
    _cachedLongitude = longitude;

    if (city != null) {
      _cachedCity = city;
    }

    if (timezone != null) {
      _cachedTimezone = timezone;
    }
  }

  static Map<String, String> get locationContext => {
        if (_cachedLatitude != null)
          'latitude': _cachedLatitude.toString(),
        if (_cachedLongitude != null)
          'longitude': _cachedLongitude.toString(),
        'city': _cachedCity,
        'timezone': _cachedTimezone,
      };

  // ============================================================
  // HEADERS
  // ============================================================

  static Future<Map<String, String>> _getHeaders({
    bool requiresAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await getToken();

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';

        // Location context
        headers['X-Timezone'] = _cachedTimezone;
        headers['X-City'] = _cachedCity;

        if (_cachedLatitude != null &&
            _cachedLongitude != null) {
          headers['X-Latitude'] =
              _cachedLatitude.toString();
          headers['X-Longitude'] =
              _cachedLongitude.toString();
        }
      }
    }

    return headers;
  }

  // ============================================================
  // GET
  // ============================================================

  static Future<dynamic> get(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    final response = await http.get(
      url,
      headers: await _getHeaders(
        requiresAuth: requiresAuth,
      ),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // POST
  // ============================================================

  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    final response = await http.post(
      url,
      headers: await _getHeaders(
        requiresAuth: requiresAuth,
      ),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // PUT
  // ============================================================

  static Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    final response = await http.put(
      url,
      headers: await _getHeaders(
        requiresAuth: requiresAuth,
      ),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // PATCH
  // ============================================================

  static Future<dynamic> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    final response = await http.patch(
      url,
      headers: await _getHeaders(
        requiresAuth: requiresAuth,
      ),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // DELETE
  // ============================================================

  static Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    final response = await http.delete(
      url,
      headers: await _getHeaders(
        requiresAuth: requiresAuth,
      ),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // IMAGE UPLOAD - FILE PATH
  // ============================================================

  static Future<dynamic> uploadFoodImage(
    String endpoint,
    String filePath, {
    Map<String, String>? extraFields,
    bool requiresAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    final request = http.MultipartRequest(
      'POST',
      url,
    );

    final headers = await _getHeaders(
      requiresAuth: requiresAuth,
    );

    // MultipartRequest creates its own Content-Type.
    headers.remove('Content-Type');

    request.headers.addAll(headers);

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        filePath,
      ),
    );

    if (extraFields != null) {
      request.fields.addAll(extraFields);
    }

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    return _handleResponse(response);
  }

  // ============================================================
  // IMAGE UPLOAD - BYTES
  //
  // Web-compatible version.
  // Used by FoodScannerScreen with XFile.readAsBytes().
  // ============================================================

  static Future<dynamic> uploadFoodImageBytes(
    String endpoint,
    Uint8List bytes, {
    required String filename,
    Map<String, String>? extraFields,
    bool requiresAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    final request = http.MultipartRequest(
      'POST',
      url,
    );

    final headers = await _getHeaders(
      requiresAuth: requiresAuth,
    );

    // MultipartRequest automatically creates the correct
    // multipart Content-Type including the boundary.
    headers.remove('Content-Type');

    request.headers.addAll(headers);

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
      ),
    );

    if (extraFields != null) {
      request.fields.addAll(extraFields);
    }

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    return _handleResponse(response);
  }

  // ============================================================
  // RESPONSE HANDLER
  // ============================================================

  static dynamic _handleResponse(
    http.Response response,
  ) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = {
        'message': response.body,
      };
    }

    // ----------------------------------------------------------
    // SUCCESS
    // ----------------------------------------------------------

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return decoded;
    }

    // ----------------------------------------------------------
    // UNAUTHORIZED
    // ----------------------------------------------------------

    if (response.statusCode == 401) {
      throw Exception(
        decoded['error'] ??
            'Session expired. Please log in again.',
      );
    }

    // ----------------------------------------------------------
    // FORBIDDEN
    // ----------------------------------------------------------

    if (response.statusCode == 403) {
      throw Exception(
        decoded['error'] ??
            'Access forbidden.',
      );
    }

    // ----------------------------------------------------------
    // OTHER SERVER ERRORS
    // ----------------------------------------------------------

    final errorMessage =
        decoded['error'] ??
        decoded['message'] ??
        'Server error: ${response.statusCode}';

    throw Exception(errorMessage);
  }
}
