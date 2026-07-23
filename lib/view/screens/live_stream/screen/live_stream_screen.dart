import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/app_route.dart';
import '../controller/live_stream_controller.dart';

class LiveStreamScreen extends StatelessWidget {
  const LiveStreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LiveStreamController());
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: controller.streams.length,
        onPageChanged: controller.onPageChanged,
        itemBuilder: (context, index) {
          final stream = controller.streams[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background Video Player with Gestures
              Obx(() {
                final vc = controller.videoControllers[index];
                final isReady = controller.videoReady[index];
                final isPaused = controller.isPaused[index];

                if (isReady && vc != null) {
                  return GestureDetector(
                    onTap: () => controller.togglePlay(index),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: vc.value.size.width,
                              height: vc.value.size.height,
                              child: VideoPlayer(vc),
                            ),
                          ),
                        ),
                        // Play Icon Overlay
                        if (isPaused)
                          Container(
                            padding: EdgeInsets.all(15.r),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 50.sp),
                          ),
                        // Red Progress Bar at the very bottom
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: SizedBox(
                            height: 3.h,
                            child: VideoProgressIndicator(
                              vc,
                              allowScrubbing: true,
                              padding: EdgeInsets.zero,
                              colors: VideoProgressColors(
                                playedColor: Colors.red,
                                bufferedColor: Colors.white24,
                                backgroundColor: Colors.white10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B9BFF),
                      strokeWidth: 2,
                    ),
                  ),
                );
              }),

              // Dark gradient overlay
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0, 0.2, 0.6, 1],
                    ),
                  ),
                ),
              ),

              // Overlay UI
              _buildOverlayUI(stream, index, context, controller),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverlayUI(LiveStreamModel stream, int index, BuildContext context, LiveStreamController controller) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        child: Column(
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: const BoxDecoration(
                        color: Colors.black38, shape: BoxShape.circle),
                    child: Icon(Icons.close, color: Colors.white, size: 22.sp),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(25.r)),
                  child: Row(
                    children: [
                      Icon(Icons.sensors, color: const Color(0xFFFF5252), size: 14.sp),
                      SizedBox(width: 6.w),
                      Text("LIVE",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      SizedBox(width: 8.w),
                      Container(
                          width: 1, height: 10.h, color: Colors.white24),
                      SizedBox(width: 8.w),
                      Text(stream.viewers,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12.h),

            // Creator Info
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(2.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: CircleAvatar(
                    radius: 20.r,
                    backgroundImage: NetworkImage(stream.productImage),
                  ),
                ),
                SizedBox(width: 10.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stream.curator,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Icon(Icons.star,
                            color: const Color(0xFFFF8BFF), size: 10.sp),
                        SizedBox(width: 2.w),
                        Text("4.9",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Obx(() => GestureDetector(
                      onTap: () => stream.isFollowing.toggle(),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 18.w, vertical: 8.h),
                        decoration: BoxDecoration(
                            color: stream.isFollowing.value
                                ? Colors.white.withOpacity(0.1)
                                : const Color(0xFF9EACFF),
                            borderRadius: BorderRadius.circular(10.r),
                            border: stream.isFollowing.value
                                ? Border.all(color: Colors.white24)
                                : null),
                        child: Text(
                            stream.isFollowing.value ? "FOLLOWING" : "FOLLOW",
                            style: TextStyle(
                                color: stream.isFollowing.value
                                    ? Colors.white
                                    : const Color(0xFF0D0D1A),
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900)),
                      ),
                    )),
              ],
            ),

            const Spacer(),

            // Bottom Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChatBubble("@user123", "Is there a warranty on this?"),
                      _buildChatBubble("@short023", "The zoom is incredible!"),
                      _buildChatBubble("@short028", "Just placed my bid 🚀"),
                      SizedBox(height: 12.h),
                      _buildProductCard(stream),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 52.h,
                              padding: EdgeInsets.symmetric(horizontal: 18.w),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(26.r)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      style: TextStyle(color: Colors.white, fontSize: 13.sp),
                                      decoration: InputDecoration(
                                        hintText: "Say something...",
                                        hintStyle:
                                            TextStyle(color: Colors.white30, fontSize: 13.sp),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.send_rounded,
                                      color: Colors.white, size: 20.sp),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),

                          GestureDetector(
                            onTap: () => _showCustomBidSheet(context, controller, stream),
                            child: Container(
                              height: 52.h,
                              width: 46.h,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF1A1A1A),
                                  shape: BoxShape.circle),
                              child: Center(
                                  child: Text("Custom",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.bold))),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Obx(() => _buildBidButton(controller, controller.streams[index])),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Multi-tap Like (boost)
                    Obx(() {
                      final liked = stream.isLiked.value;
                      final count = stream.likeCount.value;
                      final label = count >= 1000
                          ? '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}K'
                          : '$count';
                      return GestureDetector(
                        onTap: () => controller.addLike(stream),
                        child: Column(
                          children: [
                            Container(
                              margin: EdgeInsets.only(bottom: 4.h),
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: liked
                                    ? const Color(0xFFFF41FF).withOpacity(0.18)
                                    : Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                liked ? Icons.favorite : Icons.favorite_border,
                                color: liked ? const Color(0xFFFF41FF) : Colors.white,
                                size: 24.sp,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(bottom: 16.h),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    // Bookmark
                    Obx(() {
                      final bookmarked = stream.isBookmarked.value;
                      return _buildActionButton(
                        bookmarked ? Icons.bookmark : Icons.bookmark_border_outlined,
                        '',
                        color: bookmarked ? const Color(0xFF8B9BFF) : Colors.white,
                        onTap: () => controller.toggleBookmark(stream),
                      );
                    }),
                    _buildActionButton(Icons.notifications_none, "", onTap: () => Get.toNamed(AppRoute.notifications)),
                    _buildActionButton(Icons.share_outlined, ""),
                    SizedBox(height: 60.h),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(String user, String message) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35), 
          borderRadius: BorderRadius.circular(15.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user,
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 1.h),
          Text(message,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildProductCard(LiveStreamModel stream) {
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15.r),
                child: Image.network(
                  stream.productImage,
                  width: 65.r,
                  height: 65.r,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      width: 65.r, height: 65.r, color: Colors.white10),
                ),
              ),
              Positioned(
                top: -4,
                left: -4,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF41FF),
                      borderRadius: BorderRadius.circular(6.r)),
                  child: Text("HOT",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stream.productTitle,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 6.h),
                Row(children: [
                  _buildBadge("FREE SHIPPING"),
                  SizedBox(width: 4.w),
                  _buildBadge("TAXES"),
                ]),
                SizedBox(height: 8.h),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "\$ ",
                        style: TextStyle(
                          color: const Color(0xFF9EACFF),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: stream.productPrice.replaceAll('\$', '').split('.')[0],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), 
            borderRadius: BorderRadius.circular(4.r)),
        child: Text(label,
            style: TextStyle(
                color: Colors.white70,
                fontSize: 8.sp,
                fontWeight: FontWeight.bold)),
      );

  Widget _buildBidButton(LiveStreamController controller, LiveStreamModel stream) {
    return GestureDetector(
      onTap: () {
        double currentPrice = double.tryParse(stream.productPrice.value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        controller.placeBid(currentPrice + 50);
      },
      child: Container(
        height: 52.h,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        decoration: BoxDecoration(
            color: const Color(0xFFA6B4FF),
            borderRadius: BorderRadius.circular(26.r)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 10.w),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("BID",
                    style: TextStyle(
                        color: Colors.black45,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w900)),
                Text(stream.productPrice.value.split('.')[0],
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900)),
              ],
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_rounded,
                  color: Colors.black, size: 16.sp),
            ),
            SizedBox(width: 2.w),
          ],
        ),
      ),
    );
  }

  void _showCustomOfferSheet(BuildContext context, LiveStreamController controller, LiveStreamModel stream) {
    final offerCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Icon(Icons.handshake_rounded, color: const Color(0xFFBD8BFF), size: 24.sp),
                SizedBox(width: 8.w),
                Text("Make a Custom Offer", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 6.h),
            Text("Send a direct offer to the host for ${stream.productTitle}", style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
            SizedBox(height: 20.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: TextField(
                controller: offerCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "Enter offer amount",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 15.sp),
                  border: InputBorder.none,
                  prefixText: "\$",
                  prefixStyle: TextStyle(color: const Color(0xFFBD8BFF), fontSize: 18.sp, fontWeight: FontWeight.bold),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: TextField(
                controller: noteCtrl,
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: "Add note for host (optional)",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: () {
                  final text = offerCtrl.text.trim();
                  if (text.isEmpty) {
                    Get.snackbar("Error", "Please enter an offer amount.", snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  final amount = double.tryParse(text.replaceAll('\$', '').replaceAll(',', ''));
                  if (amount == null || amount <= 0) {
                    Get.snackbar("Error", "Invalid offer amount.", snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  controller.sendCustomOffer(offerPrice: amount, message: noteCtrl.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBD8BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.r)),
                ),
                child: Text("SEND CUSTOM OFFER", style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildActionButton(IconData icon, String label,
      {Color color = Colors.white, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(bottom: label.isEmpty ? 16.h : 4.h),
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          if (label.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Text(label,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  void _showCustomBidSheet(BuildContext context, LiveStreamController controller, LiveStreamModel stream) {
    Get.bottomSheet(
      Container(
        height: 800.h,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          children: [
            SizedBox(height: 12.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 30.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("CURRENT HIGHEST", style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                    Obx(() => Text(stream.productPrice.value, style: TextStyle(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.bold))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("NEXT MINIMUM", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 10.sp, fontWeight: FontWeight.bold)),
                    Obx(() {
                      double current = double.tryParse(stream.productPrice.value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
                      return Text("\$${(current + 500).toStringAsFixed(0)}", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 20.sp, fontWeight: FontWeight.bold));
                    }),
                  ],
                ),
              ],
            ),
            SizedBox(height: 40.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text("\$", style: TextStyle(color: Colors.white38, fontSize: 24.sp, fontWeight: FontWeight.bold)),
                SizedBox(width: 12.w),
                Obx(() => Text(
                  controller.currentCustomBid.value,
                  style: TextStyle(color: Colors.white, fontSize: 48.sp, fontWeight: FontWeight.bold),
                )),
              ],
            ),
            SizedBox(height: 20.h),
            const Divider(color: Colors.white10),
            SizedBox(height: 12.h),
            Text("SET YOUR CUSTOM LIMIT", style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 24.h),
            
            // Quick Amounts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildQuickAmountButton("+\$50", () => controller.addAmount(50)),
                _buildQuickAmountButton("+\$100", () => controller.addAmount(100)),
                _buildQuickAmountButton("+\$500", () => controller.addAmount(500)),
                _buildQuickAmountButton("+\$1K", () => controller.addAmount(1000)),
              ],
            ),
            SizedBox(height: 30.h),
            
            // Keypad
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                mainAxisSpacing: 10.h,
                crossAxisSpacing: 10.w,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ...["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0"].map((digit) => _buildKeypadButton(digit, () => controller.addDigit(digit))),
                  _buildKeypadButton(null, () => controller.removeDigit(), icon: Icons.backspace_outlined),
                ],
              ),
            ),
            SizedBox(height: 40.h),
            
            // Place Bid Button
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: () => controller.placeBid(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B9BFF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.gavel_rounded, size: 20.sp),
                    SizedBox(width: 12.w),
                    Text("PLACE CUSTOM BID", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30.h),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildQuickAmountButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(label, style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildKeypadButton(String? digit, VoidCallback onTap, {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(30.r),
        ),
        child: Center(
          child: digit != null 
            ? Text(digit, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold))
            : Icon(icon, color: Colors.white, size: 20.sp),
        ),
      ),
    );
  }
}
