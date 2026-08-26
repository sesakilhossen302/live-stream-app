import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import 'profile_controller.dart';

class ProfileInformationController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final ImagePicker _picker = ImagePicker();

  final fullNameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final bioController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final Rx<File?> selectedImage = Rx<File?>(null);
  final RxString profileImageUrl = "".obs;

  @override
  void onInit() {
    super.onInit();
    fetchProfileData();
  }

  Future<void> fetchProfileData() async {
    isLoading.value = true;
    try {
      final response = await _apiClient.getData(ApiUrl.profile);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        fullNameController.text = data['fullName'] ?? "";
        usernameController.text = (data['username'] ?? "").replaceAll('@', '');
        emailController.text = data['email'] ?? "";
        phoneController.text = data['phone'] ?? "";
        bioController.text = data['description'] ?? "";

        final profilePath = data['profile'] ?? "";
        if (profilePath.isNotEmpty) {
          if (profilePath.startsWith('http')) {
            profileImageUrl.value = profilePath;
          } else {
            // Ensure path starts with /
            final formattedPath = profilePath.startsWith('/')
                ? profilePath
                : '/$profilePath';
            profileImageUrl.value = "${ApiUrl.imageBaseUrl}$formattedPath";
          }
        }
      } else {
        Get.snackbar(
          "Error",
          "Failed to fetch profile data",
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "An unexpected error occurred",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        selectedImage.value = File(image.path);
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to pick image",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> saveChanges() async {
    isSaving.value = true;
    try {
      final Map<String, String> fields = {
        "fullName": fullNameController.text.trim(),
        "description": bioController.text.trim(),
        "phone": phoneController.text.trim(),
      };

      final cleanUsername = usernameController.text.replaceAll('@', '').replaceAll(' ', '').trim();
      if (cleanUsername.isNotEmpty) {
        if (cleanUsername.length < 3 || cleanUsername.length > 20) {
          Get.snackbar(
            "Invalid Username",
            "Username must be between 3 and 20 characters.",
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
          isSaving.value = false;
          return;
        }
        fields["username"] = cleanUsername;
      }

      final response = await _apiClient.patchMultipart(
        ApiUrl.profile,
        fields,
        filePath: selectedImage.value?.path,
        fieldName: 'images', // images Field
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.snackbar(
          "Success",
          "Profile updated successfully!",
          backgroundColor: const Color(0xFF22C55E),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        await fetchProfileData();
        if (Get.isRegistered<ProfileController>()) {
          Get.find<ProfileController>().fetchProfileData();
        }
        selectedImage.value = null;
        Get.back();
      } else {
        String errorMessage = "Failed to update profile";
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
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
        "An unexpected error occurred",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isSaving.value = false;
    }
  }

  void discardChanges() {
    selectedImage.value = null;
    fetchProfileData();
  }

  @override
  void onClose() {
    fullNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    bioController.dispose();
    super.onClose();
  }
}
