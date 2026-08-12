import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'agora_live_controller.dart';

class LiveStreamModel {
  final String videoUrl;
  final String curator;
  final String viewers;
  final String title;
  final String productTitle;
  final RxString productPrice;
  final String productImage;
  final RxBool isFollowing = false.obs;
  final RxBool isLiked = false.obs;
  final RxInt likeCount = 1200.obs;   // multi-tap boost count
  final RxBool isBookmarked = false.obs;

  LiveStreamModel({
    required this.videoUrl,
    required this.curator,
    required this.viewers,
    required this.title,
    required this.productTitle,
    required String productPrice,
    required this.productImage,
  }) : productPrice = productPrice.obs;
}

class LiveStreamController extends GetxController {
  final RxList<LiveStreamModel> streams = <LiveStreamModel>[
    LiveStreamModel(
      videoUrl: 'https://videos.pexels.com/video-files/8431902/8431902-uhd_1440_2732_25fps.mp4',
      curator: '@beauty_guru',
      viewers: '1.2K',
      title: 'Model in Straw Hat',
      productTitle: 'Premium Brush Set',
      productPrice: '\$45.00',
      productImage: 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?q=80&w=400&auto=format&fit=crop',
    ),
    LiveStreamModel(
      videoUrl: 'https://videos.pexels.com/video-files/6220629/6220629-uhd_1440_2732_25fps.mp4',
      curator: '@fashion_icon',
      viewers: '2.5K',
      title: 'Women Posing Portrait',
      productTitle: 'Floral Summer Dress',
      productPrice: '\$89.00',
      productImage: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?q=80&w=400&auto=format&fit=crop',
    ),
    LiveStreamModel(
      videoUrl: 'https://videos.pexels.com/video-files/9257197/9257197-uhd_1440_2732_25fps.mp4',
      curator: '@makeup_artist',
      viewers: '3.1K',
      title: 'Models Posing Together',
      productTitle: 'Eyeshadow Palette',
      productPrice: '\$35.00',
      productImage: 'https://images.unsplash.com/photo-1512496015851-a90fb38ba796?q=80&w=400&auto=format&fit=crop',
    ),
    LiveStreamModel(
      videoUrl: 'https://videos.pexels.com/video-files/8478617/8478617-uhd_1440_2560_24fps.mp4',
      curator: '@lifestyle_vlog',
      viewers: '950',
      title: 'Lifestyle Fashion Style',
      productTitle: 'Ring Light Pro',
      productPrice: '\$120.00',
      productImage: 'https://images.unsplash.com/photo-1527613426441-4da17471b66d?q=80&w=400&auto=format&fit=crop',
    ),
    LiveStreamModel(
      videoUrl: 'https://videos.pexels.com/video-files/8371250/8371250-uhd_1440_2732_25fps.mp4',
      curator: '@street_style',
      viewers: '1.8K',
      title: 'Influencer Lifestyle Walk',
      productTitle: 'Eco-Friendly Yoga Mat',
      productPrice: '\$55.00',
      productImage: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?q=80&w=400&auto=format&fit=crop',
    ),
    LiveStreamModel(
      videoUrl: 'https://videos.pexels.com/video-files/3576378/3576378-uhd_1440_2732_25fps.mp4',
      curator: '@luxury_vibe',
      viewers: '4.2K',
      title: 'Premium Lifestyle Live',
      productTitle: 'Designer Watch',
      productPrice: '\$450.00',
      productImage: 'https://images.unsplash.com/photo-1524592094714-0f0654e20314?q=80&w=400&auto=format&fit=crop',
    ),
    LiveStreamModel(
      videoUrl: 'https://videos.pexels.com/video-files/3959556/3959556-uhd_1440_2560_25fps.mp4',
      curator: '@travel_diaries',
      viewers: '3.8K',
      title: 'Exploring The Unknown',
      productTitle: 'Travel Backpack',
      productPrice: '\$120.00',
      productImage: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?q=80&w=400&auto=format&fit=crop',
    ),
    LiveStreamModel(
      videoUrl: 'https://videos.pexels.com/video-files/4011853/4011853-uhd_1440_2560_25fps.mp4',
      curator: '@night_fashion',
      viewers: '2.1K',
      title: 'Night Gala Style',
      productTitle: 'Evening Gown',
      productPrice: '\$899.00',
      productImage: 'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?q=80&w=400&auto=format&fit=crop',
    ),
    LiveStreamModel(
      videoUrl: 'https://videos.pexels.com/video-files/4201737/4201737-uhd_1440_2560_25fps.mp4',
      curator: '@vlog_queen',
      viewers: '5.5K',
      title: 'Daily Life Uncut',
      productTitle: 'Vlogging Kit',
      productPrice: '\$199.00',
      productImage: 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?q=80&w=400&auto=format&fit=crop',
    ),
    LiveStreamModel(
      videoUrl: 'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8',
      curator: '@stream_test',
      viewers: '500',
      title: 'HLS Test Stream',
      productTitle: 'Test Product',
      productPrice: '\$0.00',
      productImage: 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=400&auto=format&fit=crop',
    ),
  ].obs;

