import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_url.dart';
import 'socket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../core/app_route.dart';

import '../helpers/shared_prefe.dart';

class ApiClient {
  final String baseUrl = ApiUrl.baseUrl;

  // Base Headers
  Map<String, String> getHeader() {
    final token = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Debug Log Helper for Requests
  void _logRequest(String method, Uri url, Map<String, String> headers, {dynamic body, Map<String, String>? fields, List<String>? filePaths, String? fileFieldName}) {
    if (!kDebugMode) return;
    print('╔═══════════════════════════════════════════════════════════════════════════');
    print('║ 🚀 [API REQUEST] -> ${method.toUpperCase()}');
    print('╠═══════════════════════════════════════════════════════════════════════════');
    print('║ 🔗 URL: $url');
    print('║ 📂 Headers:');
    headers.forEach((key, value) => print('║    • $key: $value'));
    if (body != null) {
      print('║ 📝 Body:');
      try {
        final parsed = body is String ? jsonDecode(body) : body;
        final prettyString = const JsonEncoder.withIndent('  ').convert(parsed);
        for (var line in prettyString.split('\n')) {
          print('║    $line');
        }
      } catch (_) {
        print('║    $body');
      }
    }
    if (fields != null && fields.isNotEmpty) {
      print('║ 📋 Fields:');
      fields.forEach((key, value) => print('║    • $key: $value'));
    }
    if (filePaths != null && filePaths.isNotEmpty) {
      print('║ 📁 Files (Field: $fileFieldName):');
      for (var path in filePaths) {
        print('║    • $path');
      }
    }
    print('╚═══════════════════════════════════════════════════════════════════════════');
  }

  // Debug Log Helper for Responses
  void _logResponse(String method, Uri url, http.Response response, DateTime startTime) {
    if (!kDebugMode) return;
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    final statusColor = isSuccess ? '✅' : '❌';
    print('╔═══════════════════════════════════════════════════════════════════════════');
    print('║ $statusColor [API RESPONSE] -> ${method.toUpperCase()} | Status: ${response.statusCode} | Time: ${duration}ms');
    print('╠═══════════════════════════════════════════════════════════════════════════');
    print('║ 🔗 URL: $url');
    print('║ 💬 Response Body:');
    try {
      final parsed = jsonDecode(response.body);
      final prettyString = const JsonEncoder.withIndent('  ').convert(parsed);
      for (var line in prettyString.split('\n')) {
        print('║    $line');
      }
    } catch (_) {
      for (var line in response.body.split('\n')) {
        print('║    $line');
      }
    }
    print('╚═══════════════════════════════════════════════════════════════════════════');
  }

  // Debug Log Helper for Errors
  void _logError(String method, Uri url, dynamic error, DateTime startTime) {
    if (!kDebugMode) return;
    final duration = DateTime.now().difference(startTime).inMilliseconds;
    print('╔═══════════════════════════════════════════════════════════════════════════');
    print('║ 💥 [API ERROR] -> ${method.toUpperCase()} | Time: ${duration}ms');
    print('╠═══════════════════════════════════════════════════════════════════════════');
    print('║ 🔗 URL: $url');
    print('║ ⚠️ Error details: $error');
    print('╚═══════════════════════════════════════════════════════════════════════════');
  }

  // POST Request
  Future<http.Response> postData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$uri');
    final Map<String, String> requestHeaders = headers ?? getHeader();
    final String requestBody = body is Map || body is List
        ? jsonEncode(body)
        : body.toString();

    _logRequest('POST', url, requestHeaders, body: body);

    final startTime = DateTime.now();
    try {
      final response = await http.post(
        url,
        headers: requestHeaders,
        body: requestBody,
      );

      _logResponse('POST', url, response, startTime);
      return await _checkAndRefreshToken(uri, response, () => postData(uri, body, headers: headers));
    } catch (e) {
      _logError('POST', url, e, startTime);
      rethrow;
    }
  }

