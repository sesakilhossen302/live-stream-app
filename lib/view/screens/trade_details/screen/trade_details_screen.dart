import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../../../../global/widgets/custom_background.dart';
import '../controller/trade_details_controller.dart';
import '../../discover/controller/discover_controller.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../global/helper/auth_guard.dart';
import '../../../../global/helper/share_helper.dart';

class TradeDetailsScreen extends GetView<TradeDetailsController> {
  const TradeDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final detailsController = Get.put(TradeDetailsController());
    if (Get.arguments != null && Get.arguments is Map) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        detailsController.product.assignAll(Map<String, dynamic>.from(Get.arguments));
        detailsController.currentImageIndex.value = 0;
      });
    }
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: Text("Trade Details", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: () {
                final product = detailsController.product;
                final title = (product['title'] ?? product['name'] ?? 'Collectible Item').toString();
                final priceVal = product['buyNowPrice'] ?? product['price'] ?? product['estValue'] ?? '0';
                final pId = (product['_id'] ?? product['id'] ?? detailsController.productId).toString();
                ShareHelper.shareTrade(
                  context: context,
                  title: title,
                  priceOrValue: "\$$priceVal",
                  productId: pId,
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Obx(() {
              final product = controller.product;

              final dynamic categoryRaw = product['category'];
              String category = '';
              if (categoryRaw is Map) {
                category = categoryRaw['name']?.toString() ?? '';
              } else if (categoryRaw != null) {
                category = categoryRaw.toString();
              }

              final condition = (product['condition'] ?? '').toString();
              final title = product['title'] ?? '';
              final description = product['description'] ?? '';
              final estValue = product['estValue'] ?? product['buyNowPrice'] ?? '';
              final buyNowPrice = product['buyNowPrice'];
              final allowTrade = product['allowTrade'];
              final lookingFor = product['lookingFor'] ?? '';
              final minValue = product['minValue'];
              final maxValue = product['maxValue'];
              final targetCategory = product['targetCategory'] ?? '';
              final createdAt = product['createdAt'] ?? '';

              // Parse all extra specification fields dynamically
              final List<MapEntry<String, String>> extraSpecs = [];
              const knownKeys = {
                '_id', 'id', 'title', 'description', 'category', 'condition',
                'images', 'estValue', 'buyNowPrice', 'allowTrade', 'lookingFor',
                'minValue', 'maxValue', 'targetCategory', 'sellerId', 'isSold',
                'status', 'createdAt', 'updatedAt', '__v', 'rating', 'reviewsCount',
                'isFeatured', 'is_featured', 'featured',
              };
              product.forEach((key, value) {
                if (!knownKeys.contains(key) && value != null && value.toString().trim().isNotEmpty) {
                  extraSpecs.add(MapEntry(key, value.toString()));
                }
              });

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Image Gallery ──────────────────────────────────
                    _buildImageGallery(product),

                    Padding(
                      padding: EdgeInsets.all(24.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Category & Condition chips ─────────────
                          if (category.isNotEmpty || condition.isNotEmpty)
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 6.h,
                              children: [
                                if (category.isNotEmpty) _buildChip(category.toUpperCase(), const Color(0xFF8B9BFF)),
                                if (condition.isNotEmpty) _buildChip(condition.toUpperCase(), const Color(0xFF9155FF)),
                              ],
                            ),
                          SizedBox(height: 12.h),

                          // ── Title ──────────────────────────────────
                          if (title.isNotEmpty)
                            Text(
                              title,
                              style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.w900, height: 1.25),
                            ),

                          // ── Pricing Row ────────────────────────────
                          if (estValue.toString().isNotEmpty) ...[
                            SizedBox(height: 14.h),
                            _buildPricingRow(estValue: estValue.toString(), buyNowPrice: buyNowPrice?.toString()),
                          ],

                          SizedBox(height: 28.h),

                          // ── Seller Card ────────────────────────────
                          _buildDynamicTraderCard(product),

                          SizedBox(height: 28.h),

                          // ── Offering Box ───────────────────────────
                          _buildTradeBox(
                            title: "OFFERING",
                            name: title.isNotEmpty ? title : "This Item",
                            subName: condition.isNotEmpty ? "${condition.toUpperCase()} condition" : "See description",
                            isOffering: true,
                          ),

                          Center(
                            child: Container(
                              height: 44.h,
                              width: 44.h,
                              margin: EdgeInsets.symmetric(vertical: 10.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF282C36),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10.r)],
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  "assets/icons/updaont.svg",
                                  width: 20.sp,
                                  height: 20.sp,
                                  colorFilter: const ColorFilter.mode(Color(0xFF8B9BFF), BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ),

                          // ── Looking For Box ────────────────────────
                          _buildTradeBox(
                            title: "LOOKING FOR",
                            name: lookingFor.isNotEmpty ? lookingFor : "Equal Value Swaps",
                            subName: estValue.toString().isNotEmpty ? "Est. Value: \$$estValue" : "Open to offers",
                            isOffering: false,
                            badge: targetCategory.isNotEmpty ? targetCategory.toUpperCase() : (allowTrade == true ? "ANY CATEGORY" : null),
                          ),

                          SizedBox(height: 28.h),

                          // ── Description ────────────────────────────
                          if (description.isNotEmpty) ...[
                            _buildSectionLabel("DESCRIPTION"),
                            SizedBox(height: 12.h),
                            Text(
                              description,
                              style: TextStyle(color: Colors.white60, fontSize: 14.sp, height: 1.65, fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 28.h),
                          ],

                          // ── Specifications / Details ───────────────
                          _buildSectionLabel("PRODUCT DETAILS"),
                          SizedBox(height: 14.h),
                          _buildSpecGrid(product, category, condition, estValue, buyNowPrice, allowTrade, minValue, maxValue, targetCategory, createdAt),

                          // ── Extra dynamic fields ───────────────────
                          if (extraSpecs.isNotEmpty) ...[
                            SizedBox(height: 20.h),
                            _buildSectionLabel("ADDITIONAL INFO"),
                            SizedBox(height: 14.h),
                            _buildExtraSpecsGrid(extraSpecs),
                          ],

                          SizedBox(height: 28.h),

                          // ── Trade Preferences ──────────────────────
                          _buildSectionLabel("TRADE PREFERENCES"),
                          SizedBox(height: 14.h),
                          _buildTradePreferences(product, allowTrade, minValue, maxValue, targetCategory, lookingFor),

                          SizedBox(height: 28.h),

                          // ── Verification ───────────────────────────
                          _buildSectionLabel("VERIFICATION"),
                          SizedBox(height: 14.h),
                          Row(
                            children: [
                              Expanded(child: _buildVerificationCard(null, "Platform Verified", "100% Secure Auth", iconData: Icons.shield_outlined)),
                              SizedBox(width: 16.w),
                              Expanded(child: _buildVerificationCard("assets/icons/Direct Trade-icons.svg", "Direct Trade", "Peer-to-peer")),
                            ],
                          ),

                          SizedBox(height: 28.h),

                          // ── Similar Trades ─────────────────────────
                          _buildSectionLabel("SIMILAR TRADES"),
                          SizedBox(height: 14.h),
                          _buildSimilarTrades(product),

                          SizedBox(height: 120.h),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            // ── Floating CTA Bar ───────────────────────────────────────
            Obx(() {
              final product = controller.product;
              if (product.isEmpty) return const SizedBox.shrink();

              final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
              final seller = product['sellerId'];
              final sellerId = (seller is Map) ? (seller['_id'] ?? seller['id'] ?? '') : seller.toString();
              final isOwner = currentUserId.isNotEmpty && currentUserId == sellerId;
              if (isOwner) return const SizedBox.shrink();

              final buyNowPriceVal = product['buyNowPrice'] ?? product['price'];
              final hasBuyNow = buyNowPriceVal != null &&
                  double.tryParse(buyNowPriceVal.toString()) != null &&
                  double.parse(buyNowPriceVal.toString()) > 0;
              final allowTradeVal = product['allowTrade'];
              final allowOffersVal = product['allowOffers'];
              final hasTrade = allowTradeVal == true || allowTradeVal == 'true' || allowTradeVal == null;
              final allowsOffers = allowOffersVal == true || allowOffersVal == 'true' || (allowOffersVal == null && (hasTrade || hasBuyNow));

              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 32.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.95), Colors.black],
                    ),
                  ),
                  child: Row(
                    children: [
                      if (allowsOffers || hasTrade)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              AuthGuard.check(
                                title: "Sign in to Make an Offer",
                                message: "Guest mode is browse-only. Sign in or create an account to make trade offers.",
                                onAuthorized: () => _showMakeOfferBottomSheet(context, product, controller),
                              );
                            },
                            child: Container(
                              height: 56.h,
                              decoration: BoxDecoration(
                                color: hasBuyNow ? Colors.white.withOpacity(0.08) : const Color(0xFF8B9BFF),
                                borderRadius: BorderRadius.circular(28.r),
                                border: hasBuyNow ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
                                boxShadow: hasBuyNow ? [] : [
                                  BoxShadow(color: const Color(0xFF8B9BFF).withOpacity(0.3), blurRadius: 16.r, offset: const Offset(0, 4)),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Make Offer",
                                style: TextStyle(
                                  color: hasBuyNow ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if ((allowsOffers || hasTrade) && hasBuyNow) SizedBox(width: 16.w),
                      if (hasBuyNow)
                        Expanded(
                          child: GestureDetector(
                            onTap: controller.isOrdering.value ? null : () => controller.buyProduct(),
                            child: Container(
                              height: 56.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B9BFF),
                                borderRadius: BorderRadius.circular(28.r),
                                boxShadow: [BoxShadow(color: const Color(0xFF8B9BFF).withOpacity(0.3), blurRadius: 16.r, offset: const Offset(0, 4))],
                              ),
                              alignment: Alignment.center,
                              child: controller.isOrdering.value
                                  ? SizedBox(width: 22.r, height: 22.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : Text(
                                      "Buy Now \$$buyNowPriceVal",
                                      style: TextStyle(color: const Color(0xFF0F172A), fontSize: 16.sp, fontWeight: FontWeight.w900),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // IMAGE GALLERY — horizontal page swiper for all product images
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildImageGallery(Map<String, dynamic> product) {
    final dynamic rawImages = product['images'];
    List<dynamic> images = [];
    if (rawImages is List) {
      images = rawImages;
    } else if (rawImages is String && rawImages.isNotEmpty) {
      final trimmed = rawImages.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        try {
          images = jsonDecode(trimmed) as List;
        } catch (_) {
          images = [rawImages];
        }
      } else if (trimmed.contains(',')) {
        images = trimmed.split(',');
      } else {
        images = [rawImages];
      }
    }

    final estValue = product['estValue'] ?? product['buyNowPrice'] ?? '';
    final isSold = product['isSold'] == true || product['status'] == 'sold';

    final List<String> imageUrls = images.map<String>((img) {
      final path = img.toString();
      if (path.startsWith('http') || path.startsWith('data:image/')) return path;
      return "${ApiUrl.imageBaseUrl}${path.startsWith('/') ? path : '/$path'}";
    }).toList();

    if (imageUrls.isEmpty) imageUrls.add('');

    return SizedBox(
      height: 420.h,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: imageUrls.length,
            onPageChanged: (i) => controller.currentImageIndex.value = i,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _openFullScreenImageViewer(context, imageUrls, i),
              child: Container(
                color: const Color(0xFFF0F0F0),
                child: _buildDetailsProductImage(imageUrls[i], fit: BoxFit.contain),
              ),
            ),
          ),

          // Sold overlay
          if (isSold)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12.r)),
                    child: Text("SOLD", style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900, letterSpacing: 4)),
                  ),
                ),
              ),
            ),

          // Top badges
          Positioned(
            top: 16.h,
            left: 16.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBadge("OPEN TRADE", const Color(0xFF8B9BFF)),
                if (estValue.toString().isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  _buildBadge("\$$estValue EST. VALUE", Colors.black.withOpacity(0.75)),
                ],
              ],
            ),
          ),

          // Fullscreen expand icon button
          Positioned(
            top: 16.h,
            right: 16.w,
            child: GestureDetector(
              onTap: () => _openFullScreenImageViewer(
                Get.context!,
                imageUrls,
                controller.currentImageIndex.value,
              ),
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(Icons.fullscreen_rounded, color: Colors.white, size: 22.sp),
              ),
            ),
          ),

          // Page indicator dots
          if (imageUrls.length > 1)
            Positioned(
              bottom: 16.h,
              left: 0,
              right: 0,
              child: Obx(() => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(imageUrls.length, (i) {
                  final active = controller.currentImageIndex.value == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: active ? 20.w : 7.w,
                    height: 7.h,
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF8B9BFF) : Colors.white38,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  );
                }),
              )),
            ),

          // Image counter pill
          Positioned(
            bottom: 16.h,
            right: 16.w,
            child: Obx(() => Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20.r)),
              child: Text(
                "${controller.currentImageIndex.value + 1} / ${imageUrls.length}",
                style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold),
              ),
            )),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FULL SCREEN INTERACTIVE IMAGE VIEWER LIGHTBOX
  // ──────────────────────────────────────────────────────────────────────────
  void _openFullScreenImageViewer(BuildContext context, List<String> imageUrls, int initialIndex) {
    if (imageUrls.isEmpty || (imageUrls.length == 1 && imageUrls[0].isEmpty)) return;
    final currentIndex = initialIndex.obs;
    final PageController pageController = PageController(initialPage: initialIndex);

    Get.to(
      () => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Interactive Zoomable PageView
              PageView.builder(
                controller: pageController,
                itemCount: imageUrls.length,
                onPageChanged: (idx) => currentIndex.value = idx,
                itemBuilder: (context, idx) {
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: _buildDetailsProductImage(imageUrls[idx], fit: BoxFit.contain),
                    ),
                  );
                },
              ),

              // Top Bar with Close button & Counter
              Positioned(
                top: 16.h,
                left: 16.w,
                right: 16.w,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, color: Colors.white, size: 22.sp),
                      ),
                    ),
                    Obx(
                      () => Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          "${currentIndex.value + 1} / ${imageUrls.length}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Thumbnails Strip (if multiple images)
              if (imageUrls.length > 1)
                Positioned(
                  bottom: 24.h,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Obx(
                      () => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(imageUrls.length, (idx) {
                            final isSelected = currentIndex.value == idx;
                            return GestureDetector(
                              onTap: () {
                                currentIndex.value = idx;
                                pageController.animateToPage(
                                  idx,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: 6.w),
                                width: 52.w,
                                height: 52.w,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF8B9BFF) : Colors.white24,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.r),
                                  child: _buildDetailsProductImage(imageUrls[idx], fit: BoxFit.cover),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      transition: Transition.fadeIn,
      fullscreenDialog: true,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PRICING ROW
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPricingRow({required String estValue, String? buyNowPrice}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFF8B9BFF).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.attach_money_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
              Text(
                "\$$estValue est.",
                style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 13.sp, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        if (buyNowPrice != null && double.tryParse(buyNowPrice) != null && double.parse(buyNowPrice) > 0) ...[
          SizedBox(width: 10.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8BFF).withOpacity(0.10),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFFF8BFF).withOpacity(0.20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_outlined, color: const Color(0xFFFF8BFF), size: 15.sp),
                SizedBox(width: 4.w),
                Text(
                  "Buy \$$buyNowPrice",
                  style: TextStyle(color: const Color(0xFFFF8BFF), fontSize: 13.sp, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SPEC GRID — all core seller-provided fields
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSpecGrid(
    Map<String, dynamic> product,
    String category,
    String condition,
    dynamic estValue,
    dynamic buyNowPrice,
    dynamic allowTrade,
    dynamic minValue,
    dynamic maxValue,
    String targetCategory,
    String createdAt,
  ) {
    final List<_SpecItem> specs = [];

    if (category.isNotEmpty) specs.add(_SpecItem("Category", category, Icons.category_outlined));
    if (condition.isNotEmpty) specs.add(_SpecItem("Condition", condition, Icons.stars_outlined));
    if (estValue != null && estValue.toString().isNotEmpty) specs.add(_SpecItem("Est. Value", "\$$estValue", Icons.attach_money_rounded));
    if (buyNowPrice != null && double.tryParse(buyNowPrice.toString()) != null && double.parse(buyNowPrice.toString()) > 0)
      specs.add(_SpecItem("Buy Now Price", "\$$buyNowPrice", Icons.shopping_bag_outlined));
    
    // Shipping Weight (Feature 1)
    final shippingWeight = product['shippingWeight'];
    final shippingWeightUnit = product['shippingWeightUnit'] ?? 'lbs';
    if (shippingWeight != null && shippingWeight.toString().isNotEmpty && (double.tryParse(shippingWeight.toString()) ?? 0) > 0) {
      specs.add(_SpecItem("Shipping Weight", "$shippingWeight $shippingWeightUnit", Icons.scale_outlined));
    }

    specs.add(_SpecItem("Trade Allowed", allowTrade == true ? "Yes" : "No", Icons.swap_horiz_rounded));
    
    // Custom Offers & Min Offer Amount (Feature 2)
    final allowOffers = product['allowOffers'];
    if (allowOffers != null) {
      specs.add(_SpecItem("Custom Offers", (allowOffers == true || allowOffers == 'true') ? "Accepted" : "Disabled", Icons.local_offer_outlined));
    }
    final minOfferAmount = product['minOfferAmount'];
    if (minOfferAmount != null && (double.tryParse(minOfferAmount.toString()) ?? 0) > 0) {
      specs.add(_SpecItem("Min Acceptable Offer", "\$$minOfferAmount", Icons.price_check_rounded));
    }

    if (minValue != null && minValue.toString().isNotEmpty) specs.add(_SpecItem("Min Trade Value", "\$$minValue", Icons.arrow_downward_rounded));
    if (maxValue != null && maxValue.toString().isNotEmpty) specs.add(_SpecItem("Max Trade Value", "\$$maxValue", Icons.arrow_upward_rounded));
    if (targetCategory.isNotEmpty) specs.add(_SpecItem("Target Category", targetCategory, Icons.filter_list_rounded));
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        specs.add(_SpecItem("Listed On", "${dt.day}/${dt.month}/${dt.year}", Icons.calendar_today_outlined));
      } catch (_) {}
    }

    if (specs.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF11111A), borderRadius: BorderRadius.circular(24.r)),
      child: Column(
        children: List.generate(specs.length, (i) {
          final spec = specs[i];
          final isLast = i == specs.length - 1;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(7.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B9BFF).withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(spec.icon, color: const Color(0xFF8B9BFF), size: 14.sp),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      spec.label,
                      style: TextStyle(color: Colors.white54, fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        spec.value,
                        style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(color: Colors.white.withOpacity(0.04), height: 1, indent: 20.w, endIndent: 20.w),
            ],
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // EXTRA SPECS — any non-standard fields from API
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildExtraSpecsGrid(List<MapEntry<String, String>> extras) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF11111A), borderRadius: BorderRadius.circular(24.r)),
      child: Column(
        children: List.generate(extras.length, (i) {
          final entry = extras[i];
          final isLast = i == extras.length - 1;
          final label = entry.key
              .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[0]}')
              .trim()
              .split(' ')
              .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
              .join(' ');
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: Colors.white54, fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    SizedBox(width: 16.w),
                    Flexible(
                      child: Text(
                        entry.value,
                        style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.end,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(color: Colors.white.withOpacity(0.04), height: 1, indent: 20.w, endIndent: 20.w),
            ],
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TRADE PREFERENCES CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTradePreferences(
    Map<String, dynamic> product,
    dynamic allowTrade,
    dynamic minValue,
    dynamic maxValue,
    String targetCategory,
    String lookingFor,
  ) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1035), Color(0xFF0F0F1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trade toggle row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(color: const Color(0xFF8B9BFF).withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(Icons.swap_horiz_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
              ),
              SizedBox(width: 12.w),
              Text("Trade Accepted", style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: allowTrade == true ? const Color(0xFF8B9BFF).withOpacity(0.15) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  allowTrade == true ? "YES" : "NO",
                  style: TextStyle(
                    color: allowTrade == true ? const Color(0xFF8B9BFF) : Colors.white38,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          if (lookingFor.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Divider(color: Colors.white.withOpacity(0.05)),
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.search_rounded, color: Colors.white38, size: 16.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Looking For", style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      SizedBox(height: 4.h),
                      Text(lookingFor, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ],

          if (targetCategory.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Row(
              children: [
                Icon(Icons.filter_list_rounded, color: Colors.white38, size: 16.sp),
                SizedBox(width: 10.w),
                Text("Preferred Category:", style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                SizedBox(width: 8.w),
                Flexible(
                  child: Text(targetCategory, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],

          if ((minValue != null && minValue.toString().isNotEmpty) ||
              (maxValue != null && maxValue.toString().isNotEmpty)) ...[
            SizedBox(height: 14.h),
            Row(
              children: [
                Icon(Icons.monetization_on_outlined, color: Colors.white38, size: 16.sp),
                SizedBox(width: 10.w),
                Text("Accepted Value Range:", style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                SizedBox(width: 8.w),
                Text(
                  [
                    if (minValue != null && minValue.toString().isNotEmpty) "\$$minValue",
                    if (maxValue != null && maxValue.toString().isNotEmpty) "\$$maxValue",
                  ].join(" – "),
                  style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 13.sp, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(label, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w900, letterSpacing: 1.2));
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10.r)),
      child: Text(text, style: TextStyle(color: color == const Color(0xFF8B9BFF) ? Colors.black : Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildDynamicTraderCard(Map<String, dynamic> product) {
    final seller = product['sellerId'];
    final Map<String, dynamic>? sellerMap = seller is Map ? Map<String, dynamic>.from(seller) : null;
    final name = sellerMap?['fullName'] ?? sellerMap?['name'] ?? "Seller";
    final rating = (sellerMap?['rating'] ?? "—").toString();
    final address = sellerMap?['address'] ?? '';
    final isVerified = sellerMap?['isVerified'] == true;

    String avatarUrl = '';
    final sellerImage = (sellerMap?['profile'] ?? sellerMap?['image'] ?? sellerMap?['profileImageUrl'] ?? sellerMap?['avatar'])?.toString();
    if (sellerImage != null && sellerImage.isNotEmpty) {
      avatarUrl = (sellerImage.startsWith('http') || sellerImage.startsWith('data:image/'))
          ? sellerImage
          : "${ApiUrl.imageBaseUrl}${sellerImage.startsWith('/') ? sellerImage : '/$sellerImage'}";
    }

    return GestureDetector(
      onTap: () => Get.toNamed('/trader_profile', arguments: {
        "id": sellerMap?['_id'] ?? sellerMap?['id'] ?? (seller is String ? seller : ''),
        "name": name,
        "avatar": avatarUrl,
        "bio": sellerMap?['bio'] ?? sellerMap?['description'] ?? '',
      }),
      child: Container(
        padding: EdgeInsets.all(18.r),
        decoration: BoxDecoration(color: const Color(0xFF161622), borderRadius: BorderRadius.circular(24.r)),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48.r,
              height: 48.r,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
              child: ClipOval(
                child: avatarUrl.isNotEmpty
                    ? _buildDetailsProductImage(avatarUrl)
                    : Center(child: Icon(Icons.person, color: Colors.white24, size: 26.sp)),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name, style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w900),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isVerified) ...[
                        SizedBox(width: 4.w),
                        Icon(Icons.verified, color: const Color(0xFF8B9BFF), size: 15.sp),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    [if (rating != '—') "⭐ $rating", if (address.isNotEmpty) address].join('  •  '),
                    style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 26.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeBox({required String title, required String name, required String subName, required bool isOffering, String? badge}) {
    final primaryColor = isOffering ? const Color(0xFF8B9BFF) : const Color(0xFF9155FF);
    final labelColor = isOffering ? const Color(0xFF8B9BFF) : const Color(0xFFFF8BFF);

    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(color: const Color(0xFF161622), borderRadius: BorderRadius.circular(32.r)),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 2.h,
            bottom: 2.h,
            child: Container(width: 6.w, decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20.r))),
          ),
          Padding(
            padding: EdgeInsets.only(left: 28.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(color: labelColor, fontSize: 11.sp, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    Icon(
                      isOffering ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: isOffering ? Colors.white70 : labelColor,
                      size: 26.sp,
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                Text(name, style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: Text(subName, style: TextStyle(color: Colors.white38, fontSize: 14.sp, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (badge != null) ...[
                      SizedBox(width: 14.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        decoration: BoxDecoration(color: const Color(0xFF2E1E5D), borderRadius: BorderRadius.circular(10.r)),
                        child: Text(badge, style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 10.sp, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(String? svgPath, String title, String subtitle, {IconData? iconData}) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (svgPath != null)
            SvgPicture.asset(svgPath, width: 30.sp, height: 30.sp, colorFilter: const ColorFilter.mode(Color(0xFF8B9BFF), BlendMode.srcIn))
          else if (iconData != null)
            Icon(iconData, color: const Color(0xFF8B9BFF), size: 30.sp),
          SizedBox(height: 14.h),
          Text(title, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w900)),
          SizedBox(height: 4.h),
          Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildSimilarTrades(Map<String, dynamic> product) {
    final List<Map<String, dynamic>> similarItems = [];
    try {
      final discoverCtrl = Get.find<DiscoverController>();
      final String currentCategory = (product['category'] ?? '').toString();
      final String currentTitle = (product['title'] ?? '').toString();
      final matched = discoverCtrl.tradeMarketItems.where((item) {
        final raw = item['raw'];
        if (raw == null) return false;
        return raw['category']?.toString() == currentCategory && item['title'] != currentTitle;
      }).toList();
      if (matched.isNotEmpty) {
        similarItems.addAll(matched.take(4).cast<Map<String, dynamic>>());
      } else {
        similarItems.addAll(discoverCtrl.tradeMarketItems.where((item) => item['title'] != currentTitle).take(4).cast<Map<String, dynamic>>());
      }
    } catch (_) {}

    if (similarItems.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Text("No similar trades found.", style: TextStyle(color: Colors.white24, fontSize: 13.sp, fontWeight: FontWeight.w700)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: similarItems.map((item) {
          final title = item['title'].toString();
          final lookingFor = item['lookingFor'].toString();
          final value = item['value'].toString();
          final imgUrl = item['image'].toString();
          return GestureDetector(
            onTap: () {
              final detailsCtrl = Get.find<TradeDetailsController>();
              detailsCtrl.product.assignAll(Map<String, dynamic>.from(item['raw']));
              detailsCtrl.currentImageIndex.value = 0;
            },
            child: Container(
              width: 270.w,
              margin: EdgeInsets.only(right: 14.w),
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(color: const Color(0xFF161622), borderRadius: BorderRadius.circular(24.r)),
              child: Row(
                children: [
                  Container(
                    width: 64.w,
                    height: 64.w,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14.r)),
                    child: _buildDetailsProductImage(imgUrl),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: 3.h),
                        Text(lookingFor, style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: 3.h),
                        Text(value, style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 11.sp, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailsProductImage(String imgStr, {BoxFit fit = BoxFit.cover}) {
    if (imgStr.isEmpty) {
      return Container(color: const Color(0xFF1A1A2E), child: Center(child: Icon(Icons.image_outlined, color: Colors.white12, size: 32.sp)));
    }
    if (imgStr.startsWith('data:image/') && imgStr.contains('base64,')) {
      try {
        final bytes = base64Decode(imgStr.split('base64,').last);
        return Image.memory(bytes, fit: fit,
          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E), child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white12, size: 32.sp))));
      } catch (_) {
        return Container(color: const Color(0xFF1A1A2E), child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white12, size: 32.sp)));
      }
    }
    final cleanUrl = imgStr.startsWith('http') ? imgStr : "${ApiUrl.imageBaseUrl}${imgStr.startsWith('/') ? imgStr : '/$imgStr'}";
    return Image.network(cleanUrl, fit: fit,
      loadingBuilder: (_, child, progress) => progress == null ? child : Container(color: const Color(0xFF1A1A2E), child: Center(child: SizedBox(width: 22.r, height: 22.r, child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF8B9BFF).withOpacity(0.4))))),
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E), child: Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white12, size: 32.sp))));
  }

  // ── Make Offer Dialog / BottomSheet (Feature 2) ──────────────────────────
  void _showMakeOfferBottomSheet(
    BuildContext context,
    Map<String, dynamic> product,
    TradeDetailsController controller,
  ) {
    final title = product['title'] ?? 'Item';
    final dynamic rawImages = product['images'];
    String imgUrl = '';
    if (rawImages is List && rawImages.isNotEmpty) {
      imgUrl = rawImages.first.toString();
    } else if (rawImages is String && rawImages.isNotEmpty) {
      imgUrl = rawImages;
    }

    final dynamic buyNowRaw = product['buyNowPrice'] ?? product['price'] ?? product['estValue'];
    final double basePrice = double.tryParse(buyNowRaw?.toString() ?? '0') ?? 0.0;

    final dynamic minOfferRaw = product['minOfferAmount'];
    final double minOfferAmount = double.tryParse(minOfferRaw?.toString() ?? '0') ?? 0.0;

    final TextEditingController offerInputCtrl = TextEditingController(
      text: basePrice > 0 ? (basePrice * 0.9).toStringAsFixed(0) : "",
    );
    final TextEditingController noteInputCtrl = TextEditingController();
    final RxString errorMessage = "".obs;

    void validateOffer(String text) {
      final double val = double.tryParse(text.trim()) ?? 0.0;
      if (val <= 0) {
        errorMessage.value = "Please enter a valid offer amount.";
      } else if (minOfferAmount > 0 && val < minOfferAmount) {
        errorMessage.value = "Seller accepts offers over \$${minOfferAmount.toStringAsFixed(0)}.";
      } else {
        errorMessage.value = "";
      }
    }

    if (offerInputCtrl.text.isNotEmpty) {
      validateOffer(offerInputCtrl.text);
    }

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          left: 24.w,
          right: 24.w,
          top: 20.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Make an Offer",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white70, size: 18.sp),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Product card
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50.w,
                      height: 50.w,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.r),
                        color: Colors.black26,
                      ),
                      child: _buildDetailsProductImage(imgUrl),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            basePrice > 0 ? "Listed Price: \$${basePrice.toStringAsFixed(0)}" : "Open Trade",
                            style: TextStyle(
                              color: const Color(0xFF8B9BFF),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (minOfferAmount > 0) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          "Seller accepts offers over \$${minOfferAmount.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: const Color(0xFF8B9BFF),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 20.h),
              Text(
                "Your Offer Amount (\$)",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.h),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFF8B9BFF).withOpacity(0.3),
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                child: Row(
                  children: [
                    Text(
                      "\$",
                      style: TextStyle(
                        color: const Color(0xFF8B9BFF),
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: TextField(
                        controller: offerInputCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                        ),
                        onChanged: validateOffer,
                        decoration: InputDecoration(
                          hintText: "Enter amount",
                          hintStyle: TextStyle(
                            color: Colors.white24,
                            fontSize: 18.sp,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Obx(() => errorMessage.value.isNotEmpty
                  ? Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14.sp),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              errorMessage.value,
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink()),

              if (basePrice > 0) ...[
                SizedBox(height: 14.h),
                Row(
                  children: [
                    _buildDiscountChip("-5%", basePrice * 0.95, offerInputCtrl, validateOffer),
                    SizedBox(width: 8.w),
                    _buildDiscountChip("-10%", basePrice * 0.90, offerInputCtrl, validateOffer),
                    SizedBox(width: 8.w),
                    _buildDiscountChip("-15%", basePrice * 0.85, offerInputCtrl, validateOffer),
                    SizedBox(width: 8.w),
                    _buildDiscountChip("-20%", basePrice * 0.80, offerInputCtrl, validateOffer),
                  ],
                ),
              ],

              SizedBox(height: 16.h),
              Text(
                "Message to Seller (Optional)",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: TextField(
                  controller: noteInputCtrl,
                  maxLines: 2,
                  style: TextStyle(color: Colors.white, fontSize: 13.sp),
                  decoration: InputDecoration(
                    hintText: "Add a note or negotiate...",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
                    border: InputBorder.none,
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              Obx(() => GestureDetector(
                onTap: controller.isSubmittingOffer.value
                    ? null
                    : () async {
                        final double amount = double.tryParse(offerInputCtrl.text.trim()) ?? 0.0;
                        if (amount <= 0) {
                          errorMessage.value = "Please enter a valid offer amount.";
                          return;
                        }
                        if (minOfferAmount > 0 && amount < minOfferAmount) {
                          errorMessage.value = "Offer cannot be less than \$${minOfferAmount.toStringAsFixed(0)}.";
                          return;
                        }

                        final success = await controller.sendCustomPriceOffer(
                          offerAmount: amount,
                          note: noteInputCtrl.text.trim(),
                        );

                        if (success) {
                          Get.back();
                          _showOfferSuccessDialog(amount, title);
                        }
                      },
                child: Container(
                  height: 54.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF),
                    borderRadius: BorderRadius.circular(27.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B9BFF).withOpacity(0.35),
                        blurRadius: 16.r,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: controller.isSubmittingOffer.value
                      ? SizedBox(
                          width: 22.r,
                          height: 22.r,
                          child: const CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                        )
                      : Text(
                          "Send Offer",
                          style: TextStyle(
                            color: const Color(0xFF0F172A),
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              )),

              if (product['allowTrade'] == true || product['allowTrade'] == 'true' || product['allowTrade'] == null) ...[
                SizedBox(height: 12.h),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Get.back();
                      Get.toNamed('/make_offer', arguments: product);
                    },
                    child: Text(
                      "Or propose an Item Swap instead ➔",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildDiscountChip(
    String label,
    double value,
    TextEditingController controller,
    Function(String) onUpdate,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          controller.text = value.toStringAsFixed(0);
          onUpdate(controller.text);
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF8B9BFF),
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  void _showOfferSuccessDialog(double amount, String productTitle) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        child: Padding(
          padding: EdgeInsets.all(28.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72.r,
                width: 72.r,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 44.sp),
              ),
              SizedBox(height: 20.h),
              Text(
                "Offer Sent! 🎁",
                style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 10.h),
              Text(
                "Your offer of \$${amount.toStringAsFixed(0)} for \"$productTitle\" has been submitted to the seller.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13.sp, height: 1.4),
              ),
              SizedBox(height: 24.h),
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: double.infinity,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "Got It",
                    style: TextStyle(color: const Color(0xFF0F172A), fontSize: 15.sp, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper model for spec grid
class _SpecItem {
  final String label;
  final String value;
  final IconData icon;
  const _SpecItem(this.label, this.value, this.icon);
}
