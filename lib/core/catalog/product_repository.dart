import 'package:supabase_flutter/supabase_flutter.dart';

import '../networking/api_client.dart';

class ProductRepository {
  ProductRepository({SupabaseClient? client})
    : _client = client ?? ApiClient().client;

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watch(String workshopId) {
    return _client
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('workshop_id', workshopId)
        .order('name')
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  Future<void> save(Map<String, dynamic> product) async {
    await _client.from('products').upsert(product);
  }

  Future<void> archive(String productId) async {
    await _client
        .from('products')
        .update({'is_active': false})
        .eq('id', productId);
  }
}
