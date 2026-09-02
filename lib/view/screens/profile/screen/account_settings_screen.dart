import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/push_notification_service.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/profile_controller.dart';
import '../controller/profile_information_controller.dart';
import '../../../../global/controllers/safety_controller.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileInformationController());

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Account Settings",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B9BFF)),
            );
          }
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                SizedBox(height: 32.h),

                // Profile Header
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 130.r,
                            height: 130.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B9BFF), Color(0xFFFF8BFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF8B9BFF,
                                  ).withOpacity(0.3),
                                  blurRadius: 20.r,
                                  spreadRadius: 2.r,
                                ),
                              ],
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(60.r),
                            child: controller.profileImageUrl.value.isNotEmpty
                                ? Image.network(
                                    controller.profileImageUrl.value,
                                    width: 120.r,
                                    height: 120.r,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            CircleAvatar(
                                              radius: 60.r,
                                              backgroundColor: Colors.white10,
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white24,
                                                size: 60.sp,
                                              ),
                                            ),
                                  )
                                : CircleAvatar(
                                    radius: 60.r,
                                    backgroundColor: Colors.white10,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white24,
                                      size: 60.sp,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        controller.fullNameController.text.isNotEmpty
                            ? controller.fullNameController.text
                            : "User Name",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      // SizedBox(height: 12.h),
                      // Container(
                      //   padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                      //   decoration: BoxDecoration(
                      //     color: const Color(0xFF1E1E2C),
                      //     borderRadius: BorderRadius.circular(20.r),
                      //   ),
                      //   child: Text(
                      //     "CHANGE PICTURE",
                      //     style: TextStyle(
                      //       color: const Color(0xFF8B9BFF),
                      //       fontSize: 12.sp,
                      //       fontWeight: FontWeight.w900,
                      //       letterSpacing: 1,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),

                SizedBox(height: 48.h),

                // Account Details Section
                _buildSectionTitle("ACCOUNT DETAILS"),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF11111E),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.person_outline_rounded,
                        title: "Profile Information",
                        showArrow: true,
                        onTap: () => Get.toNamed(AppRoute.profileInformation),
                      ),
                      Divider(color: Colors.white.withOpacity(0.05), height: 1),
                      _buildSettingsTile(
                        icon: Icons.lock_outline_rounded,
                        title: "Security & Password",
                        showArrow: true,
                        onTap: () => Get.toNamed(AppRoute.changePassword),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32.h),

                // Preferences Section
                _buildSectionTitle("PREFERENCES"),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF11111E),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: "Payment Methods",
                        showArrow: true,
                      ),
                      Divider(color: Colors.white.withOpacity(0.05), height: 1),
                      _buildSettingsTile(
                        icon: Icons.tune_rounded,
                        title: "Preferences",
                        showArrow: true,
                        onTap: () => Get.toNamed(AppRoute.userPreferences),
                      ),
                      Divider(color: Colors.white.withOpacity(0.05), height: 1),
                      _buildSettingsTile(
                        icon: Icons.block_rounded,
                        title: "Blocked Users",
                        subtitle: "Manage accounts you have blocked",
                        showArrow: true,
                        onTap: () => Get.toNamed(AppRoute.blockedUsers),
                      ),
                      Divider(color: Colors.white.withOpacity(0.05), height: 1),
                      _buildSettingsTile(
                        icon: Icons.visibility_outlined,
                        title: "Public Profile",
                        subtitle: "Visible to other bidders",
                        trailing: Switch(
                          value: true,
                          onChanged: (v) {},
                          activeColor: const Color(0xFF8B9BFF),
                          activeTrackColor: const Color(
                            0xFF8B9BFF,
                          ).withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32.h),

                // Account Safety & Danger Zone Section
                _buildSectionTitle("ACCOUNT SAFETY"),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF11111E),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.delete_outline_rounded,
                        title: "Delete Account",
                        subtitle: "Permanently remove your account and data",
                        showArrow: true,
                        onTap: () => SafetyController.showDeleteAccountDialog(context),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40.h),

                // Sign Out Button
                GestureDetector(
                  onTap: () => _showSignOutDialog(context),
                  child: Container(
                    width: double.infinity,
                    height: 70.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2C),
                      borderRadius: BorderRadius.circular(35.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Colors.white38,
                          size: 24.sp,
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          "Sign Out",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 48.h),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 16.h),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white38,
          fontSize: 11.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    bool showArrow = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: const Color(0xFF8B9BFF), size: 22.sp),
            ),
            SizedBox(width: 20.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showArrow)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white24,
                size: 24.sp,
              ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        backgroundColor: const Color(0xFF1E1E2C),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.logout_rounded,
                color: const Color(0xFF8B9BFF),
                size: 48.sp,
              ),
              SizedBox(height: 16.h),
              Text(
                "Sign Out",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                "Are you sure you want to sign out?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
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
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        if (Get.isRegistered<ProfileController>()) {
                          Get.find<ProfileController>().logout();
                        } else {
                          try {
                            await PushNotificationService.instance.clearDeviceToken();
                          } catch (_) {}
                          await SharePrefsHelper.clear();
                          Get.offAllNamed(AppRoute.login);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        foregroundColor: const Color(0xFF0F0B1E),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Sign Out",
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
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
