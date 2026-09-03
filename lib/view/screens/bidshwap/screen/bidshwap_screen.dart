import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../../../../core/app_route.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../profile/controller/profile_controller.dart';
import '../controller/bidshwap_controller.dart';
import '../model/trade_model.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/helper/auth_guard.dart';

class BidShwapScreen extends GetView<BidShwapController> {
  const BidShwapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(BidShwapController());
    final profileController = Get.isRegistered<ProfileController>() ? Get.find<ProfileController>() : null;
    return CustomBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  profileController != null
                      ? Obx(() {
                          final imageUrl = profileController.profileImageUrl.value;
                          return CircleAvatar(
                            radius: 20.r,
                            backgroundImage: imageUrl.isNotEmpty
                                ? NetworkImage(imageUrl)
                                : const NetworkImage("https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=1974&auto=format&fit=crop") as ImageProvider,
                          );
                        })
                      : CircleAvatar(
                          radius: 20.r,
                          backgroundImage: const NetworkImage("https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=1974&auto=format&fit=crop"),
                        ),
                  Text(
                    "Auction Live",
                    style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () {
                      AuthGuard.check(
                        title: "Sign in to view Notifications",
                        message: "Guest mode is browse-only. Sign in to view your activity and notifications.",
                        onAuthorized: () => Get.toNamed(AppRoute.notifications),
                      );
                    },
                    child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26.sp),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Colors.white10, thickness: 1),
            
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    SizedBox(height: 24.h),
                    
                    // Search Bar
                    _buildSearchBar(),
                    
                    SizedBox(height: 32.h),
                    
                    // Filters
                    _buildFilters(),
                    
                    SizedBox(height: 32.h),
                    
                    // Trade List
                    Obx(() {
                      if (controller.isLoading.value && controller.trades.isEmpty) {
                        return Column(
                          children: List.generate(
                            3,
                            (index) => _buildTradeCardShimmer(),
                          ),
                        );
                      }

                      if (controller.trades.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 60.h),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  color: Colors.white38,
                                  size: 48.sp,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  "No trades found",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: controller.trades.map((trade) => _buildTradeCard(trade)).toList(),
                      );
                    }),
                    
                    SizedBox(height: 190.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 60.h,
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.white, size: 24.sp),
          SizedBox(width: 14.w),
          Expanded(
            child: TextField(
              controller: controller.searchController,
              onChanged: (value) => controller.searchQuery.value = value,
              style: TextStyle(color: Colors.white, fontSize: 16.sp),
              decoration: InputDecoration(
                hintText: "Search deals & more",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 16.sp),
                border: InputBorder.none,
              ),
            ),
          ),
          Icon(Icons.tune_rounded, color: Colors.white, size: 22.sp),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 44.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: controller.filters.length,
        itemBuilder: (context, index) {
          return Obx(() {
            final isSelected = controller.selectedFilter.value == index;
            return GestureDetector(
              onTap: () => controller.changeFilter(index),
              child: Container(
                margin: EdgeInsets.only(right: 12.w),
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8B9BFF) : const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(22.r),
                ),
                child: Text(
                  controller.filters[index],
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white38,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildTradeCard(TradeModel trade) {
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoute.tradeDetails, arguments: trade.rawProduct),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: 20.h),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.circular(28.r),
        ),
        child: Column(
          children: [
            // User Info
            Row(
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: Colors.white10,
                  child: ClipOval(
                    child: Image.network(
                      trade.userAvatar,
                      width: 36.r,
                      height: 36.r,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.network(
                        "",
                        width: 36.r,
                        height: 36.r,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trade.userName, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
                      Row(
                        children: [
                          Icon(Icons.star, color: const Color(0xFFFF8BFF), size: 12.sp),
                          SizedBox(width: 4.w),
                          Text("${trade.userRating} (${trade.tradesCount})", style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text("VERIFIED AVAILABLE", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 9.sp, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            
            SizedBox(height: 16.h),
            
            // Offered Item & Looking For Section
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    Container(
                      height: 200.h,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _buildTradeItemImageWidget(
                              trade.offeredItemImage,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            left: 12.w,
                            bottom: 12.h,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("OFFERED ITEM", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                  SizedBox(height: 4.h),
                                  Text(trade.offeredItemName, style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w900)),
                                  Text(trade.offeredItemValue, style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12.w,
                            bottom: 12.h,
                            child: Container(
                              width: 38.r,
                              height: 38.r,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(Icons.add, color: Colors.black, size: 22.sp),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 12.h),

                    // Looking For
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0B1E),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("LOOKING FOR", style: TextStyle(color: const Color(0xFFFF8BFF), fontSize: 11.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                SizedBox(height: 8.h),
                                Text(trade.lookingForItemName, style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w900)),
                                SizedBox(height: 2.h),
                                Text(trade.lookingForItemValue, style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          Icon(Icons.watch_outlined, color: Colors.white10, size: 28.sp),
                        ],
                      ),
                    ),
                  ],
                ),

                // Center Swap Icon floating cleanly over cards
                Positioned(
                  top: 178.h,
                  child: Container(
                    width: 48.r,
                    height: 48.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF8B9BFF),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B9BFF).withOpacity(0.4),
                          blurRadius: 16.r,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.r),
                        child: SvgPicture.asset(
                          "assets/icons/Container1.svg",
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16.h),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    "View Details",
                    Colors.white.withOpacity(0.06),
                    Colors.white,
                    onTap: () => Get.toNamed(AppRoute.tradeDetails, arguments: trade.rawProduct),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildActionButton(
                    "Make Offer",
                    const Color(0xFF8B9BFF),
                    Colors.black,
                    onTap: () {
                      AuthGuard.check(
                        title: "Sign in to Make an Offer",
                        message: "Guest mode is browse-only. Sign in or create an account to make custom trade offers.",
                        onAuthorized: () => Get.toNamed('/make_offer', arguments: trade.rawProduct),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildMyTradeFilters() {
  //   return Container(
  //     height: 56.h,
  //     padding: EdgeInsets.all(4.r),
  //     decoration: BoxDecoration(
  //       color: const Color(0xFF161622),
  //       borderRadius: BorderRadius.circular(28.r),
  //     ),
  //     child: Row(
  //       children: List.generate(controller.myTradeFilters.length, (index) {
  //         return Expanded(
  //           child: Obx(() {
  //             final isSelected = controller.selectedMyTradeFilter.value == index;
  //             return GestureDetector(
  //               onTap: () => controller.changeMyTradeFilter(index),
  //               child: Container(
  //                 alignment: Alignment.center,
  //                 decoration: BoxDecoration(
  //                   color: isSelected ? const Color(0xFF282C36) : Colors.transparent,
  //                   borderRadius: BorderRadius.circular(24.r),
  //                 ),
  //                 child: Text(
  //                   controller.myTradeFilters[index],
  //                   style: TextStyle(
  //                     color: isSelected ? Colors.white : const Color(0xff97A9FF),
  //                     fontSize: 14.sp,
  //                     fontWeight: FontWeight.w800,
  //                   ),
  //                 ),
  //               ),
  //             );
  //           }),
  //         );
  //       }),
  //     ),
  //   );
  // }
  //
  // Widget _buildMyTradeCard(MyTradeModel trade) {
  //   Color statusColor;
  //   Color statusTextColor = Colors.white;
  //   String statusText;
  //   switch (trade.status) {
  //     case MyTradeStatus.shipped:
  //       statusColor = const Color(0xFF2E1E5D);
  //       statusText = "SHIPPED";
  //       break;
  //     case MyTradeStatus.pending:
  //       statusColor = const Color(0xFF282C36);
  //       statusText = "PENDING";
  //       break;
  //     case MyTradeStatus.completed:
  //       statusColor = const Color(0xFF5D1E4E);
  //       statusText = "COMPLETED";
  //       break;
  //   }
  //
  //   return Container(
  //     margin: EdgeInsets.only(bottom: 24.h),
  //     padding: EdgeInsets.all(24.r),
  //     decoration: BoxDecoration(
  //       color: const Color(0xFF161622),
  //       borderRadius: BorderRadius.circular(32.r),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Text("TRADE ID: ${trade.tradeId}", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 11.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
  //             Container(
  //               padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
  //               decoration: BoxDecoration(
  //                 color: statusColor,
  //                 borderRadius: BorderRadius.circular(20.r),
  //               ),
  //               child: Text(statusText, style: TextStyle(color: statusTextColor, fontSize: 10.sp, fontWeight: FontWeight.w900)),
  //             ),
  //           ],
  //         ),
  //         SizedBox(height: 12.h),
  //         Text(trade.title, style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900, height: 1.2)),
  //         SizedBox(height: 24.h),
  //
  //         if (trade.status == MyTradeStatus.completed) ...[
  //           Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text("TRADER", style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
  //                   SizedBox(height: 10.h),
  //                   Row(
  //                     children: [
  //                       CircleAvatar(radius: 14.r, backgroundImage: NetworkImage(trade.traderAvatar ?? "")),
  //                       SizedBox(width: 10.w),
  //                       Text(trade.traderName, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900)),
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //               Column(
  //                 crossAxisAlignment: CrossAxisAlignment.end,
  //                 children: [
  //                   Text("DATE", style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
  //                   SizedBox(height: 10.h),
  //                   Text(trade.date ?? "", style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900)),
  //                 ],
  //               ),
  //             ],
  //           ),
  //           SizedBox(height: 24.h),
  //           _buildActionButton("View Receipt", const Color(0xFF8B9BFF), Colors.black),
  //           SizedBox(height: 24.h),
  //           Container(
  //             height: 180.h,
  //             width: double.infinity,
  //             decoration: BoxDecoration(
  //               color: Colors.black.withOpacity(0.2),
  //               borderRadius: BorderRadius.circular(28.r),
  //             ),
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 _buildTradeItemImage(trade.item1Image),
  //                 Padding(
  //                   padding: EdgeInsets.symmetric(horizontal: 20.w),
  //                   child: Icon(Icons.sync_alt_rounded, color: const Color(0xFF8B9BFF), size: 24.sp),
  //                 ),
  //                 _buildTradeItemImage(trade.item2Image),
  //               ],
  //             ),
  //           ),
  //         ] else ...[
  //           Row(
  //             children: [
  //               Expanded(
  //                 child: Row(
  //                   children: [
  //                     _buildTradeItemImage(trade.item1Image, small: true),
  //                     Padding(
  //                       padding: EdgeInsets.symmetric(horizontal: 8.w), // Reduced padding to prevent overflow
  //                       child: Icon(Icons.sync_alt_rounded, color: Colors.white10, size: 18.sp),
  //                     ),
  //                     _buildTradeItemImage(trade.item2Image, small: true),
  //                   ],
  //                 ),
  //               ),
  //               Column(
  //                 crossAxisAlignment: CrossAxisAlignment.end,
  //                 children: [
  //                   Text("Trader", style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w800)),
  //                   Text(trade.traderName, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
  //                 ],
  //               ),
  //             ],
  //           ),
  //           SizedBox(height: 28.h),
  //           Row(
  //             children: [
  //               Expanded(child: _buildActionButton("View Trade", const Color(0xFF1E1E2C), Colors.white)),
  //               SizedBox(width: 16.w),
  //               Container(
  //                 height: 56.h,
  //                 width: 56.h,
  //                 decoration: BoxDecoration(
  //                   color: const Color(0xFF1E1E2C),
  //                   borderRadius: BorderRadius.circular(20.r),
  //                 ),
  //                 child: Icon(Icons.chat_bubble_outline_rounded, color: const Color(0xFF8B9BFF), size: 22.sp),
  //               ),
  //             ],
  //           ),
  //         ],
  //       ],
  //     ),
  //   );
  // }

  Widget _buildActionButton(String text, Color bg, Color textCol, {VoidCallback? onTap}) {
    return SizedBox(
      height: 48.h,
      child: ElevatedButton(
        onPressed: onTap ?? () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: textCol,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildTradeItemImageWidget(String imgStr, {BoxFit fit = BoxFit.cover}) {
    final placeholder = Image.network(
      "https://images.unsplash.com/photo-1613771404721-1f92d799e49f?q=80&w=2069&auto=format&fit=crop",
      fit: fit,
    );

    if (imgStr.isEmpty) {
      return placeholder;
    }
    
    if (imgStr.startsWith('data:image/') && imgStr.contains('base64,')) {
      try {
        final base64Content = imgStr.split('base64,').last;
        final bytes = base64Decode(base64Content);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => placeholder,
        );
      } catch (_) {
        return placeholder;
      }
    }
    
    final cleanUrl = imgStr.startsWith('http')
        ? imgStr
        : "${ApiUrl.imageBaseUrl}${imgStr.startsWith('/') ? imgStr : '/$imgStr'}";

    return Image.network(
      cleanUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }

  Widget _buildTradeCardShimmer() {
    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User row shimmer
          Row(
            children: [
              CustomShimmer.circular(width: 36.r, height: 36.r),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomShimmer.rectangular(height: 14.h, width: 120.w),
                    SizedBox(height: 6.h),
                    CustomShimmer.rectangular(height: 10.h, width: 70.w),
                  ],
                ),
              ),
              CustomShimmer.rectangular(
                height: 24.h,
                width: 110.w,
                shapeBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Main image shimmer
          CustomShimmer.rectangular(
            height: 200.h,
            shapeBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
          SizedBox(height: 16.h),

          // Looking for box shimmer
          CustomShimmer.rectangular(
            height: 64.h,
            shapeBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          SizedBox(height: 16.h),

          // Action buttons shimmer
          Row(
            children: [
              Expanded(
                child: CustomShimmer.rectangular(
                  height: 48.h,
                  shapeBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: CustomShimmer.rectangular(
                  height: 48.h,
                  shapeBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
