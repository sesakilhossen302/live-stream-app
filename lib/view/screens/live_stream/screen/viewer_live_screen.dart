import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/services/api_url.dart';
import '../controller/agora_live_controller.dart';
import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import 'dart:convert';

class ViewerLiveScreen extends StatefulWidget {
  final Map<String, dynamic> streamData;
  const ViewerLiveScreen({super.key, required this.streamData});

  @override
  State<ViewerLiveScreen> createState() => _ViewerLiveScreenState();
}

class _ViewerLiveScreenState extends State<ViewerLiveScreen> {
  late AgoraLiveController ctrl;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(AgoraLiveController(), permanent: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      final seller = widget.streamData['sellerId'] ?? widget.streamData['seller'] ?? widget.streamData['hostId'] ?? widget.streamData['user'] ?? widget.streamData['host'];
      final sId = (seller is Map) ? (seller['_id'] ?? seller['id'] ?? '') : (seller?.toString() ?? '');

      if ((ctrl.isLive.value && ctrl.isHost.value) || (sId.isNotEmpty && currentUserId.isNotEmpty && sId == currentUserId)) {
        ctrl.isHost.value = true;
        Get.offNamed(AppRoute.hostLive);
        return;
      }
      ctrl.joinAsViewer(widget.streamData);
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        ctrl.minimizeStream();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Remote Video (Host's camera)
            GestureDetector(
              onDoubleTap: () => ctrl.sendLike(),
              child: Obx(() {
                final isJoined = ctrl.remoteJoined.value;
                final rUid = ctrl.remoteUid.value;
                if (ctrl.engine != null && isJoined && rUid != -1) {
                  return RepaintBoundary(
                    child: AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: ctrl.engine!,
                        canvas: VideoCanvas(
                          uid: rUid,
                          renderMode: RenderModeType.renderModeHidden,
                        ),
                        connection: RtcConnection(channelId: ctrl.channelName.value),
                        useFlutterTexture: false,
                        useAndroidSurfaceView: true,
                      ),
                    ),
                  );
                }
                return Container(
                  color: const Color(0xFF0A0A14),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ctrl.isLoading.value
                            ? const CircularProgressIndicator(color: Color(0xFF8B9BFF))
                            : Icon(Icons.live_tv_rounded, color: Colors.white24, size: 64.sp),
                        SizedBox(height: 16.h),
                        Text(
                          ctrl.isLoading.value ? "Connecting to stream..." : "Waiting for host...",
                          style: TextStyle(color: Colors.white38, fontSize: 14.sp),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),

            // ── Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.25, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // ── Weak Network Warning Overlay
            Positioned(
              top: MediaQuery.of(context).padding.top + 60.h,
              left: 16.w,
              right: 16.w,
              child: Obx(() {
                if (!ctrl.isNetworkWeak.value) return const SizedBox.shrink();
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14.sp),
                      SizedBox(width: 6.w),
                      Text(
                        "Weak Connection — Optimizing stream quality",
                        style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
            ),

            // ── Top Overlay (Close button, LIVE count, Host info)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Close & Minimize buttons
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => ctrl.minimizeStream(),
                                child: Container(
                                  padding: EdgeInsets.all(7.r),
                                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                  child: Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 20.sp),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: () => _showExitDialog(ctrl),
                                child: Container(
                                  padding: EdgeInsets.all(7.r),
                                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                  child: Icon(Icons.close_rounded, color: Colors.white, size: 20.sp),
                                ),
                              ),
                            ],
                          ),
                           // LIVE pill & TIMER row
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.wifi_tethering_rounded,
                                      color: const Color(0xFFFF52C5),
                                      size: 13.sp,
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      "LIVE",
                                      style: TextStyle(
                                        color: const Color(0xFFFF52C5),
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      "   |   ",
                                      style: TextStyle(
                                        color: Colors.white24,
                                        fontSize: 10.sp,
                                      ),
                                    ),
                                    Obx(() => Text(
                                      ctrl.viewersCount.value,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              // TIMER badge
                              Obx(() {
                                if (!ctrl.auctionActive.value) return const SizedBox.shrink();
                                final isLowTime = ctrl.bidTimer.value <= 10;
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: isLowTime ? Colors.redAccent.withOpacity(0.8) : const Color(0xFF8B9BFF).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(
                                      color: isLowTime ? Colors.redAccent : const Color(0xFF8B9BFF).withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer_outlined, color: Colors.white, size: 12.sp),
                                      SizedBox(width: 4.w),
                                      Text(
                                        "00:${ctrl.bidTimer.value.toString().padLeft(2, '0')}",
                                        style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _buildHostProfileCard(),
                    ],
                  ),
                ),
              ),
            ),

            // ── Floating Elements (Bottom Overlay)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row containing Comments/Product (left) & Right Panel (right)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildChat(),
                                SizedBox(height: 12.h),
                                Obx(() {
                                  if (!ctrl.auctionActive.value && ctrl.currentProductTitle.value.isEmpty) return const SizedBox.shrink();
                                  return _buildProductCard();
                                }),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          _buildRightSideControls(),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      // Bottom Row bar (Input, Custom, Bid capsule)
                      _buildBottomBar(),
                    ],
                  ),
                ),
              ),
            ),

            // ── Floating Hearts Overlay
            Positioned(
              right: 16.w,
              bottom: 100.h,
              child: SizedBox(
                width: 100.w,
                height: 350.h,
                child: Obx(() => Stack(
                  clipBehavior: Clip.none,
                  children: ctrl.floatingHearts.map((heart) {
                    return _buildAnimatedHeart(heart);
                  }).toList(),
                )),
              ),
            ),

            // ── Floating Emojis Overlay
            Positioned(
              right: 20.w,
              bottom: 100.h,
              child: SizedBox(
                width: 100.w,
                height: 350.h,
                child: Obx(() => Stack(
                  clipBehavior: Clip.none,
                  children: ctrl.floatingEmojis.map((emojiItem) {
                    return _buildAnimatedEmoji(emojiItem);
                  }).toList(),
                )),
              ),
            ),

            // ── Results Calculating Loader Overlay
            Obx(() {
              if (ctrl.isCalculatingResult.value) {
                return _buildCalculatingLoader();
              }
              return const SizedBox.shrink();
            }),

            // ── Winner Overlay Popup
            Obx(() {
              if (ctrl.showWinnerOverlay.value) {
                return _buildWinnerOverlay();
              }
              return const SizedBox.shrink();
            }),

            // ── Anti-Sniping Timer Extended Notice
            Obx(() {
              if (ctrl.timerExtendedNotification.value) {
                return _buildTimerExtendedOverlay();
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculatingLoader() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF8B9BFF)),
            SizedBox(height: 20.h),
            Text(
              "Calculating Result...",
              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              "Determining the winning bid",
              style: TextStyle(color: Colors.white60, fontSize: 13.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerExtendedOverlay() {
    return Positioned(
      top: 150.h,
      left: 24.w,
      right: 24.w,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white24),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.whatshot_rounded, color: Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                "🔥 New Bid! Extended by 10s!",
                style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinnerOverlay() {
    final String currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey) ?? "";
    final hasWinner = ctrl.lastBidderId.value.isNotEmpty && !ctrl.isUnsold.value;
    final isWinner = hasWinner && ctrl.lastBidderId.value == currentUserId;
    final winnerName = ctrl.lastBidderName.value;
    final finalPrice = ctrl.currentBidPrice.value;

    return Container(
      color: Colors.black.withOpacity(0.92),
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(28.r),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(32.r),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: isWinner ? Colors.amber.withOpacity(0.15) : const Color(0xFF8B9BFF).withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header icon
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: isWinner
                      ? Colors.amber.withOpacity(0.1)
                      : (hasWinner ? const Color(0xFF8B9BFF).withOpacity(0.1) : Colors.redAccent.withOpacity(0.1)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isWinner
                      ? Icons.emoji_events_rounded
                      : (hasWinner ? Icons.gavel_rounded : Icons.hourglass_disabled_rounded),
                  color: isWinner
                      ? Colors.amber
                      : (hasWinner ? const Color(0xFF8B9BFF) : Colors.redAccent),
                  size: 48.sp,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                isWinner
                    ? "🏆 Auction Won!"
                    : (hasWinner ? "Auction Ended" : (ctrl.isUnsold.value ? "Reserve Not Met" : "Auction Ended")),
                style: TextStyle(
                  color: isWinner ? Colors.amber : (ctrl.isUnsold.value ? Colors.redAccent : Colors.white),
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12.h),
              if (isWinner) ...[
                Text(
                  "Congratulations!\nYou won this auction item for \$${finalPrice.toStringAsFixed(0)}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold, height: 1.4),
                ),
                SizedBox(height: 16.h),
                // ── Action Banner ────────────────
                Container(
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stars_rounded, color: const Color(0xFFFFB800), size: 18.sp),
                          SizedBox(width: 6.w),
                          Text(
                            "Auction Won • Action Required ⚡",
                            style: TextStyle(
                              color: const Color(0xFFFFB800),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        "Please complete checkout for \$${finalPrice.toStringAsFixed(0)} to confirm shipping address and receive your item.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showCheckoutDialog(finalPrice);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB800),
                          foregroundColor: const Color(0xFF0F0B1E),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                        ),
                        icon: Icon(Icons.shopping_bag_rounded, size: 18.sp),
                        label: Text(
                          "Complete Checkout & Order (\$${finalPrice.toStringAsFixed(0)})",
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ctrl.showWinnerOverlay.value = false;
                      Get.toNamed(AppRoute.purchases);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    ),
                    icon: Icon(Icons.local_shipping_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                    label: Text(
                      "View Purchases & Tracking",
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ] else if (hasWinner) ...[
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(color: Colors.white70, fontSize: 14.sp, height: 1.4),
                    children: [
                      const TextSpan(text: "Winner: "),
                      TextSpan(
                        text: "@$winnerName\n",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.sp),
                      ),
                      const TextSpan(text: "Winning Bid: "),
                      TextSpan(
                        text: "\$$finalPrice",
                        style: const TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "Thank you for participating.",
                  style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                ),
                SizedBox(height: 32.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ctrl.showWinnerOverlay.value = false;
                          Get.offAllNamed('/main'); // Browse Products
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B9BFF),
                          foregroundColor: const Color(0xFF0F0B1E),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                        ),
                        child: Text(
                          "Browse Products",
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  ctrl.isUnsold.value
                      ? "Reserve price of \$${ctrl.reservePrice.value.toStringAsFixed(0)} was not met.\nThe highest bid was \$${finalPrice.toStringAsFixed(0)}."
                      : "No bids were received for this item.",
                  style: TextStyle(color: Colors.white60, fontSize: 14.sp, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ctrl.showWinnerOverlay.value = false;
                          Get.offAllNamed('/main');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                        ),
                        child: Text(
                          "Browse Products",
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 12.h),
              TextButton(
                onPressed: () => ctrl.showWinnerOverlay.value = false,
                child: Text(
                  "Continue Watching Stream",
                  style: TextStyle(color: Colors.white38, fontSize: 13.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCheckoutDialog(double winningAmount) {
    final addressCtrl = TextEditingController(text: "123 Main St, New York");
    final zipCtrl = TextEditingController(text: "10001");
    final isPaying = false.obs;

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            Text("Secure Checkout", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900)),
            SizedBox(height: 4.h),
            Text("Complete order for winning item", style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
            SizedBox(height: 20.h),

            // Product Details row
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50.r,
                    height: 50.r,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: ctrl.currentProductImage.value.isEmpty
                        ? Icon(Icons.image, color: Colors.white24, size: 22.sp)
                        : Image.network(
                            ctrl.currentProductImage.value.startsWith('http')
                                ? ctrl.currentProductImage.value
                                : "${ApiUrl.imageBaseUrl}${ctrl.currentProductImage.value}",
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 22.sp),
                          ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ctrl.currentProductTitle.value,
                          style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Total Amount: \$${winningAmount.toStringAsFixed(0)}",
                          style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 12.sp, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Shipping fields
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: addressCtrl,
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
                decoration: InputDecoration(
                  labelText: "Shipping Address",
                  labelStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: zipCtrl,
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
                decoration: InputDecoration(
                  labelText: "ZIP / Postal Code",
                  labelStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // Action button
            Obx(() => Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isPaying.value ? null : () async {
                      isPaying.value = true;
                      
                      final success = await ctrl.checkoutAuctionOrder(
                        subtotal: winningAmount,
                        street: addressCtrl.text.trim(),
                        postalCode: zipCtrl.text.trim(),
                      );
                      
                      isPaying.value = false;
                      if (success) {
                        Get.back(); // Close checkout sheet
                        ctrl.showWinnerOverlay.value = false; // Close Winner overlay
                        
                        _showOrderSuccessDialog(context, ctrl, winningAmount);
                      } else {
                        Get.snackbar(
                          "Payment Failed",
                          "Could not process your auction checkout. Please try again.",
                          backgroundColor: Colors.redAccent,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: const Color(0xFF0F0B1E),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    ),
                    child: isPaying.value
                        ? SizedBox(
                            width: 22.r,
                            height: 22.r,
                            child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            "Pay \$${winningAmount.toStringAsFixed(0)} Now",
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showOrderSuccessDialog(BuildContext context, AgoraLiveController ctrl, double winningAmount) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.r,
                height: 64.r,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 36.sp),
              ),
              SizedBox(height: 16.h),
              Text(
                "Payment Successful!",
                style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8.h),
              Text(
                "Your auction order message has been sent to your Inbox with full order details.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13.sp),
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48.r,
                      height: 48.r,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.r)),
                      child: ctrl.currentProductImage.value.isEmpty
                          ? Container(color: Colors.white10, child: Icon(Icons.image, color: Colors.white38, size: 20.sp))
                          : Image.network(
                              ctrl.currentProductImage.value.startsWith('http')
                                  ? ctrl.currentProductImage.value
                                  : "${ApiUrl.imageBaseUrl}${ctrl.currentProductImage.value}",
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: Colors.white10, child: Icon(Icons.image, color: Colors.white38, size: 20.sp)),
                            ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctrl.currentProductTitle.value.isNotEmpty ? ctrl.currentProductTitle.value : "Auction Winner Item",
                            style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            "Winning Bid: \$${winningAmount.toStringAsFixed(0)}",
                            style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 12.sp, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.toNamed(AppRoute.purchases);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        foregroundColor: const Color(0xFF0F0B1E),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                      child: Text("View Purchases", style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () => Get.back(),
                child: Text("Continue Watching Stream", style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeart(FloatingHeart heart) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(heart.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        final double opacity = value < 0.2
            ? (value / 0.2)
            : (value > 0.7 ? (1.0 - value) / 0.3 : 1.0);
        final double translationY = -300.h * value;
        final double translationX = 40.w * math.sin(value * math.pi) * heart.angle;
        return Positioned(
          bottom: 0,
          right: 30.w + translationX,
          child: Transform.translate(
            offset: Offset(0, translationY),
            child: Transform.scale(
              scale: heart.scale * (value < 0.2 ? value / 0.2 : 1.0),
              child: Transform.rotate(
                angle: heart.angle,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: heart.color,
                    size: 32.sp,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHostProfileCard() {
    final rawSeller = widget.streamData['sellerId'];
    final seller = rawSeller is Map ? rawSeller : {};
    final username = "@${seller['username'] ?? seller['fullName'] ?? seller['name'] ?? 'Host'}";
    final rating = seller['rating']?.toString() ?? "4.9";

    String avatarUrl = "";
    final sellerImage = (seller['profile'] ?? seller['image'] ?? seller['profileImageUrl'] ?? seller['avatar'])?.toString();
    if (sellerImage != null && sellerImage.isNotEmpty) {
      avatarUrl = (sellerImage.startsWith('http') || sellerImage.startsWith('data:image/'))
          ? sellerImage
          : "${ApiUrl.imageBaseUrl}${sellerImage.startsWith('/') ? sellerImage : '/$sellerImage'}";
    }

    return GestureDetector(
      onTap: () {
        final String sellerId = seller['_id'] ?? seller['id'] ?? '';
        if (sellerId.isNotEmpty) {
          Get.toNamed('/trader_profile', arguments: {
            "id": sellerId,
            "name": seller['fullName'] ?? seller['username'] ?? 'User',
            "avatar": avatarUrl,
            "bio": seller['bio'] ?? seller['description'] ?? '',
          });
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(28.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.r,
              height: 36.r,
              decoration: const BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
              ),
              child: avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.white54, size: 20.sp),
                      ),
                    )
                  : Icon(Icons.person, color: Colors.white54, size: 20.sp),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: const Color(0xFFFF41FF), size: 10.sp),
                    SizedBox(width: 2.w),
                    Text(
                      rating,
                      style: TextStyle(color: Colors.white70, fontSize: 9.sp, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(width: 16.w),
            Obx(() => GestureDetector(
              onTap: () => ctrl.isFollowingHost.toggle(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: ctrl.isFollowingHost.value ? Colors.white12 : const Color(0xFF8B9BFF),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Text(
                  ctrl.isFollowingHost.value ? "FOLLOWED" : "FOLLOW",
                  style: TextStyle(
                    color: ctrl.isFollowingHost.value ? Colors.white : Colors.black,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildChat() {
    return Container(
      height: 200.h,
      alignment: Alignment.bottomLeft,
      child: Obx(() {
        _scrollToBottom();
        return ListView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          padding: EdgeInsets.only(bottom: 8.h),
          itemCount: ctrl.chatMessages.length,
          itemBuilder: (context, index) {
            final m = ctrl.chatMessages[index];
            return Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: _buildCommentBubble(m),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildCommentBubble(Map<String, String> m) {
    final user = m['user'] ?? '';
    final msg = m['msg'] ?? '';
    final role = m['role'] ?? 'viewer';
    final isBid = m['isBid'] == 'true';
    final userAvatar = m['userAvatar'] ?? '';
    final isJoin = m['isJoin'] == 'true';

    final ImageProvider avatarImg = userAvatar.isNotEmpty
        ? NetworkImage(userAvatar)
        : const NetworkImage("https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200") as ImageProvider;

    if (isJoin) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10.r,
              backgroundImage: avatarImg,
            ),
            SizedBox(width: 6.w),
            Text(
              "$user joined this stream",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (isBid) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withOpacity(0.6),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.3), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12.r,
              backgroundImage: avatarImg,
            ),
            SizedBox(width: 8.w),
            Icon(Icons.gavel_rounded, color: const Color(0xFF8B9BFF), size: 14.sp),
            SizedBox(width: 6.w),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$user ",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: msg,
                    style: TextStyle(
                      color: const Color(0xFF8B9BFF),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (m['isCustomOffer'] == 'true') {
      final offerAmt = m['offerAmount'] ?? '0';
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1B4E).withOpacity(0.85),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFBD8BFF).withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFBD8BFF).withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12.r,
              backgroundImage: avatarImg,
            ),
            SizedBox(width: 8.w),
            Icon(Icons.handshake_rounded, color: const Color(0xFFBD8BFF), size: 16.sp),
            SizedBox(width: 6.w),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$user ",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: "sent Offer: \$$offerAmt",
                    style: TextStyle(
                      color: const Color(0xFFBD8BFF),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isHost = role == 'host';
    if (isHost) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF8B9BFF).withOpacity(0.55),
              const Color(0xFFBD8BFF).withOpacity(0.55),
            ],
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFBD8BFF).withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFBD8BFF).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12.r,
              backgroundImage: avatarImg,
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      user,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        "HOST",
                        style: TextStyle(
                          color: const Color(0xFF8B9BFF),
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  msg,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            user.startsWith('@') ? user : '@$user',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            msg,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildProductCard() {
    return GestureDetector(
      onTap: () => _showProductInspectionSheet(),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.white10, width: 0.5),
        ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58.r,
                height: 58.r,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Obx(() {
                  final img = ctrl.currentProductImage.value;
                  if (img.isEmpty) {
                    return Icon(Icons.image, color: Colors.white24, size: 22.sp);
                  }
                  if (img.startsWith('data:image/') && img.contains('base64,')) {
                    try {
                      final base64Content = img.split('base64,').last;
                      final bytes = base64Decode(base64Content);
                      return Image.memory(bytes, fit: BoxFit.cover);
                    } catch (_) {
                      return Icon(Icons.image, color: Colors.white24, size: 22.sp);
                    }
                  }
                  final fullUrl = img.startsWith('http')
                      ? img
                      : "${ApiUrl.imageBaseUrl}${img.startsWith('/') ? img : '/$img'}";
                  return Image.network(
                    fullUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 22.sp),
                  );
                }),
              ),
              Positioned(
                top: -6.h,
                left: -6.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF52C5),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    "HOT",
                    style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() => Text(
                  ctrl.currentProductTitle.value.isEmpty ? "Live Product" : ctrl.currentProductTitle.value,
                  style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Obx(() {
                      final cat = ctrl.currentProductCategory.value;
                      if (cat.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(right: 4.w),
                        child: _buildBadgeTag(cat.toUpperCase()),
                      );
                    }),
                    _buildBadgeTag("FREE SHIPPING"),
                  ],
                ),
                SizedBox(height: 6.h),
                Obx(() => Row(
                  children: [
                    Text(
                      "Last Bid: ",
                      style: TextStyle(color: Colors.white60, fontSize: 11.sp, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      "\$${ctrl.currentBidPrice.value.toStringAsFixed(0)}",
                      style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 14.sp, fontWeight: FontWeight.w900),
                    ),
                  ],
                )),

              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBadgeTag(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white70, fontSize: 8.sp, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildRightSideControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mute Audio Toggle
        Obx(() => GestureDetector(
          onTap: ctrl.toggleViewerAudio,
          child: Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: ctrl.isAudioMuted.value ? Colors.red.withOpacity(0.8) : Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ctrl.isAudioMuted.value ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
        )),
        SizedBox(height: 12.h),


        Obx(() {
          final count = ctrl.likeCount.value;
          final label = count >= 1000
              ? '${(count / 1000).toStringAsFixed(1)}K'
              : '$count';
          return GestureDetector(
            onTap: () => ctrl.sendLike(),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: ctrl.isLiked.value ? const Color(0xFFFF528E) : Colors.white60,
                    size: 24.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }),
        SizedBox(height: 12.h),
        GestureDetector(
          onTap: () => Get.snackbar("Share", "Link copied to clipboard!", snackPosition: SnackPosition.BOTTOM),
          child: Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.share_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Row(
      children: [
        // Chat Input Box
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    style: TextStyle(color: Colors.white, fontSize: 13.sp),
                    decoration: InputDecoration(
                      hintText: "Say something...",
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13.sp),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 11.h),
                    ),
                    onSubmitted: (val) {
                      ctrl.sendChatMessage(val, role: 'viewer');
                      _chatController.clear();
                    },
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ctrl.sendChatMessage(_chatController.text, role: 'viewer');
                    _chatController.clear();
                  },
                  child: Icon(Icons.send_rounded, color: Colors.white54, size: 18.sp),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 8.w),



        // Custom Bid Button
        GestureDetector(
          onTap: () => _showBidSheet(),
          child: Container(
            height: 48.r,
            width: 48.r,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C).withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            ),
            child: Center(
              child: Text(
                "Custom",
                style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),


        Obx(() {
          final currentBid = ctrl.currentBidPrice.value;
          final nextBid = currentBid > 0 ? (currentBid + ctrl.bidIncrement.value) : ctrl.bidIncrement.value;
          final isBidding = ctrl.isPlacingBid.value;
          return GestureDetector(
            onTap: isBidding ? null : () => ctrl.placeBid(nextBid),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48.h,
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 8.w, 4.h),
              decoration: BoxDecoration(
                color: isBidding ? const Color(0xFF8B9BFF).withValues(alpha: 0.6) : const Color(0xFF8B9BFF),
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "BID",
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.6),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        "\$${nextBid.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 12.w),
                  Container(
                    width: 32.r,
                    height: 32.r,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B7BFF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isBidding
                          ? SizedBox(
                              width: 14.r,
                              height: 14.r,
                              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.black,
                              size: 16.sp,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showBidSheet() {
    final bidAmountCtrl = TextEditingController();
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            Text("Place Your Bid", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900)),
            SizedBox(height: 8.h),
            Obx(() => Text(
              "Current highest: \$${ctrl.currentBidPrice.value.toStringAsFixed(0)}",
              style: TextStyle(color: Colors.white38, fontSize: 13.sp),
            )),
            SizedBox(height: 20.h),

            Obx(() {
              final base = ctrl.currentBidPrice.value;
              return Row(
                children: [base + 100, base + 250, base + 500].map((amt) {
                  return GestureDetector(
                    onTap: () {
                      bidAmountCtrl.text = amt.toStringAsFixed(0);
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: 10.w),
                      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text("+\$${(amt - base).toStringAsFixed(0)}",
                          style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800)),
                    ),
                  );
                }).toList(),
              );
            }),

            SizedBox(height: 20.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: bidAmountCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  hintText: "Enter bid amount",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 16.sp),
                  border: InputBorder.none,
                  prefixText: "\$",
                  prefixStyle: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 18.sp, fontWeight: FontWeight.w900),
                  contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            GestureDetector(
              onTap: () {
                final text = bidAmountCtrl.text.trim();
                debugPrint("Confirm Bid tapped: input='$text'");
                if (text.isEmpty) {
                  Get.snackbar("Error", "Please enter a bid amount.", snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                final cleanText = text.replaceAll('\$', '').replaceAll(',', '');
                final amount = double.tryParse(cleanText);
                if (amount == null) {
                  Get.snackbar("Error", "Invalid number format.", snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                debugPrint("Confirm Bid parsed amount: $amount. Placing bid...");
                ctrl.placeBid(amount);
              },
              child: Container(
                width: double.infinity,
                height: 56.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B9BFF), Color(0xFFBD8BFF)]),
                  borderRadius: BorderRadius.circular(28.r),
                ),
                child: Text("Confirm Bid", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showCustomOfferSheet() {
    final offerAmountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            Row(
              children: [
                Icon(Icons.handshake_rounded, color: const Color(0xFFBD8BFF), size: 24.sp),
                SizedBox(width: 8.w),
                Text("Make a Custom Offer", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900)),
              ],
            ),
            SizedBox(height: 4.h),
            Obx(() => Text(
              "Send a direct offer to the host for ${ctrl.currentProductTitle.value.isEmpty ? 'this item' : ctrl.currentProductTitle.value}",
              style: TextStyle(color: Colors.white38, fontSize: 12.sp),
            )),
            SizedBox(height: 20.h),

            // Quick offer chips based on current price
            Obx(() {
              final base = ctrl.currentBidPrice.value;
              final suggestions = [base * 0.9, base, base * 1.15].where((a) => a > 0).toList();
              return Row(
                children: suggestions.map((amt) {
                  return GestureDetector(
                    onTap: () {
                      offerAmountCtrl.text = amt.toStringAsFixed(0);
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: 10.w),
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFBD8BFF).withOpacity(0.3)),
                      ),
                      child: Text("\$${amt.toStringAsFixed(0)}",
                          style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800)),
                    ),
                  );
                }).toList(),
              );
            }),

            SizedBox(height: 16.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: offerAmountCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  hintText: "Enter offer amount",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 16.sp),
                  border: InputBorder.none,
                  prefixText: "\$",
                  prefixStyle: TextStyle(color: const Color(0xFFBD8BFF), fontSize: 18.sp, fontWeight: FontWeight.w900),
                  contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: noteCtrl,
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: "Add note for host (optional)",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            GestureDetector(
              onTap: () {
                final text = offerAmountCtrl.text.trim();
                if (text.isEmpty) {
                  Get.snackbar("Error", "Please enter an offer amount.", snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                final cleanText = text.replaceAll('\$', '').replaceAll(',', '');
                final amount = double.tryParse(cleanText);
                if (amount == null || amount <= 0) {
                  Get.snackbar("Error", "Invalid offer amount.", snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                ctrl.sendCustomOffer(offerPrice: amount, message: noteCtrl.text.trim());
              },
              child: Container(
                width: double.infinity,
                height: 54.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B9BFF), Color(0xFFBD8BFF)]),
                  borderRadius: BorderRadius.circular(27.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFBD8BFF).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text("Send Custom Offer", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildAnimatedEmoji(FloatingEmoji item) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(item.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1600),
      builder: (context, value, child) {
        final double opacity = value < 0.2
            ? (value / 0.2)
            : (value > 0.7 ? (1.0 - value) / 0.3 : 1.0);
        final double translationY = -320.h * value;
        final double translationX = 35.w * math.sin(value * math.pi) * item.angle;
        return Positioned(
          bottom: 0,
          right: 35.w + translationX,
          child: Transform.translate(
            offset: Offset(0, translationY),
            child: Transform.scale(
              scale: item.scale * (value < 0.2 ? value / 0.2 : 1.0),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Text(
                  item.emoji,
                  style: TextStyle(fontSize: 28.sp),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProductInspectionSheet() {
    final title = ctrl.currentProductTitle.value.isEmpty ? "Auction Item" : ctrl.currentProductTitle.value;
    final img = ctrl.currentProductImage.value;
    final cat = ctrl.currentProductCategory.value.isEmpty ? "Rare Collectibles" : ctrl.currentProductCategory.value;

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    cat.toUpperCase(),
                    style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 10.sp, fontWeight: FontWeight.w900),
                  ),
                ),
                const Spacer(),
                Icon(Icons.verified_rounded, color: const Color(0xFF22C55E), size: 18.sp),
                SizedBox(width: 4.w),
                Text("Verified Authentic", style: TextStyle(color: Colors.white60, fontSize: 11.sp, fontWeight: FontWeight.w700)),
              ],
            ),
            SizedBox(height: 16.h),
            Center(
              child: Container(
                width: 140.r,
                height: 140.r,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white10),
                ),
                child: img.isEmpty
                    ? Icon(Icons.image, color: Colors.white24, size: 48.sp)
                    : Image.network(
                        img.startsWith('http') ? img : "${ApiUrl.imageBaseUrl}$img",
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 48.sp),
                      ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(title, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
            SizedBox(height: 6.h),
            Row(
              children: [
                Text("Current Highest Bid: ", style: TextStyle(color: Colors.white60, fontSize: 13.sp)),
                Obx(() => Text("\$${ctrl.currentBidPrice.value.toStringAsFixed(0)}",
                    style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 18.sp, fontWeight: FontWeight.w900))),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              "Authentic item inspected by host. Guaranteed original condition, fast insured shipping included.",
              style: TextStyle(color: Colors.white54, fontSize: 12.sp, height: 1.4),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      final nextBid = ctrl.currentBidPrice.value + ctrl.bidIncrement.value;
                      ctrl.placeBid(nextBid);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B9BFF),
                      foregroundColor: const Color(0xFF0F0B1E),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    ),
                    child: Obx(() => Text(
                      "Place Bid (\$${(ctrl.currentBidPrice.value + ctrl.bidIncrement.value).toStringAsFixed(0)})",
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                    )),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      _showCustomOfferSheet();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBD8BFF),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    ),
                    child: Text(
                      "Make Offer",
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showExitDialog(AgoraLiveController ctrl) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          "Exit Live Stream?",
          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Would you like to minimize the stream to keep watching, or exit completely?",
          style: TextStyle(color: Colors.white70, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          OutlinedButton(
            onPressed: () {
              Get.back();
              ctrl.minimizeStream();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF8B9BFF)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text("Minimize", style: TextStyle(color: Color(0xFF8B9BFF))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            onPressed: () {
              Get.back();
              ctrl.endStream();
            },
            child: const Text("Leave", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
