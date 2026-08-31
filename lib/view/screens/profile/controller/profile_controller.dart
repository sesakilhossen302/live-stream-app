import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/push_notification_service.dart';
import '../../../../data/services/socket_service.dart';

class ProfileController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final ImagePicker _picker = ImagePicker();

  var selectedTab = 0.obs;
  final tabs = ["Listings", "Activity", "Settings"];

  var selectedActivityFilter = 0.obs;
  final activityFilters = ["All", "Purchases"];

  // Profile data
  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = "".obs;
  final RxString userId = "".obs;
  final RxString name = "".obs;
  final RxString username = "".obs;
  final RxString email = "".obs;
  final RxString description = "".obs;
  final RxString profileImageUrl = "".obs;
  final RxString coverPhotoUrl = "".obs;
  final RxBool isVerified = false.obs;
  final RxString role = "user".obs;
  final RxBool sellerVerified = false.obs; // Admin-approved seller status
  final RxBool isSwitchingRole = false.obs;
  final RxDouble rating = 0.0.obs;
  final RxInt reviewsCount = 0.obs;
  final RxInt activeCount = 0.obs;
  final RxInt soldCount = 0.obs;
  final RxInt totalTrades = 0.obs;
  final RxInt positivePercent = 0.obs;
  final RxInt followersCount = 0.obs;
  final RxInt followingCount = 0.obs;

  // User listings
  final RxList<dynamic> userListings = <dynamic>[].obs;

  // Activity data
  final RxList<dynamic> notificationsList = <dynamic>[].obs;
  final RxList<dynamic> purchasesList = <dynamic>[].obs;
  final RxBool isActivityLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProfileData();
    final userId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    if (userId.isNotEmpty) {
      fetchPurchases(userId);
      fetchNotifications();
    }
  }

  Future<void> fetchProfileData() async {
    if (SharePrefsHelper.isGuest || SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey).isEmpty) {
      isLoading.value = false;
      hasError.value = false;
      name.value = "Guest User";
      username.value = "@guest";
      description.value = "You are currently browsing as a guest.";
      return;
    }

    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = "";
    try {
      final response = await _apiClient.getData(ApiUrl.profile);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];

        final String fn = data['fullName'] ?? "";
        name.value = fn.isNotEmpty ? fn : "User";
        if (fn.isNotEmpty) {
          SharePrefsHelper.setString('fullName', fn);
        }
        final String un = data['username'] ?? fn.replaceAll(' ', '').toLowerCase();
        username.value = un.isNotEmpty ? "@$un" : "";
        if (un.isNotEmpty) {
          SharePrefsHelper.setString('userName', un);
        }
        email.value = data['email'] ?? "";
        description.value = data['description'] ?? "No bio added yet.";

        // Handle profile image
        final profilePath = data['profile'] ?? "";
        if (profilePath.isNotEmpty) {
          profileImageUrl.value = (profilePath.startsWith('http') || profilePath.startsWith('data:image/'))
              ? profilePath
              : "${ApiUrl.imageBaseUrl}${profilePath.startsWith('/') ? profilePath : '/$profilePath'}";
        }

        // Handle cover photo
        final coverPath = data['coverPhoto'] ?? "";
        if (coverPath.isNotEmpty) {
          coverPhotoUrl.value = (coverPath.startsWith('http') || coverPath.startsWith('data:image/'))
              ? coverPath
              : "${ApiUrl.imageBaseUrl}${coverPath.startsWith('/') ? coverPath : '/$coverPath'}";
        }

        // Handle additional fields
        isVerified.value = data['isVerified'] ?? data['verified'] ?? false;

        // Backend stores roles as an ARRAY (e.g. ["user","seller"]) per role_plan.txt
        // But may also return a single string 'role'. Handle both.
        final dynamic rolesRaw = data['roles'] ?? data['role'];
        Get.log("🔍 [Profile] roles raw: $rolesRaw | sellerVerified raw: ${data['sellerVerified']}");
        if (rolesRaw is List) {
          // If any element in the array is 'seller', user is a seller
          role.value = rolesRaw.any((r) => r.toString().toLowerCase() == 'seller') ? 'seller' : 'user';
        } else if (rolesRaw is String) {
          role.value = rolesRaw;
        } else {
          role.value = 'user';
        }

        // sellerVerified is the admin-approval flag (distinct from email verification)
        sellerVerified.value = data['sellerVerified'] ?? false;
        Get.log("✅ [Profile] Parsed role: ${role.value} | sellerVerified: ${sellerVerified.value}");

        // Stats block per culturecardsllc-server integration guide
        final stats = data['stats'] ?? {};
        if (stats is Map) {
          if (stats['trades'] != null) totalTrades.value = (stats['trades'] as num).toInt();
          if (stats['rating'] != null) rating.value = (stats['rating'] as num).toDouble();
          if (stats['positive'] != null) positivePercent.value = (stats['positive'] as num).toInt();
          if (stats['followers'] != null) followersCount.value = (stats['followers'] as num).toInt();
          if (stats['following'] != null) followingCount.value = (stats['following'] as num).toInt();
        }

        if (data['rating'] != null && rating.value == 0.0) {
          rating.value = (data['rating'] as num).toDouble();
        }
        reviewsCount.value = data['reviewsCount'] ?? 0;

        // Fetch products listed by this user and activity logs
        final rawUserId = (data['id'] ?? data['_id'] ?? SharePrefsHelper.getString(SharePrefsHelper.userIdKey))?.toString() ?? "";
        if (rawUserId.isNotEmpty) {
          userId.value = rawUserId;
          SharePrefsHelper.setString(SharePrefsHelper.userIdKey, rawUserId);
          await fetchUserListings(rawUserId);
          await fetchActivityData(rawUserId);
        }
      } else {
        if (response.statusCode == 401 || response.statusCode == 403) {
          try {
            if (Get.isRegistered<SocketService>()) {
              Get.find<SocketService>().disconnectSocket();
            }
          } catch (_) {}
          await SharePrefsHelper.clear();
          Get.offAllNamed(AppRoute.login);
          Get.snackbar(
            "Session Expired",
            "Your session has expired. Please log in again.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFFFF6B35),
            colorText: Colors.white,
          );
          return;
        }
        hasError.value = true;
        errorMessage.value = "Failed to load profile details (${response.statusCode}).";
      }
    } catch (e) {
      Get.log("Error fetching profile: $e");
      hasError.value = true;
      errorMessage.value = "Unable to connect. Please check your internet connection.";
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchUserListings(String userId) async {
    try {
      final response = await _apiClient.getData("${ApiUrl.products}?sellerId=$userId");
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body)['data'] as List;
        userListings.assignAll(list);

        // Update active and sold counts based on listings
        activeCount.value = list.where((item) => item['status'] == 'live' || item['status'] == 'active' || item['isSold'] != true).length;
        soldCount.value = list.where((item) => item['status'] == 'sold' || item['isSold'] == true).length;
      }
    } catch (e) {
      Get.log("Error fetching user listings: $e");
    }
  }

  Future<void> fetchActivityData(String userId) async {
    isActivityLoading.value = true;
    try {
      await Future.wait([
        fetchNotifications(),
        fetchPurchases(userId),
      ]);
    } finally {
      isActivityLoading.value = false;
    }
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await _apiClient.getData(ApiUrl.myNotifications);
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body)['data'] as List;
        notificationsList.assignAll(list);
      }
    } catch (e) {
      Get.log("Error fetching notifications: $e");
    }
  }

  Future<void> fetchPurchases(String userId) async {
    isActivityLoading.value = true;
    try {
      final response = await _apiClient.getData("${ApiUrl.userOrders}?userId=$userId&role=buyer");
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final rawData = body['data'];
        List items = [];
        if (rawData is List) {
          items = rawData;
        } else if (rawData is Map && rawData['result'] is List) {
          items = rawData['result'];
        } else if (rawData is Map && rawData['orders'] is List) {
          items = rawData['orders'];
        }
        purchasesList.assignAll(items);
      } else {
        purchasesList.clear();
      }
    } catch (e) {
      Get.log("Error fetching purchases: $e");
    } finally {
      isActivityLoading.value = false;
    }
  }

  Future<void> updateImage(ImageSource source, {required bool isCover}) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        isLoading.value = true;

        final response = await _apiClient.patchMultipart(
          ApiUrl.profile,
          {}, // No text fields for just image update
          filePath: image.path,
          fieldName: isCover ? 'coverPhoto' : 'images',
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          Get.snackbar(
            "Success",
            "${isCover ? 'Cover' : 'Profile'} photo updated!",
            backgroundColor: Colors.green.withOpacity(0.8),
            colorText: Colors.white,
          );
          fetchProfileData(); // Refresh UI
        } else {
          Get.snackbar(
            "Error",
            "Failed to update image",
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "An error occurred",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void changeTab(int index) {
    selectedTab.value = index;
    if (index == 1) {
      final currentUserId = userId.value.isNotEmpty 
          ? userId.value 
          : SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      if (currentUserId.isNotEmpty) {
        fetchPurchases(currentUserId);
        fetchNotifications();
      }
    }
  }

  void changeActivityFilter(int index) {
    selectedActivityFilter.value = index;
    final currentUserId = userId.value.isNotEmpty 
        ? userId.value 
        : SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    if (currentUserId.isNotEmpty) {
      if (index == 1) {
        fetchPurchases(currentUserId);
      } else {
        fetchNotifications();
      }
    }
  }

  Future<void> logout() async {
    try {
      await PushNotificationService.instance.clearDeviceToken();
    } catch (_) {}
    await SharePrefsHelper.clear();
    Get.offAllNamed(AppRoute.login);
  }

  Future<void> switchRole(String targetRole) async {
    Get.log("🔄 [switchRole] Starting → role: $targetRole");
    isSwitchingRole.value = true;
    try {
      Get.log("🔄 [switchRole] Calling PATCH ${ApiUrl.switchRole}");
      final response = await _apiClient.patchData(
        ApiUrl.switchRole,
        {"role": targetRole},
      );
      Get.log("🔄 [switchRole] Status: ${response.statusCode} | Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final resData = jsonDecode(response.body);
          final dataMap = resData['data'] is Map ? resData['data'] : resData;
          final newAccessToken = (dataMap['accessToken'] ?? dataMap['token'] ?? resData['accessToken'] ?? '').toString();
          if (newAccessToken.isNotEmpty) {
            await SharePrefsHelper.setString(SharePrefsHelper.accessTokenKey, newAccessToken);
            Get.log("🔑 [switchRole] Saved updated activeRole accessToken: $newAccessToken");
          }
        } catch (_) {}

        // Fetch updated profile to get new role + sellerVerified values
        await fetchProfileData();

        Get.snackbar(
          targetRole == 'seller' ? "Application Submitted ✅" : "Switched to Buyer ✅",
          targetRole == 'seller'
              ? "Your seller application is under review. You'll be notified once approved."
              : "You have successfully switched back to a Buyer account.",
          backgroundColor: const Color(0xFF161622),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
          borderRadius: 16,
          margin: const EdgeInsets.all(16),
          icon: Icon(
            targetRole == 'seller' ? Icons.hourglass_top_rounded : Icons.person_outline_rounded,
            color: targetRole == 'seller' ? const Color(0xFFFFB800) : const Color(0xFF8B9BFF),
          ),
        );
      } else {
        String errMsg = "Role switch failed (${response.statusCode})";
        try {
          final data = jsonDecode(response.body);
          errMsg = data['message'] ?? errMsg;
        } catch (_) {}
        Get.log("❌ [switchRole] Error: $errMsg");
        Get.snackbar(
          "Role Switch Failed",
          errMsg,
          backgroundColor: const Color(0xFF2A0A10),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 5),
          borderRadius: 16,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (e) {
      Get.log("❌ [switchRole] Exception: $e");
      Get.snackbar(
        "Network Error",
        "Could not switch role: $e",
        backgroundColor: const Color(0xFF2A0A10),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5),
        borderRadius: 16,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isSwitchingRole.value = false;
    }
  }
}
