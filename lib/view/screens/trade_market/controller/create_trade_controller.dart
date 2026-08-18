import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../profile/controller/profile_controller.dart';

class CreateTradeController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final ImagePicker _picker = ImagePicker();

  // Your Item Fields
  final itemNameController = TextEditingController();
  final descriptionController = TextEditingController();
  final estValueController = TextEditingController();
  final buyNowPriceController = TextEditingController(); // Optional instant buy price
  final RxBool enableBuyNow = false.obs; // Toggle for buy now price

  // Shipping Weight Fields (Feature 1)
  final shippingWeightController = TextEditingController();
  final RxString shippingWeightUnit = "lbs".obs;
  final weightUnits = ["lbs", "oz", "kg"];

  // Custom Offer Settings (Feature 2)
  final RxBool allowOffers = true.obs; // Toggle for accepting custom offers
  final minOfferAmountController = TextEditingController(); // Minimum acceptable offer amount

  var selectedCategory = "Streetwear".obs;
  var selectedCondition = "Mint".obs;

  final RxList<String> categories = <String>[].obs;
  final RxMap<String, String> categoryNameToId = <String, String>{}.obs;
  final conditions = ["Mint", "Near Mint", "Excellent", "Good", "Fair"];

  // Image handling
  final RxList<File> selectedImages = <File>[].obs;
  final RxInt selectedImageIndex = 0.obs; // Currently viewed image index
  final RxBool isLoading = false.obs;

  // What You Want Fields
  final desiredItemController = TextEditingController();
  final minValueController = TextEditingController();
  final maxValueController = TextEditingController();

  var targetCategory = "Any Category".obs;
  final RxList<String> targetCategories = <String>["Any Category"].obs;

  Future<void> pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 20,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (images.isNotEmpty) {
        selectedImages.addAll(images.map((img) => File(img.path)));
        selectedImageIndex.value = selectedImages.length - 1; // set preview to last selected
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to pick images");
    }
  }

  void removeImage(int index) {
    if (index >= 0 && index < selectedImages.length) {
      selectedImages.removeAt(index);
      if (selectedImageIndex.value >= selectedImages.length) {
        selectedImageIndex.value = selectedImages.isEmpty ? 0 : selectedImages.length - 1;
      }
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchCategories();
  }

  void setCategory(String val) => selectedCategory.value = val;
  void setCondition(String val) => selectedCondition.value = val;
  
  Future<void> fetchCategories() async {
    try {
      Get.log("🔄 [fetchCategories] Fetching category from primary: /categories");
      var response = await _apiClient.getData("/categories");
      Get.log("🔄 [fetchCategories] /categories status code: ${response.statusCode}");

      // Fallback: try singular /category if /categories fails
      if (response.statusCode != 200 && response.statusCode != 201) {
        Get.log("🔄 [fetchCategories] /categories failed, trying fallback: ${ApiUrl.category}");
        response = await _apiClient.getData(ApiUrl.category);
        Get.log("🔄 [fetchCategories] /category fallback status code: ${response.statusCode}");
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        var decoded = jsonDecode(response.body);
        List<dynamic> dataList = [];
        
        if (decoded is List) {
          dataList = decoded;
        } else if (decoded is Map) {
          if (decoded['data'] is List) {
            dataList = decoded['data'];
          } else if (decoded['categories'] is List) {
            dataList = decoded['categories'];
          } else if (decoded['data'] is Map && decoded['data']['data'] is List) {
            dataList = decoded['data']['data'];
          }
        }

        // If categories are empty, try the other endpoint just in case
        if (dataList.isEmpty && response.request?.url.path.endsWith("/categories") == true) {
          Get.log("🔄 [fetchCategories] /categories was empty, trying fallback: ${ApiUrl.category}");
          response = await _apiClient.getData(ApiUrl.category);
          decoded = jsonDecode(response.body);
          if (decoded is List) {
            dataList = decoded;
          } else if (decoded is Map) {
            if (decoded['data'] is List) {
              dataList = decoded['data'];
            } else if (decoded['categories'] is List) {
              dataList = decoded['categories'];
            }
          }
        }

        categoryNameToId.clear();
        final List<String> parsed = [];
        for (var item in dataList) {
          if (item is Map) {
            final String name = item['name']?.toString() ?? item['title']?.toString() ?? "";
            final String id = item['_id']?.toString() ?? item['id']?.toString() ?? "";
            if (name.isNotEmpty && id.isNotEmpty) {
              parsed.add(name);
              categoryNameToId[name] = id;
            }
          }
        }

        Get.log("🔄 [fetchCategories] Successfully parsed ${parsed.length} categories: $parsed");

        if (parsed.isNotEmpty) {
          categories.assignAll(parsed);
          targetCategories.assignAll(["Any Category", ...parsed]);
          if (!categories.contains(selectedCategory.value)) {
            selectedCategory.value = parsed[0];
          }
        }
      }
    } catch (e) {
      Get.log("Error fetching categories: $e");
    }
  }

  void setTargetCategory(String val) => targetCategory.value = val;

  Future<String?> _uploadImageToS3(File file) async {
    try {
      final fileName = file.path.split('/').last.split('\\').last;
      final ext = fileName.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

      // 1. Get S3 Presigned URL
      final response = await _apiClient.postData("/upload/presign", {
        "fileName": fileName,
        "contentType": contentType,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final uploadUrl = body['data']['url'].toString();

          // 2. PUT request directly to S3
          final fileBytes = await file.readAsBytes();
          final s3Response = await http.put(
            Uri.parse(uploadUrl),
            headers: {
              "Content-Type": contentType,
            },
            body: fileBytes,
          );

          if (s3Response.statusCode == 200 || s3Response.statusCode == 201) {
            // Retrieve actual file URL from presigned URL
            final s3Url = uploadUrl.split('?').first;
            return s3Url;
          }
        }
      }
    } catch (e) {
      Get.log("S3 upload error: $e");
    }
    return null;
  }

  Future<void> postTrade() async {
    final title = itemNameController.text.trim();
    final description = descriptionController.text.trim();
    final estValue = estValueController.text.trim();

    if (title.isEmpty || description.isEmpty || estValue.isEmpty) {
      Get.snackbar(
        "Error",
        "Please fill all required fields",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    if (selectedImages.isEmpty) {
      Get.snackbar(
        "Error",
        "Please select at least one image",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    try {
      final String userId = SharePrefsHelper.getString(
        SharePrefsHelper.userIdKey,
      );

      final List<String> imageUrls = [];

      // S3 upload with local base64 fallback
      for (var file in selectedImages) {
        final s3Url = await _uploadImageToS3(file);
        if (s3Url != null && s3Url.isNotEmpty) {
          imageUrls.add(s3Url);
        } else {
          // Fallback to Base64 String
          final bytes = await file.readAsBytes();
          final base64Str = base64Encode(bytes);
          final mimeType = file.path.split('.').last.toLowerCase();
          imageUrls.add("data:image/$mimeType;base64,$base64Str");
        }
      }

      final String buyNowRaw = buyNowPriceController.text.trim();
      final double? buyNowParsed = enableBuyNow.value && buyNowRaw.isNotEmpty
          ? double.tryParse(buyNowRaw)
          : null;

      final String shippingWeightRaw = shippingWeightController.text.trim();
      final double shippingWeightParsed = double.tryParse(shippingWeightRaw) ?? 0.0;

      final String minOfferRaw = minOfferAmountController.text.trim();
      final double? minOfferParsed = allowOffers.value && minOfferRaw.isNotEmpty
          ? double.tryParse(minOfferRaw)
          : null;

      final selectedCategoryId = categoryNameToId[selectedCategory.value] ?? selectedCategory.value;

      final Map<String, dynamic> requestBody = {
        "title": title,
        "description": description,
        "category": selectedCategoryId, // ✅ Passes valid MongoDB ObjectId reference
        "condition": selectedCondition.value,
        "estValue": double.tryParse(estValue) ?? 0.0,
        if (buyNowParsed != null) "buyNowPrice": buyNowParsed,
        "allowOffers": allowOffers.value,
        if (minOfferParsed != null) "minOfferAmount": minOfferParsed,
        if (shippingWeightParsed > 0) "shippingWeight": shippingWeightParsed,
        "shippingWeightUnit": shippingWeightUnit.value,
        "allowTrade": true,
        "sellerId": userId,
        "images": imageUrls,
        "lookingFor": desiredItemController.text.trim(),
        "targetCategory": targetCategory.value,
        "minValue": double.tryParse(minValueController.text.trim()) ?? 0.0,
        "maxValue": double.tryParse(maxValueController.text.trim()) ?? 0.0,
      };

      final response = await _apiClient.postData(
        ApiUrl.products,
        requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh the profile controller if active in memory to display the new item instantly
        try {
          if (Get.isRegistered<ProfileController>()) {
            Get.find<ProfileController>().fetchProfileData();
          }
        } catch (_) {}

        Get.back();
        Get.snackbar(
          "Success",
          "Your trade has been posted successfully!",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF8B9BFF),
          colorText: Colors.black,
        );
      } else {
        String errorMessage = "Failed to post trade";
        try {
          final data = jsonDecode(response.body);
          errorMessage = data['message'] ?? errorMessage;
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
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    itemNameController.dispose();
    descriptionController.dispose();
    estValueController.dispose();
    buyNowPriceController.dispose();
    shippingWeightController.dispose();
    minOfferAmountController.dispose();
    desiredItemController.dispose();
    minValueController.dispose();
    maxValueController.dispose();
    super.onClose();
  }
}

