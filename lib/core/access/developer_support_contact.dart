import '../networking/api_client.dart';

class DeveloperSupportContact {
  const DeveloperSupportContact({required this.email, required this.phone});

  static const fallback = DeveloperSupportContact(
    email: 'luisarmandoceron91@gmail.com',
    phone: '3207539325',
  );

  final String email;
  final String phone;

  static Future<DeveloperSupportContact> load() async {
    if (!ApiClient.cloudEnabled || !ApiClient().isInitialized) return fallback;
    try {
      final result = await ApiClient().client
          .rpc('get_developer_support_contact')
          .timeout(const Duration(seconds: 4));
      if (result is Map) {
        final email = result['email']?.toString().trim() ?? '';
        final phone = result['phone']?.toString().trim() ?? '';
        if (email.contains('@') && phone.isNotEmpty) {
          return DeveloperSupportContact(email: email, phone: phone);
        }
      }
    } catch (_) {}
    return fallback;
  }
}
