import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';

class ResetPasswordController extends GetxController {
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;

  @override
  void onInit() {
    super.onInit();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }
  final RxBool isLoading = false.obs;
  final ApiClient _apiClient = Get.find<ApiClient>();

  Future<void> onResetPassword() async {
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (password.isEmpty) {
      Get.snackbar(
        "Error",
        "Password is required",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    if (password != confirmPassword) {
      Get.snackbar(
        "Error",
        "Passwords do not match",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    // Extract token from route arguments or persistent store
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final String passedToken = (args['token'] ?? '').toString();
    final savedToken = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);
    String rawToken = (passedToken.isNotEmpty ? passedToken : savedToken).trim();
    if (rawToken.startsWith('Bearer ')) {
      rawToken = rawToken.substring(7).trim();
    }
    print("--- ATTEMPTING RESET WITH RAW TOKEN: $rawToken ---");

    try {
      final response = await _apiClient.postData(
        ApiUrl.resetPassword,
        {
          "password": password,
        },
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (rawToken.isNotEmpty) 'Authorization': 'Bearer $rawToken',
          if (rawToken.isNotEmpty) 'authorization': rawToken,
          if (rawToken.isNotEmpty) 'token': rawToken,
          if (rawToken.isNotEmpty) 'tempToken': rawToken,
          if (rawToken.isNotEmpty) 'forget-password-token': rawToken,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.snackbar(
          "Success",
          "Password reset successful! Please login with your new password.",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        Get.offAllNamed(AppRoute.login);
      } else {
        String errorMessage = "Failed to reset password.";
        try {
          final data = jsonDecode(response.body);
          if (data['message'] != null) {
            errorMessage = data['message'];
          } else if (data['error'] != null) {
            errorMessage = data['error'];
          }
        } catch (_) {}

        Get.snackbar(
          "Error",
          errorMessage,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "An unexpected error occurred.",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
