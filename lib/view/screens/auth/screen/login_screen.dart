import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/login_controller.dart';

class LoginScreen extends GetView<LoginController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(LoginController());
    return CustomBackground(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Container(
              padding: EdgeInsets.all(32.r),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C).withOpacity(0.9),
                borderRadius: BorderRadius.circular(32.r),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Welcome Back",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "Step back into the world's most exclusive auctions.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 48.h),
                  
                  // Email Field
                  _buildLabel("EMAIL OR USERNAME"),
                  TextField(
                    controller: controller.emailController,
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    decoration: InputDecoration(
                      hintText: "Enter your credentials",
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 16.sp),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B9BFF))),
                    ),
                  ),
                  
                  SizedBox(height: 32.h),
                  
                  // Password Field
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel("PASSWORD"),
                      GestureDetector(
                        onTap: () => controller.onForgotPassword(),
                        child: Text(
                          "FORGOT PASSWORD?",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Obx(
                    () => TextField(
                      controller: controller.passwordController,
                      obscureText: controller.isObscured.value,
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      decoration: InputDecoration(
                        hintText: "••••••••",
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 16.sp),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B9BFF))),
                        suffixIcon: IconButton(
                          icon: Icon(
                            controller.isObscured.value
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white38,
                            size: 20.sp,
                          ),
                          onPressed: () => controller.toggleObscure(),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 48.h),
                  
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 60.h,
                    child: Obx(
                      () => ElevatedButton(
                        onPressed: controller.isLoading.value ? null : () => controller.onLogin(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B9BFF),
                          disabledBackgroundColor: const Color(0xFF8B9BFF).withOpacity(0.7),
                          foregroundColor: const Color(0xFF0F0B1E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                          elevation: 0,
                        ),
                        child: controller.isLoading.value
                            ? SizedBox(
                                width: 24.w,
                                height: 24.h,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                "Login",
                                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 32.h),
                  
                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Colors.white38, fontSize: 14.sp),
                      ),
                      GestureDetector(
                        onTap: () => controller.onSignUp(),
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            color: const Color(0xFF8B9BFF),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  // Divider with OR
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        child: Text(
                          "OR",
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                    ],
                  ),

                  SizedBox(height: 20.h),

                  // Continue as Guest Button
                  GestureDetector(
                    onTap: () => controller.continueAsGuest(),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            color: const Color(0xFF8B9BFF),
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            "Continue as Guest",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white38,
                            size: 11.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFF8B9BFF),
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
