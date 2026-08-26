import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../core/app_route.dart';
import '../../messages/controller/messages_controller.dart';

class MakeOfferController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  final RxMap<String, dynamic> sellerProduct = <String, dynamic>{}.obs;
  final RxList<dynamic> userProducts = <dynamic>[].obs;
  final Rxn<Map<String, dynamic>> selectedUserProduct = Rxn<Map<String, dynamic>>();
  final RxDouble cashSupplement = 0.0.obs;
  
  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;

  final ImagePicker _picker = ImagePicker();
  final RxBool isCustomOffer = false.obs;

  // Custom offer categories
  final RxList<String> categories = <String>[].obs;
  final RxMap<String, String> categoryNameToId = <String, String>{}.obs;

  // Custom offer form fields
  final customTitleController = TextEditingController();
  final customValueController = TextEditingController();
  final RxDouble customValue = 0.0.obs;
  final RxString customCategory = "Streetwear".obs;
  final RxString customCondition = "Mint".obs;
  final Rxn<File> customImageFile = Rxn<File>();

  final categoriesList = [
    "Fine Art",
    "Sports Cards",
    "Rare Spirits",
    "Luxury Cars",
    "Electronics",
    "Streetwear",
    "TCG",
    "Digital Assets",
  ];
  final conditionsList = ["Mint", "Near Mint", "Excellent", "Good", "Fair"];

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments is Map) {
      sellerProduct.assignAll(Map<String, dynamic>.from(Get.arguments));
    }
    fetchUserProducts();
    fetchCategories();
  }

  Future<void> fetchUserProducts() async {
    final userId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    if (userId.isEmpty) return;

    isLoading.value = true;
    try {
      final response = await _apiClient.getData("${ApiUrl.products}?sellerId=$userId");
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['data'] ?? body['products'] ?? body['result'] ?? [];
        if (list is List) {
          userProducts.assignAll(list);
          if (list.isNotEmpty) {
            selectedUserProduct.value = Map<String, dynamic>.from(list[0]);
          }
        }
      }
    } catch (e) {
      Get.log("Error fetching user products: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void selectProduct(Map<String, dynamic> product) {
    selectedUserProduct.value = product;
  }

  void updateCashSupplement(double val) {
    cashSupplement.value = val;
  }

  double get sellerProductValue {
    final val = sellerProduct['estValue'] ?? sellerProduct['buyNowPrice'] ?? '0';
    return double.tryParse(val.toString()) ?? 0.0;
  }

  double get userProductValue {
    if (isCustomOffer.value) {
      return customValue.value;
    }
    if (selectedUserProduct.value == null) return 0.0;
    final val = selectedUserProduct.value!['estValue'] ?? selectedUserProduct.value!['buyNowPrice'] ?? '0';
    return double.tryParse(val.toString()) ?? 0.0;
  }

  double get valueDelta {
    // Delta = (User Product Value + Cash Supplement) - Seller Product Value
    return (userProductValue + cashSupplement.value) - sellerProductValue;
  }

  Future<void> pickCustomImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        customImageFile.value = File(image.path);
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to pick image");
    }
  }

  Future<String?> _uploadImageToS3(File file) async {
    try {
      final fileName = file.path.split('/').last.split('\\').last;
      final ext = fileName.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final response = await _apiClient.postData("/upload/presign", {
        "fileName": fileName,
        "contentType": contentType,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final uploadUrl = body['data']['url'].toString();

          final fileBytes = await file.readAsBytes();
          final s3Response = await http.put(
            Uri.parse(uploadUrl),
            headers: {
              "Content-Type": contentType,
            },
            body: fileBytes,
          );

          if (s3Response.statusCode == 200 || s3Response.statusCode == 201) {
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

  Future<void> sendOffer() async {
    final senderId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    final seller = sellerProduct['sellerId'];
    final receiverId = (seller is Map) ? (seller['_id'] ?? seller['id'] ?? "") : seller.toString();
    final receiverProductId = sellerProduct['_id'] ?? sellerProduct['id'] ?? "";

    if (senderId.isEmpty || receiverId.isEmpty || receiverProductId.isEmpty) {
      Get.snackbar("Error", "Missing sender, receiver, or product information.", snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isSubmitting.value = true;
    try {
      String senderProductId = "";

      if (isCustomOffer.value) {
        final title = customTitleController.text.trim();
        final valueStr = customValueController.text.trim();
        final estVal = double.tryParse(valueStr) ?? 0.0;

        if (title.isEmpty) {
          Get.snackbar("Error", "Please enter a title for your custom offer.", snackPosition: SnackPosition.BOTTOM);
          isSubmitting.value = false;
          return;
        }

        String imageUrl = "";
        if (customImageFile.value != null) {
          final s3Url = await _uploadImageToS3(customImageFile.value!);
          if (s3Url != null && s3Url.isNotEmpty) {
            imageUrl = s3Url;
          } else {
            final bytes = await customImageFile.value!.readAsBytes();
            final base64Str = base64Encode(bytes);
            final mimeType = customImageFile.value!.path.split('.').last.toLowerCase();
            imageUrl = "data:image/$mimeType;base64,$base64Str";
          }
        }

        final String categoryId = categoryNameToId[customCategory.value] ?? customCategory.value;

        final requestBody = {
          "title": title,
          "description": "Custom trade offer item.",
          "category": categoryId,
          "condition": customCondition.value,
          "estValue": estVal,
          "buyNowPrice": estVal,
          "allowTrade": true,
          "sellerId": senderId,
          "images": imageUrl.isNotEmpty ? [imageUrl] : [],
        };

        final prodResponse = await _apiClient.postData(ApiUrl.products, requestBody);
        if (prodResponse.statusCode == 200 || prodResponse.statusCode == 201) {
          final prodBody = jsonDecode(prodResponse.body);
          final newProd = prodBody['data'] ?? prodBody;
          senderProductId = (newProd['_id'] ?? newProd['id'] ?? "").toString();
        } else {
          Get.snackbar("Error", "Failed to create custom product. Status: ${prodResponse.statusCode}", snackPosition: SnackPosition.BOTTOM);
          isSubmitting.value = false;
          return;
        }
      } else {
        if (selectedUserProduct.value == null) {
          Get.snackbar("Error", "Please select a product from your inventory to offer.", snackPosition: SnackPosition.BOTTOM);
          isSubmitting.value = false;
          return;
        }
        senderProductId = selectedUserProduct.value!['_id'] ?? selectedUserProduct.value!['id'] ?? "";
      }

      if (senderProductId.isEmpty) {
        Get.snackbar("Error", "Failed to retrieve offer product ID.", snackPosition: SnackPosition.BOTTOM);
        isSubmitting.value = false;
        return;
      }

      final payload = {
        "receiverId": receiverId,
        "senderProductId": senderProductId,
        "receiverProductId": receiverProductId,
        "cashSupplement": cashSupplement.value,
      };

      final response = await _apiClient.postData("/trades/offer", payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body['success'] == true || response.statusCode == 200 || response.statusCode == 201) {
          final sellerName = (seller is Map) ? (seller['fullName'] ?? seller['name'] ?? seller['username'] ?? "Trader") : "Trader";
          final sellerAvatar = (seller is Map) ? (seller['profile'] ?? seller['profileImage'] ?? seller['avatar'] ?? "") : "";
          _showSuccessDialog(receiverId, sellerName, sellerAvatar);
        } else {
          Get.snackbar("Error", body['message'] ?? "Failed to send trade offer", snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar("Error", "Failed to send trade offer. Status: ${response.statusCode}", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar("Error", "An unexpected error occurred: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSubmitting.value = false;
    }
  }

  void _showSuccessDialog(String receiverId, String receiverName, String receiverAvatar) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32.r)),
        child: Padding(
          padding: EdgeInsets.all(28.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80.r,
                width: 80.r,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 48.sp),
              ),
              SizedBox(height: 24.h),
              Text(
                "Offer Sent! 🚀",
                style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 12.h),
              Text(
                "Your trade proposal has been sent to $receiverName. You can discuss the details in your inbox.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13.sp, height: 1.5),
              ),
              SizedBox(height: 32.h),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Get.back(); // close dialog
                        Get.back(); // close make offer screen
                      },
                      child: Container(
                        height: 52.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(26.r),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Text("Done", style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Get.back(); // close dialog
                        Get.back(); // close make offer screen
                        try {
                          final mc = Get.put(MessagesController());
                          final chatId = await mc.createChatRoom(receiverId);
                          if (chatId != null && chatId.isNotEmpty) {
                            Get.toNamed(
                              AppRoute.messageDetails,
                              arguments: {
                                "chatId": chatId,
                                "name": receiverName.startsWith('@') ? receiverName : "@$receiverName",
                                "avatar": receiverAvatar,
                              },
                            );
                            return;
                          }
                        } catch (e) {
                          Get.log("Error creating chat room: $e");
                        }
                        // Fallback to mock room
                        Get.toNamed(
                          AppRoute.messageDetails,
                          arguments: {
                            "chatId": "mock_room_1",
                            "name": receiverName.startsWith('@') ? receiverName : "@$receiverName",
                            "avatar": receiverAvatar,
                          },
                        );
                      },
                      child: Container(
                        height: 52.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B9BFF), Color(0xFFBD8BFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B9BFF).withOpacity(0.3),
                              blurRadius: 12.r,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text("Go to Inbox", style: TextStyle(color: Colors.black, fontSize: 14.sp, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> fetchCategories() async {
    try {
      var response = await _apiClient.getData("/categories");
      if (response.statusCode != 200 && response.statusCode != 201) {
        response = await _apiClient.getData(ApiUrl.category);
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

        if (parsed.isNotEmpty) {
          categories.assignAll(parsed);
          if (categories.contains(customCategory.value)) {
            // Keep default
          } else {
            customCategory.value = parsed[0];
          }
        }
      }
    } catch (e) {
      Get.log("Error fetching categories in MakeOfferController: $e");
    }
  }

  @override
  void onClose() {
    customTitleController.dispose();
    customValueController.dispose();
    super.onClose();
  }
}
