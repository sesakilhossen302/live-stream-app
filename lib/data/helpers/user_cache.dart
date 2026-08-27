import 'dart:convert';
import 'package:get/get.dart';
import '../services/api_client.dart';
import '../services/api_url.dart';

class UserCache {
  static final Map<String, Map<String, String>> _cache = {};

  static Map<String, String>? get(String userId) => _cache[userId];

  static void set(String userId, String name, String avatar) {
    if (userId.isEmpty) return;
    final cleanName = name.replaceAll('@', '').trim();
    if (cleanName.isEmpty || cleanName.toLowerCase() == 'user') return;
    _cache[userId] = {
      'name': cleanName,
      'avatar': avatar,
    };
  }

  static Future<Map<String, String>> fetchUser(ApiClient client, String userId) async {
    if (userId.isEmpty) return {'name': '', 'avatar': ''};
    if (_cache.containsKey(userId)) {
      return _cache[userId]!;
    }

    try {
      final res = await client.getData('${ApiUrl.users}/$userId');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body;
        final String fn = (data['fullName'] ?? data['name'] ?? data['username'] ?? '').toString().trim();
        final String av = (data['avatar'] ?? data['profileImage'] ?? data['image'] ?? data['profile'] ?? '').toString();
        if (fn.isNotEmpty && fn.toLowerCase() != 'user') {
          final result = {
            'name': fn.replaceAll('@', '').trim(),
            'avatar': av,
          };
          _cache[userId] = result;
          return result;
        }
      }
    } catch (e) {
      Get.log("UserCache fetch error: $e");
    }

    return {'name': '', 'avatar': ''};
  }
}
