import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../view/screens/main/controller/main_controller.dart';
import '../helper/auth_guard.dart';

class CustomBottomNavbar extends StatelessWidget {
  const CustomBottomNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MainController>();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: 165.h + bottomPadding,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Invisible spacer to expand hit-test area
          SizedBox(height: 165.h + bottomPadding, width: double.infinity),
          // Navbar Background (Moved down to accommodate the spacer)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              
              height: 100.h + bottomPadding,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0B1E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40.r),
                  topRight: Radius.circular(40.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 30.r,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 12.w,
                right: 12.w,
                bottom: 10.h + bottomPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _navItem(controller, 0, "assets/icons/Home-navBar.svg", "Home"),
                  _navItem(controller, 1, "assets/icons/Messg-navbar.svg", "Message"),
                  _navItem(controller, 2, "assets/icons/Discover-navBar.svg", "Discover"),
                  _navItem(controller, 3, "assets/icons/Bidswap-navBar.svg", "BidShwap"),
                  _navItem(controller, 4, "assets/icons/Profile-navBar.svg", "Profile"),
                ],
              ),
            ),
          ),
          // Floating Action Button
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: () {
                AuthGuard.check(
                  title: "Sign in to Create a Trade",
                  message: "Guest mode is browse-only. Sign in to list items and start trading with others.",
                  onAuthorized: () => Get.toNamed('/create_trade'),
                );
              },
              child: Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B9BFF),
                  shape: BoxShape.circle,
                  boxShadow : [
                    BoxShadow(
                      color: const Color(0xFF8B9BFF).withValues(alpha: 0.5),
                      blurRadius: 25.r,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFF0F0B1E), width: 6.w),
                ),
                child: Icon(Icons.add, color: Colors.black, size: 38.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(MainController controller, int index, String iconPath, String label) {
    return Obx(() {
      bool isSelected = controller.currentIndex.value == index;
      final int unreadCount = index == 1 ? controller.unreadMessageCount.value : 0;

      return GestureDetector(
        onTap: () {
          if (index == 1) {
            final allowed = AuthGuard.check(
              title: "Sign in to access Messages",
              message: "Guest mode is browse-only. Sign in or create an account to message other traders and view offers.",
              onAuthorized: () {
                controller.changeIndex(index);
                if (Get.currentRoute != "/main") {
                  Get.until((route) => Get.currentRoute == "/main");
                }
              },
            );
            if (!allowed) return;
          } else if (index == 4) {
            final allowed = AuthGuard.check(
              title: "Sign in to view your Profile",
              message: "Sign in or create an account to view your trade history, manage listings, and update profile settings.",
              onAuthorized: () {
                controller.changeIndex(index);
                if (Get.currentRoute != "/main") {
                  Get.until((route) => Get.currentRoute == "/main");
                }
              },
            );
            if (!allowed) return;
          } else {
            controller.changeIndex(index);
            // If we are in a detail screen, go back to main first
            if (Get.currentRoute != "/main") {
              Get.until((route) => Get.currentRoute == "/main");
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.fastOutSlowIn,
          padding: EdgeInsets.symmetric(horizontal: isSelected ? 16.w : 10.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8B9BFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(28.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B9BFF).withValues(alpha: 0.45),
                      blurRadius: 14.r,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: SvgPicture.asset(
                      iconPath,
                      colorFilter: ColorFilter.mode(
                        isSelected ? Colors.black : Colors.white70,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -6.h,
                      right: -8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                        constraints: BoxConstraints(minWidth: 16.r, minHeight: 16.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4B67),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF8B9BFF) : const Color(0xFF0F0B1E),
                            width: 1.5.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4B67).withValues(alpha: 0.6),
                              blurRadius: 8.r,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unreadCount > 99 ? "99+" : "$unreadCount",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (isSelected) ...[
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}
