import 'dart:convert';
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/api_client.dart';
import '../../../../core/app_route.dart';
import '../../live_stream/controller/agora_live_controller.dart';

class HomeLivePreviewWidget extends StatefulWidget {
  final String channelName;
  final String fallbackImageUrl;

  const HomeLivePreviewWidget({
    super.key,
    required this.channelName,
    required this.fallbackImageUrl,
  });

  @override
  State<HomeLivePreviewWidget> createState() => _HomeLivePreviewWidgetState();
}

class _HomeLivePreviewWidgetState extends State<HomeLivePreviewWidget> {
  RtcEngine? _engine;
  bool _remoteJoined = false;
  int _remoteUid = -1;
  bool _isLoading = true;
  StreamSubscription? _routeSubscription;

  @override
  void initState() {
    super.initState();
    _initPreviewAgora();
    
    // Listen to custom route stream
    _routeSubscription = AppRoute.routeStream.stream.listen((currentRoute) {
      _handleRouteChange(currentRoute);
    });
  }

  void _handleRouteChange(String currentRoute) {
    if (!mounted) return;
    if (currentRoute != '/main') {
      if (_engine != null) {
        debugPrint("📺 [HomePreview] Navigated away from home route ($currentRoute). Releasing engine.");
        _cleanupPreview();
      }
    } else {
      if (_engine == null) {
        debugPrint("📺 [HomePreview] Returned to home route. Re-initializing engine.");
        _initPreviewAgora();
      }
    }
  }

  Future<void> _initPreviewAgora() async {
    try {
      if (Get.isRegistered<AgoraLiveController>()) {
        final agoraCtrl = Get.find<AgoraLiveController>();
        if (agoraCtrl.isLive.value && agoraCtrl.channelName.value == widget.channelName) {
          debugPrint("📺 [HomePreview] Stream active in AgoraLiveController for ${widget.channelName}. Skipping secondary engine.");
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      }

      final apiClient = Get.find<ApiClient>();
      final response = await apiClient.getData(
        "${ApiUrl.agoraToken}?channelName=${widget.channelName}&uid=0&role=subscriber"
      );
      
      String token = "";
      String appId = "040148b3e0a14154bc4eb74663dabf5f"; // fallback Agora App ID
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final data = body['data'];
          token = data['token'] ?? "";
          appId = data['appId'] ?? appId;
        }
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: appId));
      
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint("📺 [HomePreview] Joined channel: ${connection.channelId}");
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        onUserJoined: (connection, uid, elapsed) {
          debugPrint("📺 [HomePreview] Host joined: $uid");
          if (mounted) {
            setState(() {
              _remoteUid = uid;
              _remoteJoined = true;
            });
          }
        },
        onUserOffline: (connection, uid, reason) {
          if (mounted && uid == _remoteUid) {
            setState(() {
              _remoteUid = -1;
              _remoteJoined = false;
            });
          }
        },
      ));

      await _engine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
      await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
      await _engine!.muteLocalAudioStream(true);
      await _engine!.muteLocalVideoStream(true);
      await _engine!.muteAllRemoteAudioStreams(true); // mute preview audio so it's a silent live preview
      await _engine!.enableVideo();

      await _engine!.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          autoSubscribeAudio: false, // do not subscribe to audio
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      debugPrint("❌ [HomePreview] Error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _routeSubscription?.cancel();
    _cleanupPreview();
    super.dispose();
  }

  Future<void> _cleanupPreview() async {
    try {
      if (_engine != null) {
        await _engine!.leaveChannel();
        _engine = null;
        if (mounted) {
          setState(() {
            _remoteJoined = false;
            _remoteUid = -1;
            _isLoading = true;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ [HomePreview] Cleanup error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget background;
    final String fallback = widget.fallbackImageUrl;
    if (fallback.isNotEmpty && fallback.startsWith('http')) {
      background = Image.network(
        fallback, 
        fit: BoxFit.cover,          
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF161622),
          child: const Center(
            child: Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 48),
          ),
        ),
      );
    } else {
      background = Container(
        color: const Color(0xFF161622),
        child: const Center(
          child: Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 48),
        ),
      );
    }

    if (Get.isRegistered<AgoraLiveController>()) {
      final agoraCtrl = Get.find<AgoraLiveController>();
      if (agoraCtrl.isLive.value && agoraCtrl.channelName.value == widget.channelName && agoraCtrl.engine != null) {
        if (agoraCtrl.isHost.value && agoraCtrl.isLocalVideoReady.value) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(32.r),
            child: SizedBox.expand(
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: agoraCtrl.engine!,
                  canvas: const VideoCanvas(
                    uid: 0,
                    renderMode: RenderModeType.renderModeHidden,
                    mirrorMode: VideoMirrorModeType.videoMirrorModeEnabled,
                    sourceType: VideoSourceType.videoSourceCamera,
                  ),
                  useFlutterTexture: true,
                  useAndroidSurfaceView: false,
                ),
              ),
            ),
          );
        } else if (agoraCtrl.remoteJoined.value && agoraCtrl.remoteUid.value != -1) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(32.r),
            child: SizedBox.expand(
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: agoraCtrl.engine!,
                  canvas: VideoCanvas(
                    uid: agoraCtrl.remoteUid.value,
                    renderMode: RenderModeType.renderModeHidden,
                  ),
                  connection: RtcConnection(channelId: widget.channelName),
                  useFlutterTexture: true,
                  useAndroidSurfaceView: false,
                ),
              ),
            ),
          );
        }
      }
    }

    if (_remoteJoined && _remoteUid != -1 && _engine != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(32.r),
        child: SizedBox.expand(
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine!,
              canvas: VideoCanvas(
                uid: _remoteUid,
                renderMode: RenderModeType.renderModeHidden,
              ),
              connection: RtcConnection(channelId: widget.channelName),
              useFlutterTexture: true,
              useAndroidSurfaceView: false,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: background),
        if (!_isLoading && !_remoteJoined)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8.r,
                        height: 8.r,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        "STREAM ENDED",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
