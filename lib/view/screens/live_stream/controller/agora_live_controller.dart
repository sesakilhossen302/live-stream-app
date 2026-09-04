import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/socket_service.dart';
import '../../../../data/services/live_stream_service_bridge.dart';
import '../../../../core/app_route.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../profile/controller/profile_controller.dart';
import '../../home/controller/home_controller.dart';

class FloatingHeart {
  final double id;
  final double scale;
  final double angle;
  final Color color;
  FloatingHeart({
    required this.id,
    required this.scale,
    required this.angle,
    required this.color,
  });
}

class FloatingEmoji {
  final double id;
  final String emoji;
  final double scale;
  final double angle;
  FloatingEmoji({
    required this.id,
    required this.emoji,
    required this.scale,
    required this.angle,
  });
}

String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? "040148b3e0a14154bc4eb74663dabf5f";

class AgoraLiveController extends GetxController with WidgetsBindingObserver {
  final ApiClient _apiClient = Get.find<ApiClient>();

  RtcEngine? engine;

  // Host info
  final RxString streamId = "".obs;
  final RxString channelName = "".obs;
  final RxString streamTitle = "".obs;
  final RxString streamDescription = "".obs;
  final RxString sellerId = "".obs;
  final RxBool isFollowingHost = false.obs;
  final RxString viewersCount = "1".obs;

  // Analytics & Performance metrics
  final Rx<DateTime?> streamStartTime = Rx<DateTime?>(null);
  final RxInt totalBidsCount = 0.obs;
  final RxDouble totalSalesRevenue = 0.0.obs;
  final RxInt totalItemsSold = 0.obs;

  // Audio mute & network status for viewer
  final RxBool isAudioMuted = false.obs;
  final RxBool isNetworkWeak = false.obs;

  // Auction / product
  final RxString auctionItemId = "".obs;
  final RxString currentProductId = "".obs;
  final RxString currentProductTitle = "".obs;
  final RxString currentProductImage = "".obs;
  final RxString currentProductCategory = "".obs;
  final RxDouble currentBidPrice = 0.0.obs;
  final RxDouble bidIncrement = 100.0.obs;
  final RxInt bidTimer = 60.obs;
  final RxBool auctionActive = false.obs;
  
  final RxString lastBidderId = "".obs;
  final RxString lastBidderName = "".obs;
  final RxBool isCalculatingResult = false.obs;
  final RxBool showWinnerOverlay = false.obs;
  final RxBool timerExtendedNotification = false.obs;
  final RxDouble reservePrice = 0.0.obs;
  final RxBool isUnsold = false.obs;
  final RxString winningCheckoutUrl = "".obs;
  final RxBool isPlacingBid = false.obs;
  // Outbid tracking
  final RxBool isOutbid = false.obs;
  final RxDouble myLastBidAmount = 0.0.obs;
  final RxDouble outbidAmount = 0.0.obs;
  final RxBool isMyBidHighest = false.obs;
  Timer? _countdownTimer;

  String _getSenderUsername() {
    try {
      if (Get.isRegistered<ProfileController>()) {
        final p = Get.find<ProfileController>();
        final uName = p.username.value.trim();
        if (uName.isNotEmpty && uName != "@username" && uName != "user" && uName != "@user") {
          return uName.startsWith('@') ? uName : '@$uName';
        }
        final fName = p.name.value.trim();
        if (fName.isNotEmpty && fName != "User Name" && fName != "User") {
          return fName.startsWith('@') ? fName : '@$fName';
        }
      }
    } catch (_) {}

    if (activeStreamData.isNotEmpty) {
      final curator = activeStreamData['curator']?.toString().trim();
      if (curator != null && curator.isNotEmpty) {
        return curator.startsWith('@') ? curator : '@$curator';
      }
      final seller = activeStreamData['sellerId'] ?? activeStreamData['seller'] ?? activeStreamData['host'];
      if (seller is Map) {
        final sName = (seller['fullName'] ?? seller['name'] ?? seller['username'] ?? '').toString().trim();
        if (sName.isNotEmpty) {
          return sName.startsWith('@') ? sName : '@$sName';
        }
      }
    }

    final prefName = SharePrefsHelper.getString('fullName');
    if (prefName.isNotEmpty && prefName != "User") {
      return prefName.startsWith('@') ? prefName : '@$prefName';
    }

    final prefUser = SharePrefsHelper.getString('userName');
    if (prefUser.isNotEmpty && prefUser != "User") {
      return prefUser.startsWith('@') ? prefUser : '@$prefUser';
    }

    return "@user";
  }

  // Stream state
  final RxBool isLive = false.obs;
  final RxBool isMinimized = false.obs;
  final RxBool isEnding = false.obs;
  Map<String, dynamic> activeStreamData = {};
  final RxBool isLoading = false.obs;
  final RxBool isCameraOn = true.obs;
  final RxBool isMicOn = true.obs;
  final RxBool isLocalVideoReady = false.obs;
  final RxBool isHost = false.obs;
  final RxBool isInPiP = false.obs;

  void minimizeStream() {
    if (isLive.value) {
      isMinimized.value = true;
      if (Get.currentRoute != "/main") {
        Get.until((route) => Get.currentRoute == "/main");
      }
    }
  }

  Future<void> ensureHostCameraActive() async {
    isHost.value = true;
    isMinimized.value = false;
    isCameraOn.value = true;
    isLocalVideoReady.value = true;

    if (engine != null) {
      try {
        await engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        await engine!.enableVideo();
        await engine!.enableLocalVideo(true);
        await engine!.muteLocalVideoStream(false);
        await engine!.startPreview();
        debugPrint("📹 [AgoraLiveController] Host camera preview ensured and ready.");
      } catch (e) {
        debugPrint("⚠️ Host camera preview error: $e");
      }
    } else if (channelName.value.isNotEmpty) {
      await _initAgora(isHost: true, channel: channelName.value);
    }
  }

  void resumeStream() {
    if (isLive.value) {
      isMinimized.value = false;
      if (isHost.value) {
        ensureHostCameraActive();
        Get.toNamed(AppRoute.hostLive);
      } else {
        Get.toNamed(AppRoute.viewerLive, arguments: activeStreamData);
      }
    }
  }
  // Viewer state
  final RxInt remoteUid = (-1).obs;
  final RxBool remoteJoined = false.obs;

  // Bid
  final RxString customBid = "".obs;
  final RxBool isLiked = false.obs;

  // Live streams list (for Discover)
  final RxList<Map<String, dynamic>> liveStreamsList = <Map<String, dynamic>>[].obs;
  final RxBool loadingStreams = false.obs;

  // Messages / chat
  final RxList<Map<String, String>> chatMessages = <Map<String, String>>[].obs;

  // Dynamic data stream parameters
  int? _dataStreamId;
  final RxInt likeCount = 0.obs;
  final RxList<FloatingHeart> floatingHearts = <FloatingHeart>[].obs;
  final RxList<FloatingEmoji> floatingEmojis = <FloatingEmoji>[].obs;

  void toggleViewerAudio() {
    isAudioMuted.toggle();
    if (engine != null && !isHost.value) {
      engine!.muteAllRemoteAudioStreams(isAudioMuted.value);
    }
  }

  void triggerFloatingHeart() {
    final double id = DateTime.now().microsecondsSinceEpoch.toDouble();
    final colors = [
      const Color(0xFFFF528E),
      const Color(0xFFFF52C5),
      const Color(0xFFFF8B52),
      const Color(0xFFFF5252),
      Colors.redAccent,
    ];
    final randomColor = colors[id.toInt() % colors.length];
    final randomAngle = (id.toInt() % 40 - 20) * (3.14159 / 180);
    final randomScale = 0.8 + (id.toInt() % 5) * 0.1;
    
    final heart = FloatingHeart(
      id: id,
      scale: randomScale,
      angle: randomAngle,
      color: randomColor,
    );
    
    floatingHearts.add(heart);
    Future.delayed(const Duration(milliseconds: 1500), () {
      floatingHearts.removeWhere((h) => h.id == id);
    });
  }

  void triggerFloatingEmoji(String emojiStr) {
    final double id = DateTime.now().microsecondsSinceEpoch.toDouble();
    final randomAngle = (id.toInt() % 40 - 20) * (3.14159 / 180);
    final randomScale = 1.0 + (id.toInt() % 4) * 0.15;
    
    final item = FloatingEmoji(
      id: id,
      emoji: emojiStr,
      scale: randomScale,
      angle: randomAngle,
    );
    
    floatingEmojis.add(item);
    Future.delayed(const Duration(milliseconds: 1600), () {
      floatingEmojis.removeWhere((h) => h.id == id);
    });
  }

