import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

typedef Json = Map<String, dynamic>;

List<Json> rows(Json data, String key) =>
    (data[key] as List<dynamic>).cast<Json>();

class ChoferApi {
  ChoferApi(this._token, {this.scope = 'chofer'});

  final String _token;
  final String scope;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AuthService.baseUrl}/v1/$scope/$path')
          .replace(queryParameters: query);

  Future<http.Response> _send(Future<http.Response> request) async {
    late final http.Response response;
    try {
      response = await request.timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const ChoferError('La API tardó demasiado. Puedes reintentar.');
    } on http.ClientException {
      throw const ChoferError('No se pudo conectar con la API.');
    }
    if (response.statusCode >= 400) {
      String? message;
      try {
        message =
            (jsonDecode(utf8.decode(response.bodyBytes)) as Json)['mensaje']
                as String?;
      } on FormatException {
        // El servidor intermediario puede devolver HTML.
      }
      throw ChoferError(message ?? 'Error HTTP ${response.statusCode}.');
    }
    return response;
  }

  Future<Json> get(String path, [Map<String, String>? query]) async {
    final response = await _send(
      http.get(_uri(path, query), headers: _headers),
    );
    return jsonDecode(utf8.decode(response.bodyBytes)) as Json;
  }

  Future<Json> post(
    String path,
    Json data, [
    Map<String, String>? query,
  ]) async {
    final response = await _send(
      http.post(_uri(path, query), headers: _headers, body: jsonEncode(data)),
    );
    return jsonDecode(utf8.decode(response.bodyBytes)) as Json;
  }

  Future<Uint8List> evidence(String path) async =>
      (await _send(http.get(_uri(path), headers: _headers))).bodyBytes;

  Future<void> logout() async {
    await _send(
      http.post(
        Uri.parse('${AuthService.baseUrl}/auth/logout'),
        headers: _headers,
      ),
    );
  }
}

class ChoferError implements Exception {
  const ChoferError(this.message);
  final String message;

  @override
  String toString() => message;
}

String operationKey() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
