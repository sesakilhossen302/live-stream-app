import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../core/app_route.dart';
import '../../data/helpers/shared_prefe.dart';

class AuthGuard {
  /// Checks if the current user is authenticated.
  /// Returns `true` if logged in and executes [onAuthorized].
  /// If the user is in Guest Mode or not logged in, presents a sleek bottom sheet and returns `false`.
  static bool check({
    String? title,
    String? message,
    VoidCallback? onAuthorized,
  }) {
    final token = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);
    final isGuest = SharePrefsHelper.isGuest;

    if (token.isNotEmpty && !isGuest) {
      if (onAuthorized != null) {
        onAuthorized();
      }
      return true;
    }

    // Show Auth Modal Sheet
    showAuthPrompt(
      title: title ?? "Sign In Required",
      message: message ?? "Guest mode allows browsing only. Sign in or create an account to watch streams, like, chat, bid, and trade.",
    );
    return false;
  }

  /// Displays the modern Sign In / Sign Up modal bottom sheet
  static void showAuthPrompt({
    String title = "Sign In Required",
    String message = "Guest mode allows browsing only. Sign in or create an account to unlock all interactive features.",
  }) {
    final context = Get.context;
    if (context == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32.r),
              topRight: Radius.circular(32.r),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30.r,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 24.h),

              // Icon badge
              Container(
                width: 68.w,
                height: 68.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B9BFF), Color(0xFF6C5CE7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B9BFF).withOpacity(0.35),
                      blurRadius: 20.r,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lock_person_rounded,
                  color: const Color(0xFF0F0B1E),
                  size: 34.sp,
                ),
              ),
              SizedBox(height: 20.h),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 10.h),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13.sp,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 28.h),

              // Log In Button
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Get.toNamed(AppRoute.login);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    foregroundColor: const Color(0xFF0F0B1E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.r),
                    ),
                  ),
                  child: Text(
                    "Log In",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Create Account Button
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Get.toNamed(AppRoute.signUp);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.r),
                    ),
                  ),
                  child: Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Dismiss
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  "Continue Browsing",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
  }
}
