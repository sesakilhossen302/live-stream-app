import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/discover_controller.dart';
import '../../../../core/app_route.dart';
import '../../../../global/helper/auth_guard.dart';

class AllLiveShowsScreen extends StatelessWidget {
  const AllLiveShowsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DiscoverController>();

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Live Shows",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
        ),
        body: Obx(() {
          if (controller.liveShows.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.videocam_off_outlined,
                      color: Colors.white30,
                      size: 48.sp,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    "No live shows currently broadcasting.",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            itemCount: controller.liveShows.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final show = controller.liveShows[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: GestureDetector(
                  onTap: () {
                    AuthGuard.check(
                      title: "Sign in to Watch Stream",
                      message: "Guest mode is browse-only. Sign in or create an account to watch live streams.",
                      onAuthorized: () => Get.toNamed(AppRoute.viewerLive, arguments: show['raw']),
                    );
                  },
                  child: _buildLiveCard(
                    show['title']!,
                    show['host']!,
                    show['viewers']!,
                    show['image']!,
                    show['hostAvatar'] ?? '',
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildLiveCard(String title, String host, String viewers, String imgUrl, String hostAvatar) {
    return Container(
      height: 320.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(32.r),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
                image: imgUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(imgUrl),
                        fit: BoxFit.cover,
                        opacity: 0.6,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (imgUrl.isEmpty)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2C),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
                        ),
                        child: Icon(
                          Icons.videocam_outlined,
                          color: Colors.white12,
                          size: 64.sp,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 20.h,
                    left: 20.w,
                    child: Row(
                      children: [
                        _buildSmallBadge("LIVE", const Color(0xFFFF4D4D), showDot: true),
                        SizedBox(width: 8.w),
                        _buildSmallBadge(
                          viewers,
                          Colors.black.withOpacity(0.6),
                          icon: Icons.visibility_outlined,
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "LVE",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 48.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 10,
                          ),
                        ),
                        Text(
                          "STREAM",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 48.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: const Color(0xFF11111A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32.r)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundImage: hostAvatar.isNotEmpty
                      ? NetworkImage(hostAvatar)
                      : const NetworkImage("https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200") as ImageProvider,
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        host,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {}, // Handled by GestureDetector wrapping card
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  ),
                  child: Text(
                    "Join",
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w900,
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

  Widget _buildSmallBadge(String text, Color color, {bool showDot = false, IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Icon(Icons.circle, color: Colors.white, size: 6.sp),
            SizedBox(width: 6.w),
          ],
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 14.sp),
            SizedBox(width: 6.w),
          ],
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
