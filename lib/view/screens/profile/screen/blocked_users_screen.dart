import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/controllers/safety_controller.dart';
import '../../../../global/widgets/custom_background.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final SafetyController _safetyCtrl = SafetyController.instance;

  @override
  void initState() {
    super.initState();
    _safetyCtrl.fetchBlockedUsers();
  }

  @override
  Widget build(BuildContext context) {
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
            "Blocked Users",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
        ),
        body: Obx(() {
          if (_safetyCtrl.isBlockedListLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B9BFF)),
            );
          }

          if (_safetyCtrl.blockedUsers.isEmpty) {
            return RefreshIndicator(
              color: const Color(0xFF8B9BFF),
              backgroundColor: const Color(0xFF161622),
              onRefresh: () => _safetyCtrl.fetchBlockedUsers(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                children: [
                  SizedBox(height: 120.h),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(24.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2C),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: const Color(0xFF8B9BFF),
                            size: 48.sp,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          "No Blocked Users",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40.w),
                          child: Text(
                            "Users you block will appear here. You can unblock them at any time.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13.sp,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFF8B9BFF),
            backgroundColor: const Color(0xFF161622),
            onRefresh: () => _safetyCtrl.fetchBlockedUsers(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              itemCount: _safetyCtrl.blockedUsers.length,
              separatorBuilder: (context, index) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final user = _safetyCtrl.blockedUsers[index];
                final String userId = (user['_id'] ?? user['id'] ?? '').toString();
                final String name = (user['fullName'] ?? user['name'] ?? 'Blocked User').toString();
                final String email = (user['email'] ?? '').toString();
                final String profile = (user['profile'] ?? user['image'] ?? user['avatar'] ?? '').toString();

                String avatarUrl = "";
                if (profile.isNotEmpty) {
                  avatarUrl = (profile.startsWith('http') || profile.startsWith('data:image/'))
                      ? profile
                      : "${ApiUrl.imageBaseUrl}${profile.startsWith('/') ? profile : '/$profile'}";
                }

                return Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11111E),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 48.r,
                        height: 48.r,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2C),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: ClipOval(
                          child: avatarUrl.isNotEmpty
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.person,
                                    color: Colors.white38,
                                    size: 24.sp,
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  color: Colors.white38,
                                  size: 24.sp,
                                ),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (email.isNotEmpty) ...[
                              SizedBox(height: 2.h),
                              Text(
                                email,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12.sp,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Unblock Button
                      ElevatedButton(
                        onPressed: () => _safetyCtrl.unblockUser(userId, userName: name),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E2C),
                          foregroundColor: const Color(0xFF8B9BFF),
                          side: BorderSide(color: const Color(0xFF8B9BFF).withValues(alpha: 0.4)),
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Unblock",
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
