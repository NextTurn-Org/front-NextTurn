import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// Thin JSON wrapper around the Symfony back (`back-NextTurn`).
///
/// The only place in the app that knows the base URL and HTTP details.
/// Can be swapped for the OpenAPI-generated client later.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<dynamic> get(String path) async =>
      _decode(await _http.get(_uri(path), headers: _headers));

  Future<dynamic> post(String path, Object body) async => _decode(
        await _http.post(_uri(path), headers: _headers, body: jsonEncode(body)),
      );

  Future<void> delete(String path) async =>
      _decode(await _http.delete(_uri(path), headers: _headers));

  void close() => _http.close();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  dynamic _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, res.body);
    }
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }
}
