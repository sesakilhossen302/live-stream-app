import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/push_notification_service.dart';

class OtpController extends GetxController {
  final pinController = TextEditingController();
  final focusNode = FocusNode();

  final RxInt timerSeconds = 60.obs;
  bool _isTimerRunning = false;

  String email = "";
  bool fromForgotPassword = false;
  final RxBool isLoading = false.obs;
  final ApiClient _apiClient = Get.find<ApiClient>();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map) {
      email = args['email'] ?? "";
      fromForgotPassword = args['fromForgotPassword'] ?? false;
    } else {
      email = args ?? "";
    }
    startTimer();
  }

  void startTimer() {
    if (_isTimerRunning) return;
    _isTimerRunning = true;
    timerSeconds.value = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (timerSeconds.value > 0) {
        timerSeconds.value--;
        return true;
      }
      _isTimerRunning = false;
      return false;
    });
  }

  Future<void> onVerify() async {
    String otp = pinController.text;
    if (otp.length != 6) {
      Get.snackbar(
        "Error",
        "Please enter 6-digit OTP",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    if (email.isEmpty) {
      Get.snackbar(
        "Error",
        "Email address is missing. Please try signing up again.",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    try {
      final response = await _apiClient.postData(ApiUrl.verifyAccount, {
        "email": email,
        "oneTimeCode": otp.trim().toString(),
        "authType": fromForgotPassword ? "resetPassword" : "createAccount",
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print("--- OTP Verification Response: $responseData ---");
        String? accessToken;

        if (responseData['data'] != null && responseData['data'] is Map) {
          final dataMap = responseData['data'];
          accessToken = dataMap['accessToken'] ?? dataMap['token'];
        } else {
          accessToken =
              responseData['accessToken'] ??
              responseData['token'] ??
              (responseData['data'] is String ? responseData['data'] : null);
        }

        if (accessToken != null && accessToken.isNotEmpty) {
          print("--- SAVING TOKEN: $accessToken ---");
          await SharePrefsHelper.setString(
            SharePrefsHelper.accessTokenKey,
            accessToken,
          );
          await SharePrefsHelper.setBool(SharePrefsHelper.isLoginKey, true);
          // Sync device token
          PushNotificationService.instance.syncDeviceToken();
        } else {
          print("--- NO TOKEN FOUND IN RESPONSE ---");
        }

        Get.snackbar(
          "Success",
          "Verification Successful!",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );

        if (fromForgotPassword) {
          Get.toNamed(AppRoute.resetPassword, arguments: {
            'token': accessToken ?? '',
            'email': email,
          });
        } else {
          Get.offAllNamed(AppRoute.category);
        }
      } else {
        String errorMessage = "Verification failed. Please check the code.";
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
        "Error",
        "An unexpected error occurred. Please check your connection.",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> onResend() async {
    if (timerSeconds.value == 0) {
      isLoading.value = true;
      try {
        final String authType = fromForgotPassword ? "resetPassword" : "createAccount";
        final response = await _apiClient.postData(ApiUrl.resendOtp, {
          "email": email,
          "authType": authType,
        });

        if (response.statusCode == 200 || response.statusCode == 201) {
          Get.snackbar(
            "Success",
            "OTP Resent Successfully!",
            backgroundColor: Colors.green.withOpacity(0.8),
            colorText: Colors.white,
          );
          startTimer();
        } else {
          String errorMessage = "Failed to resend OTP.";
          try {
            final data = jsonDecode(response.body);
            if (data['message'] != null) {
              errorMessage = data['message'];
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
          "Error",
          "An unexpected error occurred.",
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      } finally {
        isLoading.value = false;
      }
    }
  }

  @override
  void onClose() {
    pinController.dispose();
    focusNode.dispose();
    super.onClose();
  }
}
