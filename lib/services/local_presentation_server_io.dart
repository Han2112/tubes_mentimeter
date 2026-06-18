import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocalPresentationServer {
  LocalPresentationServer._();

  static final instance = LocalPresentationServer._();

  static const int _port = 8787;
  static final Uri _baseUri = Uri.parse('http://127.0.0.1:$_port');

  HttpServer? _server;
  SupabaseClient? _supabase;
  String? _lastError;

  bool get isAvailable => _server != null;
  String? get lastError => _lastError;

  Future<void> start(SupabaseClient supabase) async {
    _supabase = supabase;
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
      _server!.listen(_handleRequest);
      _lastError = null;
      debugPrint('Local presentation server running on $_baseUri');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Local presentation server failed to start: $e');
    }
  }

  Future<Map<String, dynamic>?> findPresentationByCode(String code) async {
    final response = await _getJson(
      '/presentations/code/${Uri.encodeComponent(code)}',
    );
    if (response == null) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<List<dynamic>> fetchSlides(String presentationId) async {
    final response = await _getJson('/presentations/$presentationId/slides');
    if (response is List) return response;
    return const [];
  }

  Future<void> submitResponse(Map<String, dynamic> responseData) async {
    await _postJson('/responses', responseData);
  }

  Future<dynamic> _getJson(String path) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(_baseUri.resolve(path));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == HttpStatus.notFound) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body);
      }
      return jsonDecode(body);
    } on SocketException {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _postJson(String path, Map<String, dynamic> data) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(_baseUri.resolve(path));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(data));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body);
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _addCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      await request.response.close();
      return;
    }

    try {
      final supabase = _supabase;
      if (supabase == null) {
        await _sendJson(request.response, {
          'error': 'Supabase belum siap.',
        }, statusCode: HttpStatus.serviceUnavailable);
        return;
      }

      final segments = request.uri.pathSegments;

      if (request.method == 'GET' &&
          segments.length == 3 &&
          segments[0] == 'presentations' &&
          segments[1] == 'code') {
        final presentation = await supabase
            .from('presentations')
            .select()
            .eq('join_code', segments[2])
            .maybeSingle();

        if (presentation == null) {
          await _sendJson(request.response, {
            'error': 'Presentasi tidak ditemukan.',
          }, statusCode: HttpStatus.notFound);
          return;
        }

        await _sendJson(request.response, presentation);
        return;
      }

      if (request.method == 'GET' &&
          segments.length == 3 &&
          segments[0] == 'presentations' &&
          segments[2] == 'slides') {
        final slides = await supabase
            .from('slides')
            .select('*, options(*)')
            .eq('presentation_id', segments[1])
            .order('order_num', ascending: true);

        await _sendJson(request.response, slides);
        return;
      }

      if (request.method == 'POST' &&
          segments.length == 1 &&
          segments[0] == 'responses') {
        final body = await utf8.decoder.bind(request).join();
        final data = Map<String, dynamic>.from(jsonDecode(body));
        await supabase.from('responses').insert(data);
        await _sendJson(request.response, {'ok': true});
        return;
      }

      await _sendJson(request.response, {
        'error': 'Endpoint tidak ditemukan.',
      }, statusCode: HttpStatus.notFound);
    } catch (e) {
      await _sendJson(request.response, {
        'error': e.toString(),
      }, statusCode: HttpStatus.internalServerError);
    }
  }

  void _addCorsHeaders(HttpResponse response) {
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type');
  }

  Future<void> _sendJson(
    HttpResponse response,
    Object data, {
    int statusCode = HttpStatus.ok,
  }) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }
}
