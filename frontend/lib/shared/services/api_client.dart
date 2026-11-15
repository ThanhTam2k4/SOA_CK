import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/soa_services.dart';

class SoaApiClient {
  static const _tokenKey = 'soa_jwt_access_token';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  static Future<bool> checkPortHealth(SoaServiceConfig service) async {
    try {
      final res = await http
          .get(Uri.parse(service.healthUrl))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> ensureJwtToken({
    String username = 'chutro1',
    String password = 'chutropassword123',
  }) async {
    final existing = await getToken();
    if (existing != null && existing.isNotEmpty) return existing;
    try {
      final res = await http
          .post(
            Uri.parse('${SoaServices.identity.apiBase}/auth/login/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final token = data['access'] as String?;
        if (token != null) await setToken(token);
        return token;
      }
    } catch (_) {}
    return null;
  }

  static Future<dynamic> getJson(SoaServiceConfig service, String path) async {
    final token = await ensureJwtToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final res = await http
        .get(Uri.parse('${service.apiBase}$path'), headers: headers)
        .timeout(const Duration(seconds: 3));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw Exception('HTTP ${res.statusCode}');
  }
}

