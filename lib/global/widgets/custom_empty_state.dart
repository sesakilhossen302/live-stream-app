import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomEmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final String? description;
  final IconData icon;
  final VoidCallback? onRetry;
  final String? buttonText;

  const CustomEmptyState({
    super.key,
    required this.title,
    this.message,
    this.description,
    this.icon = Icons.inbox_rounded,
    this.onRetry,
    this.buttonText = "Refresh",
  });

  String get displayMessage => description ?? message ?? "";


  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: const Color(0xFF141024).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: const Color(0xFF8B9BFF).withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20.r,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glowing aura
              Container(
                padding: EdgeInsets.all(18.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B9BFF).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B9BFF).withValues(alpha: 0.2),
                      blurRadius: 20.r,
                      spreadRadius: 2.r,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 42.sp,
                  color: const Color(0xFF8B9BFF),
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                displayMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13.sp,
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                SizedBox(height: 20.h),
                InkWell(
                  onTap: onRetry,
                  borderRadius: BorderRadius.circular(30.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B9BFF), Color(0xFF6B7BFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B9BFF).withValues(alpha: 0.4),
                          blurRadius: 12.r,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.black, size: 16.sp),
                        SizedBox(width: 6.w),
                        Text(
                          buttonText ?? "Refresh",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
