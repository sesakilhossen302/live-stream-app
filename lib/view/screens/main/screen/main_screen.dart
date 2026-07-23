import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_bottom_navbar.dart';
import '../../../../global/widgets/floating_live_stream_overlay.dart';
import '../controller/main_controller.dart';

class MainScreen extends GetView<MainController> {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(MainController());
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1E),
      body: Stack(
        children: [
          Obx(() => controller.screens[controller.currentIndex.value]),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomBottomNavbar(),
          ),
          const FloatingLiveStreamOverlay(),
        ],
      ),
    );
  }
}