  // Track initialization status
  final RxList<bool> videoReady = <bool>[].obs;
  final RxList<bool> isPaused = <bool>[].obs;
  int currentIdx = 0;
  final RxList<VideoPlayerController?> videoControllers = <VideoPlayerController?>[].obs;

  // Custom Bid state
  final RxString currentCustomBid = "".obs;

  void addDigit(String digit) {
    if (currentCustomBid.value == "0") {
      currentCustomBid.value = digit;
    } else {
      currentCustomBid.value += digit;
    }
  }

  void removeDigit() {
    if (currentCustomBid.value.isNotEmpty) {
      currentCustomBid.value = currentCustomBid.value.substring(0, currentCustomBid.value.length - 1);
      if (currentCustomBid.value.isEmpty) {
        currentCustomBid.value = "0";
      }
    }
  }

  void addAmount(int amount) {
    int current = int.tryParse(currentCustomBid.value) ?? 0;
    currentCustomBid.value = (current + amount).toString();
  }

  void placeBid([double? customAmount]) {
    if (currentIdx < streams.length) {
      double currentPrice = double.tryParse(streams[currentIdx].productPrice.value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      double newBid = customAmount ?? double.tryParse(currentCustomBid.value) ?? 0;

      if (newBid <= currentPrice && customAmount == null) {
        Get.snackbar(
          "Invalid Bid", 
          "Your bid must be higher than the current highest price (\$${currentPrice.toStringAsFixed(0)})", 
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      streams[currentIdx].productPrice.value = "\$${newBid.toStringAsFixed(0)}";
      
      // Connect to real backend/socket via AgoraLiveController if available
      if (Get.isRegistered<AgoraLiveController>()) {
        try {
          final agoraCtrl = Get.find<AgoraLiveController>();
          agoraCtrl.placeBid(newBid);
        } catch (e) {
          debugPrint("AgoraLiveController placeBid error: $e");
        }
      }

      if (Get.isBottomSheetOpen == true) Get.back();
      Get.snackbar("Bid Placed!", "Your bid of \$${newBid.toStringAsFixed(0)} is live!", 
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP);
    }
  }

  Future<void> sendCustomOffer({required double offerPrice, String message = ""}) async {
    if (Get.isRegistered<AgoraLiveController>()) {
      try {
        final agoraCtrl = Get.find<AgoraLiveController>();
        await agoraCtrl.sendCustomOffer(offerPrice: offerPrice, message: message);
        return;
      } catch (e) {
        debugPrint("AgoraLiveController sendCustomOffer error: $e");
      }
    }
    if (Get.isBottomSheetOpen == true) Get.back();
    Get.snackbar(
      "Custom Offer Sent! 🤝",
      "Your offer of \$${offerPrice.toStringAsFixed(0)} has been sent to the host!",
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFFBD8BFF),
      colorText: Colors.white,
    );
  }

  void addLike(LiveStreamModel stream) {
    stream.isLiked.value = true;
    stream.likeCount.value++;
  }

  void toggleBookmark(LiveStreamModel stream) {
    stream.isBookmarked.value = !stream.isBookmarked.value;
    Get.snackbar(
      stream.isBookmarked.value ? '🔖 Saved' : 'Removed',
      stream.isBookmarked.value ? 'Stream bookmarked!' : 'Bookmark removed.',
      backgroundColor: const Color(0xFF1E1E2C),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 1),
      margin: const EdgeInsets.all(12),
    );
  }

  @override
  void onInit() {
    super.onInit();
    
    // Handle incoming data from other pages
    if (Get.arguments != null && Get.arguments is LiveStreamModel) {
      final incomingStream = Get.arguments as LiveStreamModel;
      bool exists = streams.any((s) => s.videoUrl == incomingStream.videoUrl);
      if (!exists) {
        streams.insert(0, incomingStream);
      } else {
        int idx = streams.indexWhere((s) => s.videoUrl == incomingStream.videoUrl);
        final item = streams.removeAt(idx);
        streams.insert(0, item);
      }
    }

    // Initialize status lists
    videoReady.assignAll(List.generate(streams.length, (_) => false));
    isPaused.assignAll(List.generate(streams.length, (_) => false));
    videoControllers.assignAll(List.generate(streams.length, (_) => null));

    // Pre-initialize first few videos
    for (int i = 0; i < (streams.length < 3 ? streams.length : 3); i++) {
      _initializeController(i);
    }
  }

  void togglePlay(int index) {
    if (index >= videoControllers.length) return;
    final controller = videoControllers[index];
    if (controller != null && controller.value.isInitialized) {
      if (controller.value.isPlaying) {
        controller.pause();
        isPaused[index] = true;
      } else {
        controller.play();
        isPaused[index] = false;
      }
    }
  }

  Future<void> _initializeController(int i) async {
    if (i >= streams.length || videoControllers[i] != null) return;

    try {
      debugPrint('🎬 Initializing Video $i: ${streams[i].videoUrl}');
      
      final vc = VideoPlayerController.networkUrl(
        Uri.parse(streams[i].videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      
      videoControllers[i] = vc;
      
      await vc.initialize().timeout(const Duration(seconds: 15), onTimeout: () {
        throw 'Connection timeout for video $i';
      });

      vc.setLooping(true);
      vc.setVolume(1.0);
      videoReady[i] = true;

      if (i == currentIdx) {
        await vc.play();
      }
      
      update();
      debugPrint('✅ Video $i initialized successfully');
    } catch (e) {
      debugPrint('❌ Video $i failed to initialize: $e');
      videoReady[i] = false;
      update();
    }
  }

  void onPageChanged(int index) {
    // Pause previous video
    if (currentIdx < videoControllers.length) {
      final oldController = videoControllers[currentIdx];
      if (oldController != null && videoReady[currentIdx]) {
        oldController.pause();
        isPaused[currentIdx] = true;
      }
    }

    currentIdx = index;

    // Play current video
    if (index < videoControllers.length) {
      final newController = videoControllers[index];
      if (newController != null && videoReady[index]) {
        newController.play();
        isPaused[index] = false;
      } else {
        // Initialize next video if not ready
        _initializeController(index);
      }
    }
    
    // Pre-initialize next video
    if (index + 1 < streams.length) {
      _initializeController(index + 1);
    }

    // Cleanup controllers far behind (index - 2 or further) to free RAM & prevent OOM
    for (int i = 0; i < videoControllers.length; i++) {
      if ((i < index - 1 || i > index + 2) && videoControllers[i] != null) {
        try {
          videoControllers[i]?.dispose();
        } catch (_) {}
        videoControllers[i] = null;
        videoReady[i] = false;
      }
    }
    
    update();
  }

  @override
  void onClose() {
    for (var vc in videoControllers) {
      vc?.dispose();
    }
    super.onClose();
  }
}
