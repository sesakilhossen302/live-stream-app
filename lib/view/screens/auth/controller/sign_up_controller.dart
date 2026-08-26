import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_route.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';

class SignUpController extends GetxController {
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;

  @override
  void onInit() {
    super.onInit();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  final RxBool agreeToTerms = false.obs;
  final RxBool isPasswordVisible = false.obs;
  final RxBool isConfirmPasswordVisible = false.obs;
  
  final RxBool isLoading = false.obs;
  final ApiClient _apiClient = Get.find<ApiClient>();

  Future<void> onSignUp() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (firstName.isEmpty) {
      Get.snackbar("Required", "First name is required", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (lastName.isEmpty) {
      Get.snackbar("Required", "Last name is required", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (email.isEmpty) {
      Get.snackbar("Required", "Email is required", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (password.isEmpty) {
      Get.snackbar("Required", "Password is required", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (password != confirmPassword) {
      Get.snackbar("Error", "Passwords do not match", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (!agreeToTerms.value) {
      Get.snackbar("Error", "Please agree to the Terms of Service and Privacy Policy", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    isLoading.value = true;

    try {
      final fullName = "$firstName $lastName";
      final response = await _apiClient.postData(
        ApiUrl.signUp,
        {
          "fullName": fullName,
          "email": email,
          "password": password,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.snackbar(
          "Success",
          "Registration successful! OTP sent to your email.",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );
        Get.toNamed(AppRoute.otp, arguments: email);
      } else {
        String errorMessage = "Registration failed. Please try again.";
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

  void onLogin() {
    Get.back();
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
