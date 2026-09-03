import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../../../core/app_route.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/profile_controller.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../../../global/widgets/custom_empty_state.dart';
import '../../../../data/helpers/shared_prefe.dart';

class ProfileScreen extends GetView<ProfileController> {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(ProfileController());
    return CustomBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    "Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.fetchProfileData(),
                color: const Color(0xFF8B9BFF),
                backgroundColor: const Color(0xFF11111A),
                strokeWidth: 2.5,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: (SharePrefsHelper.isGuest || SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey).isEmpty)
                      ? _buildGuestProfileView()
                      : Obx(() {
                          if (controller.hasError.value && controller.name.value.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.only(top: 80.h),
                        child: CustomEmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: "Failed to Load Profile",
                          description: controller.errorMessage.value.isNotEmpty
                              ? controller.errorMessage.value
                              : "Could not fetch profile details. Please check your internet connection.",
                          onRetry: () => controller.fetchProfileData(),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        SizedBox(height: 8.h),

                        // Profile Info — Facebook-style cover
                        _buildProfileHeader(),

                        SizedBox(height: 24.h),

                        // Stats Row
                        _buildStatsRow(),

                        SizedBox(height: 32.h),

                        // Tabs
                        _buildTabBar(),

                        SizedBox(height: 24.h),

                        // Content Section
                        if (controller.selectedTab.value == 1)
                          _buildActivityTab()
                        else if (controller.selectedTab.value == 2)
                          _buildSettingsTab()
                        else
                          _buildListingsGrid(),

                        SizedBox(height: 120.h),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Obx(() {
      final coverUrl = controller.coverPhotoUrl.value;
      final profileUrl = controller.profileImageUrl.value;

      if (controller.isLoading.value && controller.name.value.isEmpty) {
        return _buildProfileHeaderShimmer();
      }

      final displayUsername = controller.username.value.replaceAll('@', '');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Photo Banner
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => _showImagePickerSheet(isCover: true),
                child: Container(
                  width: double.infinity,
                  height: 190.h,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF11111E),
                    gradient: coverUrl.isEmpty
                        ? const LinearGradient(
                            colors: [Color(0xFF0D0D1A), Color(0xFF1A1040)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                  ),
                  child: coverUrl.isNotEmpty
                      ? _buildProfileProductImage(coverUrl)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(14.r),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.white38,
                                size: 28.sp,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              "Add Cover Photo",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Edit cover floating button
              Positioned(
                top: 14.h,
                right: 14.w,
                child: GestureDetector(
                  onTap: () => _showImagePickerSheet(isCover: true),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 7.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: const Color(0xFF8B9BFF),
                          size: 14.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          "Edit Cover",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Avatar overlapping the bottom edge of the cover
              Positioned(
                bottom: -44.h,
                left: 20.w,
                child: GestureDetector(
                  onTap: () => _showImagePickerSheet(isCover: false),
                  child: Stack(
                    children: [
                      Container(
                        padding: EdgeInsets.all(3.r),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B9BFF), Color(0xFF22C55E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 16.r,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 44.r,
                          backgroundColor: const Color(0xFF0D0D1A),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(44.r),
                            child: profileUrl.isNotEmpty
                                ? SizedBox(
                                    width: 88.r,
                                    height: 88.r,
                                    child: _buildProfileProductImage(profileUrl),
                                  )
                                : Icon(
                                    Icons.person,
                                    color: Colors.white24,
                                    size: 44.sp,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 52.h),

          // Name, Username, Verified Badge, Rating, Bio
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Verified Badge Row
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        controller.name.value.isNotEmpty ? controller.name.value : "User",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (controller.isVerified.value || controller.sellerVerified.value) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: const Color(0xFF22C55E), size: 13.sp),
                            SizedBox(width: 4.w),
                            Text(
                              "Verified",
                              style: TextStyle(
                                color: const Color(0xFF22C55E),
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                
                if (displayUsername.isNotEmpty) ...[
                  SizedBox(height: 3.h),
                  Text(
                    "@$displayUsername",
                    style: TextStyle(
                      color: const Color(0xFF8B9BFF).withOpacity(0.85),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],

                if (controller.email.value.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, color: Colors.white38, size: 13.sp),
                      SizedBox(width: 5.w),
                      Text(
                        controller.email.value,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],

                if (controller.description.value.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    controller.description.value,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],

                SizedBox(height: 14.h),

                // Rating & Reviews Pill
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161626),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, color: const Color(0xFFFFB800), size: 16.sp),
                      SizedBox(width: 5.w),
                      Text(
                        controller.rating.value > 0
                            ? controller.rating.value.toStringAsFixed(1)
                            : "5.0",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Text("•", style: TextStyle(color: Colors.white24, fontSize: 12.sp)),
                      ),
                      Text(
                        "${controller.reviewsCount.value} Reviews",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  void _showImagePickerSheet({required bool isCover}) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Update ${isCover ? 'Cover' : 'Profile'} Photo",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceItem(
                  icon: Icons.camera_alt_rounded,
                  label: "Camera",
                  onTap: () {
                    Get.back();
                    controller.updateImage(
                      ImageSource.camera,
                      isCover: isCover,
                    );
                  },
                ),
                _buildSourceItem(
                  icon: Icons.photo_library_rounded,
                  label: "Gallery",
                  onTap: () {
                    Get.back();
                    controller.updateImage(
                      ImageSource.gallery,
                      isCover: isCover,
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: const Color(0xFF8B9BFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF8B9BFF), size: 32.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  void _showCoverOptions() {
    _showImagePickerSheet(isCover: true);
  }

  Widget _buildStatsRow() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF141422),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Obx(() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("ACTIVE", "${controller.activeCount.value}", const Color(0xFF8B9BFF), Icons.storefront_rounded),
          Container(height: 32.h, width: 1, color: Colors.white10),
          _buildStatItem("SOLD", "${controller.soldCount.value}", const Color(0xFF22C55E), Icons.shopping_bag_rounded, onTap: () => Get.toNamed(AppRoute.soldItems)),
          Container(height: 32.h, width: 1, color: Colors.white10),
          _buildStatItem("TRADES", "${controller.totalTrades.value}", const Color(0xFFFF8BFF), Icons.swap_horizontal_circle_rounded, onTap: () => Get.toNamed('/my_trades')),
        ],
      )),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color.withOpacity(0.8), size: 14.sp),
              SizedBox(width: 4.w),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(6.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(32.r),
      ),
      child: Row(
        children: List.generate(controller.tabs.length, (index) {
          return Expanded(
            child: Obx(() {
              final isSelected = controller.selectedTab.value == index;
              return GestureDetector(
                onTap: () => controller.changeTab(index),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF282C36)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(28.r),
                  ),
                  child: Text(
                    controller.tabs[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white38,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildListingsGrid() {
    return Obx(() {
      if (controller.isLoading.value) {
        return _buildListingsGridShimmer();
      }
      
      if (controller.userListings.isEmpty) {
        return CustomEmptyState(
          icon: Icons.inventory_2_outlined,
          title: "No Listings Found",
          description: "You haven't posted any items for sale or trade yet.",
        );
      }

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 16.w,
            mainAxisSpacing: 16.h,
          ),
          itemCount: controller.userListings.length,
          itemBuilder: (context, index) {
            final item = controller.userListings[index];
            final title = item['title'] ?? "";
            final priceVal = item['buyNowPrice'] ?? item['estValue'] ?? 0;
            final price = "\$${priceVal.toString()}";

            String imageUrl = "";
            final imagesList = item['images'];
            if (imagesList != null && imagesList is List && imagesList.isNotEmpty) {
              final imagePath = imagesList[0].toString();
              imageUrl = (imagePath.startsWith('http') || imagePath.startsWith('data:image/'))
                  ? imagePath
                  : "${ApiUrl.imageBaseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}";
            }

            final isLive = item['status'] == 'live' || item['status'] == 'active';
            final isSold = item['status'] == 'sold' || item['isSold'] == true;
            final hasTrade = item['allowTrade'] == true;

            return _buildListingCard(
              title,
              price,
              imageUrl,
              isLive: isLive,
              hasTrade: hasTrade,
              isSold: isSold,
              onTap: () {
                final Map<String, dynamic> itemWithSeller = Map<String, dynamic>.from(item);
                if (itemWithSeller['sellerId'] == null || itemWithSeller['sellerId'] is String) {
                  itemWithSeller['sellerId'] = {
                    "fullName": controller.name.value,
                    "image": controller.profileImageUrl.value,
                    "rating": controller.rating.value.toString(),
                    "address": "Verified Owner"
                  };
                }
                Get.toNamed('/trade_details', arguments: itemWithSeller);
              },
            );
          },
        ),
      );
    });
  }
  Widget _buildActivityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-filters
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: List.generate(controller.activityFilters.length, (index) {
              return Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: Obx(() {
                  final isSelected =
                      controller.selectedActivityFilter.value == index;
                  return GestureDetector(
                    onTap: () => controller.changeActivityFilter(index),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF8B9BFF)
                            : const Color(0xFF161622),
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      child: Text(
                        controller.activityFilters[index],
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white38,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
        SizedBox(height: 32.h),

        // Activity List
        Obx(() {
          if (controller.isActivityLoading.value) {
            return _buildActivityListShimmer();
          }

          final isPurchases = controller.selectedActivityFilter.value == 1;
          final List<dynamic> currentList = isPurchases 
              ? controller.purchasesList 
              : controller.notificationsList;

          if (currentList.isEmpty) {
            return SizedBox(
              height: 200.h,
              child: Center(
                child: Text(
                  isPurchases ? "No purchases made yet." : "No activity logs available.",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: List.generate(currentList.length, (index) {
                final item = currentList[index];
                
                String svgPath = "assets/icons/New Message.svg";
                String title = "";
                String subtitle = "";
                String timeAgo = "";

                if (isPurchases) {
                  svgPath = "assets/icons/Purchase Made.svg";
                  title = "Purchase Made";
                  final product = item['productId'] ?? item['product'] ?? item['item'];
                  String productTitle = 'Item';
                  if (product is Map) {
                    productTitle = product['title'] ?? product['name'] ?? 'Item';
                  } else if (item['productName'] != null) {
                    productTitle = item['productName'].toString();
                  } else if (item['title'] != null) {
                    productTitle = item['title'].toString();
                  }
                  
                  final amountDetails = item['amountDetails'];
                  dynamic amount;
                  if (amountDetails is Map) {
                    amount = amountDetails['totalPaid'] ?? amountDetails['itemSubtotal'];
                  }
                  amount ??= (item['totalAmount'] ?? item['amount'] ?? item['price']);

                  final amountText = amount != null ? " (\$${amount})" : "";
                  subtitle = "You bought $productTitle$amountText";
                  timeAgo = item['createdAt'] != null 
                      ? _formatTimestamp(item['createdAt'].toString())
                      : "Recently";
                } else {
                  final type = item['type'] ?? "";
                  if (type.toString().toLowerCase().contains('order')) {
                    svgPath = "assets/icons/Order Delivered.svg";
                  } else if (type.toString().toLowerCase().contains('trade')) {
                    svgPath = "assets/icons/Trade Completed.svg";
                  } else {
                    svgPath = "assets/icons/New Message.svg";
                  }
                  title = item['title'] ?? "Alert";
                  subtitle = item['text'] ?? item['message'] ?? "";
                  timeAgo = item['createdAt'] != null
                      ? _formatTimestamp(item['createdAt'].toString())
                      : "Just now";
                }

                return _buildActivityItem(
                  svgPath: svgPath,
                  title: title,
                  subtitle: subtitle,
                  time: timeAgo,
                  isFirst: index == 0,
                  isLast: index == currentList.length - 1,
                  onTap: () {
                    final itemId = item['_id'] ?? item['id'] ?? item['orderId'] ?? item;
                    Get.toNamed(AppRoute.trackOrder, arguments: itemId);
                  },
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final difference = DateTime.now().difference(dateTime);
      if (difference.inMinutes < 60) {
        return "${difference.inMinutes}m ago";
      } else if (difference.inHours < 24) {
        return "${difference.inHours}h ago";
      } else {
        return "${difference.inDays}d ago";
      }
    } catch (_) {
      return "Recently";
    }
  }

  Widget _buildActivityItem({
    IconData? icon,
    String? svgPath,
    required String title,
    required String subtitle,
    required String time,
    bool isFirst = false,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline Line & Icon
            Column(
              children: [
                Container(
                  width: 48.r,
                  height: 48.r,
                  padding: EdgeInsets.all(12.r),
                  decoration: const BoxDecoration(
                    color: Color(0xFF161622),
                    shape: BoxShape.circle,
                  ),
                  child: svgPath != null
                      ? SvgPicture.asset(
                          svgPath,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFFF8BFF),
                            BlendMode.srcIn,
                          ),
                        )
                      : Icon(icon, color: const Color(0xFFFF8BFF), size: 22.sp),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.w,
                      margin: EdgeInsets.symmetric(vertical: 4.h),
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 20.w),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 32.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRoleSwitcherCard(),
        SizedBox(height: 16.h),
        _buildSettingsSection("ACCOUNT", [
          _buildSettingsTile(
            svgPath: "assets/icons/Edit Profile.svg",
            title: "Edit Profile",
            showArrow: true,
            onTap: () => Get.toNamed(AppRoute.accountSettings),
          ),
          _buildSettingsTile(
            svgPath: "assets/icons/Username.svg",
            title: "Username",
            trailing: Obx(
              () => Text(
                controller.username.value,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ]),
        SizedBox(height: 32.h),
        _buildSettingsSection("PAYMENTS", [
          _buildSettingsTile(
            svgPath: "assets/icons/My Purchase.svg",
            title: "My Purchase",
            showArrow: true,
            onTap: () => Get.toNamed('/purchases'),
          ),
          _buildSettingsTile(
            svgPath: "assets/icons/My Trades.svg",
            title: "My Trades",
            showArrow: true,
            onTap: () => Get.toNamed('/my_trades'),
          ),
          _buildSettingsTile(
            svgPath: "assets/icons/My Purchase.svg",
            title: "Sold Items",
            showArrow: true,
            onTap: () => Get.toNamed(AppRoute.soldItems),
          ),
        ]),
        SizedBox(height: 32.h),
        _buildSettingsSection("SUPPORT", [
          _buildSettingsTile(
            svgPath: "assets/icons/Terms & Conditions.svg",
            title: "Terms & Conditions",
            showArrow: true,
            onTap: () => Get.toNamed(AppRoute.terms),
          ),
        ]),
        SizedBox(height: 48.h),

        // Logout Button
        GestureDetector(
          onTap: () => _showLogoutConfirmation(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Container(
              width: double.infinity,
              height: 56.h,
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A10),
                borderRadius: BorderRadius.circular(28.r),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: const Color(0xFFFF4B6E), size: 20.sp),
                  SizedBox(width: 10.w),
                  Text(
                    "Logout",
                    style: TextStyle(color: const Color(0xFFFF4B6E), fontSize: 15.sp, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSwitcherCard() {
    return Obx(() {
      final isSeller = controller.role.value == 'seller';
      final sellerVerified = controller.sellerVerified.value;
      final isLoading = controller.isSwitchingRole.value;

      // State 1: Buyer
      if (!isSeller) return _buildBuyerCard(isLoading);
      // State 2: Seller Pending
      if (!sellerVerified) return _buildPendingSellerCard();
      // State 3: Verified Seller
      return _buildVerifiedSellerCard();
    });
  }

  /// STATE 1 — Buyer: show CTA to apply as seller
  Widget _buildBuyerCard(bool isLoading) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1E36), Color(0xFF0D0D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.15), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF8B9BFF).withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(color: const Color(0xFF8B9BFF).withOpacity(0.10), shape: BoxShape.circle),
                child: Icon(Icons.shopping_bag_outlined, color: const Color(0xFF8B9BFF), size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buyer Account', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3.h),
                    Text('Browse, bid & buy from the platform', style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Divider(color: Colors.white.withOpacity(0.05)),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Want to sell?', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3.h),
                    Text('Apply to list products & host live streams.', style: TextStyle(color: Colors.white38, fontSize: 11.sp, height: 1.4)),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              GestureDetector(
                onTap: isLoading ? null : () => _showBecomeSeller(),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 11.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8B9BFF), Color(0xFF6C7BFF)]),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [BoxShadow(color: const Color(0xFF8B9BFF).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: isLoading
                      ? SizedBox(width: 16.r, height: 16.r, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_rounded, color: Colors.white, size: 14.sp),
                            SizedBox(width: 5.w),
                            Text('Apply Now', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w900)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// STATE 2 — Seller Pending: informational only, no action
  Widget _buildPendingSellerCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1200), Color(0xFF0D0D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.18), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFFFFB800).withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(color: const Color(0xFFFFB800).withOpacity(0.10), shape: BoxShape.circle),
                child: Icon(Icons.hourglass_top_rounded, color: const Color(0xFFFFB800), size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Seller Application', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w900)),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB800).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.28)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 5.r, height: 5.r, decoration: const BoxDecoration(color: Color(0xFFFFB800), shape: BoxShape.circle)),
                              SizedBox(width: 4.w),
                              Text('PENDING', style: TextStyle(color: const Color(0xFFFFB800), fontSize: 9.sp, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Text('Seller account request submitted. Please wait for approval.', style: TextStyle(color: Colors.white54, fontSize: 12.sp, height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withOpacity(0.05),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: const Color(0xFFFFB800), size: 15.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Admin review is in progress. You will be notified once your seller account is approved.',
                    style: TextStyle(color: const Color(0xFFFFB800).withOpacity(0.85), fontSize: 11.sp, fontWeight: FontWeight.w600, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _buildAccessChip(Icons.shopping_bag_outlined, 'Buy', true),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.gavel_rounded, 'Bid', true),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.storefront_rounded, 'Sell', false),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.videocam_outlined, 'Stream', false),
            ],
          ),
        ],
      ),
    );
  }

  /// STATE 3 — Verified Seller: all features active
  Widget _buildVerifiedSellerCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12003A), Color(0xFF0D0D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.22), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF8B9BFF).withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(color: const Color(0xFF8B9BFF).withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(Icons.storefront_rounded, color: const Color(0xFF8B9BFF), size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Seller Account', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w900)),
                        SizedBox(width: 6.w),
                        Icon(Icons.verified_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text('Verified Merchant · All features unlocked', style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 12.sp, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFF8B9BFF).withOpacity(0.06),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: const Color(0xFF8B9BFF), size: 15.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Your seller account is fully active. You can list products and host live auction streams.',
                    style: TextStyle(color: const Color(0xFF8B9BFF).withOpacity(0.9), fontSize: 11.sp, fontWeight: FontWeight.w600, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _buildAccessChip(Icons.shopping_bag_outlined, 'Buy', true),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.gavel_rounded, 'Bid', true),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.storefront_rounded, 'Sell', true),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.videocam_outlined, 'Stream', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccessChip(IconData icon, String label, bool active) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8B9BFF).withOpacity(0.08) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: active ? const Color(0xFF8B9BFF).withOpacity(0.18) : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14.sp, color: active ? const Color(0xFF8B9BFF) : Colors.white24),
            SizedBox(height: 3.h),
            Text(label, style: TextStyle(color: active ? const Color(0xFF8B9BFF) : Colors.white24, fontSize: 9.sp, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  void _showBecomeSeller() {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF11111A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(color: const Color(0xFF8B9BFF).withOpacity(0.10), shape: BoxShape.circle),
                child: Icon(Icons.storefront_rounded, color: const Color(0xFF8B9BFF), size: 32.sp),
              ),
              SizedBox(height: 18.h),
              Text('Become a Seller?', style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              SizedBox(height: 10.h),
              Text(
                'Submit your seller application for admin review. Once approved, you can list products and host live auction streams.',
                style: TextStyle(color: Colors.white60, fontSize: 13.sp, height: 1.5),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(color: const Color(0xFFFFB800).withOpacity(0.06), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.15))),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: const Color(0xFFFFB800), size: 14.sp),
                    SizedBox(width: 8.w),
                    Expanded(child: Text('Approval is not instant. Admin reviews may take some time.', style: TextStyle(color: const Color(0xFFFFB800).withOpacity(0.85), fontSize: 11.sp, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        controller.switchRole('seller');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: Text('Apply Now', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900)),
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


  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 24.w, bottom: 16.h),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white24,
              fontSize: 11.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF11111A),
            borderRadius: BorderRadius.circular(32.r),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required String svgPath,
    required String title,
    bool showArrow = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 22.h),
        child: Row(
          children: [
            SvgPicture.asset(
              svgPath,
              width: 24.w,
              colorFilter: const ColorFilter.mode(
                Color(0xFF8B9BFF),
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 20.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (showArrow)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white24,
                size: 20.sp,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingCard(
    String title,
    String price,
    String imageUrl, {
    bool isLive = false,
    bool hasTrade = false,
    bool isSold = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.r),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: _buildProfileProductImage(imageUrl),
                  ),
                ),
                if (isLive)
                  Positioned(
                    top: 12.h,
                    left: 12.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B9BFF),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6.r,
                            height: 6.r,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            "LIVE",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isSold)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24.r),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          "SOLD",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: const Color(0xFF8B9BFF),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (hasTrade)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E1E5D),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          "TRADE",
                          style: TextStyle(
                            color: const Color(0xFF8B9BFF),
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w900,
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
  );
}

  Widget _buildProfileProductImage(String imgStr, {BoxFit fit = BoxFit.cover}) {
    if (imgStr.isEmpty) {
      return const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white24,
          size: 32,
        ),
      );
    }
    
    if (imgStr.startsWith('data:image/') && imgStr.contains('base64,')) {
      try {
        final base64Content = imgStr.split('base64,').last;
        final bytes = base64Decode(base64Content);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white24,
              size: 32,
            ),
          ),
        );
      } catch (_) {
        return const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.white24,
            size: 32,
          ),
        );
      }
    }
    
    final cleanUrl = imgStr.startsWith('http')
        ? imgStr
        : "${ApiUrl.imageBaseUrl}${imgStr.startsWith('/') ? imgStr : '/$imgStr'}";

    return Image.network(
      cleanUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white24,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildProfileHeaderShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomShimmer.rectangular(height: 170.h),
        SizedBox(height: 50.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomShimmer.circular(width: 90.r, height: 90.r),
              SizedBox(height: 16.h),
              CustomShimmer.rectangular(height: 22.h, width: 180.w),
              SizedBox(height: 8.h),
              CustomShimmer.rectangular(height: 14.h, width: 100.w),
              SizedBox(height: 12.h),
              CustomShimmer.rectangular(height: 14.h, width: 250.w),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomShimmer.rectangular(height: 50.h, width: 100.w),
                  CustomShimmer.rectangular(height: 50.h, width: 100.w),
                  CustomShimmer.rectangular(height: 50.h, width: 100.w),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListingsGridShimmer() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16.w,
          mainAxisSpacing: 16.h,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: const Color(0xFF11111A),
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: const CustomShimmer.rectangular(height: double.infinity),
                  ),
                ),
                SizedBox(height: 12.h),
                CustomShimmer.rectangular(height: 14.h, width: 100.w),
                SizedBox(height: 8.h),
                CustomShimmer.rectangular(height: 12.h, width: 60.w),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityListShimmer() {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              CustomShimmer.circular(width: 48.r, height: 48.r),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomShimmer.rectangular(height: 14.h, width: 180.w),
                    SizedBox(height: 6.h),
                    CustomShimmer.rectangular(height: 12.h, width: 120.w),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF11111A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Text(
          "Sign Out",
          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
        ),
        content: Text(
          "Are you sure you want to sign out of your account?",
          style: TextStyle(color: Colors.white54, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text("Cancel", style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4B6E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text("Sign Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestProfileView() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          // Guest Avatar
          Container(
            width: 100.r,
            height: 100.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.3), width: 2),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: const Color(0xFF8B9BFF),
              size: 54.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            "Guest User",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            "You are currently browsing as a guest. Sign in or create an account to manage your profile, host live auctions, bid, and trade.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13.sp,
              height: 1.5,
            ),
          ),
          SizedBox(height: 32.h),
          // Log In Button
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton(
              onPressed: () => Get.toNamed(AppRoute.login),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B9BFF),
                foregroundColor: const Color(0xFF0F0B1E),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.r)),
              ),
              child: Text(
                "Log In",
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          // Sign Up Button
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: OutlinedButton(
              onPressed: () => Get.toNamed(AppRoute.signUp),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.r)),
              ),
              child: Text(
                "Create Account",
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SizedBox(height: 36.h),
          // Additional links
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: Color(0xFF8B9BFF)),
                  title: const Text("Terms & Conditions", style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                  onTap: () => Get.toNamed(AppRoute.terms),
                ),
              ],
            ),
          ),
          SizedBox(height: 100.h),
        ],
      ),
    );
  }
}
