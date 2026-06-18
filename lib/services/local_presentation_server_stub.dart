import 'package:supabase_flutter/supabase_flutter.dart';

class LocalPresentationServer {
  LocalPresentationServer._();

  static final instance = LocalPresentationServer._();

  bool get isAvailable => false;
  String? get lastError => null;

  Future<void> start(SupabaseClient supabase) async {}

  Future<Map<String, dynamic>?> findPresentationByCode(String code) async {
    return null;
  }

  Future<List<dynamic>> fetchSlides(String presentationId) async {
    return const [];
  }

  Future<void> submitResponse(Map<String, dynamic> responseData) async {}
}
