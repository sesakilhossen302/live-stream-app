import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/spin_wheel_controller.dart';

class SpinWheelScreen extends StatelessWidget {
  const SpinWheelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SpinWheelController());

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Daily Reward Wheel",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.info_outline_rounded, color: Colors.white70, size: 22.sp),
              onPressed: () => _showPolicyModal(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            children: [
              // Anti-Gambling Guaranteed Reward Notice Banner
              _buildPolicyBanner(context),
<<<<<<< HEAD
              SizedBox(height: 28.h),
=======

              SizedBox(height: 28.h),

>>>>>>> f576f84c7d71787184ff21c82756b260d0963aee
              // ── Wheel + Pointer Section ──────────────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow Ring
                  Container(
                    width: 320.r,
                    height: 320.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B9BFF).withValues(alpha: 0.25),
                          blurRadius: 40.r,
                          spreadRadius: 8.r,
                        ),
                      ],
                    ),
                  ),

                  // Animated Rotating Wheel
                  AnimatedBuilder(
                    animation: controller.animController,
                    builder: (context, child) {
                      final double turns = controller.isSpinning.value
                          ? controller.spinAnimation.value
                          : controller.rotationTurns.value;

                      return Transform.rotate(
                        angle: turns * 2 * math.pi,
                        child: CustomPaint(
                          size: Size(300.r, 300.r),
                          painter: _WheelPainter(rewards: controller.rewards),
                        ),
                      );
                    },
                  ),

                  // Center Gold Emblem
                  Container(
                    width: 64.r,
                    height: 64.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 12.r,
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Center(
                      child: Icon(Icons.stars_rounded, color: Colors.white, size: 32.sp),
                    ),
                  ),

                  // Top Pointer
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 24.w,
                      height: 36.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12.r),
                          bottomRight: Radius.circular(12.r),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 8.r,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(Icons.arrow_drop_down, color: Colors.redAccent, size: 28.sp),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 32.h),

              // Free Spins Left Counter
              Obx(() => Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                    SizedBox(width: 6.w),
                    Text(
                      "${controller.freeSpinsLeft.value} Free Spin Available Today",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )),

              SizedBox(height: 20.h),

              // ── Spin Button ──────────────────────────────────────────────
              Obx(() => SizedBox(
                width: double.infinity,
                height: 58.h,
                child: ElevatedButton.icon(
                  onPressed: controller.isSpinning.value ? null : controller.spin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    foregroundColor: const Color(0xFF0F172A),
                    disabledBackgroundColor: const Color(0xFF8B9BFF).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(29.r),
                    ),
                    elevation: 0,
                  ),
                  icon: controller.isSpinning.value
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                        )
                      : Icon(Icons.autorenew_rounded, size: 24.sp),
                  label: Text(
                    controller.isSpinning.value ? "Spinning..." : "SPIN NOW",
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              )),

              SizedBox(height: 32.h),

              // Reward Dialog Trigger
              Obx(() {
                if (controller.showRewardDialog.value && controller.wonReward.value != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showRewardDialog(context, controller);
                  });
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ANTI-GAMBLING POLICY BANNER & MODAL
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPolicyBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPolicyModal(context),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_user_rounded, color: const Color(0xFF22C55E), size: 22.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Guaranteed Reward Policy 🛡️",
                    style: TextStyle(
                      color: const Color(0xFF22C55E),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    "100% Free Daily Entry. Every spin yields a certified reward. No purchase required.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20.sp),
          ],
        ),
      ),
    );
  }

  void _showPolicyModal(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: const Color(0xFF8B9BFF), size: 24.sp),
                SizedBox(width: 10.w),
                Text(
                  "Fair Play & Anti-Gambling Terms",
                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _policyBullet("1. Guaranteed Prize:", "Every participant is 100% guaranteed to receive a real prize or promotional benefit on each spin."),
            _policyBullet("2. Free to Play:", "No purchase, payment, or entry fee is required to participate in daily rewards."),
            _policyBullet("3. Store Compliant:", "In accordance with Apple App Store & Google Play Promotional Guidelines and US Sweepstakes Regulations."),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B9BFF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
                ),
                child: Text("Understood", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _policyBullet(String title, String desc) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 16.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.white70, fontSize: 12.sp, height: 1.4),
                children: [
                  TextSpan(text: "$title ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // REWARD CONGRATULATIONS DIALOG
  // ──────────────────────────────────────────────────────────────────────────
  void _showRewardDialog(BuildContext context, SpinWheelController controller) {
    final reward = controller.wonReward.value;
    if (reward == null) return;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: const Color(0xFF8B9BFF).withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B9BFF).withValues(alpha: 0.25),
                blurRadius: 30.r,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72.r,
                height: 72.r,
                decoration: BoxDecoration(
                  color: reward.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: reward.color.withValues(alpha: 0.4), width: 2),
                ),
                child: Icon(reward.icon, color: reward.color, size: 36.sp),
              ),
              SizedBox(height: 18.h),
              Text(
                "You Won!",
                style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8.h),
              Text(
                reward.title,
                textAlign: TextAlign.center,
                style: TextStyle(color: reward.color, fontSize: 16.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6.h),
              Text(
                reward.description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12.sp, height: 1.4),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    controller.claimReward();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.r)),
                  ),
                  child: Text("Claim & Add to Vault", style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// CUSTOM WHEEL CANVAS PAINTER
// ────────────────────────────────────────────────────────────────────────────
class _WheelPainter extends CustomPainter {
  final List<SpinReward> rewards;

  _WheelPainter({required this.rewards});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final double sweepAngle = 2 * math.pi / rewards.length;

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 2;

    for (int i = 0; i < rewards.length; i++) {
      final startAngle = i * sweepAngle;
      paint.color = rewards[i].color.withValues(alpha: 0.85);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
