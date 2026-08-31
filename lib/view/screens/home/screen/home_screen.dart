import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../../../../core/app_route.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../purchases/screen/purchases_screen.dart';
import '../controller/home_controller.dart';
import 'home_live_preview_widget.dart';
import '../../live_stream/controller/agora_live_controller.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../../../global/helper/auth_guard.dart';
import '../../../../data/services/api_url.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());
    return CustomBackground(
      child: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF8B9BFF),
          backgroundColor: const Color(0xFF1E1E2C),
          onRefresh: () async {
            await controller.refreshHome();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Welcome Header
              Text(
                "WELCOME BACK",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Obx(
                      () => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Hello, ${controller.fullName.value} 👋",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () async {
                      AuthGuard.check(
                        title: "Sign in for Notifications",
                        message: "Guest mode is browse-only. Sign in to view your trade alerts and updates.",
                        onAuthorized: () async {
                          await Get.toNamed(AppRoute.notifications);
                          controller.fetchUnreadNotificationCount();
                        },
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 24.sp,
                          ),
                        ),
                        Obx(() {
                          final count = controller.unreadNotificationCount.value;
                          if (count <= 0) return const SizedBox.shrink();
                          return Positioned(
                            top: -2.r,
                            right: -2.r,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                              constraints: BoxConstraints(minWidth: 17.r, minHeight: 17.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B9BFF),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: const Color(0xFF0D0819), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B9BFF).withValues(alpha: 0.45),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  count > 99 ? "99+" : "$count",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              // Go Live Button
              GestureDetector(
                onTap: () {
                  AuthGuard.check(
                    title: "Sign in to Go Live",
                    message: "Guest mode is browse-only. Sign in or create an account to host streams and auction items.",
                    onAuthorized: () {
                      try {
                        if (Get.isRegistered<AgoraLiveController>()) {
                          final ctrl = Get.find<AgoraLiveController>();
                          if (ctrl.isLive.value) {
                            ctrl.resumeStream();
                            return;
                          }
                        }
                      } catch (_) {}
                      Get.toNamed(AppRoute.goLiveSetup);
                    },
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 67.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36.r),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                    color: Colors.white.withOpacity(0.01),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        "assets/icons/Go Live.svg",
                        width: 36.w,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF8B9BFF),
                          BlendMode.srcIn,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Text(
                        "Go Live",
                        style: TextStyle(
                          color: const Color(0xFF8B9BFF),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 28.h),

              // Category Chips
              SizedBox(
                height: 48.h,
                child: Obx(
                  () => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.categories.length,
                    itemBuilder: (context, index) {
                      return Obx(() {
                        final isSelected =
                            controller.selectedCategoryIndex.value == index;
                        return GestureDetector(
                          onTap: () => controller.onCategorySelected(index),
                          child: Container(
                            margin: EdgeInsets.only(right: 12.w),
                            padding: EdgeInsets.symmetric(horizontal: 28.w),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF8B9BFF)
                                  : const Color(0xFF1E1E2C).withOpacity(0.4),
                              borderRadius: BorderRadius.circular(30.r),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.white.withOpacity(0.05),
                              ),
                            ),
                            child: Text(
                              controller.categories[index],
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF0F0B1E)
                                    : Colors.white60,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      });
                    },
                  ),
                ),
              ),

              // Dynamic spacing between Category Chips and content (prevents clutter when live shows are hidden)
              Obx(() => SizedBox(height: controller.liveItems.isNotEmpty ? 0 : 36.h)),

              // Conditional Live Sections (Featured Card & Live Now Grid) or Shimmer
              Obx(() {
                if (controller.isLoading.value && controller.liveItems.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeaturedLiveShimmer(),
                      SizedBox(height: 40.h),
                    ],
                  );
                }

                final hasLive = controller.liveItems.isNotEmpty;
                if (!hasLive) return const SizedBox.shrink();

                final liveShow = controller.liveItems.first;
                final String image = liveShow.image;
                final String title = liveShow.title;
                final String curator = liveShow.curator;
                final String viewers = liveShow.viewers;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20.h),
                    // Featured Card
                    Container(
                      height: 440.h,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20.r,
                            offset: Offset(0, 10.h),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: HomeLivePreviewWidget(
                              channelName: liveShow.raw?['agoraChannelName'] ?? '',
                              fallbackImageUrl: image,
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.9),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(28.r),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildSmallBadge("LIVE", const Color(0xFFFF5252)),
                                    SizedBox(width: 10.w),
                                    _buildSmallBadge(
                                      viewers,
                                      Colors.black.withOpacity(0.4),
                                      icon: Icons.visibility_outlined,
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    Container(
                                      width: 44.w,
                                      height: 44.w,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12.r),
                                        border: Border.all(
                                          color: Colors.white24,
                                          width: 1.5.w,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10.r),
                                        child: liveShow.curatorAvatar.isNotEmpty
                                            ? Image.network(
                                                liveShow.curatorAvatar,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => _buildFallbackAvatar(curator),
                                              )
                                            : _buildFallbackAvatar(curator),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "CURATED BY",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          curator,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 18.h),
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 24.h),
                                SizedBox(
                                   width: double.infinity,
                                   height: 60.h,
                                   child: Obx(() {
                                     AgoraLiveController? agoraCtrl;
                                     try {
                                       if (Get.isRegistered<AgoraLiveController>()) {
                                         agoraCtrl = Get.find<AgoraLiveController>();
                                       }
                                     } catch (_) {}

                                     final String sId = liveShow.raw?['_id']?.toString() ?? '';
                                     final bool isLiveActive = agoraCtrl != null && agoraCtrl.isLive.value && (agoraCtrl.streamId.value == sId || sId.isEmpty || (agoraCtrl.isHost.value && agoraCtrl.isLive.value));
                                     final bool isHost = agoraCtrl?.isHost.value ?? false;

                                     String btnText = "Join Stream";
                                     IconData btnIcon = Icons.play_circle_fill_rounded;
                                     if (isLiveActive) {
                                       btnText = isHost ? "Return to My Stream" : "Return to Stream";
                                       btnIcon = isHost ? Icons.videocam_rounded : Icons.play_circle_fill_rounded;
                                     }

                                     return ElevatedButton(
                                       onPressed: () {
                                         AuthGuard.check(
                                           title: "Sign in to Watch Stream",
                                           message: "Guest mode is browse-only. Sign in or create an account to watch live streams.",
                                           onAuthorized: () {
                                             if (isLiveActive && agoraCtrl != null) {
                                               agoraCtrl.resumeStream();
                                             } else if (liveShow.raw != null) {
                                               Get.toNamed(AppRoute.viewerLive, arguments: liveShow.raw);
                                             }
                                           },
                                         );
                                       },
                                       style: ElevatedButton.styleFrom(
                                         backgroundColor: isLiveActive ? const Color(0xFFFF4B4B) : const Color(0xFF8B9BFF),
                                         foregroundColor: isLiveActive ? Colors.white : const Color(0xFF0F0B1E),
                                         shape: RoundedRectangleBorder(
                                           borderRadius: BorderRadius.circular(30.r),
                                         ),
                                         elevation: 0,
                                       ),
                                       child: Row(
                                         mainAxisAlignment: MainAxisAlignment.center,
                                         children: [
                                           Icon(
                                             btnIcon,
                                             size: 28.sp,
                                             color: isLiveActive ? Colors.white : const Color(0xFF0F0B1E),
                                           ),
                                           SizedBox(width: 10.w),
                                           Text(
                                             btnText,
                                             style: TextStyle(
                                               fontWeight: FontWeight.w900,
                                               fontSize: 18.sp,
                                               color: isLiveActive ? Colors.white : const Color(0xFF0F0B1E),
                                             ),
                                           ),
                                         ],
                                       ),
                                     );
                                   }),
                                 ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 40.h),

                    // Live Now Grid Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Live Now",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              "Bidding wars in progress",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => Get.to(() => PurchasesScreen()),
                          child: Text(
                            "SEE ALL",
                            style: TextStyle(
                              color: const Color(0xFF8B9BFF),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 18.w,
                        mainAxisSpacing: 18.h,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: controller.liveItems.length,
                      itemBuilder: (context, index) {
                        final item = controller.liveItems[index];
                        return _buildLiveCard(item, index);
                      },
                    ),
                    SizedBox(height: 40.h),
                  ],
                );
              }),

              // Collectibles & Streetwear Products Section (Dynamic from Database)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Featured Collectibles",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    "Explore items verified by experts",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Obx(() {
                    if (controller.isProductsLoading.value) {
                      return _buildProductGridShimmer();
                    }

                    if (controller.products.isEmpty) {
                      return Container(
                        padding: EdgeInsets.symmetric(vertical: 40.h),
                        alignment: Alignment.center,
                        child: Text(
                          "No products found in this category.",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16.w,
                        mainAxisSpacing: 16.h,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: controller.products.length,
                      itemBuilder: (context, index) {
                        final product = controller.products[index];
                        return _buildProductCard(product);
                      },
                    );
                  }),
                ],
              ),

              SizedBox(height: 190.h), // Bottom padding for navigation bar & floating plus button
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSmallBadge(String text, Color bgColor, {IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text == "LIVE")
            Padding(
              padding: EdgeInsets.only(right: 6.w),
              child: Icon(Icons.circle, color: Colors.white, size: 8.sp),
            ),
          if (icon != null)
            Padding(
              padding: EdgeInsets.only(right: 4.w),
              child: Icon(icon, color: Colors.white, size: 12.sp),
            ),
          Text(
            text,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard(LiveItemModel item, int index) {
    return GestureDetector(
      onTap: () {
        AuthGuard.check(
          title: "Sign in to Watch Stream",
          message: "Guest mode is browse-only. Sign in or create an account to watch live streams.",
          onAuthorized: () {
            try {
              if (Get.isRegistered<AgoraLiveController>()) {
                final ctrl = Get.find<AgoraLiveController>();
                final String sId = item.raw?['_id']?.toString() ?? '';
                if (ctrl.isLive.value && (ctrl.streamId.value == sId || (ctrl.isHost.value && ctrl.isLive.value))) {
                  ctrl.resumeStream();
                  return;
                }
              }
            } catch (_) {}
            if (item.raw != null) {
              Get.toNamed(AppRoute.viewerLive, arguments: item.raw);
            } else {
              Get.snackbar("Cannot Join", "Stream data is not available.", snackPosition: SnackPosition.BOTTOM);
            }
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10.r,
              offset: Offset(0, 5.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.r),
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildProductImage(item.image, fit: BoxFit.cover, fallbackIcon: Icons.videocam_outlined),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildSmallBadge("LIVE", const Color(0xFFFF4B67)),
                        const Spacer(),
                        _buildSmallBadge(
                          item.viewers,
                          Colors.black.withOpacity(0.4),
                          icon: Icons.visibility_outlined,
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (index == 0)
                      Center(
                        child: Container(
                          margin: EdgeInsets.only(bottom: 20.h),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2C).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            "LIVE PREVIEW",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10.r,
                          backgroundImage: const NetworkImage(
                            "https://i.pravatar.cc/150?u=avatar",
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            item.curator,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final title = product['title'] ?? product['name'] ?? 'Item';
    final double price = (product['buyNowPrice'] ?? product['price'] ?? 0).toDouble();
    final List images = product['images'] ?? [];
    final String rawImg = images.isNotEmpty ? images[0].toString() : '';
    final String img = (rawImg.isNotEmpty && !rawImg.startsWith('http') && !rawImg.startsWith('data:image/'))
        ? "${ApiUrl.imageBaseUrl}${rawImg.startsWith('/') ? rawImg : '/$rawImg'}"
        : rawImg;
    final bool allowTrade = product['allowTrade'] == true;
    final bool isSold = (product['status'] ?? '') == 'sold';
    final String productId = product['_id'] ?? product['id'] ?? '';

    // Safeguard seller data
    final seller = product['sellerId'];
    final String sellerId = seller is Map ? (seller['_id'] ?? seller['id'] ?? '') : (seller?.toString() ?? '');
    final String sellerName = seller is Map ? (seller['fullName'] ?? seller['name'] ?? 'Seller') : 'Seller';
    final String sellerAvatar = seller is Map ? (seller['avatar'] ?? seller['profile'] ?? '') : '';

    return GestureDetector(
      onTap: () {
        final Map<String, dynamic> argMap = Map<String, dynamic>.from(product);
        argMap['productId'] = productId;
        argMap['sellerId'] = {
          '_id': sellerId,
          'fullName': sellerName,
          'name': sellerName,
          'avatar': sellerAvatar,
          'profile': sellerAvatar,
          'image': sellerAvatar,
          'bio': seller is Map ? (seller['bio'] ?? seller['description'] ?? '') : '',
          'rating': seller is Map ? (seller['rating'] ?? '4.8').toString() : '4.8',
        };
        Get.toNamed(AppRoute.tradeDetails, arguments: argMap);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                      child: _buildProductImage(rawImg, fit: BoxFit.cover),
                    ),
                  ),
                  if (isSold)
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text('SOLD', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  if (allowTrade && !isSold)
                    Positioned(
                      top: 8.h,
                      left: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD677FF).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text('TRADE', style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '\$${price.toStringAsFixed(0)}',
                    style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 15.sp, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String name) {
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFF2E2A4F),
      child: Text(
        initials,
        style: TextStyle(
          color: const Color(0xFF8B9BFF),
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProductImage(String imgStr, {double? height, double? width, BoxFit fit = BoxFit.cover, IconData fallbackIcon = Icons.image_outlined}) {
    if (imgStr.isEmpty) {
      return _buildGradientPlaceholder(icon: fallbackIcon, height: height, width: width);
    }
    if (imgStr.startsWith('data:image/') && imgStr.contains('base64,')) {
      try {
        final bytes = base64Decode(imgStr.split('base64,').last);
        return Image.memory(
          bytes,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildGradientPlaceholder(icon: Icons.broken_image_outlined, height: height, width: width),
        );
      } catch (_) {
        return _buildGradientPlaceholder(icon: Icons.broken_image_outlined, height: height, width: width);
      }
    }
    final cleanUrl = imgStr.startsWith('http') ? imgStr : "${ApiUrl.imageBaseUrl}${imgStr.startsWith('/') ? imgStr : '/$imgStr'}";
    return Image.network(
      cleanUrl,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) => _buildGradientPlaceholder(icon: fallbackIcon, height: height, width: width),
    );
  }

  Widget _buildGradientPlaceholder({IconData? icon, String? subtitle, double iconSize = 32, double? height, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1E1C2E), // Deep indigo
            Color(0xFF2C1E3C), // Cyber magenta
            Color(0xFF0F0F1A), // Dark obsidian
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: const Color(0xFF8B9BFF).withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.15), width: 1.5),
              ),
              child: Icon(icon ?? Icons.image_outlined, color: const Color(0xFF8B9BFF), size: iconSize.sp),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 6.h),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedLiveShimmer() {
    return Container(
      height: 440.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(32.r),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32.r),
              child: const CustomShimmer.rectangular(height: double.infinity),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(28.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomShimmer.rectangular(height: 24.h, width: 60.w),
                    SizedBox(width: 10.w),
                    CustomShimmer.rectangular(height: 24.h, width: 50.w),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    CustomShimmer.circular(width: 44.w, height: 44.w),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomShimmer.rectangular(height: 10.h, width: 70.w),
                        SizedBox(height: 6.h),
                        CustomShimmer.rectangular(height: 14.h, width: 110.w),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                CustomShimmer.rectangular(height: 24.h, width: 220.w),
                SizedBox(height: 8.h),
                CustomShimmer.rectangular(height: 20.h, width: 140.w),
                SizedBox(height: 24.h),
                CustomShimmer.rectangular(height: 60.h, width: double.infinity),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGridShimmer() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: 0.75,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF11111A),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                  child: const CustomShimmer.rectangular(height: double.infinity),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomShimmer.rectangular(height: 13.h, width: 110.w),
                    SizedBox(height: 8.h),
                    CustomShimmer.rectangular(height: 15.h, width: 65.w),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
