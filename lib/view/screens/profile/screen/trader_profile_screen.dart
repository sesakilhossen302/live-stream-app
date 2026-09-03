import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../../../../core/app_route.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../messages/controller/messages_controller.dart';
import '../controller/trader_profile_controller.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../../../global/controllers/safety_controller.dart';
import '../../../../global/helper/share_helper.dart';

class TraderProfileScreen extends GetView<TraderProfileController> {
  const TraderProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(TraderProfileController());
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(context),
        body: RefreshIndicator(
          color: const Color(0xFF8B9BFF),
          backgroundColor: const Color(0xFF161622),
          onRefresh: () => controller.refreshAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 32.h),
                Obx(() => _buildProfileHeader()),
                SizedBox(height: 32.h),
                _buildStatsRow(),
                SizedBox(height: 32.h),
                _buildActionButtons(),
                SizedBox(height: 32.h),
                Obx(() => _buildUpcomingShowsSection()),
                SizedBox(height: 40.h),
                Obx(() => _buildTabs()),
                SizedBox(height: 24.h),
                Obx(() => _buildTabContent()),
                SizedBox(height: 80.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── APP BAR ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
        onPressed: () => Get.back(),
      ),
      title: Obx(() => Text(
            controller.displayName,
            style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w900),
          )),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.share_outlined, color: Colors.white, size: 22.sp),
          onPressed: () {
            ShareHelper.shareProfile(
              context: context,
              username: controller.displayName,
              traderId: controller.traderId.value,
              rating: controller.rating.value > 0 ? controller.rating.value.toStringAsFixed(1) : null,
            );
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: Colors.white, size: 24.sp),
          color: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          onSelected: (value) {
            if (value == 'report') {
              SafetyController.showReportDialog(
                context,
                contentType: 'user',
                reportedUser: controller.traderId.value,
                targetName: controller.displayName,
              );
            } else if (value == 'block') {
              SafetyController.showBlockUserDialog(
                context,
                userId: controller.traderId.value,
                userName: controller.displayName,
                onBlocked: () => Get.back(),
              );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, color: const Color(0xFFFF4B4B), size: 18.sp),
                  SizedBox(width: 12.w),
                  Text("Report User", style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block_rounded, color: const Color(0xFFFF4B4B), size: 18.sp),
                  SizedBox(width: 12.w),
                  Text("Block User", style: TextStyle(color: const Color(0xFFFF4B4B), fontSize: 13.sp, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── PROFILE HEADER ─────────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    if (controller.isLoading.value && controller.traderName.value.isEmpty) {
      return _buildHeaderShimmer();
    }
    if (controller.hasError.value && controller.traderName.value.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.white38, size: 48.sp),
            SizedBox(height: 12.h),
            Text(controller.errorMessage.value,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 14.sp)),
            SizedBox(height: 16.h),
            GestureDetector(
              onTap: () => controller.fetchTraderProfile(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF),
                    borderRadius: BorderRadius.circular(20.r)),
                child: Text('Retry',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      );
    }

    final avatar = controller.displayAvatar;
    final String resolvedAvatarUrl = (avatar.isNotEmpty && !avatar.startsWith('http') && !avatar.startsWith('data:image/'))
        ? "${ApiUrl.imageBaseUrl}${avatar.startsWith('/') ? avatar : '/$avatar'}"
        : avatar;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Avatar
            Container(
              width: 120.r,
              height: 120.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF8B9BFF).withOpacity(0.4), width: 3),
              ),
              child: ClipOval(
                child: Container(
                  color: const Color(0xFF1E1E2C),
                  width: 120.r,
                  height: 120.r,
                  child: Builder(
                    builder: (context) {
                      if (resolvedAvatarUrl.isEmpty) {
                        return Icon(Icons.person, color: Colors.white38, size: 48.sp);
                      }
                      if (resolvedAvatarUrl.startsWith('data:image/') && resolvedAvatarUrl.contains('base64,')) {
                        try {
                          final bytes = base64Decode(resolvedAvatarUrl.split('base64,').last);
                          return Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.white38, size: 48.sp),
                          );
                        } catch (_) {
                          return Icon(Icons.person, color: Colors.white38, size: 48.sp);
                        }
                      }
                      return Image.network(
                        resolvedAvatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.white38, size: 48.sp),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (controller.isVerified.value)
              Positioned(
                bottom: 4,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: const BoxDecoration(
                      color: Color(0xFF0F0B1E), shape: BoxShape.circle),
                  child: Icon(Icons.verified,
                      color: const Color(0xFF8B9BFF), size: 22.sp),
                ),
              ),
          ],
        ),
        SizedBox(height: 16.h),

        // Name + Verified Badge Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                controller.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5),
              ),
            ),
            if (controller.isVerified.value) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: const Color(0xFF22C55E), size: 12.sp),
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

        if (controller.displayUsername.isNotEmpty) ...[
          SizedBox(height: 3.h),
          Text(
            controller.displayUsername,
            style: TextStyle(
                color: const Color(0xFF8B9BFF),
                fontSize: 14.sp,
                fontWeight: FontWeight.w800),
          ),
        ],

        if (controller.displayEmail.isNotEmpty) ...[
          SizedBox(height: 5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email_outlined, color: Colors.white38, size: 13.sp),
              SizedBox(width: 6.w),
              Text(
                controller.displayEmail,
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],

        SizedBox(height: 10.h),

        // Role + Member Since row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (controller.traderRole.value.isNotEmpty)
              _buildBadge(
                  controller.traderRole.value.toUpperCase(),
                  const Color(0xFF8B9BFF)),
            if (controller.traderRole.value.isNotEmpty &&
                controller.memberSince.value.isNotEmpty)
              SizedBox(width: 8.w),
            if (controller.memberSince.value.isNotEmpty)
              _buildBadge(
                  'Since ${controller.memberSince.value}',
                  Colors.white12),
          ],
        ),

        SizedBox(height: 14.h),

        // Bio
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Text(
            controller.displayBio,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white60,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                height: 1.5),
          ),
        ),

        SizedBox(height: 16.h),

        // Rating & Reviews Pill
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFF161626),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: const Color(0xFFFFB800), size: 16.sp),
              SizedBox(width: 6.w),
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
                "${controller.reviewCount.value} Reviews",
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
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color == Colors.white12 ? Colors.white.withOpacity(0.08) : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color == Colors.white12
                ? Colors.white70
                : const Color(0xFF8B9BFF),
            fontSize: 10.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildHeaderShimmer() {
    return Column(
      children: [
        _shimmerBox(120.r, 120.r, circle: true),
        SizedBox(height: 16.h),
        _shimmerBox(20.h, 160.w),
        SizedBox(height: 10.h),
        _shimmerBox(14.h, 260.w),
        SizedBox(height: 6.h),
        _shimmerBox(14.h, 220.w),
      ],
    );
  }

  // ─── STATS ROW ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Obx(() {
      final stats = [
        {
          'value': controller.totalTrades.value > 0
              ? controller.totalTrades.value.toString()
              : '—',
          'label': 'TRADES',
          'icon': Icons.swap_horiz_rounded,
        },
        {
          'value': controller.ratingDisplay,
          'label': 'RATING',
          'icon': Icons.star_rounded,
        },
        {
          'value': controller.positiveDisplay,
          'label': 'POSITIVE',
          'icon': Icons.thumb_up_rounded,
        },
        {
          'value': controller.followersCount.value.toString(),
          'label': 'FOLLOWERS',
          'icon': Icons.people_rounded,
        },
      ];

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Row(
          children: stats
              .map((s) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: _buildStatCard(
                        s['value'] as String,
                        s['label'] as String,
                        s['icon'] as IconData,
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
    });
  }

  Widget _buildStatCard(String val, String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF8B9BFF), size: 18.sp),
          SizedBox(height: 6.h),
          Text(val,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900)),
          SizedBox(height: 2.h),
          Text(label,
              style: TextStyle(
                  color: Colors.white24,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ─── ACTION BUTTONS ─────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    final name = controller.displayName;
    final avatar = controller.displayAvatar;
    final traderId = controller.traderId.value;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        children: [
          // Message Button
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (traderId.isNotEmpty) {
                  final mc = Get.put(MessagesController());
                  final chatId = await mc.createChatRoom(traderId);
                  if (chatId != null && chatId.isNotEmpty) {
                    Get.toNamed(AppRoute.messageDetails, arguments: {
                      'chatId': chatId,
                      'name': name,
                      'avatar': avatar,
                    });
                  } else {
                    Get.toNamed(AppRoute.messageDetails, arguments: {
                      'chatId': 'mock_room_1',
                      'name': name,
                      'avatar': avatar,
                    });
                  }
                }
              },
              child: Container(
                height: 52.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B9BFF),
                  borderRadius: BorderRadius.circular(28.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.message_rounded, color: Colors.black, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text('Message',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),

          // Follow / Unfollow Button
          Obx(() => Expanded(
            child: GestureDetector(
              onTap: () => controller.toggleFollow(),
              child: Container(
                height: 52.h,
                decoration: BoxDecoration(
                  color: controller.isFollowing.value
                      ? const Color(0xFF1C1C28)
                      : const Color(0xFF8B9BFF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(
                    color: controller.isFollowing.value
                        ? Colors.white12
                        : const Color(0xFF8B9BFF).withOpacity(0.5),
                  ),
                ),
                child: controller.isFollowLoading.value
                    ? Center(
                        child: SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: const Color(0xFF8B9BFF),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            controller.isFollowing.value
                                ? Icons.person_remove_rounded
                                : Icons.person_add_rounded,
                            color: controller.isFollowing.value
                                ? Colors.white38
                                : const Color(0xFF8B9BFF),
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            controller.isFollowing.value
                                ? 'Following'
                                : 'Follow',
                            style: TextStyle(
                                color: controller.isFollowing.value
                                    ? Colors.white38
                                    : const Color(0xFF8B9BFF),
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  // ─── TABS ───────────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    final tabs = [
      {'label': 'Collection', 'count': controller.products.length},
      {'label': 'Bids', 'count': controller.recentBids.length},
      {'label': 'Reviews', 'count': controller.reviews.length},
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        children: List.generate(
          tabs.length,
          (i) => Expanded(
            child: GestureDetector(
              onTap: () => controller.setTab(i),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tabs[i]['label'] as String,
                        style: TextStyle(
                          color: controller.activeTab.value == i
                              ? Colors.white
                              : Colors.white24,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ((tabs[i]['count'] as int) > 0) ...[
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: controller.activeTab.value == i
                                ? const Color(0xFF8B9BFF)
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            (tabs[i]['count'] as int).toString(),
                            style: TextStyle(
                                color: controller.activeTab.value == i
                                    ? Colors.black
                                    : Colors.white38,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 10.h),
                  if (controller.activeTab.value == i)
                    Container(
                        height: 2.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B9BFF),
                          borderRadius: BorderRadius.circular(2.r),
                        ))
                  else
                    Container(height: 2.h, color: Colors.transparent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── TAB CONTENT ────────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    switch (controller.activeTab.value) {
      case 0:
        return _buildCollectionGrid();
      case 1:
        return _buildBidsList();
      case 2:
        return _buildReviewsList();
      default:
        return const SizedBox.shrink();
    }
  }

  // Collection Grid
  Widget _buildCollectionGrid() {
    if (controller.isProductsLoading.value) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 16.w,
          childAspectRatio: 0.72,
          children: List.generate(4, (_) => _buildProductShimmer()),
        ),
      );
    }
    if (controller.products.isEmpty) {
      return _buildEmptyState(
          'No items in collection', Icons.inventory_2_outlined);
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 16.h,
        crossAxisSpacing: 16.w,
        childAspectRatio: 0.72,
        children: controller.products
            .map((p) => _buildProductCard(p))
            .toList(),
      ),
    );
  }

  Widget _buildProductShimmer() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(20.r),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final title = product['title'] ?? product['name'] ?? 'Item';
    final double price =
        (product['buyNowPrice'] ?? product['price'] ?? 0).toDouble();
    final List images = product['images'] ?? [];
    final String rawImg = images.isNotEmpty ? images[0].toString() : '';
    final String img = (rawImg.isNotEmpty && !rawImg.startsWith('http') && !rawImg.startsWith('data:image/'))
        ? "${ApiUrl.imageBaseUrl}${rawImg.startsWith('/') ? rawImg : '/$rawImg'}"
        : rawImg;
    final bool allowTrade = product['allowTrade'] == true;
    final bool isSold = (product['status'] ?? '') == 'sold';
    final String productId = product['_id'] ?? product['id'] ?? '';

    return GestureDetector(
      onTap: () {
        final Map<String, dynamic> argMap = Map<String, dynamic>.from(product);
        argMap['productId'] = productId;
        argMap['sellerId'] = {
          '_id': controller.traderId.value,
          'fullName': controller.traderName.value,
          'name': controller.traderName.value,
          'avatar': controller.traderAvatar.value,
          'profile': controller.traderAvatar.value,
          'image': controller.traderAvatar.value,
          'bio': controller.traderBio.value,
          'rating': controller.rating.value > 0 ? controller.rating.value.toString() : '4.8',
        };
        Get.toNamed(AppRoute.tradeDetails, arguments: argMap);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20.r)),
                      color: const Color(0xFF1E1E2C),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: _buildDetailsProductImage(img, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  if (isSold)
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 6.h),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(10.r)),
                        child: Text('SOLD',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  if (allowTrade && !isSold)
                    Positioned(
                      top: 8.h,
                      left: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                            color: const Color(0xFFD677FF).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(8.r)),
                        child: Text('TRADE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w900)),
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
                  Text(title,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 6.h),
                  Text(
                    '\$${price.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: const Color(0xFF8B9BFF),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bids List
  Widget _buildBidsList() {
    if (controller.isBidsLoading.value) {
      return Column(
        children: List.generate(
            3, (_) => _shimmerBox(72.h, double.infinity, margin: 16.w)),
      );
    }
    if (controller.recentBids.isEmpty) {
      return _buildEmptyState('No recent bids', Icons.gavel_rounded);
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      itemCount: controller.recentBids.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (_, i) => _buildBidCard(controller.recentBids[i]),
    );
  }

  Widget _buildBidCard(Map<String, dynamic> bid) {
    final senderProduct = bid['senderProductId'];
    final receiverProduct = bid['receiverProductId'];
    final String sTitle = senderProduct is Map
        ? (senderProduct['title'] ?? 'Item')
        : 'Trade Item';
    final String rTitle = receiverProduct is Map
        ? (receiverProduct['title'] ?? 'Item')
        : 'Trade Item';
    final String status = bid['status'] ?? 'pending';
    final Color statusColor = status == 'accepted'
        ? const Color(0xFF4CAF50)
        : status == 'declined'
            ? const Color(0xFFFF5252)
            : const Color(0xFFFFB74D);

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offered: $sTitle',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: 4.h),
                Text('For: $rTitle',
                    style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                  color: statusColor,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  // Reviews List
  Widget _buildReviewsList() {
    if (controller.isReviewsLoading.value) {
      return Column(
        children: List.generate(
            3, (_) => _shimmerBox(90.h, double.infinity, margin: 16.w)),
      );
    }
    if (controller.reviews.isEmpty) {
      return _buildEmptyState('No reviews yet', Icons.star_border_rounded);
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      itemCount: controller.reviews.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (_, i) => _buildReviewCard(controller.reviews[i]),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final int stars = (review['rating'] ?? 0) as int;
    final String comment = review['comment'] ?? review['text'] ?? '';
    final reviewer = review['reviewerId'] ?? review['reviewer'];
    final String reviewerName = reviewer is Map
        ? (reviewer['fullName'] ?? reviewer['name'] ?? 'Anonymous')
        : 'Anonymous';
    final String reviewerAvatar = reviewer is Map
        ? (reviewer['avatar'] ?? reviewer['profileImage'] ?? '')
        : '';
    final String createdAt = review['createdAt'] ?? '';
    String dateLabel = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateLabel = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor: const Color(0xFF1E1E2C),
                backgroundImage: reviewerAvatar.isNotEmpty
                    ? NetworkImage(reviewerAvatar)
                    : null,
                child: reviewerAvatar.isEmpty
                    ? Icon(Icons.person, color: Colors.white38, size: 18.sp)
                    : null,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reviewerName,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700)),
                    if (dateLabel.isNotEmpty)
                      Text(dateLabel,
                          style: TextStyle(
                              color: Colors.white38, fontSize: 10.sp)),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFFD700),
                    size: 14.sp,
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(comment,
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.sp,
                    height: 1.5,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(String msg, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 56.h),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: Colors.white24, size: 44.sp),
            SizedBox(height: 14.h),
            Text(msg,
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double height, double width,
      {bool circle = false, double margin = 0}) {
    if (circle) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: margin, vertical: margin > 0 ? 6.h : 0),
        child: CustomShimmer.circular(width: width, height: height),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margin, vertical: margin > 0 ? 6.h : 0),
      child: CustomShimmer.rectangular(height: height, width: width),
    );
  }

  Widget _buildDetailsProductImage(String imgStr, {BoxFit fit = BoxFit.cover}) {
    if (imgStr.isEmpty) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: Center(
          child: Icon(Icons.image_outlined, color: Colors.white12, size: 32.sp),
        ),
      );
    }
    if (imgStr.startsWith('data:image/') && imgStr.contains('base64,')) {
      try {
        final bytes = base64Decode(imgStr.split('base64,').last);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF1A1A2E),
            child: Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white12, size: 32.sp),
            ),
          ),
        );
      } catch (_) {
        return Container(
          color: const Color(0xFF1A1A2E),
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white12, size: 32.sp),
          ),
        );
      }
    }
    final cleanUrl = imgStr.startsWith('http') ? imgStr : "${ApiUrl.imageBaseUrl}${imgStr.startsWith('/') ? imgStr : '/$imgStr'}";
    return Image.network(
      cleanUrl,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF1A1A2E),
        child: Center(
          child: Icon(Icons.image_not_supported_outlined, color: Colors.white12, size: 32.sp),
        ),
      ),
    );
  }

  // ─── UPCOMING SHOWS SECTION (Feature 5) ──────────────────────────────────
  Widget _buildUpcomingShowsSection() {
    if (controller.isUpcomingShowsLoading.value && controller.upcomingShows.isEmpty) {
      return const SizedBox.shrink();
    }
    if (controller.upcomingShows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 16.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B9BFF),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    "UPCOMING SHOWS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B9BFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      "${controller.upcomingShows.length}",
                      style: TextStyle(
                        color: const Color(0xFF8B9BFF),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoute.allLiveShows),
                child: Text(
                  "View all",
                  style: TextStyle(
                    color: const Color(0xFF8B9BFF),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          height: 230.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            itemCount: controller.upcomingShows.length,
            itemBuilder: (context, index) {
              final show = controller.upcomingShows[index];
              return _buildShowCard(show);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShowCard(Map<String, dynamic> show) {
    final String showId = (show['id'] ?? show['_id'] ?? '').toString();
    final String title = (show['title'] ?? show['name'] ?? 'Upcoming Live Stream').toString();
    final String scheduledTime = (show['scheduledTime'] ?? show['scheduledAt'] ?? 'Tomorrow, 8:00 PM').toString();
    final String thumbnail = (show['thumbnail'] ?? show['coverImage'] ?? show['image'] ?? '').toString();
    final String category = (show['category'] ?? 'Collectibles').toString();
    final bool isLive = show['isLive'] == true || show['status'] == 'live';

    return GestureDetector(
      onTap: () {
        if (isLive) {
          Get.toNamed(AppRoute.viewerLive, arguments: show);
        } else {
          controller.toggleReminder(showId);
        }
      },
      child: Container(
        width: 250.w,
        margin: EdgeInsets.only(right: 14.w),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Badges
            Stack(
              children: [
                SizedBox(
                  height: 115.h,
                  width: double.infinity,
                  child: thumbnail.isNotEmpty
                      ? _buildDetailsProductImage(thumbnail, fit: BoxFit.cover)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF2A2A40), Color(0xFF161622)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Icon(Icons.live_tv_rounded, color: Colors.white24, size: 36.sp),
                          ),
                        ),
                ),
                // Gradient overlay for text readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Status Badge (SCHEDULED or LIVE)
                Positioned(
                  top: 10.h,
                  left: 10.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isLive ? const Color(0xFFFF4B6E) : Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: isLive ? Colors.transparent : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6.r,
                          height: 6.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLive ? Colors.white : const Color(0xFF8B9BFF),
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          isLive ? "LIVE NOW" : "SCHEDULED",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Reminder Bell Button
                Positioned(
                  top: 10.h,
                  right: 10.w,
                  child: Obx(() {
                    final isReminded = controller.remindedShowIds.contains(showId);
                    return GestureDetector(
                      onTap: () => controller.toggleReminder(showId),
                      child: Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: isReminded ? const Color(0xFF8B9BFF) : Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isReminded ? Colors.transparent : Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          isReminded ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                          color: isReminded ? const Color(0xFF0F172A) : Colors.white,
                          size: 14.sp,
                        ),
                      ),
                    );
                  }),
                ),
                // Category pill bottom-left on thumbnail
                Positioned(
                  bottom: 8.h,
                  left: 10.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B9BFF).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Card Body (Title & Time)
            Padding(
              padding: EdgeInsets.all(12.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: const Color(0xFF8B9BFF), size: 13.sp),
                      SizedBox(width: 5.w),
                      Expanded(
                        child: Text(
                          scheduledTime,
                          style: TextStyle(
                            color: const Color(0xFF8B9BFF),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
}