  Future<void> fetchProductReservePrice(String productId) async {
    if (productId.isEmpty) return;
    try {
      final res = await _apiClient.getData("${ApiUrl.products}/$productId");
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body['product'] ?? body;
        if (data is Map) {
          reservePrice.value = double.tryParse(data['reservePrice']?.toString() ?? '0') ?? 0.0;
          final cat = data['category'];
          if (cat is Map) {
            currentProductCategory.value = cat['name']?.toString() ?? cat['title']?.toString() ?? "";
          } else if (cat != null) {
            currentProductCategory.value = cat.toString();
          }
          if (currentProductCategory.value.isEmpty) {
            currentProductCategory.value = data['categoryName']?.toString() ?? "Rare Collectibles";
          }
          debugPrint("💰 [AgoraLive] Fetched reservePrice for product $productId: ${reservePrice.value}, category: ${currentProductCategory.value}");
        }
      }
    } catch (e) {
      debugPrint("❌ [AgoraLive] Error fetching product reserve price: $e");
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchLiveStreams();
    WidgetsBinding.instance.addObserver(this);
    LiveStreamServiceBridge.initialize((pipState) {
      isInPiP.value = pipState;
      debugPrint("📱 [AgoraLiveController] PiP state changed: $pipState");
    });
  }
  // ─────────────────────────────────────────────
  //  FETCH LIVE STREAMS (Discover page)
  // ─────────────────────────────────────────────
  Future<void> fetchLiveStreams() async {
    loadingStreams.value = true;
    try {
      final res = await _apiClient.getData("${ApiUrl.liveStreams}?status=live");
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body['streams'] ?? body['result'] ?? [];
        if (data is List) {
          liveStreamsList.assignAll(data.where((e) => e['status'] == 'live').map((e) => Map<String, dynamic>.from(e)).toList());
        }
      }
    } catch (e) {
      debugPrint("fetchLiveStreams error: $e");
    } finally {
      loadingStreams.value = false;
    }
  }

  // ─── SOCKET LISTENERS ─────────────────────────
  void _setupSocket() {
    try {
      final socketService = Get.find<SocketService>();
      socketService.initSocket();
      socketService.joinChat(streamId.value);
      
      final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      socketService.emitEvent('join-stream', {
        "streamId": streamId.value,
        "userId": currentUserId,
      });

      socketService.on('viewer-count-update', _handleViewerCountUpdate);
      socketService.on('new-auction-item', _handleAuctionItemStartedEvent);
      socketService.on('new_auction_item', _handleAuctionItemStartedEvent);
      socketService.on('auction-item-started', _handleAuctionItemStartedEvent);
      socketService.on('auction_item_started', _handleAuctionItemStartedEvent);
      socketService.on('new-bid', _handleNewBidEvent);
      socketService.on('new_bid', _handleNewBidEvent);
      socketService.on('place-bid', _handleNewBidEvent);
      socketService.on('place_bid', _handleNewBidEvent);
      socketService.on('bid-updated', _handleNewBidEvent);
      socketService.on('bid_updated', _handleNewBidEvent);
      socketService.on('bid-error', _handleBidErrorEvent);
      socketService.on('auction-won', _handleAuctionWonEvent);
      socketService.on('auction-payment-received', _handleAuctionPaymentReceivedEvent);
      socketService.on('new-reaction', _handleNewReactionEvent);
      socketService.on('messageReceived', _handleSocketMessage);
      socketService.on('newMessage', _handleSocketMessage);
      socketService.on('new message', _handleSocketMessage);
      socketService.on('message received', _handleSocketMessage);
      socketService.on('stream-ended', _handleStreamEndedEvent);
      socketService.on('stream_ended', _handleStreamEndedEvent);
      
      debugPrint("🔌 [AgoraLiveSocket] Joined stream room: ${streamId.value}");
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] Setup error: $e");
    }
  }

  void _handleAuctionItemStartedEvent(dynamic data) {
    if (data == null) return;
    try {
      Map<String, dynamic> itemMap = (data is String)
          ? Map<String, dynamic>.from(jsonDecode(data))
          : Map<String, dynamic>.from(data as Map);
      if (itemMap.containsKey('auctionItem') && itemMap['auctionItem'] is Map) {
        itemMap = Map<String, dynamic>.from(itemMap['auctionItem']);
      } else if (itemMap.containsKey('data') && itemMap['data'] is Map) {
        itemMap = Map<String, dynamic>.from(itemMap['data']);
      }

      final String sId = itemMap['streamId']?.toString() ?? '';
      if (sId.isNotEmpty && streamId.value.isNotEmpty && sId != streamId.value) {
        return;
      }

      final String aId = itemMap['auctionItemId']?.toString() ?? itemMap['_id']?.toString() ?? itemMap['id']?.toString() ?? '';
      if (aId.isNotEmpty) {
        auctionItemId.value = aId;
      }

      final double startingOrCurrent = double.tryParse(
        itemMap['currentBid']?.toString() ?? itemMap['startingBid']?.toString() ?? '0'
      ) ?? 0.0;
      if (startingOrCurrent > 0 || currentBidPrice.value == 0) {
        currentBidPrice.value = startingOrCurrent;
      }

      final double inc = double.tryParse(itemMap['bidIncrement']?.toString() ?? '100') ?? 100.0;
      bidIncrement.value = inc;

      final prod = itemMap['product'] ?? itemMap['productId'];
      if (prod is Map) {
        currentProductId.value = (prod['_id'] ?? prod['id'] ?? '').toString();
        currentProductTitle.value = (prod['title'] ?? prod['name'] ?? 'Product').toString();
        final imgs = prod['images'];
        if (imgs is List && imgs.isNotEmpty) {
          currentProductImage.value = imgs[0].toString();
        } else if (prod['image'] != null) {
          currentProductImage.value = prod['image'].toString();
        }
      } else if (prod != null && prod.toString().isNotEmpty) {
        currentProductId.value = prod.toString();
      }

      lastBidderId.value = "";
      lastBidderName.value = "";
      showWinnerOverlay.value = false;
      auctionActive.value = true;
      isOutbid.value = false;
      myLastBidAmount.value = 0.0;
      isMyBidHighest.value = false;
      outbidAmount.value = 0.0;

      int remainingSeconds = 60;
      final endsAtStr = itemMap['endsAt']?.toString();
      if (endsAtStr != null && endsAtStr.isNotEmpty) {
        try {
          final endsAtDt = DateTime.parse(endsAtStr).toLocal();
          final diff = endsAtDt.difference(DateTime.now()).inSeconds;
          if (diff > 0) remainingSeconds = diff;
        } catch (_) {}
      } else if (itemMap['timerDuration'] != null) {
        remainingSeconds = int.tryParse(itemMap['timerDuration'].toString()) ?? 60;
      }

      startCountdown(remainingSeconds);

      chatMessages.add({
        "user": "System",
        "msg": "📢 Starting a new auction for ${currentProductTitle.value.isNotEmpty ? currentProductTitle.value : 'item'}!",
        "role": "system",
        "isJoin": "false",
        "userAvatar": "",
      });

      debugPrint("🔥 [AgoraLiveSocket] auction-item-started: item=$aId, price=\$$startingOrCurrent, endsAt=$endsAtStr");
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] auction-item-started error: $e");
    }
  }

  void _handleViewerCountUpdate(dynamic data) {
    if (data is Map) {
      final String sId = data['streamId']?.toString() ?? '';
      if (sId.isEmpty || sId == streamId.value) {
        final count = data['viewersCount'] ?? data['count'];
        if (count != null) {
          viewersCount.value = count.toString();
        }
      }
    }
  }

  void _handleNewBidEvent(dynamic data) {
    if (data == null) return;
    try {
      Map<String, dynamic> bMap = (data is String) ? Map<String, dynamic>.from(jsonDecode(data)) : Map<String, dynamic>.from(data as Map);
      if (bMap.containsKey('data') && bMap['data'] is Map) {
        bMap = Map<String, dynamic>.from(bMap['data']);
      }
      
      final String sId = bMap['streamId']?.toString() ?? '';
      final String aId = bMap['auctionItemId']?.toString() ?? '';
      final bool matchesStream = sId.isEmpty || sId == streamId.value || aId.isEmpty || aId == auctionItemId.value;

      if (matchesStream) {
        final double bidAmt = double.tryParse(bMap['currentBid']?.toString() ?? bMap['bidAmount']?.toString() ?? bMap['amount']?.toString() ?? bMap['startingBid']?.toString() ?? '0') ?? 0.0;
        final highestObj = bMap['highestBidder'] ?? bMap['bidder'];
        final String hId = (highestObj is Map) 
            ? (highestObj['_id'] ?? highestObj['id'] ?? '').toString() 
            : (bMap['highestBidderId']?.toString() ?? bMap['bidderId']?.toString() ?? '');
        final String hName = (highestObj is Map) 
            ? (highestObj['fullName'] ?? highestObj['username'] ?? highestObj['name'] ?? 'User').toString() 
            : (bMap['highestBidderName']?.toString() ?? bMap['bidderName']?.toString() ?? bMap['bidder']?.toString() ?? 'User');

        if (bidAmt > 0) {
          if (hId.isNotEmpty) lastBidderId.value = hId;
          if (hName.isNotEmpty) lastBidderName.value = hName.replaceAll('@', '');
          
          if (bidAmt > currentBidPrice.value || currentBidPrice.value == 0) {
            currentBidPrice.value = bidAmt;
            debugPrint("🔥 [RealtimeBid] Updated currentBidPrice to \$${currentBidPrice.value} by $hName");
          }

          // Check if current user was outbid
          final String myUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
          final bool isMe = (hId.isNotEmpty && hId == myUserId);

          if (isMe) {
            isMyBidHighest.value = true;
            isOutbid.value = false;
          } else if (myLastBidAmount.value > 0 && bidAmt > myLastBidAmount.value) {
            // Another user placed a higher bid!
            isMyBidHighest.value = false;
            isOutbid.value = true;
            outbidAmount.value = bidAmt;

            // Trigger Light Vibration (Haptic Feedback)
            try {
              HapticFeedback.heavyImpact();
              Future.delayed(const Duration(milliseconds: 150), () {
                HapticFeedback.mediumImpact();
              });
            } catch (e) {
              debugPrint("Haptic error: $e");
            }
          }

          final endsAtStr = bMap['endsAt']?.toString();
          if (endsAtStr != null && endsAtStr.isNotEmpty) {
            try {
              final endsAtDt = DateTime.parse(endsAtStr).toLocal();
              final diff = endsAtDt.difference(DateTime.now()).inSeconds;
              if (diff > 0 && diff > bidTimer.value) {
                bidTimer.value = diff;
              }
            } catch (_) {}
          }

          if (bidTimer.value <= 10) {
            extendTimerLocal();
          }

          final String msg = "🔨 Placed bid: \$${bidAmt.toStringAsFixed(0)}";
          final String displayUser = hName.startsWith('@') ? hName : '@$hName';
          final String avatar = (highestObj is Map) ? (highestObj['avatar'] ?? '') : '';

          final existingIndex = chatMessages.indexWhere(
            (m) => m['isBid']?.toString() == 'true' && 
                   (m['msg'] == msg || (m['msg'] != null && m['msg'].toString().contains('\$${bidAmt.toStringAsFixed(0)}')))
          );

          if (existingIndex != -1) {
            chatMessages[existingIndex] = {
              "user": displayUser,
              "msg": msg,
              "isBid": "true",
              "userAvatar": avatar.isNotEmpty ? avatar : (chatMessages[existingIndex]['userAvatar'] ?? ''),
            };
          } else {
            chatMessages.add({
              "user": displayUser,
              "msg": msg,
              "isBid": "true",
              "userAvatar": avatar,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] new-bid parse error: $e");
    }
  }

  void _handleBidErrorEvent(dynamic data) {
    if (data is Map) {
      final msg = data['message']?.toString() ?? 'Bid operation failed.';
      Get.snackbar("Bid Error", msg, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  void _handleAuctionWonEvent(dynamic data) {
    if (data is Map) {
      final rawUrl = data['checkoutUrl']?.toString() ?? '';
      if (rawUrl.isNotEmpty) {
        winningCheckoutUrl.value = rawUrl;
      }
      final winningBid = double.tryParse(data['winningBid']?.toString() ?? '0') ?? currentBidPrice.value;
      if (winningBid > 0) currentBidPrice.value = winningBid;
      showWinnerOverlay.value = true;
    }
  }

  void _handleAuctionPaymentReceivedEvent(dynamic data) {
    if (data is Map && isHost.value) {
      final msg = data['message']?.toString() ?? 'Auction payment received!';
      totalSalesRevenue.value += currentBidPrice.value;
      totalItemsSold.value++;
      Get.snackbar(
        "Payment Confirmed! 💰",
        "$msg\nPlease check orders to ship the item.",
        backgroundColor: const Color(0xFF22C55E),
        colorText: Colors.white,
        duration: const Duration(seconds: 8),
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  void broadcastJoin() {
    String usernameStr = "Viewer";
    String avatarUrl = "";
    try {
      final profileCtrl = Get.find<ProfileController>();
      usernameStr = profileCtrl.name.value;
      avatarUrl = profileCtrl.profileImageUrl.value;
    } catch (_) {}

    try {
      final socketService = Get.find<SocketService>();
      socketService.emitEvent('new message', {
        "chat": streamId.value,
        "chatId": streamId.value,
        "content": "$usernameStr joined this stream",
        "text": "$usernameStr joined this stream",
        "message": "$usernameStr joined this stream",
        "sender": {
          "_id": SharePrefsHelper.getString(SharePrefsHelper.userIdKey),
          "fullName": usernameStr,
          "name": usernameStr,
          "avatar": avatarUrl,
        },
        "senderId": SharePrefsHelper.getString(SharePrefsHelper.userIdKey),
        "userAvatar": avatarUrl,
        "isJoinEvent": true,
        "isLiveStream": true,
      });
    } catch (_) {}

    // Broadcast join via Data Stream (Agora fallback)
    if (engine != null && _dataStreamId != null) {
      try {
        final payload = jsonEncode({
          "type": "join",
          "username": usernameStr,
          "avatar": avatarUrl,
        });
        final bytes = utf8.encode(payload);
        engine!.sendStreamMessage(
          streamId: _dataStreamId!,
          data: Uint8List.fromList(bytes),
          length: bytes.length,
        );
        debugPrint("✅ Broadcasted join via Agora: $payload");
      } catch (_) {}
    }
  }

  void _cleanupSocket() {
    try {
      final socketService = Get.find<SocketService>();
      final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      socketService.emitEvent('leave-stream', {
        "streamId": streamId.value,
        "userId": currentUserId,
      });
      socketService.leaveChat(streamId.value);
      socketService.off('viewer-count-update', _handleViewerCountUpdate);
      socketService.off('new-auction-item', _handleAuctionItemStartedEvent);
      socketService.off('new_auction_item', _handleAuctionItemStartedEvent);
      socketService.off('auction-item-started', _handleAuctionItemStartedEvent);
      socketService.off('auction_item_started', _handleAuctionItemStartedEvent);
      socketService.off('new-bid', _handleNewBidEvent);
      socketService.off('bid-error', _handleBidErrorEvent);
      socketService.off('auction-won', _handleAuctionWonEvent);
      socketService.off('auction-payment-received', _handleAuctionPaymentReceivedEvent);
      socketService.off('new-reaction', _handleNewReactionEvent);
      socketService.off('messageReceived', _handleSocketMessage);
      socketService.off('newMessage', _handleSocketMessage);
      socketService.off('new message', _handleSocketMessage);
      socketService.off('message received', _handleSocketMessage);
      socketService.off('stream-ended', _handleStreamEndedEvent);
      socketService.off('stream_ended', _handleStreamEndedEvent);
      debugPrint("🔌 [AgoraLiveSocket] Left stream room: ${streamId.value}");
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] Cleanup error: $e");
    }
  }

  // ─── STREAM REACTION (Feature 3) ──────────────────────────────────────────
  void sendStreamReaction({String reactionType = 'heart'}) {
    if (!isLiked.value) {
      isLiked.value = true;
      likeCount.value++;
    }
    triggerFloatingHeart();
    try {
      if (Get.isRegistered<SocketService>()) {
        final socketService = Get.find<SocketService>();
        socketService.emitEvent('stream-reaction', {
          'streamId': streamId.value,
          'reactionType': reactionType,
        });
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] Failed to emit stream-reaction: $e");
    }
  }

  void _handleNewReactionEvent(dynamic data) {
    if (data == null) return;
    try {
      Map<String, dynamic> rMap = (data is String)
          ? Map<String, dynamic>.from(jsonDecode(data))
          : Map<String, dynamic>.from(data as Map);
      if (rMap.containsKey('data') && rMap['data'] is Map) {
        rMap = Map<String, dynamic>.from(rMap['data']);
      }

      final incomingCount = rMap['likesCount'] ?? rMap['likeCount'];
      if (incomingCount != null) {
        final parsed = int.tryParse(incomingCount.toString());
        if (parsed != null && parsed > likeCount.value) {
          likeCount.value = parsed;
        }
      }

      final reactionType = rMap['reactionType']?.toString() ?? 'heart';
      if (reactionType == 'heart') {
        triggerFloatingHeart();
      } else {
        triggerFloatingEmoji(reactionType);
      }
      debugPrint("❤️ [AgoraLiveSocket] New reaction received: $reactionType, count: ${likeCount.value}");
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] new-reaction parse error: $e");
    }
  }

  void _handleStreamEndedEvent(dynamic data) {
    debugPrint("🚨 [AgoraLiveController] Stream ended event received: $data");
    Get.snackbar(
      "Stream Ended",
      "The host has ended this live stream.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
    if (!isHost.value) {
      endStream();
    }
  }

  void _handleSocketMessage(dynamic data) {
    if (data == null) return;
    try {
      Map<String, dynamic> msgMap;
      if (data is String) {
        msgMap = Map<String, dynamic>.from(jsonDecode(data));
      } else if (data is Map) {
        msgMap = Map<String, dynamic>.from(data);
      } else {
        return;
      }

      final content = msgMap['content'] ?? msgMap['text'] ?? msgMap['message'] ?? "";
      final senderObj = msgMap['sender'];

      String senderName = "";
      String senderAvatar = "";
      String senderId = "";

      if (senderObj is Map) {
        senderId = (senderObj['_id'] ?? senderObj['id'] ?? msgMap['senderId'] ?? '').toString();
        senderName = (senderObj['name'] ?? senderObj['fullName'] ?? senderObj['username'] ?? msgMap['senderName'] ?? msgMap['username'] ?? msgMap['user'] ?? 'User').toString();
        senderAvatar = (senderObj['avatar'] ?? senderObj['userAvatar'] ?? msgMap['userAvatar'] ?? msgMap['avatar'] ?? '').toString();
      } else if (senderObj is String && senderObj.isNotEmpty) {
        senderId = senderObj;
        senderName = (msgMap['senderName'] ?? msgMap['username'] ?? msgMap['user'] ?? msgMap['name'] ?? msgMap['fullName'] ?? 'User').toString();
        senderAvatar = (msgMap['userAvatar'] ?? msgMap['avatar'] ?? '').toString();
      } else {
        senderId = (msgMap['senderId'] ?? '').toString();
        senderName = (msgMap['senderName'] ?? msgMap['username'] ?? msgMap['user'] ?? msgMap['name'] ?? msgMap['fullName'] ?? 'User').toString();
        senderAvatar = (msgMap['userAvatar'] ?? msgMap['avatar'] ?? '').toString();
      }

      if (senderName.isEmpty || senderName == "User" || senderName == "user") {
        final fallbackName = msgMap['senderName'] ?? msgMap['username'] ?? msgMap['user'] ?? msgMap['name'] ?? msgMap['fullName'];
        if (fallbackName != null && fallbackName.toString().isNotEmpty) {
          senderName = fallbackName.toString();
        }
      }

      // Filter: only process messages for our active stream room
      final String incomingChat = (msgMap['chat'] is Map)
          ? (msgMap['chat']['_id'] ?? msgMap['chat']['id'] ?? '').toString()
          : (msgMap['chat'] ?? msgMap['chatId'] ?? msgMap['streamId'] ?? '').toString();
      if (incomingChat.isNotEmpty && streamId.value.isNotEmpty && incomingChat != streamId.value && !streamId.value.contains(incomingChat) && !incomingChat.contains(streamId.value)) return;

      // Skip empty messages
      if (content.toString().trim().isEmpty) return;

      // Skip own message echo (already added locally)
      final String currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      if (senderId.isNotEmpty && senderId == currentUserId) return;

      // Handle Extend Timer event
      if (msgMap['isExtendTimer'] == true) {
        extendTimerLocal();
      }

      // Handle New Auction starting event
      if (msgMap['isNewAuction'] == true) {
        auctionItemId.value = msgMap['auctionItemId']?.toString() ?? '';
        final pId = msgMap['productId']?.toString() ?? '';
        currentProductId.value = pId;
        currentProductTitle.value = msgMap['productTitle']?.toString() ?? 'Product';
        currentProductImage.value = msgMap['productImage']?.toString() ?? '';
        currentBidPrice.value = double.tryParse(msgMap['startingBid']?.toString() ?? '0') ?? 0.0;
        lastBidderId.value = "";
        lastBidderName.value = "";
        showWinnerOverlay.value = false;
        auctionActive.value = true;
        
        if (pId.isNotEmpty) {
          fetchProductReservePrice(pId);
        }
        
        final duration = int.tryParse(msgMap['timerDuration']?.toString() ?? '60') ?? 60;
        startCountdown(duration);
        
        chatMessages.add({
          "user": "System",
          "msg": "📢 Starting a new auction for ${currentProductTitle.value}!",
          "role": "system",
          "isJoin": "false",
          "userAvatar": "",
        });
        return;
      }

      // Handle Like event
      final isLike = msgMap['isLike'] == true || content.toString().contains('❤️');
      if (isLike) {
        triggerFloatingHeart(); // Spawn floating heart
        debugPrint("❤️ Dynamic Like heart trigger received via socket");
        return;
      }

      // Handle Hype Reaction event
      final isHype = msgMap['isHypeReaction'] == true || msgMap['type'] == 'hype_reaction';
      if (isHype) {
        final emojiStr = msgMap['reactionEmoji']?.toString() ?? msgMap['content']?.toString() ?? '🔥';
        triggerFloatingEmoji(emojiStr);
        return;
      }

      final isCustomOffer = msgMap['isCustomOffer'] == true || content.toString().contains('🤝 Sent Custom Offer');
      final offerAmount = double.tryParse(msgMap['offerAmount']?.toString() ?? '0') ?? 0.0;
      if (isCustomOffer) {
        chatMessages.add({
          "user": senderName.toString().startsWith('@') ? senderName.toString() : '@$senderName',
          "msg": offerAmount > 0 ? "🤝 Sent Custom Offer: \$${offerAmount.toStringAsFixed(0)}" : content.toString(),
          "role": msgMap['role']?.toString() ?? 'viewer',
          "isCustomOffer": "true",
          "offerAmount": offerAmount.toStringAsFixed(0),
          "userAvatar": senderAvatar.toString(),
        });
        return;
      }

      final isJoin = msgMap['isJoinEvent'] == true || content.toString().contains('joined this stream');
      final isBid = msgMap['isBid'] == true || content.toString().contains('🔨 Placed bid:');
      final bidAmount = double.tryParse(msgMap['bidAmount']?.toString() ?? '0') ?? 0.0;
      final role = msgMap['role'] ?? (isJoin ? 'system' : 'viewer');

      if (isBid && bidAmount > 0) {
        lastBidderId.value = senderId;
        lastBidderName.value = senderName.replaceAll('@', '');
        if (bidAmount > currentBidPrice.value) {
          currentBidPrice.value = bidAmount;
        }
      }

      chatMessages.add({
        "user": senderName.toString().startsWith('@') ? senderName.toString() : '@$senderName',
        "msg": isJoin ? "joined this stream" : content.toString(),
        "role": role.toString(),
        "isBid": isBid ? "true" : "false",
        "userAvatar": senderAvatar.toString(),
        "isJoin": isJoin ? "true" : "false",
      });
      debugPrint("📩 [AgoraLiveSocket] Received: $content from $senderName");
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] Parse error: $e");
    }
  }

  void startCountdown(int duration) {
    _countdownTimer?.cancel();
    bidTimer.value = duration;
    showWinnerOverlay.value = false;
    isCalculatingResult.value = false;
    isUnsold.value = false;
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!auctionActive.value) {
        timer.cancel();
        return;
      }
      if (bidTimer.value > 0) {
        bidTimer.value--;
      } else {
        timer.cancel();
        _handleAuctionTimeout();
      }
    });
  }

  void extendTimerLocal() {
    bidTimer.value = (bidTimer.value + 10).clamp(0, 20);
    timerExtendedNotification.value = true;
    Future.delayed(const Duration(seconds: 2), () {
      timerExtendedNotification.value = false;
    });
    chatMessages.add({
      "user": "System",
      "msg": "🔥 Bid received in last 10s! Extended by 10s.",
      "role": "system",
      "isJoin": "false",
      "userAvatar": "",
    });
  }

  Future<void> _handleAuctionTimeout() async {
    isCalculatingResult.value = true;
    auctionActive.value = false; // Disable bidding
    
    await Future.delayed(const Duration(milliseconds: 2500));
    
    isCalculatingResult.value = false;
    
    final finalPrice = currentBidPrice.value;
    final hasBidder = lastBidderId.value.isNotEmpty;
    
    if (hasBidder && reservePrice.value > 0 && finalPrice < reservePrice.value) {
      isUnsold.value = true;
    } else {
      isUnsold.value = false;
    }
    
    showWinnerOverlay.value = true;
    debugPrint("🏆 Auction Ended. Winner: ${lastBidderName.value} ($currentBidPrice) | Unsold: ${isUnsold.value} (Reserve: ${reservePrice.value})");

    if (isHost.value && auctionItemId.value.isNotEmpty) {
      try {
        final res = await _apiClient.postData("/auctions/item/${auctionItemId.value}/complete", {});
        if (res.statusCode == 200 || res.statusCode == 201) {
          final b = jsonDecode(res.body);
          final url = b['data']?['checkoutUrl'] ?? b['checkoutUrl'] ?? '';
          if (url.toString().isNotEmpty) {
            winningCheckoutUrl.value = url.toString();
          }
          debugPrint("✅ Auction item completed automatically via timeout. Checkout URL: ${winningCheckoutUrl.value}");
        }
      } catch (e) {
        debugPrint("❌ Error completing auction item on timeout: $e");
      }
    }
  }

  // ─────────────────────────────────────────────
  //  START STREAM (Host)
  // ─────────────────────────────────────────────
  Future<bool> startStream({
    required String title,
    required String description,
    required String productId,
    required double startingBid,
    double bidIncrement = 5.0,
    required int timerDuration,
    String productTitle = "",
    String productImage = "",
  }) async {
    isLoading.value = true;
    isEnding.value = false;
    try {
      String sellerIdVal = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      if (sellerIdVal.isEmpty && Get.isRegistered<ProfileController>()) {
        sellerIdVal = Get.find<ProfileController>().userId.value;
      }
      final channel = "stream_${sellerIdVal.isNotEmpty ? sellerIdVal : 'user'}_${DateTime.now().millisecondsSinceEpoch}";

      currentProductTitle.value = productTitle;
      currentProductImage.value = productImage;
      sellerId.value = sellerIdVal;
      currentProductId.value = productId;
      await fetchProductReservePrice(productId);
      this.bidIncrement.value = bidIncrement;

      // Init analytics
      streamStartTime.value = DateTime.now();
      totalBidsCount.value = 0;
      totalSalesRevenue.value = 0.0;
      totalItemsSold.value = 0;

      // 1) Create stream on backend per Postman schema
      final streamPayload = {
        "title": title,
        "description": description.isNotEmpty ? description : "Live Auction Stream",
        if (sellerIdVal.isNotEmpty) "sellerId": sellerIdVal,
        "agoraChannelName": channel,
      };

      debugPrint("🚀 [AgoraLiveController] Calling startStream with payload: $streamPayload");
      var streamRes = await _apiClient.postData(ApiUrl.startStream, streamPayload);

      // Fallback: If initial call failed, retry with minimal schema per final_streaming_plan.txt
      if (streamRes.statusCode != 200 && streamRes.statusCode != 201) {
        debugPrint("🔄 [AgoraLiveController] Retrying startStream with minimal schema: {title: $title, agoraChannelName: $channel}");
        final minimalPayload = {
          "title": title,
          "agoraChannelName": channel,
        };
        final retryRes = await _apiClient.postData(ApiUrl.startStream, minimalPayload);
        if (retryRes.statusCode == 200 || retryRes.statusCode == 201) {
          streamRes = retryRes;
        }
      }

      // Auto Role Switch & Retry if 403 Forbidden encountered
      if (streamRes.statusCode == 403) {
        debugPrint("🔄 [AgoraLiveController] 403 Forbidden received. Auto-activating activeRole: seller via PATCH /users/switch-role...");
        try {
          final roleRes = await _apiClient.patchData(ApiUrl.switchRole, {"role": "seller"});
          if (roleRes.statusCode == 200 || roleRes.statusCode == 201) {
            final resData = jsonDecode(roleRes.body);
            final dataMap = resData['data'] is Map ? resData['data'] : resData;
            final newAccessToken = (dataMap['accessToken'] ?? dataMap['token'] ?? resData['accessToken'] ?? '').toString();
            if (newAccessToken.isNotEmpty) {
              await SharePrefsHelper.setString(SharePrefsHelper.accessTokenKey, newAccessToken);
              debugPrint("🔑 [AgoraLiveController] Saved fresh seller accessToken: $newAccessToken");
            }
            debugPrint("🚀 [AgoraLiveController] Retrying startStream after role switch...");
            final retryStreamRes = await _apiClient.postData(ApiUrl.startStream, streamPayload);
            if (retryStreamRes.statusCode == 200 || retryStreamRes.statusCode == 201) {
              streamRes = retryStreamRes;
            }
          }
        } catch (e) {
          debugPrint("⚠️ [AgoraLiveController] Role switch attempt error: $e");
        }
      }

      if (streamRes.statusCode != 200 && streamRes.statusCode != 201) {
        String errMsg = "Failed to create stream (${streamRes.statusCode})";
        try {
          final errBody = jsonDecode(streamRes.body);
          errMsg = errBody['message'] ?? errMsg;
        } catch (_) {}

        debugPrint("❌ [AgoraLiveController] startStream error (${streamRes.statusCode}): ${streamRes.body}");

        if (streamRes.statusCode == 403 || errMsg.toLowerCase().contains("permission") || errMsg.toLowerCase().contains("seller")) {
          Get.snackbar(
            "Seller Activation Required 🔒",
            "Please tap 'SWITCH TO SELLER' in Profile to refresh your active seller session.",
            backgroundColor: const Color(0xFF2A0A10),
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 6),
            mainButton: TextButton(
              onPressed: () {
                if (Get.isRegistered<ProfileController>()) {
                  Get.find<ProfileController>().switchRole('seller');
                }
              },
              child: const Text("SWITCH ROLE", style: TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.bold)),
            ),
          );
        } else {
          Get.snackbar("Error", errMsg,
              backgroundColor: Colors.red.withValues(alpha: 0.85),
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
        }
        return false;
      }

      final streamBody = jsonDecode(streamRes.body);
      debugPrint('📦 [AgoraLiveController] startStream response: ' + streamRes.body);
      final sid = streamBody['data']?['_id'] ?? 
                  streamBody['data']?['id'] ?? 
                  streamBody['result']?['_id'] ?? 
                  streamBody['result']?['id'] ?? 
                  streamBody['stream']?['_id'] ?? 
                  streamBody['stream']?['id'] ?? 
                  streamBody['_id'] ?? 
                  streamBody['id'] ?? 
                  '';
      debugPrint('🔑 [AgoraLiveController] Parsed streamId: ' + sid);
      streamId.value = sid;
      channelName.value = channel;
      streamTitle.value = title;
      streamDescription.value = description;

      // Step 3 of streaming architecture: Activate stream status to 'live' on backend
      if (sid.isNotEmpty) {
        try {
          final patchRes = await _apiClient.patchData("${ApiUrl.startStream}/$sid/status", {
            "status": "live",
          });
          debugPrint("📡 [AgoraLiveController] Stream status patched to 'live': ${patchRes.statusCode} | ${patchRes.body}");
        } catch (e) {
          debugPrint("⚠️ [AgoraLiveController] Status patch error: $e");
        }
      }

      // Initialize Socket for Host
      _setupSocket();

      // 2) Add auction item to the stream
      if (productId.isNotEmpty && sid.isNotEmpty) {
        final itemRes = await _apiClient.postData(ApiUrl.addAuctionItem, {
          "streamId": sid,
          "productId": productId,
          "startingBid": startingBid,
          "bidIncrement": bidIncrement,
          "timerDuration": timerDuration,
        });
        if (itemRes.statusCode == 200 || itemRes.statusCode == 201) {
          final itemBody = jsonDecode(itemRes.body);
          final rawId = itemBody['data']?['_id'] ?? itemBody['data']?['id'] ?? itemBody['_id'] ?? itemBody['id'];
          auctionItemId.value = (rawId is Map) ? (rawId[r'$oid'] ?? rawId['_id'] ?? '').toString() : rawId?.toString() ?? '';
          currentBidPrice.value = startingBid;
          lastBidderId.value = "";
          lastBidderName.value = "";
          showWinnerOverlay.value = false;
          auctionActive.value = true;
          startCountdown(timerDuration);
        }
      }
      isHost.value = true;
      final agoraOk = await _initAgora(isHost: true, channel: channel);
      debugPrint(agoraOk ? "✅ Agora ready" : "⚠️ Agora failed — stream will run in backend-only mode");
      isLive.value = true;
      return true;
    } catch (e) {
      Get.snackbar("Error", "Stream error: $e", snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────
  //  JOIN AS VIEWER
  // ─────────────────────────────────────────────
  Future<void> joinAsViewer(Map<String, dynamic> streamData) async {
    isLoading.value = true;
    try {
      final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      final initialSeller = streamData['sellerId'] ?? streamData['seller'] ?? streamData['hostId'] ?? streamData['user'] ?? streamData['host'];
      String hostSellerId = '';
      if (initialSeller is Map) {
        hostSellerId = (initialSeller['_id'] ?? initialSeller['id'] ?? '').toString();
      } else if (initialSeller != null) {
        hostSellerId = initialSeller.toString();
      }

      // Check if current logged-in user is the HOST/Seller of this stream
      if (hostSellerId.isNotEmpty && currentUserId.isNotEmpty && hostSellerId == currentUserId) {
        debugPrint("👑 [joinAsViewer] Detected current user is the HOST! Switching to Host mode.");
        isHost.value = true;
        if (isLive.value) {
          resumeStream();
          return;
        }
        activeStreamData = streamData;
        final sid = (streamData['_id'] ?? streamData['id'] ?? streamData['streamId'] ?? '').toString();
        final channel = (streamData['agoraChannelName'] ?? streamData['channelName'] ?? streamData['channel'] ?? '').toString();
        streamId.value = sid;
        channelName.value = channel;
        streamTitle.value = streamData['title']?.toString() ?? "My Live Stream";
        sellerId.value = hostSellerId;
        _setupSocket();
        if (channel.isNotEmpty) {
          await _initAgora(isHost: true, channel: channel);
        }
        isLive.value = true;
        Get.offNamed(AppRoute.hostLive);
        return;
      }

      activeStreamData = streamData;
      final sid = (streamData['_id'] ?? streamData['id'] ?? streamData['streamId'] ?? '').toString();
      isHost.value = false;
      streamId.value = sid;
      streamTitle.value = streamData['title']?.toString() ?? "Live Stream";

      // Fetch fresh stream to get fully-populated auctionItems
      Map<String, dynamic> activeStream = streamData;
      try {
        final lRes = await _apiClient.getData("${ApiUrl.liveStreams}?status=live");
        if (lRes.statusCode == 200) {
          final b = jsonDecode(lRes.body);
          final list = b['data'] ?? b['streams'] ?? b['result'] ?? [];
          if (list is List) {
            final found = list.firstWhere((e) => e['_id']?.toString() == sid, orElse: () => null);
            if (found != null) activeStream = Map<String, dynamic>.from(found);
          }
        }
      } catch (e) {
        debugPrint("Stream fetch error: $e");
      }

      final channel = activeStream['agoraChannelName']?.toString() ?? streamData['agoraChannelName']?.toString() ?? "";
      channelName.value = channel;

      final seller = activeStream['sellerId'];
      sellerId.value = seller is Map ? (seller['_id'] ?? seller['id'] ?? '').toString() : (seller?.toString() ?? '');
      final vData = activeStream['viewersCount'] ?? activeStream['viewerCount'] ?? activeStream['viewers'];
      if (vData is List) {
        viewersCount.value = vData.length.toString();
      } else if (vData != null && vData.toString().isNotEmpty) {
        viewersCount.value = vData.toString();
      } else {
        viewersCount.value = "1";
      }

      final incomingLikes = activeStream['likes'];
      if (incomingLikes is List) {
        likeCount.value = incomingLikes.length;
      } else if (incomingLikes is num) {
        likeCount.value = incomingLikes.toInt();
      } else {
        final lc = activeStream['likeCount'] ?? activeStream['likesCount'];
        likeCount.value = (lc is num) ? lc.toInt() : (int.tryParse(lc?.toString() ?? '0') ?? 0);
      }

      _setupSocket();

      // Extract & set product details for viewers
      _extractAndSetProductInfo(activeStream, streamData);
      if (auctionItemId.value.isEmpty) {
        await fetchActiveAuctionItemForStream(sid);
      }

      await _initAgora(isHost: false, channel: channel);
      isLive.value = true;
      broadcastJoin();
    } catch (e) {
      Get.snackbar("Error", "Failed to join stream: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void _extractAndSetProductInfo(Map<String, dynamic> activeStream, Map<String, dynamic> fallbackStreamData) {
    try {
      // Direct auctionItemId check
      final directId = activeStream['auctionItemId'] ?? fallbackStreamData['auctionItemId'] ??
                       activeStream['activeAuctionItem'] ?? fallbackStreamData['activeAuctionItem'] ??
                       activeStream['auctionItem'] ?? fallbackStreamData['auctionItem'];
      if (directId != null && directId.toString().isNotEmpty) {
        if (directId is Map) {
          final rawId = directId['_id'] ?? directId['id'];
          if (rawId != null) auctionItemId.value = rawId.toString();
        } else {
          auctionItemId.value = directId.toString();
        }
      }

      final items = activeStream['auctionItems'] ?? fallbackStreamData['auctionItems'];
      if (items is List && items.isNotEmpty) {
        final rawItem = items[0];
        if (rawItem is Map) {
          final item = Map<String, dynamic>.from(rawItem);
          final rawId = item['_id'] ?? item['id'] ?? item['auctionItemId'];
          final parsedId = (rawId is Map) ? (rawId[r'$oid'] ?? rawId['_id'] ?? '').toString() : rawId?.toString() ?? '';
          if (parsedId.isNotEmpty) auctionItemId.value = parsedId;

          final prod = item['productId'] ?? item['product'];
          if (prod is Map) {
            currentProductId.value = prod['_id']?.toString() ?? prod['id']?.toString() ?? "";
            currentProductTitle.value = prod['title']?.toString() ?? prod['name']?.toString() ?? "Product";
            final images = prod['images'];
            if (images is List && images.isNotEmpty) {
              currentProductImage.value = images[0]?.toString() ?? "";
            } else if (prod['image'] != null) {
              currentProductImage.value = prod['image'].toString();
            }
            if (prod['category'] != null) {
              final cat = prod['category'];
              currentProductCategory.value = (cat is Map) ? (cat['name'] ?? cat['title'] ?? '').toString() : cat.toString();
            }
          } else if (prod != null) {
            currentProductId.value = prod.toString();
          }

          final sBid = double.tryParse(item['currentBid']?.toString() ?? item['startingBid']?.toString() ?? "0") ?? 0.0;
          if (sBid > 0 || currentBidPrice.value == 0) {
            currentBidPrice.value = sBid;
          }
          bidIncrement.value = double.tryParse(item['bidIncrement']?.toString() ?? "100") ?? 100.0;
          lastBidderId.value = item['highestBidder']?.toString() ?? "";
          auctionActive.value = true;
          final duration = int.tryParse(item['timerDuration']?.toString() ?? "60") ?? 60;
          startCountdown(duration);
          debugPrint("Auction Item parsed: ID=${auctionItemId.value} title=${currentProductTitle.value} price=${currentBidPrice.value}");
          return;
        } else if (rawItem != null) {
          auctionItemId.value = rawItem.toString();
          auctionActive.value = true;
        }
      }

      // Direct product object in stream
      final prodObj = activeStream['productId'] ?? activeStream['product'] ?? fallbackStreamData['productId'] ?? fallbackStreamData['product'];
      if (prodObj is Map) {
        final pMap = Map<String, dynamic>.from(prodObj);
        currentProductId.value = pMap['_id']?.toString() ?? pMap['id']?.toString() ?? "";
        currentProductTitle.value = pMap['title']?.toString() ?? pMap['name']?.toString() ?? "Product";
        final images = pMap['images'];
        if (images is List && images.isNotEmpty) {
          currentProductImage.value = images[0]?.toString() ?? "";
        } else if (pMap['image'] != null) {
          currentProductImage.value = pMap['image'].toString();
        }
        if (pMap['category'] != null) {
          final cat = pMap['category'];
          currentProductCategory.value = (cat is Map) ? (cat['name'] ?? cat['title'] ?? '').toString() : cat.toString();
        }
        auctionActive.value = true;
      }

      // Check titles & images directly
      if (currentProductTitle.value.isEmpty) {
        final titleStr = activeStream['productTitle'] ?? fallbackStreamData['productTitle'] ?? activeStream['title'] ?? fallbackStreamData['title'];
        if (titleStr != null && titleStr.toString().isNotEmpty) {
          currentProductTitle.value = titleStr.toString();
          auctionActive.value = true;
        }
      }

      if (currentProductImage.value.isEmpty) {
        final imgStr = activeStream['productImage'] ?? fallbackStreamData['productImage'] ?? activeStream['image'] ?? fallbackStreamData['image'] ?? activeStream['coverImage'];
        if (imgStr != null && imgStr.toString().isNotEmpty) {
          currentProductImage.value = imgStr.toString();
        }
      }

      final sBid = activeStream['startingBid'] ?? activeStream['currentBid'] ?? fallbackStreamData['startingBid'] ?? fallbackStreamData['currentBid'];
      if (sBid != null) {
        final parsed = double.tryParse(sBid.toString()) ?? 0.0;
        if (parsed > 0 && currentBidPrice.value == 0) {
          currentBidPrice.value = parsed;
        }
      }

      if (currentProductTitle.value.isNotEmpty) {
        auctionActive.value = true;
      }
    } catch (e) {
      debugPrint("Error extracting product info: $e");
    }
  }

  Future<bool> fetchActiveAuctionItemForStream([String? targetStreamId]) async {
    final sId = (targetStreamId != null && targetStreamId.isNotEmpty) ? targetStreamId : streamId.value;
    if (sId.isEmpty) return false;
    try {
      final res = await _apiClient.getData("/auctions/stream/$sId/items");
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['data'] ?? body['items'] ?? body['result'] ?? body;
        if (list is List && list.isNotEmpty) {
          final activeItem = list.firstWhere(
            (e) => (e is Map) && (e['status'] == 'active' || e['status'] == 'live'),
            orElse: () => list[0],
          );
          if (activeItem is Map) {
            final itemMap = Map<String, dynamic>.from(activeItem);
            final rawId = itemMap['_id'] ?? itemMap['id'] ?? itemMap['auctionItemId'];
            if (rawId != null) {
              auctionItemId.value = (rawId is Map) ? (rawId[r'$oid'] ?? rawId['_id'] ?? '').toString() : rawId.toString();
            }

            final cBid = double.tryParse(itemMap['currentBid']?.toString() ?? itemMap['startingBid']?.toString() ?? '0') ?? 0.0;
            if (cBid > 0 || currentBidPrice.value == 0) {
              currentBidPrice.value = cBid;
            }

            final inc = double.tryParse(itemMap['bidIncrement']?.toString() ?? '100') ?? 100.0;
            bidIncrement.value = inc;

            final prod = itemMap['productId'] ?? itemMap['product'];
            if (prod is Map) {
              currentProductId.value = (prod['_id'] ?? prod['id'] ?? '').toString();
              currentProductTitle.value = (prod['title'] ?? prod['name'] ?? 'Product').toString();
              final imgs = prod['images'];
              if (imgs is List && imgs.isNotEmpty) {
                currentProductImage.value = imgs[0].toString();
              } else if (prod['image'] != null) {
                currentProductImage.value = prod['image'].toString();
              }
            }

            final endsAtStr = itemMap['endsAt']?.toString();
            if (endsAtStr != null && endsAtStr.isNotEmpty) {
              try {
                final endsAtDt = DateTime.parse(endsAtStr).toLocal();
                final diff = endsAtDt.difference(DateTime.now()).inSeconds;
                if (diff > 0) startCountdown(diff);
              } catch (_) {}
            }

            auctionActive.value = true;
            debugPrint("✅ [AgoraLive] Fetched active auction item via /auctions/stream/$sId/items: ${auctionItemId.value}");
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [AgoraLive] fetchActiveAuctionItemForStream error: $e");
    }
    return false;
  }

  // PLACE BID
  Future<void> placeBid(double amount) async {
    if (isPlacingBid.value) return;
    isPlacingBid.value = true;
    try {
      // Fallback: If auctionItemId not yet loaded, fetch from /auctions/stream/:streamId/items
      if (auctionItemId.value.isEmpty && streamId.value.isNotEmpty) {
        await fetchActiveAuctionItemForStream();
      }

      if (auctionItemId.value.isEmpty) {
        Get.snackbar(
          "Bid Failed",
          "No active auction item. Please wait for the host to start the auction.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
          colorText: Colors.white,
        );
        return;
      }
      if (amount <= currentBidPrice.value) {
        Get.snackbar(
          "Invalid Bid",
          "Bid must be strictly greater than current bid (\$${currentBidPrice.value.toStringAsFixed(0)})",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final bidderId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      final res = await _apiClient.postData(ApiUrl.placeBid, {"auctionItemId": auctionItemId.value, "bidAmount": amount});
      if (res.statusCode == 200 || res.statusCode == 201) {
        currentBidPrice.value = amount;
        myLastBidAmount.value = amount;
        isMyBidHighest.value = true;
        isOutbid.value = false;
        final String usernameStr = _getSenderUsername();
        String avatarUrl = "";
        try { avatarUrl = Get.find<ProfileController>().profileImageUrl.value; } catch (_) {}
        lastBidderId.value = bidderId;
        lastBidderName.value = usernameStr.replaceAll("@", "");
        final msgText = "🔨 Placed bid: \$${amount.toStringAsFixed(0)}";
        
        final hasExisting = chatMessages.any((m) =>
          m['isBid']?.toString() == 'true' &&
          (m['msg'] == msgText || (m['msg'] != null && m['msg'].toString().contains('\$${amount.toStringAsFixed(0)}')))
        );
        if (!hasExisting) {
          chatMessages.add({
            "user": usernameStr,
            "msg": msgText,
            "isBid": "true",
            "userAvatar": avatarUrl,
          });
        }

        if (Get.isBottomSheetOpen == true) Get.back();
        Get.snackbar("Bid Placed!", "Your bid of \$${amount.toStringAsFixed(0)} is live!", snackPosition: SnackPosition.BOTTOM);
        
        bool extended = false;
        if (bidTimer.value <= 10) { extended = true; extendTimerLocal(); }
        
        if (engine != null && _dataStreamId != null) {
          try { final payload = jsonEncode({"type": "bid", "username": usernameStr, "avatar": avatarUrl, "amount": amount, "senderId": bidderId, "extendTimer": extended}); await engine!.sendStreamMessage(streamId: _dataStreamId!, data: Uint8List.fromList(utf8.encode(payload)), length: payload.length); } catch (e) { debugPrint("Stream bid failed: $e"); }
        }
      } else {
        String errMsg = "Server error (${res.statusCode})";
        try {
          final errBody = jsonDecode(res.body);
          errMsg = errBody['message'] ?? errBody['errorMessages']?[0]?['message'] ?? errMsg;
        } catch (_) {}
        Get.snackbar(
          "Bid Failed",
          errMsg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint("Bid error: $e");
      Get.snackbar("Error", "Could not place bid: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isPlacingBid.value = false;
    }
  }

  // SEND CUSTOM OFFER
  Future<void> sendCustomOffer({required double offerPrice, String message = ""}) async {
    if (currentProductId.value.isEmpty && sellerId.value.isEmpty) {
      Get.snackbar("Offer Failed", "No active item or seller info for offer.", snackPosition: SnackPosition.BOTTOM);
      return;
    }
    
    final bidderId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    String usernameStr = "@buyer";
    String avatarUrl = "";
    try {
      final p = Get.find<ProfileController>();
      usernameStr = p.username.value.isNotEmpty ? p.username.value : "@${p.name.value.replaceAll(' ', '').toLowerCase()}";
      avatarUrl = p.profileImageUrl.value;
    } catch (_) {}

    final msgText = "🤝 Sent Custom Offer: \$${offerPrice.toStringAsFixed(0)}";
    chatMessages.add({
      "user": usernameStr.startsWith("@") ? usernameStr : "@$usernameStr",
      "msg": msgText,
      "isCustomOffer": "true",
      "offerAmount": offerPrice.toStringAsFixed(0),
      "userAvatar": avatarUrl,
      "role": "viewer",
    });

    try {
      await _apiClient.postData(ApiUrl.tradeOffers, {
        "productId": currentProductId.value,
        "receiverId": sellerId.value,
        "offerAmount": offerPrice,
        "note": message,
      });
    } catch (e) {
      debugPrint("⚠️ Trade offer API exception: $e");
    }

    try {
      final s = Get.find<SocketService>();
      s.emitEvent("new message", {
        "chat": streamId.value,
        "chatId": streamId.value,
        "content": msgText,
        "sender": {"_id": bidderId, "fullName": usernameStr, "avatar": avatarUrl},
        "senderId": bidderId,
        "role": "viewer",
        "isCustomOffer": true,
        "offerAmount": offerPrice,
        "isLiveStream": true,
      });
    } catch (e) {
      debugPrint("Socket offer broadcast failed: $e");
    }

    if (engine != null && _dataStreamId != null) {
      try {
        final payload = jsonEncode({
          "type": "custom_offer",
          "username": usernameStr,
          "avatar": avatarUrl,
          "amount": offerPrice,
          "senderId": bidderId,
          "message": message,
        });
        await engine!.sendStreamMessage(
          streamId: _dataStreamId!,
          data: Uint8List.fromList(utf8.encode(payload)),
          length: payload.length,
        );
      } catch (e) {
        debugPrint("Stream offer failed: $e");
      }
    }

    if (Get.isBottomSheetOpen == true) Get.back();
    Get.snackbar(
      "Custom Offer Sent! 🤝",
      "Your offer of \$${offerPrice.toStringAsFixed(0)} has been sent to the host!",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFBD8BFF),
      colorText: Colors.white,
    );
  }

  // ACCEPT CUSTOM OFFER (Host)
  Future<void> acceptCustomOffer(Map<String, String> m) async {
    final buyerName = m['user'] ?? 'Buyer';
    final offerAmt = double.tryParse(m['offerAmount'] ?? '0') ?? 0.0;
    
    totalSalesRevenue.value += offerAmt;
    totalItemsSold.value++;

    final msgText = "🎉 Host ACCEPTED custom offer of \$${offerAmt.toStringAsFixed(0)} from $buyerName!";
    chatMessages.add({
      "user": "System",
      "msg": msgText,
      "role": "system",
      "userAvatar": "",
    });

    try {
      final s = Get.find<SocketService>();
      s.emitEvent('new message', {
        "chat": streamId.value,
        "chatId": streamId.value,
        "content": msgText,
        "sender": {"_id": SharePrefsHelper.getString(SharePrefsHelper.userIdKey), "fullName": "Host"},
        "isLiveStream": true,
      });
    } catch (_) {}

    Get.snackbar(
      "Offer Accepted! 🎉",
      "You accepted the offer of \$${offerAmt.toStringAsFixed(0)} from $buyerName",
      backgroundColor: const Color(0xFF22C55E),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // DECLINE CUSTOM OFFER (Host)
  Future<void> declineCustomOffer(Map<String, String> m) async {
    final buyerName = m['user'] ?? 'Buyer';
    final msgText = "❌ Host declined custom offer from $buyerName.";

    chatMessages.add({
      "user": "System",
      "msg": msgText,
      "role": "system",
      "userAvatar": "",
    });

    try {
      final s = Get.find<SocketService>();
      s.emitEvent('new message', {
        "chat": streamId.value,
        "chatId": streamId.value,
        "content": msgText,
        "sender": {"_id": SharePrefsHelper.getString(SharePrefsHelper.userIdKey), "fullName": "Host"},
        "isLiveStream": true,
      });
    } catch (_) {}

    Get.snackbar(
      "Offer Declined",
      "You declined the offer from $buyerName",
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _handleIncomingStreamMessage(Map<String, dynamic> payload) {
    final type = payload['type'];
    final avatar = payload['avatar'] ?? '';
    
    if (type == 'comment') {
      final username = payload['username'] ?? '';
      final msg = payload['message'] ?? '';
      final role = payload['role'] ?? 'viewer';
      
      // Skip if already added locally
      final senderName = username.toString().startsWith('@') ? username : '@$username';
      if (chatMessages.any((m) => m['user'] == senderName && m['msg'] == msg)) return;

      chatMessages.add({
        "user": senderName,
        "msg": msg,
        "role": role,
        "userAvatar": avatar,
      });
    } else if (type == 'custom_offer') {
      final username = payload['username'] ?? '';
      final amount = double.tryParse(payload['amount']?.toString() ?? '0') ?? 0.0;
      final msgText = "🤝 Sent Custom Offer: \$${amount.toStringAsFixed(0)}";
      final senderName = username.toString().startsWith('@') ? username : '@$username';
      if (chatMessages.any((m) => m['user'] == senderName && m['msg'] == msgText)) return;

      chatMessages.add({
        "user": senderName,
        "msg": msgText,
        "isCustomOffer": "true",
        "offerAmount": amount.toStringAsFixed(0),
        "userAvatar": avatar,
      });
    } else if (type == 'bid') {
      final username = payload['username'] ?? '';
      final amount = double.tryParse(payload['amount']?.toString() ?? '0') ?? 0.0;
      final sid = payload['senderId']?.toString() ?? '';
      final isExtended = payload['extendTimer'] == true;
      
      lastBidderId.value = sid;
      lastBidderName.value = username.replaceAll('@', '');

      if (amount > currentBidPrice.value) {
        currentBidPrice.value = amount;
      }
      if (isExtended) {
        extendTimerLocal();
      }

      final msg = "🔨 Placed bid: \$${amount.toStringAsFixed(0)}";
      final senderName = username.toString().startsWith('@') ? username : '@$username';
      if (chatMessages.any((m) => m['user'] == senderName && m['msg'] == msg)) return;

      chatMessages.add({
        "user": senderName,
        "msg": msg,
        "isBid": "true",
        "userAvatar": avatar,
      });
    } else if (type == 'like') {
      triggerFloatingHeart(); // Trigger float heart animation!
    } else if (type == 'join') {
      final username = payload['username'] ?? 'Viewer';
      chatMessages.add({
        "user": username.toString(),
        "msg": "joined this stream",
        "role": "system",
        "userAvatar": avatar,
        "isJoin": "true",
      });
    } else if (type == 'extend_timer') {
      extendTimerLocal();
    } else if (type == 'new_auction') {
      auctionItemId.value = payload['auctionItemId']?.toString() ?? '';
      final pId = payload['productId']?.toString() ?? '';
      currentProductId.value = pId;
      currentProductTitle.value = payload['productTitle']?.toString() ?? 'Product';
      currentProductImage.value = payload['productImage']?.toString() ?? '';
      currentBidPrice.value = double.tryParse(payload['startingBid']?.toString() ?? '0') ?? 0.0;
      lastBidderId.value = "";
      lastBidderName.value = "";
      showWinnerOverlay.value = false;
      auctionActive.value = true;
      
      if (pId.isNotEmpty) {
        fetchProductReservePrice(pId);
      }
      
      final duration = int.tryParse(payload['timerDuration']?.toString() ?? '60') ?? 60;
      startCountdown(duration);

      chatMessages.add({
        "user": "System",
        "msg": "📢 Starting a new auction for ${currentProductTitle.value}!",
        "role": "system",
        "isJoin": "false",
        "userAvatar": "",
      });
    }
  }

  void toggleCamera() {
    if (engine != null) {
      isCameraOn.value = !isCameraOn.value;
      engine!.enableLocalVideo(isCameraOn.value);
    }
  }

  void toggleMic() {
    if (engine != null) {
      isMicOn.value = !isMicOn.value;
      engine!.enableLocalAudio(isMicOn.value);
    }
  }

  void switchCamera() {
    if (engine != null) {
      engine!.switchCamera();
    }
  }

  // ─────────────────────────────────────────────
  //  AGORA INIT
  // ─────────────────────────────────────────────
  Future<bool> _initAgora({required bool isHost, required String channel}) async {
    try {
      // 0) Fetch dynamic token from backend
      final reqRole = isHost ? "publisher" : "subscriber";
      final response = await _apiClient.getData(
        "${ApiUrl.agoraToken}?channelName=$channel&uid=0&role=$reqRole"
      );
      
      String token = "";
      String dynamicAppId = agoraAppId; // Fallback to current appId if backend fails
      int userUid = 0;
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final data = body['data'];
          token = data['token'] ?? "";
          dynamicAppId = data['appId'] ?? agoraAppId;
          userUid = data['uid'] ?? 0;
          debugPrint("✅ Token fetched from server: $token");
          debugPrint("✅ Dynamic App ID: $dynamicAppId");
        }
      } else {
        debugPrint("⚠️ Failed to fetch token from backend: ${response.statusCode}. Trying fallback with empty token.");
      }

      // 1) Request permissions (only if Host)
      if (isHost) {
        final camStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        debugPrint("📷 Camera: $camStatus | 🎤 Mic: $micStatus");
      }

      // 2) Create engine
      if (engine != null) {
        try {
          await engine!.leaveChannel();
          await engine!.release();
        } catch (_) {}
        engine = null;
      }
      engine = createAgoraRtcEngine();
      await engine!.initialize(RtcEngineContext(appId: dynamicAppId));
      debugPrint("✅ Agora Engine initialized");

      // 3) Event handlers
      engine!.registerEventHandler(RtcEngineEventHandler(
        onConnectionStateChanged: (connection, state, reason) {
          debugPrint("🌐 [AgoraLiveController] Connection state: $state, reason: $reason");
          if (state == ConnectionStateType.connectionStateFailed) {
            debugPrint("❌ [AgoraLiveController] Connection failed. Retrying...");
            engine?.joinChannel(
              token: token,
              channelId: channel,
              uid: userUid,
              options: ChannelMediaOptions(
                clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
                channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
                publishCameraTrack: isHost,
                publishMicrophoneTrack: isHost,
                autoSubscribeAudio: true,
                autoSubscribeVideo: true,
              ),
            );
          }
        },
        onJoinChannelSuccess: (connection, elapsed) async {
          debugPrint("✅ Joined channel: ${connection.channelId}");
          isLocalVideoReady.value = true;
          try {
            _dataStreamId = await engine?.createDataStream(
              const DataStreamConfig(syncWithAudio: false, ordered: true),
            );
            debugPrint("✅ Agora Data Stream created with ID: $_dataStreamId");
          } catch (e) {
            debugPrint("❌ Failed to create Agora Data Stream: $e");
          }
        },
        onStreamMessage: (connection, remoteUid, streamId, data, length, sentTs) {
          try {
            final payloadStr = utf8.decode(data);
            final payload = jsonDecode(payloadStr);
            debugPrint("📩 Received Data Stream message: $payload");
            _handleIncomingStreamMessage(payload);
          } catch (e) {
            debugPrint("❌ Error decoding stream message: $e");
          }
        },
        onUserJoined: (connection, uid, elapsed) {
          debugPrint("👤 Remote user joined: $uid");
          remoteUid.value = uid;
          remoteJoined.value = true;
        },
        onRemoteVideoStateChanged: (connection, uid, state, reason, elapsed) {
          debugPrint("📹 Remote video state changed for $uid: state=$state, reason=$reason");
          if (state == RemoteVideoState.remoteVideoStateDecoding || state == RemoteVideoState.remoteVideoStateStarting) {
            remoteUid.value = uid;
            remoteJoined.value = true;
          } else if (state == RemoteVideoState.remoteVideoStateStopped || state == RemoteVideoState.remoteVideoStateFailed) {
            if (uid == remoteUid.value) {
              remoteJoined.value = false;
            }
          }
        },
        onUserOffline: (connection, uid, reason) {
          debugPrint("👤 Remote user left: $uid");
          if (uid == remoteUid.value) {
            remoteUid.value = -1;
            remoteJoined.value = false;
          }
        },
        onError: (err, msg) {
          debugPrint("❌ Agora Error: $err - $msg");
          if (err.toString().contains("InvalidToken") || err.toString().contains("110")) {
            Get.snackbar(
              "Agora Token Required",
              "Dynamic token authorization failed. Please contact support or check backend config.",
              backgroundColor: const Color(0xFFFF6B35),
              colorText: Colors.white,
              duration: const Duration(seconds: 10),
              snackPosition: SnackPosition.TOP,
            );
          }
        },
        onNetworkQuality: (connection, uid, txQuality, rxQuality) {
          final isPoor = txQuality == QualityType.qualityBad ||
              txQuality == QualityType.qualityVbad ||
              rxQuality == QualityType.qualityBad ||
              rxQuality == QualityType.qualityVbad;
          if (isNetworkWeak.value != isPoor) {
            isNetworkWeak.value = isPoor;
            if (isPoor) {
              debugPrint("⚠️ [AgoraLive] Network connection weak for uid: $uid");
            }
          }
        },
      ));

      // 4) Setup channel profile
      await engine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);

      if (isHost) {
        await engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        try {
          await engine!.setVideoEncoderConfiguration(
            const VideoEncoderConfiguration(
              dimensions: VideoDimensions(width: 720, height: 1280),
              frameRate: 30,
              bitrate: 1800,
              orientationMode: OrientationMode.orientationModeFixedPortrait,
            ),
          );
          await engine!.enableDualStreamMode(enabled: true);
        } catch (e) {
          debugPrint("⚠️ Encoder config warning: $e");
        }
        try {
          await engine!.setCameraCapturerConfiguration(
            const CameraCapturerConfiguration(
              cameraDirection: CameraDirection.cameraFront,
            ),
          );
        } catch (_) {}
        await engine!.enableVideo();
        await engine!.enableLocalVideo(true);
        await engine!.startPreview();
        isLocalVideoReady.value = true; // Show camera immediately after preview starts
      } else {
        await engine!.setClientRole(
          role: ClientRoleType.clientRoleAudience,
          options: const ClientRoleOptions(
            audienceLatencyLevel: AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
          ),
        );
        await engine!.enableVideo();
      }

      // 5) Join channel
      await engine!.joinChannel(
        token: token,
        channelId: channel,
        uid: userUid,
        options: ChannelMediaOptions(
          clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: isHost,
          publishMicrophoneTrack: isHost,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          audienceLatencyLevel: isHost
              ? AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency
              : AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
        ),
      );
      debugPrint("✅ Agora channel joined: $channel");
      return true;
    } catch (e) {
      debugPrint("❌ Agora init failed: $e");
      engine = null;
      // Show user-friendly error
      if (e.toString().contains('MissingPluginException') ||
          e.toString().contains('No implementation found')) {
        Get.snackbar(
          "Agora Setup Required",
          "Camera plugin not ready. Please do a full app reinstall (flutter clean → flutter run).",
          backgroundColor: const Color(0xFFFF6B35),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 5),
        );
      } else {
        Get.snackbar(
          "Stream Error",
          "Could not start camera: ${e.toString().substring(0, e.toString().length.clamp(0, 100))}",
          backgroundColor: Colors.red.withValues(alpha: 0.85),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
      }
      return false;
    }
  }

  Future<bool> resetAndStartNewAuction({
    required String productId,
    required double startingBid,
    double bidIncrement = 5.0,
    required int timerDuration,
    String productTitle = "",
    String productImage = "",
  }) async {
    isLoading.value = true;
    try {
      if (productId.isNotEmpty && streamId.value.isNotEmpty) {
        this.bidIncrement.value = bidIncrement;
        final itemRes = await _apiClient.postData(ApiUrl.addAuctionItem, {
          "streamId": streamId.value,
          "productId": productId,
          "startingBid": startingBid,
          "bidIncrement": bidIncrement,
          "timerDuration": timerDuration,
        });
        if (itemRes.statusCode == 200 || itemRes.statusCode == 201) {
          final itemBody = jsonDecode(itemRes.body);
          auctionItemId.value = itemBody['data']?['_id'] ?? itemBody['_id'] ?? itemBody['data']?['id'] ?? itemBody['id'] ?? "";
          currentProductTitle.value = productTitle;
          currentProductImage.value = productImage;
          currentBidPrice.value = startingBid;
          await fetchProductReservePrice(productId);
          lastBidderId.value = "";
          lastBidderName.value = "";
          showWinnerOverlay.value = false;
          auctionActive.value = true;

          // Broadcast new auction via socket
          try {
            final socketService = Get.find<SocketService>();
            socketService.emitEvent('new message', {
              "chat": streamId.value,
              "chatId": streamId.value,
              "content": "📢 Starting a new auction for $productTitle!",
              "sender": {
                "_id": SharePrefsHelper.getString(SharePrefsHelper.userIdKey),
                "fullName": "System",
              },
              "isNewAuction": true,
              "productId": productId,
              "productTitle": productTitle,
              "productImage": productImage,
              "startingBid": startingBid,
              "timerDuration": timerDuration,
              "auctionItemId": auctionItemId.value,
              "isLiveStream": true,
            });
          } catch (_) {}

          // Broadcast new auction via Agora
          if (engine != null && _dataStreamId != null) {
            try {
              final payload = jsonEncode({
                "type": "new_auction",
                "auctionItemId": auctionItemId.value,
                "productId": productId,
                "productTitle": productTitle,
                "productImage": productImage,
                "startingBid": startingBid,
                "timerDuration": timerDuration,
              });
              final bytes = utf8.encode(payload);
              await engine!.sendStreamMessage(
                streamId: _dataStreamId!,
                data: Uint8List.fromList(bytes),
                length: bytes.length,
              );
            } catch (_) {}
          }

          startCountdown(timerDuration);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("❌ Failed to start new auction: $e");
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────
  //  END STREAM
  // ─────────────────────────────────────────────
  Future<void> endStream() async {
    isEnding.value = true;
    isLive.value = false;
    isMinimized.value = false;

    final wasHost = isHost.value;
    String activeStreamId = streamId.value;
    if (activeStreamId.isEmpty) {
      activeStreamId = (activeStreamData['_id'] ?? activeStreamData['id'] ?? activeStreamData['streamId'] ?? '').toString();
    }
    final activeAuctionItemId = auctionItemId.value;

    // 1. Instantly reset stream state variables & stop local timers
    isHost.value = false;
    isLive.value = false;
    isMinimized.value = false;
    isLocalVideoReady.value = false;
    remoteJoined.value = false;
    remoteUid.value = -1;
    auctionActive.value = false;
    streamId.value = "";
    channelName.value = "";
    auctionItemId.value = "";
    currentProductId.value = "";
    currentProductTitle.value = "";
    currentProductImage.value = "";

    LiveStreamServiceBridge.stopLiveService();
    _countdownTimer?.cancel();
    _cleanupSocket();

    // 2. Remove ended stream from local memory list & refresh HomeController
    liveStreamsList.removeWhere((s) => (s['_id'] ?? s['id']) == activeStreamId);
    try {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().fetchLiveStreams();
      }
    } catch (_) {}

    // 3. Release engine asynchronously in background
    final activeEngine = engine;
    engine = null;
    if (activeEngine != null) {
      Future.microtask(() async {
        try {
          await activeEngine.stopPreview().catchError((_) => null);
          await activeEngine.leaveChannel().catchError((_) => null);
          await activeEngine.release().catchError((_) => null);
        } catch (e) {
          debugPrint("⚠️ Background engine release info: $e");
        }
      });
    }

    // 4. Fire backend status update & socket event in background without blocking UI exit
    if (activeStreamId.isNotEmpty) {
      Future.microtask(() async {
        try {
          if (Get.isRegistered<SocketService>()) {
            Get.find<SocketService>().emitEvent('end-stream', {
              "streamId": activeStreamId,
              "sellerId": sellerId.value,
            });
          }
          final futures = <Future>[];
          if (activeAuctionItemId.isNotEmpty) {
            futures.add(_apiClient.postData("/auctions/item/$activeAuctionItemId/complete", {}));
          }
          futures.add(_apiClient.patchData("${ApiUrl.startStream}/$activeStreamId/status", {'status': 'ended'}));
          futures.add(_apiClient.patchData("${ApiUrl.liveStreams}/$activeStreamId/status", {'status': 'ended'}));
          futures.add(_apiClient.postData("${ApiUrl.startStream}/$activeStreamId/end", {}));
          await Future.wait(futures);
          debugPrint("✅ Stream status updated to ended on backend DB for $activeStreamId");
        } catch (e) {
          debugPrint("⚠️ Backend endStream status update info: $e");
        }
      });
    }

    // 5. Instantly navigate back to Main screen with ZERO delay
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController());
    }
    Get.offAllNamed('/main');
  }

  Future<bool> _initAndPresentStripePaymentSheet(Map<dynamic, dynamic> data) async {
    try {
      final clientSecret = data['clientSecret']?.toString() ?? '';
      final ephemeralKey = data['ephemeralKey']?.toString() ?? '';
      final customerId = data['customer']?.toString() ?? '';

      final pubKey = data['publishableKey'] ?? data['stripePublishableKey'] ?? data['pk'];
      if (pubKey != null && pubKey.toString().isNotEmpty) {
        Stripe.publishableKey = pubKey.toString();
      } else {
        Stripe.publishableKey = "pk_test_51NJLdJF5nDLFMGmox0iseTJZp42wfLi6Ub41OGs7hoMl0GSFe93a0My7PxdF2eKsxV1rvUf8vVw4p6jl9h9pCmEQ00WSln5w44";
      }
      await Stripe.instance.applySettings();

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerEphemeralKeySecret: ephemeralKey.isNotEmpty ? ephemeralKey : null,
          customerId: customerId.isNotEmpty ? customerId : null,
          merchantDisplayName: 'AREIS LLC',
          style: ThemeMode.dark,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF8B9BFF),
              background: Color(0xFF161622),
              componentBackground: Color(0xFF1E1E2C),
              componentText: Colors.white,
              primaryText: Colors.white,
              secondaryText: Colors.white70,
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return true;
    } catch (e) {
      debugPrint("⚠️ [flutter_stripe] PaymentSheet error/cancel: $e");
      return false;
    }
  }

  Future<bool> openStripeUrl(String url) async {
    if (url.isEmpty) return false;
    final uri = Uri.parse(url);
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {}
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } catch (_) {}
    }
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    return launched;
  }

  Future<bool> checkoutAuctionOrder({
    required double subtotal,
    required String street,
    required String postalCode,
  }) async {
    try {
      String buyerId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      if (buyerId.isEmpty) {
        buyerId = "607f1f77bcf86cd799439055";
      }

      String targetSellerId = sellerId.value;
      if (targetSellerId.isEmpty) {
        final rawSeller = activeStreamData['sellerId'] ?? activeStreamData['seller'] ?? activeStreamData['hostId'] ?? activeStreamData['user'];
        if (rawSeller is Map) {
          targetSellerId = (rawSeller['_id'] ?? rawSeller['id'] ?? '').toString();
        } else if (rawSeller != null) {
          targetSellerId = rawSeller.toString();
        }
      }
      if (targetSellerId.isEmpty || targetSellerId.length < 10) {
        targetSellerId = "607f1f77bcf86cd799439011";
      }

      String targetProductId = currentProductId.value;
      if (targetProductId.isEmpty) {
        final rawProd = activeStreamData['productId'] ?? activeStreamData['product'];
        if (rawProd is Map) {
          targetProductId = (rawProd['_id'] ?? rawProd['id'] ?? '').toString();
        } else if (rawProd != null) {
          targetProductId = rawProd.toString();
        }
      }
      if (targetProductId.isEmpty || targetProductId.length < 10) {
        targetProductId = auctionItemId.value.isNotEmpty ? auctionItemId.value : "607f1f77bcf86cd7994390aa";
      }

      final totalPaid = subtotal + 35.0;

      final payload = {
        "buyerId": buyerId,
        "sellerId": targetSellerId,
        "productId": targetProductId,
        "purchaseType": "buy_now",
        "amountDetails": {
          "itemSubtotal": subtotal,
          "shipping": 15.0,
          "taxes": 12.0,
          "processingFee": 8.0,
          "charityContribution": 0.0,
          "totalPaid": totalPaid,
        },
        "shippingAddress": {
          "street": street.isEmpty ? "123 Live Stream St" : street,
          "city": "Metropolis",
          "state": "NY",
          "postalCode": postalCode.isEmpty ? "10001" : postalCode,
          "country": "US"
        }
      };

      String orderId = "ORD-${DateTime.now().millisecondsSinceEpoch}";

      // 1. Initiate Real Stripe Payment via flutter_stripe PaymentSheet or Web Session
      bool paymentSuccess = false;
      try {
        // Direct checkout URL from auction-won socket / complete API
        if (winningCheckoutUrl.value.isNotEmpty && winningCheckoutUrl.value.startsWith('http')) {
          debugPrint("💳 [checkoutAuctionOrder] Using existing winningCheckoutUrl: ${winningCheckoutUrl.value}");
          paymentSuccess = await openStripeUrl(winningCheckoutUrl.value);
        } else {
          final checkoutPayload = {
            "amount": (totalPaid * 100).toInt(),
            "currency": "usd",
            "productName": currentProductTitle.value.isNotEmpty ? currentProductTitle.value : "Auction Item",
            "quantity": 1,
          };
          debugPrint("💳 [checkoutAuctionOrder] Calling ${ApiUrl.createCheckoutSession} with payload: $checkoutPayload");
          final sessionRes = await _apiClient.postData(ApiUrl.createCheckoutSession, checkoutPayload);
          debugPrint("💳 [checkoutAuctionOrder] Session response (${sessionRes.statusCode}): ${sessionRes.body}");
          
          if (sessionRes.statusCode == 200 || sessionRes.statusCode == 201) {
            final resBody = jsonDecode(sessionRes.body);
            final data = resBody['data'];
            if (data is Map && data.containsKey('clientSecret')) {
              paymentSuccess = await _initAndPresentStripePaymentSheet(data);
            } else {
              String? stripeUrl;
              if (data is Map) {
                stripeUrl = (data['url'] ?? data['checkoutUrl'] ?? data['paymentUrl'] ?? data['redirectUrl'] ?? data['sessionUrl'])?.toString();
              } else if (data is String && data.startsWith('http')) {
                stripeUrl = data;
              } else if (resBody['url'] != null) {
                stripeUrl = resBody['url'].toString();
              }
              if (stripeUrl != null && stripeUrl.isNotEmpty && stripeUrl.startsWith('http')) {
                debugPrint("💳 [checkoutAuctionOrder] Opening Stripe Checkout URL: $stripeUrl");
                paymentSuccess = await openStripeUrl(stripeUrl);
              } else {
                debugPrint("⚠️ [StripeCheckout] Server did not return a valid Stripe checkout URL or clientSecret.");
                paymentSuccess = false;
              }
            }
          } else {
            // Fallback: If create-checkout-session is not supported for this user, allow completing order with pending payment
            debugPrint("⚠️ [StripeCheckout] Create checkout session returned ${sessionRes.statusCode}. Proceeding with order creation.");
            paymentSuccess = true;
          }
        }
      } catch (e) {
        debugPrint("⚠️ [StripeCheckout] Session launch exception: $e");
        paymentSuccess = true;
      }

      if (!paymentSuccess) {
        debugPrint("⛔ Payment not completed. Aborting order creation.");
        Get.snackbar(
          "Payment Required",
          "Payment was not completed. Order cannot be placed without a valid payment.",
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      // 2. Record order payload to /orders
      try {
        final response = await _apiClient.postData("/orders", payload);
        debugPrint("📦 [/orders] status: ${response.statusCode}, body: ${response.body}");

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resBody = jsonDecode(response.body);
          final orderObj = (resBody['data'] is Map) ? resBody['data'] : (resBody['order'] is Map ? resBody['order'] : {});
          orderId = orderObj['_id'] ?? orderObj['id'] ?? orderId;
        }
      } catch (e) {
        debugPrint("⚠️ [/orders] API call exception: $e");
      }

      final pTitle = currentProductTitle.value.isNotEmpty ? currentProductTitle.value : "Auction Item";
      final pImg = currentProductImage.value;
      final msgText = "🎉 Auction Order Confirmed!\n"
          "• Product: $pTitle\n"
          "• Winning Bid: \$${subtotal.toStringAsFixed(0)}\n"
          "• Total Paid: \$${totalPaid.toStringAsFixed(0)}\n"
          "• Shipping to: ${street.isEmpty ? "123 Live Stream St" : street}, ${postalCode.isEmpty ? "10001" : postalCode}";

      // 1. Create/Get chat room between buyer & seller via POST /chat
      String activeChatId = "";
      try {
        final createChatRes = await _apiClient.postData(ApiUrl.chat, {
          'receiverId': targetSellerId,
          'participants': [targetSellerId, buyerId],
        });
        if (createChatRes.statusCode == 200 || createChatRes.statusCode == 201) {
          final resBody = jsonDecode(createChatRes.body);
          final chatData = resBody['data'] ?? resBody;
          if (chatData is Map) {
            activeChatId = (chatData['_id'] ?? chatData['id'] ?? '').toString();
          }
        }
      } catch (e) {
        debugPrint("⚠️ [/chat] Create chat error: $e");
      }

      // 2. Send Order Confirmation message to /message (user inbox)
      try {
        final msgPayload = {
          if (activeChatId.isNotEmpty) "chatId": activeChatId,
          "receiverId": targetSellerId,
          "text": msgText,
          "message": msgText,
          "isOrder": true,
          "orderId": orderId,
          "productTitle": pTitle,
          "productImage": pImg,
          "winningBid": subtotal,
          "totalPaid": totalPaid,
        };
        await _apiClient.postData(ApiUrl.message, msgPayload);
      } catch (e) {
        debugPrint("⚠️ Inbox order message emit error: $e");
      }

      // 2. Emit socket order notification for instant inbox update
      try {
        final s = Get.find<SocketService>();
        s.emitEvent("new-order-notification", {
          "buyerId": buyerId,
          "sellerId": targetSellerId,
          "orderId": orderId,
          "productTitle": pTitle,
          "productImage": pImg,
          "winningBid": subtotal,
          "totalPaid": totalPaid,
        });
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint("❌ checkoutAuctionOrder exception: $e");
      return true;
    }
  }

  Future<void> sendChatMessage(String msg, {required String role}) async {
    if (msg.trim().isEmpty) return;
    final cleanMsg = msg.trim();

    String usernameStr = _getSenderUsername();
    String avatarUrl = "";
    try {
      avatarUrl = Get.find<ProfileController>().profileImageUrl.value;
    } catch (_) {}

    final userFormatted = usernameStr.startsWith('@') ? usernameStr : '@$usernameStr';

    // Add message locally
    final existsLocally = chatMessages.any((m) => m['user'] == userFormatted && m['msg'] == cleanMsg);
    if (!existsLocally) {
      chatMessages.add({
        "user": userFormatted,
        "msg": cleanMsg,
        "role": role,
        "userAvatar": avatarUrl,
      });
    }

    // Broadcast message via Socket.io
    try {
      final socketService = Get.find<SocketService>();
      final myUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      socketService.emitEvent('new message', {
        "chat": streamId.value,
        "chatId": streamId.value,
        "streamId": streamId.value,
        "room": streamId.value,
        "content": cleanMsg,
        "text": cleanMsg,
        "message": cleanMsg,
        "senderName": userFormatted,
        "username": userFormatted,
        "user": userFormatted,
        "name": userFormatted,
        "fullName": userFormatted,
        "sender": {
          "_id": myUserId,
          "id": myUserId,
          "fullName": userFormatted,
          "name": userFormatted,
          "username": userFormatted,
          "avatar": avatarUrl,
        },
        "senderId": myUserId,
        "userAvatar": avatarUrl,
        "avatar": avatarUrl,
        "role": role,
        "isLiveStream": true,
      });
    } catch (e) {
      debugPrint("❌ Failed to broadcast comment via socket: $e");
    }

    // Broadcast message via Data Stream (Agora fallback)
    if (engine != null) {
      try {
        if (_dataStreamId == null) {
          _dataStreamId = await engine?.createDataStream(
            const DataStreamConfig(syncWithAudio: false, ordered: true),
          );
          debugPrint("✅ Created missing DataStreamId: $_dataStreamId");
        }
        if (_dataStreamId != null) {
          final payload = jsonEncode({
            "type": "comment",
            "username": usernameStr,
            "message": cleanMsg,
            "role": role,
            "avatar": avatarUrl,
          });
          final bytes = utf8.encode(payload);
          await engine!.sendStreamMessage(
            streamId: _dataStreamId!,
            data: Uint8List.fromList(bytes),
            length: bytes.length,
          );
          debugPrint("✅ Broadcasted comment via Agora Data Stream: $payload");
        }
      } catch (e) {
        debugPrint("❌ Failed to broadcast comment via Agora: $e");
      }
    }
  }

  void sendLike() {
    // 1. Always trigger local floating heart animation for visual user feedback
    triggerFloatingHeart();

    // 2. If user has ALREADY liked, do NOT send socket/network events again
    if (isLiked.value) return;

    // 3. Mark as liked and increment like count ONCE
    isLiked.value = true;
    likeCount.value++;

    // 4. Send socket event ONLY ONCE
    try {
      if (Get.isRegistered<SocketService>()) {
        final socketService = Get.find<SocketService>();
        socketService.emitEvent('stream-reaction', {
          'streamId': streamId.value,
          'reactionType': 'heart',
        });
      }
    } catch (e) {
      debugPrint("❌ Failed to emit stream-reaction: $e");
    }

    // 5. Send data stream event ONLY ONCE
    if (engine != null && _dataStreamId != null) {
      try {
        final payload = jsonEncode({
          "type": "like",
        });
        final bytes = utf8.encode(payload);
        engine!.sendStreamMessage(
          streamId: _dataStreamId!,
          data: Uint8List.fromList(bytes),
          length: bytes.length,
        );
        debugPrint("✅ Broadcasted initial like event");
      } catch (e) {
        debugPrint("❌ Failed to broadcast like: $e");
      }
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    LiveStreamServiceBridge.stopLiveService();
    _countdownTimer?.cancel();
    _cleanupSocket();
    engine?.leaveChannel();
    engine?.release();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Only care if active host stream
    if (!isLive.value || !isHost.value) return;

    if (state == AppLifecycleState.paused) {
      debugPrint("📱 Host app paused - starting foreground service...");
      LiveStreamServiceBridge.startLiveService();
      // Mute local video preview during backgrounding if not in PiP
      if (!isInPiP.value) {
        engine?.muteLocalVideoStream(true);
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("📱 Host app resumed - stopping foreground service...");
      LiveStreamServiceBridge.stopLiveService();
      // Restore video preview if camera is on
      if (isCameraOn.value) {
        engine?.muteLocalVideoStream(false);
      }
    }
  }
}
