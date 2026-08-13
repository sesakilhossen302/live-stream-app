import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../view/screens/live_stream/controller/agora_live_controller.dart';


class FloatingLiveStreamOverlay extends StatefulWidget {
  const FloatingLiveStreamOverlay({super.key});

  @override
  State<FloatingLiveStreamOverlay> createState() => _FloatingLiveStreamOverlayState();
}

class _FloatingLiveStreamOverlayState extends State<FloatingLiveStreamOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  
  // Position coordinates for draggable floating mini player
  double? _left;
  double? _top;
  final double _miniWidth = 145;
  final double _miniHeight = 220;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _snapToEdge(double screenWidth, double screenHeight) {
    if (_left == null || _top == null) return;
    final double midX = screenWidth / 2;
    setState(() {
      if (_left! + (_miniWidth / 2) < midX) {
        _left = 12.w; // Snap to left edge
      } else {
        _left = screenWidth - _miniWidth.w - 12.w; // Snap to right edge
      }
      // Keep within vertical bounds
      _top = _top!.clamp(60.h, screenHeight - _miniHeight.h - 100.h);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgoraLiveController>();

    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Default initial position (bottom right corner above bottom navbar)
    _left ??= screenWidth - _miniWidth.w - 16.w;
    _top ??= screenHeight - _miniHeight.h - 115.h;

    return Obx(() {
      if (!ctrl.isLive.value || !ctrl.isMinimized.value) {
        return const SizedBox.shrink();
      }

      final isHost = ctrl.isHost.value;
      final title = ctrl.currentProductTitle.value.isNotEmpty
          ? ctrl.currentProductTitle.value
          : (ctrl.streamTitle.value.isNotEmpty ? ctrl.streamTitle.value : "Live Stream");

      return Positioned(
        left: _left,
        top: _top,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _left = (_left! + details.delta.dx).clamp(0.0, screenWidth - _miniWidth.w);
                _top = (_top! + details.delta.dy).clamp(40.h, screenHeight - _miniHeight.h);
              });
            },
            onPanEnd: (_) => _snapToEdge(screenWidth, screenHeight),
            onTap: () => ctrl.resumeStream(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _miniWidth.w,
              height: _miniHeight.h,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0B1E),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(color: const Color(0xFF8B9BFF).withValues(alpha: 0.8), width: 2.w),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B9BFF).withValues(alpha: 0.35),
                    blurRadius: 18.r,
                    spreadRadius: 2.r,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 24.r,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),

              child: ClipRRect(
                borderRadius: BorderRadius.circular(18.r),
                child: Stack(
                  children: [
                    // ── 1. Video Surface (Host Camera Preview or Viewer Remote Feed)
                    Positioned.fill(
                      child: isHost
                          ? _buildHostVideoView(ctrl)
                          : _buildViewerVideoView(ctrl),
                    ),

                    // ── 2. Gradient Overlay for readability
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            stops: const [0.0, 0.3, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // ── 3. Top Info Bar (LIVE, Timer, Viewer Count)
                    Positioned(
                      top: 6.h,
                      left: 6.w,
                      right: 6.w,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 🔴 LIVE badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FadeTransition(
                                  opacity: _pulseController,
                                  child: Container(
                                    width: 5.w,
                                    height: 5.w,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 3.w),
                                Text(
                                  "LIVE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Viewer count / Duration timer
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 9.sp),
                                SizedBox(width: 3.w),
                                Text(
                                  ctrl.viewersCount.value,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── 4. Title / Host Name Tag
                    Positioned(
                      bottom: 42.h,
                      left: 8.w,
                      right: 8.w,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 4.r),
                          ],
                        ),
                      ),
                    ),

                    // ── 5. Quick Controls Bar at Bottom
                    Positioned(
                      bottom: 4.h,
                      left: 4.w,
                      right: 4.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: isHost
                            ? _buildHostControls(ctrl)
                            : _buildViewerControls(context, ctrl),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildHostVideoView(AgoraLiveController ctrl) {
    if (ctrl.engine != null && ctrl.isLocalVideoReady.value) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: ctrl.engine!,
          canvas: const VideoCanvas(
            uid: 0,
            renderMode: RenderModeType.renderModeHidden,
            mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
          ),
          useFlutterTexture: true,
          useAndroidSurfaceView: false,
        ),
      );
    }
    return Container(
      color: const Color(0xFF19132B),
      child: Center(
        child: Icon(Icons.videocam_rounded, color: const Color(0xFF8B9BFF), size: 32.sp),
      ),
    );
  }

  Widget _buildViewerVideoView(AgoraLiveController ctrl) {
    final isJoined = ctrl.remoteJoined.value;
    final rUid = ctrl.remoteUid.value;
    if (ctrl.engine != null && isJoined && rUid != -1) {
      return AgoraVideoView(
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
      );
    }
    return Container(
      color: const Color(0xFF19132B),
      child: Center(
        child: Icon(Icons.live_tv_rounded, color: const Color(0xFF8B9BFF), size: 32.sp),
      ),
    );
  }

  Widget _buildHostControls(AgoraLiveController ctrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mic Toggle
        GestureDetector(
          onTap: () => ctrl.toggleMic(),
          child: Icon(
            ctrl.isMicOn.value ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: ctrl.isMicOn.value ? Colors.white : Colors.redAccent,
            size: 14.sp,
          ),
        ),
        // Camera Switch Flip
        GestureDetector(
          onTap: () => ctrl.switchCamera(),
          child: Icon(
            Icons.cameraswitch_rounded,
            color: Colors.white,
            size: 14.sp,
          ),
        ),
        // Expand Full Screen
        GestureDetector(
          onTap: () => ctrl.resumeStream(),
          child: Icon(
            Icons.fullscreen_rounded,
            color: const Color(0xFF8B9BFF),
            size: 16.sp,
          ),
        ),
        // End Stream Red Button
        GestureDetector(
          onTap: () => _confirmExitStream(context, ctrl),
          child: Icon(
            Icons.power_settings_new_rounded,
            color: Colors.redAccent,
            size: 14.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildViewerControls(BuildContext context, AgoraLiveController ctrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // Expand Full Screen Button
        GestureDetector(
          onTap: () => ctrl.resumeStream(),
          child: Row(
            children: [
              Icon(Icons.fullscreen_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
              SizedBox(width: 3.w),
              Text("Expand", style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        // Leave Button
        GestureDetector(
          onTap: () => _confirmExitStream(context, ctrl),
          child: Container(
            padding: EdgeInsets.all(2.r),
            decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
            child: Icon(Icons.close_rounded, color: Colors.white70, size: 12.sp),
          ),
        ),
      ],
    );
  }

  void _confirmExitStream(BuildContext context, AgoraLiveController ctrl) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          ctrl.isHost.value ? "End Live Stream?" : "Leave Live Stream?",
          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        content: Text(
          ctrl.isHost.value
              ? "Ending the stream will disconnect all viewers."
              : "Are you sure you want to exit the live stream?",
          style: TextStyle(color: Colors.white70, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Get.back();
              ctrl.endStream();
            },
            child: Text(ctrl.isHost.value ? "End" : "Leave", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