  // POST Multipart Request
  Future<http.Response> postMultipart(
    String uri,
    Map<String, String> fields, {
    List<String>? filePaths,
    String fieldName = 'images',
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$uri');
    final Map<String, String> requestHeaders = headers ?? getHeader();
    requestHeaders.remove('Content-Type');

    _logRequest(
      'POST (Multipart)',
      url,
      requestHeaders,
      fields: fields,
      filePaths: filePaths,
      fileFieldName: fieldName,
    );

    final startTime = DateTime.now();
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(requestHeaders);

      fields.forEach((key, value) {
        request.fields[key] = value;
      });

      if (filePaths != null) {
        for (String path in filePaths) {
          final mimeType = path.endsWith('.png') ? 'png' : 'jpeg';
          request.files.add(
            await http.MultipartFile.fromPath(
              fieldName,
              path,
              contentType: MediaType('image', mimeType),
            ),
          );
        }
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(const Duration(seconds: 30));

      _logResponse('POST (Multipart)', url, response, startTime);
      return await _checkAndRefreshToken(
        uri,
        response,
        () => postMultipart(uri, fields, filePaths: filePaths, fieldName: fieldName, headers: headers),
      );
    } catch (e) {
      _logError('POST (Multipart)', url, e, startTime);
      rethrow;
    }
  }

  // PATCH Request
  Future<http.Response> patchData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$uri');
    final Map<String, String> requestHeaders = headers ?? getHeader();
    final String requestBody = body is Map || body is List
        ? jsonEncode(body)
        : body.toString();

    _logRequest('PATCH', url, requestHeaders, body: body);

    final startTime = DateTime.now();
    try {
      final response = await http.patch(
        url,
        headers: requestHeaders,
        body: requestBody,
      );

      _logResponse('PATCH', url, response, startTime);
      return await _checkAndRefreshToken(uri, response, () => patchData(uri, body, headers: headers));
    } catch (e) {
      _logError('PATCH', url, e, startTime);
      rethrow;
    }
  }

