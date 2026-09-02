import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../core/app_route.dart';
import '../../data/helpers/shared_prefe.dart';
import '../../data/services/api_client.dart';
import '../../data/services/api_url.dart';
import '../../data/services/push_notification_service.dart';
import '../../data/services/socket_service.dart';

class SafetyController extends GetxController {
  static SafetyController get instance {
    if (Get.isRegistered<SafetyController>()) {
      return Get.find<SafetyController>();
    }
    return Get.put(SafetyController(), permanent: true);
  }

  final ApiClient _apiClient = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : Get.put(ApiClient());

  final RxBool isActionLoading = false.obs;
  final RxBool isBlockedListLoading = false.obs;
  final RxList<Map<String, dynamic>> blockedUsers = <Map<String, dynamic>>[].obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // BLOCK & UNBLOCK
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch list of blocked users
  Future<void> fetchBlockedUsers() async {
    isBlockedListLoading.value = true;
    try {
      final response = await _apiClient.getData(ApiUrl.blockedList);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final dynamic rawList = data['data'];
        if (rawList is List) {
          blockedUsers.assignAll(
            rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          );
        } else {
          blockedUsers.clear();
        }
      } else {
        Get.log("❌ [SafetyController] fetchBlockedUsers error: ${response.statusCode}");
      }
    } catch (e) {
      Get.log("❌ [SafetyController] fetchBlockedUsers exception: $e");
    } finally {
      isBlockedListLoading.value = false;
    }
  }

  /// Block a user
  Future<bool> blockUser(String userId, {String? userName}) async {
    if (userId.isEmpty) return false;
    isActionLoading.value = true;
    try {
      final response = await _apiClient.postData(ApiUrl.blockUser(userId), {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final String name = userName ?? "User";
        Get.snackbar(
          "User Blocked",
          "$name has been blocked. They can no longer interact with you.",
          backgroundColor: const Color(0xFF161622),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
          icon: const Icon(Icons.block_rounded, color: Color(0xFFFF4B4B)),
        );
        fetchBlockedUsers();
        return true;
      } else {
        String msg = "Failed to block user.";
        try {
          final body = jsonDecode(response.body);
          msg = body['message'] ?? msg;
        } catch (_) {}
        Get.snackbar("Block Failed", msg,
            backgroundColor: const Color(0xFF2A0A10), colorText: Colors.white);
        return false;
      }
    } catch (e) {
      Get.snackbar("Error", "Could not block user: $e",
          backgroundColor: const Color(0xFF2A0A10), colorText: Colors.white);
      return false;
    } finally {
      isActionLoading.value = false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String userId, {String? userName}) async {
    if (userId.isEmpty) return false;
    isActionLoading.value = true;
    try {
      final response = await _apiClient.postData(ApiUrl.unblockUser(userId), {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        blockedUsers.removeWhere((u) => (u['_id'] ?? u['id']) == userId);
        final String name = userName ?? "User";
        Get.snackbar(
          "User Unblocked",
          "$name has been unblocked.",
          backgroundColor: const Color(0xFF161622),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
          icon: const Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
        );
        return true;
      } else {
        String msg = "Failed to unblock user.";
        try {
          final body = jsonDecode(response.body);
          msg = body['message'] ?? msg;
        } catch (_) {}
        Get.snackbar("Unblock Failed", msg,
            backgroundColor: const Color(0xFF2A0A10), colorText: Colors.white);
        return false;
      }
    } catch (e) {
      Get.snackbar("Error", "Could not unblock user: $e",
          backgroundColor: const Color(0xFF2A0A10), colorText: Colors.white);
      return false;
    } finally {
      isActionLoading.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REPORT (SUPPORT SYSTEM)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Submit a report against user, stream, comment, or review
  Future<bool> submitReport({
    required String contentType, // 'comment' | 'review' | 'user' | 'stream'
    required String reason,      // 'harassment' | 'spam' | 'fraud' | 'other'
    required String message,
    String? reportedUser,
    String? reportedStream,
    String? contentId,
    List<String>? attachments,
  }) async {
    if (message.trim().isEmpty) {
      Get.snackbar("Required", "Please enter a message explaining your report.",
          backgroundColor: const Color(0xFF2A0A10), colorText: Colors.white);
      return false;
    }

    isActionLoading.value = true;
    try {
      final Map<String, dynamic> payload = {
        "contentType": contentType,
        "reason": reason,
        "message": message.trim(),
      };
      if (reportedUser != null && reportedUser.isNotEmpty) {
        payload["reportedUser"] = reportedUser;
      }
      if (reportedStream != null && reportedStream.isNotEmpty) {
        payload["reportedStream"] = reportedStream;
      }
      if (contentId != null && contentId.isNotEmpty) {
        payload["contentId"] = contentId;
      }
      if (attachments != null && attachments.isNotEmpty) {
        payload["attachments"] = attachments;
      }

      final response = await _apiClient.postData(ApiUrl.support, payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.snackbar(
          "Report Submitted",
          "Thank you for keeping our community safe. Our team will review this report shortly.",
          backgroundColor: const Color(0xFF161622),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 5),
          icon: const Icon(Icons.verified_user_outlined, color: Color(0xFF8B9BFF)),
        );
        return true;
      } else {
        String msg = "Could not submit report.";
        try {
          final body = jsonDecode(response.body);
          msg = body['message'] ?? msg;
        } catch (_) {}
        Get.snackbar("Submission Failed", msg,
            backgroundColor: const Color(0xFF2A0A10), colorText: Colors.white);
        return false;
      }
    } catch (e) {
      Get.snackbar("Error", "Report failed: $e",
          backgroundColor: const Color(0xFF2A0A10), colorText: Colors.white);
      return false;
    } finally {
      isActionLoading.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DELETE ACCOUNT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Delete account permanently
  Future<bool> deleteAccount(String password) async {
    if (password.isEmpty) {
      Get.snackbar("Password Required", "Please enter your current password to confirm deletion.",
          backgroundColor: const Color(0xFF2A0A10), colorText: Colors.white);
      return false;
    }

    isActionLoading.value = true;
    try {
      final response = await _apiClient.deleteData(
        ApiUrl.deleteAccount,
        body: {"password": password},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        try {
          await PushNotificationService.instance.clearDeviceToken();
        } catch (_) {}
        try {
          if (Get.isRegistered<SocketService>()) {
            Get.find<SocketService>().disconnectSocket();
          }
        } catch (_) {}

        await SharePrefsHelper.clear();

        Get.offAllNamed(AppRoute.login);
        Get.snackbar(
          "Account Deleted",
          "Your account and associated data have been permanently removed.",
          backgroundColor: const Color(0xFF161622),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
        );
        return true;
      } else {
        String msg = "Failed to delete account. Please verify your password.";
        try {
          final body = jsonDecode(response.body);
          msg = body['message'] ?? msg;
        } catch (_) {}
        Get.snackbar("Deletion Failed", msg,
            backgroundColor: const Color(0xFF2A0A10), colorText: Colors.white);
        return false;
      }
    } catch (e) {
      Get.snackbar("Error", "Could not delete account: $e",
          backgroundColor: const Color(0xFF2A0A10), colorText: Colors.white);
      return false;
    } finally {
      isActionLoading.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REUSABLE DIALOGS & BOTTOM SHEETS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Show Report Bottom Sheet
  static void showReportDialog(
    BuildContext context, {
    required String contentType, // 'stream' | 'user' | 'comment' | 'review'
    String? reportedUser,
    String? reportedStream,
    String? contentId,
    String? targetName,
  }) {
    final controller = SafetyController.instance;
    final reasons = [
      {"key": "harassment", "label": "Harassment or Bullying", "icon": Icons.sentiment_very_dissatisfied_rounded},
      {"key": "spam", "label": "Spam or Scam Links", "icon": Icons.report_problem_outlined},
      {"key": "fraud", "label": "Fraud or Counterfeit Goods", "icon": Icons.gavel_rounded},
      {"key": "other", "label": "Other Inappropriate Conduct", "icon": Icons.info_outline_rounded},
    ];

    final selectedReason = "harassment".obs;
    final messageController = TextEditingController();

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4B4B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.flag_rounded, color: const Color(0xFFFF4B4B), size: 24.sp),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Report ${contentType == 'stream' ? 'Live Stream' : (targetName ?? 'Content')}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          "Help us understand what went wrong",
                          style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Text(
                "SELECT A REASON",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 12.h),
              ...reasons.map((r) {
                return Obx(() {
                  final isSelected = selectedReason.value == r['key'];
                  return GestureDetector(
                    onTap: () => selectedReason.value = r['key'] as String,
                    child: Container(
                      margin: EdgeInsets.only(bottom: 8.h),
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1E1E2C) : Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF8B9BFF) : Colors.white.withValues(alpha: 0.06),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            r['icon'] as IconData,
                            color: isSelected ? const Color(0xFF8B9BFF) : Colors.white54,
                            size: 20.sp,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              r['label'] as String,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 13.sp,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                        ],
                      ),
                    ),
                  );
                });
              }),
              SizedBox(height: 16.h),
              Text(
                "DETAILS",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0B1E),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: messageController,
                  maxLines: 4,
                  style: TextStyle(color: Colors.white, fontSize: 13.sp),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.all(16.r),
                    hintText: "Describe the issue clearly...",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: const BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: Text("Cancel", style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Obx(() => ElevatedButton(
                      onPressed: controller.isActionLoading.value
                          ? null
                          : () async {
                              final success = await controller.submitReport(
                                contentType: contentType,
                                reason: selectedReason.value,
                                message: messageController.text,
                                reportedUser: reportedUser,
                                reportedStream: reportedStream,
                                contentId: contentId,
                              );
                              if (success) {
                                Get.back();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4B4B),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        elevation: 0,
                      ),
                      child: controller.isActionLoading.value
                          ? SizedBox(width: 18.r, height: 18.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text("Submit Report", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900)),
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  /// Show Block User Confirmation Dialog
  static void showBlockUserDialog(
    BuildContext context, {
    required String userId,
    required String userName,
    VoidCallback? onBlocked,
  }) {
    final controller = SafetyController.instance;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        backgroundColor: const Color(0xFF1E1E2C),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4B4B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.block_rounded, color: const Color(0xFFFF4B4B), size: 36.sp),
              ),
              SizedBox(height: 18.h),
              Text(
                "Block $userName?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 12.h),
              Text(
                "They will no longer be able to message you, view your profile, or join your streams. Existing follow connections will be removed.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13.sp, height: 1.4),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: const BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: Text("Cancel", style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Obx(() => ElevatedButton(
                      onPressed: controller.isActionLoading.value
                          ? null
                          : () async {
                              final ok = await controller.blockUser(userId, userName: userName);
                              if (ok) {
                                Get.back();
                                onBlocked?.call();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4B4B),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        elevation: 0,
                      ),
                      child: controller.isActionLoading.value
                          ? SizedBox(width: 18.r, height: 18.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text("Block User", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900)),
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show Delete Account Dialog with password verification
  static void showDeleteAccountDialog(BuildContext context) {
    final controller = SafetyController.instance;
    final passwordController = TextEditingController();
    final isObscure = true.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        backgroundColor: const Color(0xFF1E1E2C),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4B4B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_forever_rounded, color: const Color(0xFFFF4B4B), size: 36.sp),
                ),
              ),
              SizedBox(height: 16.h),
              Center(
                child: Text(
                  "Delete Account",
                  style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                "This action is permanent and cannot be undone. All your listings, orders, messages, and profile information will be deleted.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13.sp, height: 1.4),
              ),
              SizedBox(height: 20.h),
              Text(
                "ENTER PASSWORD TO CONFIRM",
                style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF11111E),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Obx(() => TextField(
                  controller: passwordController,
                  obscureText: isObscure.value,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    hintText: "Your current password",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscure.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white38,
                        size: 20.sp,
                      ),
                      onPressed: () => isObscure.toggle(),
                    ),
                  ),
                )),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: const BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: Text("Cancel", style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Obx(() => ElevatedButton(
                      onPressed: controller.isActionLoading.value
                          ? null
                          : () async {
                              await controller.deleteAccount(passwordController.text);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF334B),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        elevation: 0,
                      ),
                      child: controller.isActionLoading.value
                          ? SizedBox(width: 18.r, height: 18.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text("Delete", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900)),
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
