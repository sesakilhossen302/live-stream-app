import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';

import '../../../../data/services/push_notification_service.dart';

class LoginController extends GetxController {
  late TextEditingController emailController;
  late TextEditingController passwordController;

  @override
  void onInit() {
    super.onInit();
    emailController = TextEditingController();
    passwordController = TextEditingController();
  }

  final RxBool isLoading = false.obs;
  final RxBool isObscured = true.obs;
  final ApiClient _apiClient = Get.find<ApiClient>();

  void toggleObscure() {
    isObscured.value = !isObscured.value;
  }

  Future<void> onLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty) {
      Get.snackbar(
        "Required",
        "Email or username cannot be empty",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    if (password.isEmpty) {
      Get.snackbar(
        "Required",
        "Password cannot be empty",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    try {
      // Fetch FCM Device Token for Backend Sync (Option A)
      final String? deviceToken = await PushNotificationService.instance.getDeviceToken();

      final Map<String, dynamic> loginPayload = {
        "email": email,
        "password": password,
      };

      if (deviceToken != null && deviceToken.isNotEmpty) {
        loginPayload["deviceToken"] = deviceToken;
      }

      final response = await _apiClient.postData(
        ApiUrl.login,
        loginPayload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['data'] != null) {
          final dataMap = responseData['data'] is Map ? responseData['data'] : responseData;
          final userMap = dataMap['user'] is Map ? dataMap['user'] : (responseData['user'] is Map ? responseData['user'] : {});
          final accessToken = (dataMap['accessToken'] ?? dataMap['token'] ?? '').toString();
          final refreshToken = (dataMap['refreshToken'] ?? '').toString();
          final userId = (dataMap['id'] ?? dataMap['_id'] ?? userMap['id'] ?? userMap['_id'] ?? '').toString();
          final userEmail = (dataMap['email'] ?? userMap['email'] ?? email).toString();

          if (accessToken.isNotEmpty) {
            await SharePrefsHelper.setString(SharePrefsHelper.accessTokenKey, accessToken);
          }
          if (refreshToken.isNotEmpty) {
            await SharePrefsHelper.setString(SharePrefsHelper.refreshTokenKey, refreshToken);
          }
          if (userId.isNotEmpty) {
            await SharePrefsHelper.setString(SharePrefsHelper.userIdKey, userId);
          }
          if (userEmail.isNotEmpty) {
            await SharePrefsHelper.setString(SharePrefsHelper.userEmailKey, userEmail);
          }
          await SharePrefsHelper.setBool(SharePrefsHelper.isLoginKey, true);
<<<<<<< HEAD
          await SharePrefsHelper.setGuest(false);
=======
>>>>>>> de8e507e15ad8ce63f8a30024ad690138cb76a0b

          // Guarantee FCM token is synced to profile
          PushNotificationService.instance.syncDeviceToken();
        }

        Get.snackbar(
          "Success",
          "Login Successful!",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );
        Get.offAllNamed(AppRoute.main);
      } else {
        String errorMessage = "Login failed. Please try again.";
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
        );
      }
    } catch (e) {
      Get.snackbar(
        "Try again","Please check your connection.",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> continueAsGuest() async {
    await SharePrefsHelper.setGuest(true);
    Get.offAllNamed(AppRoute.main);
  }

  void onSignUp() {
    Get.toNamed(AppRoute.signUp);
  }

  void onForgotPassword() {
    Get.toNamed(AppRoute.forgotPassword);
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