  // PATCH Multipart Request
  Future<http.Response> patchMultipart(
    String uri,
    Map<String, String> fields, {
    String? filePath,
    String fieldName = 'profile',
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$uri');
    final Map<String, String> requestHeaders = headers ?? getHeader();
    requestHeaders.remove('Content-Type');

    _logRequest(
      'PATCH (Multipart)',
      url,
      requestHeaders,
      fields: fields,
      filePaths: filePath != null ? [filePath] : null,
      fileFieldName: fieldName,
    );

    final startTime = DateTime.now();
    try {
      final request = http.MultipartRequest('PATCH', url);
      request.headers.addAll(requestHeaders);
      request.fields.addAll(fields);

      if (filePath != null) {
        final mimeType = filePath.endsWith('.png') ? 'png' : 'jpeg';
        request.files.add(
          await http.MultipartFile.fromPath(
            fieldName,
            filePath,
            contentType: MediaType('image', mimeType),
          ),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(const Duration(seconds: 30));

      _logResponse('PATCH (Multipart)', url, response, startTime);
      return await _checkAndRefreshToken(
        uri,
        response,
        () => patchMultipart(uri, fields, filePath: filePath, fieldName: fieldName, headers: headers),
      );
    } catch (e) {
      _logError('PATCH (Multipart)', url, e, startTime);
      rethrow;
    }
  }

  // DELETE Request
  Future<http.Response> deleteData(
    String uri, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$uri');
    final Map<String, String> requestHeaders = headers ?? getHeader();
    final String? requestBody = body != null
        ? (body is Map || body is List ? jsonEncode(body) : body.toString())
        : null;

    _logRequest('DELETE', url, requestHeaders, body: body);

    final startTime = DateTime.now();
    try {
      final request = http.Request('DELETE', url);
      request.headers.addAll(requestHeaders);
      if (requestBody != null) {
        request.body = requestBody;
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(const Duration(seconds: 30));

      _logResponse('DELETE', url, response, startTime);
      return await _checkAndRefreshToken(
        uri,
        response,
        () => deleteData(uri, body: body, headers: headers),
      );
    } catch (e) {
      _logError('DELETE', url, e, startTime);
      rethrow;
    }
  }

  // GET Request
  Future<http.Response> getData(
    String uri, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$uri');
    final Map<String, String> requestHeaders = headers ?? getHeader();

    _logRequest('GET', url, requestHeaders);

    final startTime = DateTime.now();
    try {
      final response = await http.get(url, headers: requestHeaders);

      _logResponse('GET', url, response, startTime);
      return await _checkAndRefreshToken(uri, response, () => getData(uri, headers: headers));
    } catch (e) {
      _logError('GET', url, e, startTime);
      rethrow;
    }
  }

  // Interceptor to handle expired tokens, permission errors, and retry requests
  Future<http.Response> _checkAndRefreshToken(
    String uri,
    http.Response response,
    Future<http.Response> Function() retryAction,
  ) async {
    // If in Guest mode, do not trigger forced logout or refresh token logic
    if (SharePrefsHelper.isGuest || SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey).isEmpty) {
      return response;
    }
    // Check if session/token is expired or account is invalid
    if (response.statusCode >= 400) {
      try {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final String rawMsg = (body['message'] ?? body['error'] ?? body['msg'] ?? "").toString();
        final String lowerMsg = rawMsg.toLowerCase();

        if (lowerMsg.contains("account is deleted") ||
            lowerMsg.contains("account has been deleted") ||
            lowerMsg.contains("user not found") ||
            lowerMsg.contains("user does not exist") ||
            lowerMsg.contains("account is deactivated") ||
            lowerMsg.contains("jwt malformed") ||
            lowerMsg.contains("invalid token") ||
            lowerMsg.contains("invalid signature") ||
            lowerMsg.contains("jwt expired") ||
            lowerMsg.contains("token expired") ||
            lowerMsg.contains("session expired") ||
            lowerMsg.contains("unauthorized") ||
            lowerMsg.contains("not logged in") ||
            lowerMsg.contains("token is not valid")) {
          await _logoutUser(message: rawMsg.isNotEmpty ? rawMsg : "Your session has expired. Please log in again.");
          return response;
        }
      } catch (_) {}
    }

    if ((response.statusCode == 401 || (response.statusCode == 403 && (uri.contains("/users/profile") || uri == ApiUrl.profile))) && uri != "/auth/refresh-token") {
      final success = await _refreshToken();
      if (success) {
        // Token refresh succeeded, retry request with new token
        return await retryAction();
      } else {
        // Refresh failed, log out user and redirect directly to Login
        await _logoutUser(message: "Your session has expired. Please log in again.");
      }
    } else if (response.statusCode == 403) {
      try {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final String message = (body['message'] ?? body['error'] ?? body['msg'] ?? "").toString();
        if (message.toLowerCase().contains("not verified") || 
            message.toLowerCase().contains("admin approval") ||
            message.toLowerCase().contains("seller account")) {
          _showVerificationPendingDialog(message);
        }
      } catch (_) {}
    }
    return response;
  }

  // Calls refresh token endpoint to get new access token
  Future<bool> _refreshToken() async {
    final rToken = SharePrefsHelper.getString(SharePrefsHelper.refreshTokenKey);
    if (rToken.isEmpty) return false;

    try {
      final url = Uri.parse('$baseUrl/auth/refresh-token');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final body = jsonEncode({
        'refreshToken': rToken,
      });

      if (kDebugMode) {
        print("🔄 [API CLIENT] Session expired. Trying to refresh token...");
      }

      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final resBody = jsonDecode(response.body);
        final data = resBody['data'] is Map ? resBody['data'] : resBody;
        final newAccessToken = data['accessToken'] ?? data['token'] ?? resBody['accessToken'] ?? "";
        final newRefreshToken = data['refreshToken'] ?? resBody['refreshToken'] ?? "";

        if (newAccessToken.toString().isNotEmpty) {
          await SharePrefsHelper.setString(SharePrefsHelper.accessTokenKey, newAccessToken.toString());
          if (newRefreshToken.toString().isNotEmpty) {
            await SharePrefsHelper.setString(SharePrefsHelper.refreshTokenKey, newRefreshToken.toString());
          }
          if (kDebugMode) {
            print("✅ [API CLIENT] Token refresh successful. Saved to SharedPreferences.");
          }
          return true;
        }
      }
      if (kDebugMode) {
        print("❌ [API CLIENT] Token refresh failed: Status ${response.statusCode}");
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print("❌ [API CLIENT] Token refresh exception: $e");
      }
      return false;
    }
  }

  // Clear preferences and navigate back to Login
  Future<void> _logoutUser({String? message}) async {
    if (kDebugMode) {
      print("🚨 [API CLIENT] Redirecting to Login screen...");
    }
    try {
      Get.find<SocketService>().disconnectSocket();
    } catch (_) {}
    await SharePrefsHelper.clear();
    Get.offAllNamed(AppRoute.login);
    Get.snackbar(
      "Session Expired",
      message ?? "Your session has expired. Please log in again.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFF6B35),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  void _showVerificationPendingDialog(String message) {
    if (Get.isDialogOpen ?? false) return;
    
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF11111A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Row(
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              color: const Color(0xFFFFB800),
              size: 24.sp,
            ),
            SizedBox(width: 10.w),
            Text(
              "Verification Pending",
              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Text(
          message.isNotEmpty ? message : "Your seller account is not verified yet. Please wait for admin approval.",
          style: TextStyle(color: Colors.white70, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              "Got it",
              style: TextStyle(color: const Color(0xFF8B9BFF), fontWeight: FontWeight.bold, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }
}
