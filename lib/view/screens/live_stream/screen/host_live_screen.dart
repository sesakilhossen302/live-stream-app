import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/agora_live_controller.dart';
import 'dart:convert';
import '../../../../data/services/api_url.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';

class HostLiveScreen extends StatefulWidget {
  const HostLiveScreen({super.key});

  @override
  State<HostLiveScreen> createState() => _HostLiveScreenState();
}

class _HostLiveScreenState extends State<HostLiveScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AgoraLiveController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = Get.find<AgoraLiveController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.isMinimized.value = false;
      ctrl.ensureHostCameraActive();
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
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ── Local Camera Preview
            Obx(() {
              final isReady = ctrl.isLocalVideoReady.value;
              if (ctrl.engine != null && isReady) {
                return RepaintBoundary(
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: ctrl.engine!,
                      canvas: const VideoCanvas(
                        uid: 0,
                        renderMode: RenderModeType.renderModeHidden,
                        mirrorMode: VideoMirrorModeType.videoMirrorModeEnabled,
                      ),
                      useFlutterTexture: false,
                      useAndroidSurfaceView: true,
                    ),
                  ),
                );
              }
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF8B9BFF)),
                      SizedBox(height: 16.h),
                      Text("Starting camera...",
                          style: TextStyle(color: Colors.white60, fontSize: 14.sp)),
                    ],
                  ),
                ),
              );
            }),

            // ── Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  child: Row(
                    children: [
                      // LIVE badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 7.r, height: 7.r, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            SizedBox(width: 6.w),
                            Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
                      SizedBox(width: 8.w),
                      // LIKE counter badge
                      Obx(() => Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF528E).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: const Color(0xFFFF528E).withOpacity(0.4), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_rounded, color: const Color(0xFFFF528E), size: 12.sp),
                            SizedBox(width: 4.w),
                            Text(
                              "${ctrl.likeCount.value}",
                              style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      )),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Obx(() => Text(
                          ctrl.streamTitle.value,
                          style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                      ),
                      const Spacer(),
                      // Minimize button
                      GestureDetector(
                        onTap: () => ctrl.minimizeStream(),
                        child: Container(
                          padding: EdgeInsets.all(7.r),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.fullscreen_exit, color: Colors.white, size: 16.sp),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // End button
                      GestureDetector(
                        onTap: () => _showEndStreamDialog(ctrl),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text("End", style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
                     // ── Auction Card (bottom)
            Obx(() {
              if (!ctrl.auctionActive.value) return const SizedBox.shrink();
              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.95)],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Chat messages
                      _buildChat(ctrl),
                      SizedBox(height: 12.h),
                      // Auction Info Row
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            // Product thumb
                            Obx(() {
                              final img = ctrl.currentProductImage.value;
                              return Container(
                                width: 54.r,
                                height: 54.r,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: img.isEmpty
                                    ? Icon(Icons.image, color: Colors.white24, size: 22.sp)
                                    : img.startsWith('data:image/') && img.contains('base64,')
                                        ? (() {
                                            try {
                                              final base64Content = img.split('base64,').last;
                                              final bytes = base64Decode(base64Content);
                                              return Image.memory(
                                                bytes,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 22.sp),
                                              );
                                            } catch (_) {
                                              return Icon(Icons.image, color: Colors.white24, size: 22.sp);
                                            }
                                          })()
                                        : Image.network(
                                            img.startsWith('http') ? img : "${ApiUrl.imageBaseUrl}$img",
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 22.sp),
                                          ),
                              );
                            }),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Obx(() {
                                    final cat = ctrl.currentProductCategory.value;
                                    if (cat.isEmpty) return const SizedBox.shrink();
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 2.h),
                                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B9BFF).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                      child: Text(
                                        cat.toUpperCase(),
                                        style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 8.sp, fontWeight: FontWeight.w900),
                                      ),
                                    );
                                  }),
                                  Obx(() => Text(
                                    ctrl.currentProductTitle.value.isEmpty ? "Auction Item" : ctrl.currentProductTitle.value,
                                    style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )),
                                  SizedBox(height: 4.h),
                                  Obx(() => Text(
                                    "Last Bid: \$${ctrl.currentBidPrice.value.toStringAsFixed(0)}",
                                    style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 13.sp, fontWeight: FontWeight.w800),
                                  )),
                                ],
                              ),
                            ),
                            // HOST sees total viewers badge
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.remove_red_eye_outlined, color: Colors.white60, size: 14.sp),
                                  SizedBox(width: 4.w),
                                  Obx(() => Text(
                                    ctrl.viewersCount.value,
                                    style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      // Chat input
                      _buildChatInput(ctrl),
                    ],
                  ),
                ),
              );
            }),

            // ── Right Side Controls (Moved below bottom card overlay to make them clickable)
            Positioned(
              right: 16.w,
              bottom: 200.h,
              child: Obx(() => Column(
                children: [
                  _sideButton(
                    ctrl.isCameraOn.value ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    ctrl.isCameraOn.value ? Colors.white24 : Colors.red.withValues(alpha: 0.6),
                    onTap: ctrl.toggleCamera,
                  ),
                  SizedBox(height: 16.h),
                  _sideButton(
                    ctrl.isMicOn.value ? Icons.mic_rounded : Icons.mic_off_rounded,
                    ctrl.isMicOn.value ? Colors.white24 : Colors.red.withValues(alpha: 0.6),
                    onTap: ctrl.toggleMic,
                  ),
                  SizedBox(height: 16.h),
                  _sideButton(Icons.flip_camera_ios_rounded, Colors.white24, onTap: () {
                    ctrl.engine?.switchCamera();
                  }),
                ],
              )),
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

  Widget _buildWinnerOverlay() {
    final hasWinner = ctrl.lastBidderId.value.isNotEmpty && !ctrl.isUnsold.value;
    final winnerName = ctrl.lastBidderName.value;
    final finalPrice = ctrl.currentBidPrice.value;

    return Container(
      color: Colors.black.withOpacity(0.9),
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
                color: const Color(0xFF8B9BFF).withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: hasWinner ? const Color(0xFF8B9BFF).withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasWinner ? Icons.emoji_events_rounded : Icons.hourglass_disabled_rounded,
                  color: hasWinner ? const Color(0xFF8B9BFF) : Colors.redAccent,
                  size: 48.sp,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                hasWinner ? "Auction Completed!" : (ctrl.isUnsold.value ? "Reserve Not Met" : "Auction Ended"),
                style: TextStyle(color: ctrl.isUnsold.value ? Colors.redAccent : Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 12.h),
              if (hasWinner) ...[
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
                      const TextSpan(text: "Winning Amount: "),
                      TextSpan(
                        text: "\$$finalPrice",
                        style: const TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(
                    "STATUS: AWAITING PAYMENT",
                    style: TextStyle(color: Colors.amber, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ] else ...[
                Text(
                  ctrl.isUnsold.value
                      ? "Reserve price of \$${ctrl.reservePrice.value.toStringAsFixed(0)} was not met.\nThe highest bid was \$${finalPrice.toStringAsFixed(0)}."
                      : "No bids were received for this item.",
                  style: TextStyle(color: Colors.white60, fontSize: 14.sp, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: 32.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showStartNewAuctionSheet(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        foregroundColor: const Color(0xFF0F0B1E),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                      ),
                      child: Text(
                        "Start New Auction",
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
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

  void _showStartNewAuctionSheet() {
    final productsList = <Map<String, dynamic>>[].obs;
    final loadingProducts = true.obs;
    
    // Fetch products
    final sellerId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    Get.find<ApiClient>().getData("${ApiUrl.products}?sellerId=$sellerId").then((res) {
      loadingProducts.value = false;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['data'] ?? [];
        if (list is List) {
          productsList.assignAll(list.map((e) => Map<String, dynamic>.from(e)).toList());
        }
      }
    }).catchError((_) {
      loadingProducts.value = false;
    });

    final startingBidCtrl = TextEditingController(text: "100");
    final incrementCtrl = TextEditingController(text: "5");
    final durationCtrl = TextEditingController(text: "60");

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
            Text("Start New Auction", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900)),
            SizedBox(height: 16.h),
            
            // Starting Bid, Increment & Duration Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: TextField(
                      controller: startingBidCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        labelText: "Start Bid (\$)",
                        labelStyle: const TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: TextField(
                      controller: incrementCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        labelText: "Increment (\$)",
                        labelStyle: const TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        labelText: "Timer (sec)",
                        labelStyle: const TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Text("Select Product to Auction", style: TextStyle(color: Colors.white60, fontSize: 13.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 12.h),
            
            SizedBox(
              height: 250.h,
              child: Obx(() {
                if (loadingProducts.value) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF8B9BFF)));
                }
                if (productsList.isEmpty) {
                  return Center(
                    child: Text("No products available to auction.", style: TextStyle(color: Colors.white38, fontSize: 13.sp)),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: productsList.length,
                  itemBuilder: (context, index) {
                    final prod = productsList[index];
                    final String title = prod['title'] ?? 'Product';
                    final String image = (prod['images'] is List && (prod['images'] as List).isNotEmpty)
                        ? prod['images'][0].toString()
                        : "";
                    final String pid = prod['_id'] ?? prod['id'] ?? "";

                    return GestureDetector(
                      onTap: () async {
                        final double startingBid = double.tryParse(startingBidCtrl.text) ?? 100.0;
                        final double bidIncrement = double.tryParse(incrementCtrl.text) ?? 5.0;
                        final int duration = int.tryParse(durationCtrl.text) ?? 60;
                        
                        Get.back(); // Close bottom sheet
                        final ok = await ctrl.resetAndStartNewAuction(
                          productId: pid,
                          startingBid: startingBid,
                          bidIncrement: bidIncrement,
                          timerDuration: duration,
                          productTitle: title,
                          productImage: image,
                        );
                        if (ok) {
                          Get.snackbar("Auction Started!", "New auction for $title is now live!", snackPosition: SnackPosition.BOTTOM);
                        } else {
                          Get.snackbar("Error", "Failed to start new auction.", snackPosition: SnackPosition.BOTTOM);
                        }
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44.r,
                              height: 44.r,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: image.isEmpty
                                  ? Icon(Icons.image, color: Colors.white24, size: 20.sp)
                                  : Image.network(
                                      image.startsWith('http') ? image : "${ApiUrl.imageBaseUrl}$image",
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 20.sp),
                                    ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14.sp),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
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

  Widget _sideButton(IconData icon, Color bg, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48.r,
        height: 48.r,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22.sp),
      ),
    );
  }

  Widget _buildChat(AgoraLiveController ctrl) {
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
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1B4E).withOpacity(0.9),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
            SizedBox(height: 8.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => ctrl.acceptCustomOffer(m),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      "Accept \$$offerAmt",
                      style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => ctrl.declineCustomOffer(m),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                    child: Text(
                      "Decline",
                      style: TextStyle(color: Colors.white70, fontSize: 10.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
              Text(
                user,
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

  Widget _buildChatInput(AgoraLiveController ctrl) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.white10),
            ),
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
                ctrl.sendChatMessage(val, role: 'host');
                _chatController.clear();
              },
            ),
          ),
        ),
        SizedBox(width: 10.w),
        GestureDetector(
          onTap: () {
            ctrl.sendChatMessage(_chatController.text, role: 'host');
            _chatController.clear();
          },
          child: Container(
            width: 44.r,
            height: 44.r,
            decoration: const BoxDecoration(color: Color(0xFF8B9BFF), shape: BoxShape.circle),
            child: Icon(Icons.send_rounded, color: Colors.white, size: 18.sp),
          ),
        ),
      ],
    );
  }

  void _showEndStreamDialog(AgoraLiveController ctrl) {
    final startTime = ctrl.streamStartTime.value ?? DateTime.now();
    final diff = DateTime.now().difference(startTime);
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    final durationStr = hours != "00" ? "$hours:$minutes:$seconds" : "$minutes:$seconds";

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: const Color(0xFF141422),
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B9BFF).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.analytics_rounded, color: const Color(0xFF8B9BFF), size: 36.sp),
              ),
              SizedBox(height: 16.h),
              Text(
                "End Live Session?",
                style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 6.h),
              Text(
                "Here is your live session performance summary:",
                style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),

              // Metrics Grid
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricTile("⏱️ Duration", durationStr),
                        _metricTile("👥 Viewers", ctrl.remoteJoined.value ? "1" : "0"),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Divider(color: Colors.white10, height: 1.h),
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricTile("🔨 Total Bids", "${ctrl.totalBidsCount.value}"),
                        _metricTile("💰 Revenue", "\$${ctrl.totalSalesRevenue.value.toStringAsFixed(0)}"),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Get.back();
                        ctrl.minimizeStream();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF8B9BFF)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                      child: Text(
                        "Minimize",
                        style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 12.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        await ctrl.endStream();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                      child: Text(
                        "End & Exit",
                        style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w900),
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

  Widget _metricTile(String title, String value) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w600)),
        SizedBox(height: 4.h),
        Text(value, style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 16.sp, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
