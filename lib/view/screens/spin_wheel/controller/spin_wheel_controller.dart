import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SpinReward {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String type; // 'card', 'discount', 'shipping', 'points', 'pack', 'badge'

  const SpinReward({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.type,
  });
}

class SpinWheelController extends GetxController with GetSingleTickerProviderStateMixin {
  final RxBool isSpinning = false.obs;
  final RxDouble rotationTurns = 0.0.obs;
  final RxInt selectedIndex = 0.obs;
  final RxInt freeSpinsLeft = 1.obs;
  final Rx<SpinReward?> wonReward = Rx<SpinReward?>(null);
  final RxBool showRewardDialog = false.obs;

  late AnimationController animController;
  late Animation<double> spinAnimation;

  final List<SpinReward> rewards = const [
    SpinReward(
      title: "Rare Collectible Card",
      description: "1999 Base Set Holo card added to your Vault.",
      icon: Icons.style_rounded,
      color: Color(0xFFFF4B6E),
      type: 'card',
    ),
    SpinReward(
      title: "\$15 Stream Coupon",
      description: "Applies automatically on your next live auction purchase.",
      icon: Icons.confirmation_number_rounded,
      color: Color(0xFF8B9BFF),
      type: 'discount',
    ),
    SpinReward(
      title: "Free Express Shipping",
      description: "Valid for 1 upcoming CultureCards order.",
      icon: Icons.local_shipping_rounded,
      color: Color(0xFF22C55E),
      type: 'shipping',
    ),
    SpinReward(
      title: "500 Reward Points",
      description: "Added to your CultureCards reward balance.",
      icon: Icons.monetization_on_rounded,
      color: Color(0xFFF59E0B),
      type: 'points',
    ),
    SpinReward(
      title: "Mystery Booster Pack",
      description: "Physical hobby pack routed to your next shipment.",
      icon: Icons.card_giftcard_rounded,
      color: Color(0xFFBD8BFF),
      type: 'pack',
    ),
    SpinReward(
      title: "Gold Curator Badge",
      description: "Special profile badge highlighted in live chat.",
      icon: Icons.verified_rounded,
      color: Color(0xFF06B6D4),
      type: 'badge',
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
<<<<<<< HEAD

    // Feature 6: Socket listener for server-triggered spin-result
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    try {
      // If SocketService is registered (e.g. during live stream room), listen for room-wide spin-result
      // ignore: avoid_dynamic_calls
      if (Get.isRegistered<dynamic>(tag: 'SocketService') || Get.isRegistered<GetxController>()) {
        // Safe check
      }
    } catch (_) {}
  }

  void handleSocketSpinResult(dynamic data) {
    if (data == null) return;
    try {
      final Map<String, dynamic> resMap = (data is Map)
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final String prizeName = resMap['prizeName']?.toString() ?? 'Guaranteed Reward';
      final double degreeIndex = double.tryParse(resMap['degreeIndex']?.toString() ?? '0') ?? 0.0;
      spinToDegree(degreeIndex, prizeName: prizeName);
    } catch (e) {
      debugPrint("❌ [SpinWheel] Socket spin-result error: $e");
    }
  }

  void spinToDegree(double targetDegree, {String? prizeName}) {
    if (isSpinning.value) return;

    isSpinning.value = true;
    showRewardDialog.value = false;

    final double startTurns = rotationTurns.value;
    final double fullSpins = 5.0 * 360.0;
    final double totalAngle = fullSpins + (targetDegree % 360.0);
    final double targetTurns = startTurns + (totalAngle / 360.0);

    final double segmentAngle = 360.0 / rewards.length;
    final int targetIndex = ((360.0 - (targetDegree % 360.0)) / segmentAngle).floor() % rewards.length;
    selectedIndex.value = targetIndex;

    spinAnimation = Tween<double>(begin: startTurns, end: targetTurns).animate(
      CurvedAnimation(
        parent: animController,
        curve: Curves.easeOutCubic,
      ),
    );

    animController.reset();
    animController.forward().then((_) {
      isSpinning.value = false;
      rotationTurns.value = targetTurns % 1.0;
      if (prizeName != null && prizeName.isNotEmpty) {
        wonReward.value = SpinReward(
          title: prizeName,
          description: "Guaranteed promotional prize added to your vault.",
          icon: Icons.stars_rounded,
          color: const Color(0xFF8B9BFF),
          type: 'card',
        );
      } else {
        wonReward.value = rewards[targetIndex];
      }
      showRewardDialog.value = true;
      if (freeSpinsLeft.value > 0) {
        freeSpinsLeft.value--;
      }
    });
=======
>>>>>>> f576f84c7d71787184ff21c82756b260d0963aee
  }

  @override
  void onClose() {
    animController.dispose();
    super.onClose();
  }

  void spin() {
    if (isSpinning.value) return;

    isSpinning.value = true;
    showRewardDialog.value = false;

    // Pick random target reward
    final random = Random();
    final targetIndex = random.nextInt(rewards.length);
    selectedIndex.value = targetIndex;

    // Calculate rotation angle (5 to 8 full rotations + target segment offset)
    final double segmentAngle = 360.0 / rewards.length;
    final double targetAngle = (360.0 - (targetIndex * segmentAngle)) - (segmentAngle / 2);
    final double fullSpins = (5 + random.nextInt(3)) * 360.0;
    final double totalAngle = fullSpins + targetAngle;

    final double startTurns = rotationTurns.value;
    final double targetTurns = startTurns + (totalAngle / 360.0);

    spinAnimation = Tween<double>(begin: startTurns, end: targetTurns).animate(
      CurvedAnimation(
        parent: animController,
        curve: Curves.easeOutCubic,
      ),
    );

    animController.reset();
    animController.forward().then((_) {
      isSpinning.value = false;
      rotationTurns.value = targetTurns % 1.0;
      wonReward.value = rewards[targetIndex];
      showRewardDialog.value = true;
      if (freeSpinsLeft.value > 0) {
        freeSpinsLeft.value--;
      }
    });
  }

  void claimReward() {
    showRewardDialog.value = false;
    Get.snackbar(
      "Reward Claimed! 🎉",
      "${wonReward.value?.title ?? 'Reward'} has been added to your account.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF8B9BFF),
      colorText: Colors.black,
    );
  }
}
