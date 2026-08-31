import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../../../../global/widgets/custom_background.dart';
import '../controller/discover_controller.dart';
import '../../../../core/app_route.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../../../global/helper/auth_guard.dart';

class DiscoverScreen extends GetView<DiscoverController> {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(DiscoverController());
    return CustomBackground(
      child: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.fetchDiscoverData(),
                color: const Color(0xFF8B9BFF),
                backgroundColor: const Color(0xFF11111A),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16.h),
                      _buildHeroText(),
                      SizedBox(height: 24.h),
                      _buildSearchBar(),
                      SizedBox(height: 24.h),
                      _buildFilterBar(),
                      SizedBox(height: 32.h),

                      // Tabs or Search Results
                      Obx(() {
                        if (controller.isSearching) {
                          return _buildSearchResultsView();
                        }
                        switch (controller.selectedFilter.value) {
                          case 1:
                            return _buildLiveShowsTab();
                          case 2:
                            return _buildTradeMarketTab();
                          default:
                            return _buildAllTab();
                        }
                      }),
                      SizedBox(height: 190.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB BUILDERS ---

  Widget _buildSearchResultsView() {
    return Obx(() {
      final query = controller.searchQuery.value.trim();
      final liveResults = controller.filteredLiveShows;
      final tradeResults = controller.filteredTradeMarketItems;
      final totalCount = liveResults.length + tradeResults.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Search Results",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "Found $totalCount matches for \"$query\"",
                    style: TextStyle(
                      color: const Color(0xFF8B9BFF),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => controller.clearSearch(),
                icon: Icon(Icons.close_rounded, color: Colors.white60, size: 16.sp),
                label: Text(
                  "Clear",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),

          if (totalCount == 0)
            _buildEmptySearchState(query)
          else ...[
            // 1. Live Shows Results
            if (liveResults.isNotEmpty) ...[
              _buildSectionHeader(
                "Live Streams (${liveResults.length})",
                onSeeAll: () => Get.toNamed(AppRoute.allLiveShows),
                seeAllText: "VIEW ALL →",
              ),
              SizedBox(height: 16.h),
              ...liveResults.map((show) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: GestureDetector(
<<<<<<< HEAD
                    onTap: () {
                      AuthGuard.check(
                        title: "Sign in to Watch Stream",
                        message: "Guest mode is browse-only. Sign in or create an account to watch live streams.",
                        onAuthorized: () => Get.toNamed(AppRoute.viewerLive, arguments: show['raw']),
                      );
                    },
=======
                    onTap: () => Get.toNamed(AppRoute.viewerLive, arguments: show['raw']),
>>>>>>> de8e507e15ad8ce63f8a30024ad690138cb76a0b
                    child: _buildLiveCard(
                      show['title'] ?? 'Live Show',
                      show['host'] ?? 'Host',
                      show['viewers'] ?? '0',
                      show['image'] ?? '',
                      show['hostAvatar'] ?? '',
                    ),
                  ),
                );
              }),
              SizedBox(height: 24.h),
            ],

            // 2. Deals & Trade Items Results
            if (tradeResults.isNotEmpty) ...[
              _buildSectionHeader(
                "Deals & Trade Items (${tradeResults.length})",
              ),
              SizedBox(height: 16.h),
              ...tradeResults.map((item) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: _buildTradeListItem(item),
                );
              }),
            ],
          ],

          SizedBox(height: 32.h),
          _buildTrendingTagsSection(),
        ],
      );
    });
  }

  Widget _buildEmptySearchState(String query) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 36.h),
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(32.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(18.r),
            decoration: BoxDecoration(
              color: const Color(0xFF8B9BFF).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              color: const Color(0xFF8B9BFF),
              size: 40.sp,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            "No results found for\n\"$query\"",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Try searching with different keywords or check out trending tags below.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: () => controller.clearSearch(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B9BFF),
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              elevation: 0,
            ),
            child: Text(
              "Clear Search",
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTab() {
    return Column(
      children: [
        _buildLiveShowsTab(isAllTab: true),
        SizedBox(height: 40.h),
        _buildTradeMarketTab(isAllTab: true),
        SizedBox(height: 32.h),
        _buildTrendingTagsSection(),
        SizedBox(height: 24.h),
        _buildTopSellersSection(),
      ],
    );
  }

  Widget _buildLiveShowsTab({bool isAllTab = false}) {
    return Obx(() {
      if (controller.isLoading.value && controller.liveShows.isEmpty) {
        return Column(
          children: List.generate(
            2,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: 20.h),
              child: _buildLiveShowShimmer(),
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.featuredLiveItems.isNotEmpty) ...[
            _buildSectionHeader("Featured", onSeeAll: () {}, seeAllText: "VIEW ALL →"),
            SizedBox(height: 18.h),
            Row(
              children: controller.featuredLiveItems.map((item) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: item == controller.featuredLiveItems.last ? 0 : 16.w),
                    child: GestureDetector(
                      onTap: () {
                        if (item['productRaw'] != null) {
                          Get.toNamed(AppRoute.tradeDetails, arguments: item['productRaw']);
                        }
                      },
                      child: _buildSmallFeaturedCard(
                        item['category']!,
                        item['title']!,
                        item['price']!,
                        item['image']!,
                        item['badge']!,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 40.h),
          ],
          _buildSectionHeader(
            "Live Now",
            onSeeAll: () => Get.toNamed(AppRoute.allLiveShows),
            seeAllText: "VIEW ALL →",
          ),
          SizedBox(height: 18.h),
          if (controller.liveShows.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Center(
                child: Text(
                  "No live shows currently broadcasting.",
                  style: TextStyle(color: Colors.white38, fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            )
          else
            ...controller.liveShows.take(2).map((show) {
              return Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: GestureDetector(
                  onTap: () {
                    AuthGuard.check(
                      title: "Sign in to Watch Stream",
                      message: "Guest mode is browse-only. Sign in or create an account to watch live streams.",
                      onAuthorized: () => Get.toNamed(AppRoute.viewerLive, arguments: show['raw']),
                    );
                  },
                  child: _buildLiveCard(show['title']!, show['host']!, show['viewers']!, show['image']!, show['hostAvatar'] ?? ''),
                ),
              );
            }).toList(),
          if (!isAllTab) ...[
            SizedBox(height: 32.h),
            _buildTrendingTagsSection(),
            SizedBox(height: 24.h),
            _buildTopSellersSection(),
          ],
        ],
      );
    });
  }

  Widget _buildTradeMarketTab({bool isAllTab = false}) {
    return Obx(() {
      if (controller.isLoading.value && controller.tradeMarketItems.isEmpty) {
        return Column(
          children: List.generate(
            3,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: _buildTradeItemShimmer(),
            ),
          ),
        );
      }

      final marketList = controller.filteredTradeMarketItems;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.featuredTrades.isNotEmpty) ...[
            _buildSectionHeader("Featured Trades", onSeeAll: () {}),
            SizedBox(height: 18.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: controller.featuredTrades.map((item) {
                  return Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: _buildLargeFeaturedCard(item),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 40.h),
          ],
          _buildSectionHeader("Available for Trade", showFilter: true),
          SizedBox(height: 20.h),
          if (marketList.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Center(
                child: Text(
                  "No items available for trade.",
                  style: TextStyle(color: Colors.white38, fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            )
          else
            ...marketList.map((item) {
              return Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: _buildTradeListItem(item),
              );
            }).toList(),
          SizedBox(height: 32.h),
          _buildDiscoverGridSection(),
        ],
      );
    });
  }

  // --- UI COMPONENTS ---

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Discover", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          SizedBox(width: 24.sp),
        ],
      ),
    );
  }

  Widget _buildHeroText() {
    return Text(
      "Explore live streams and\ntrending categories",
      style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.5),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 64.h,
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(32.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
      ),
      padding: EdgeInsets.symmetric(horizontal: 22.w),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: const Color(0xFF8B9BFF), size: 24.sp),
          SizedBox(width: 14.w),
          Expanded(
            child: TextField(
              controller: controller.searchController,
              onChanged: (val) => controller.searchQuery.value = val,
              onSubmitted: (val) => controller.performServerSearch(val),
              textInputAction: TextInputAction.search,
              style: TextStyle(color: Colors.white, fontSize: 16.sp),
              cursorColor: const Color(0xFF8B9BFF),
              cursorWidth: 2.w,
              decoration: InputDecoration(
                hintText: "Search deals, streams & more...",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 15.sp, fontWeight: FontWeight.w500),
                border: InputBorder.none,
              ),
            ),
          ),
          Obx(() => controller.searchQuery.value.isNotEmpty
              ? GestureDetector(
                  onTap: () => controller.clearSearch(),
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 16.sp),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Obx(() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(controller.filters.length, (index) {
          final isSelected = controller.selectedFilter.value == index;
          return GestureDetector(
            onTap: () => controller.changeFilter(index),
            child: Container(
              margin: EdgeInsets.only(right: 12.w),
              padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF8B9BFF) : const Color(0xFF161622).withOpacity(0.6),
                borderRadius: BorderRadius.circular(26.r),
              ),
              child: Text(
                controller.filters[index],
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white24,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        }),
      ),
    ));
  }

  Widget _buildLiveCard(String title, String host, String viewers, String imgUrl, String hostAvatar) {
    return Container(
      height: 320.h,
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF11111A), borderRadius: BorderRadius.circular(32.r)),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
                image: DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover, opacity: 0.6),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 20.h,
                    left: 20.w,
                    child: Row(
                      children: [
                        _buildSmallBadge("LIVE", const Color(0xFFFF4D4D), showDot: true),
                        SizedBox(width: 8.w),
                        _buildSmallBadge("$viewers", Colors.black.withOpacity(0.6), icon: Icons.visibility_outlined),
                      ],
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("LVE", style: TextStyle(color: Colors.white, fontSize: 52.sp, fontWeight: FontWeight.w900, letterSpacing: 10)),
                        Text("STREAM", style: TextStyle(color: Colors.white, fontSize: 52.sp, fontWeight: FontWeight.w900, letterSpacing: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(20.r),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundImage: hostAvatar.isNotEmpty
                      ? NetworkImage(hostAvatar)
                      : const NetworkImage("https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200") as ImageProvider,
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                      Text(host, style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Get.toNamed(AppRoute.liveStream),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    elevation: 0,
                  ),
                  child: Text("Join", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallFeaturedCard(String category, String title, String price, String imageUrl, String badge) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(color: const Color(0xFF11111A), borderRadius: BorderRadius.circular(24.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120.h,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildDiscoverProductImage(imageUrl),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    margin: EdgeInsets.all(8.r),
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(color: const Color(0xFF8B9BFF), borderRadius: BorderRadius.circular(6.r)),
                    child: Text(badge, style: TextStyle(color: Colors.black, fontSize: 8.sp, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Text(category, style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 10.sp, fontWeight: FontWeight.w900)),
          Text(title, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(price, style: TextStyle(color: const Color(0xFFD677FF), fontSize: 13.sp, fontWeight: FontWeight.w900)),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8.h),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12.r)),
            child: Text(badge == "BUY NOW" ? "BUY NOW" : "BID NOW", style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeFeaturedCard(Map<String, dynamic> item) {
    final title = item['title'].toString();
    final price = item['price'].toString();
    final imgUrl = item['image'].toString();
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoute.tradeDetails, arguments: item['raw']),
      child: Container(
        height: 400.h,
        width: 0.85.sw,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40.r),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: _buildDiscoverProductImage(imgUrl)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, 
                    end: Alignment.bottomCenter, 
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(28.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(title, style: TextStyle(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.w900, height: 1.1)),
                  Text(price, style: TextStyle(color: Colors.white38, fontSize: 15.sp, fontWeight: FontWeight.w700)),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: () => Get.toNamed(AppRoute.tradeDetails, arguments: item['raw']),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B9BFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.r))),
                      child: Text("Inquire Trade", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeListItem(Map<String, dynamic> item) {
    final title = item['title'].toString();
    final val = item['value'].toString();
    final lookingFor = item['lookingFor'].toString();
    final img = item['image'].toString();
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoute.tradeDetails, arguments: item['raw']),
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(color: const Color(0xFF11111A), borderRadius: BorderRadius.circular(24.r)),
        child: Row(
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black, 
                borderRadius: BorderRadius.circular(16.r), 
              ),
              child: _buildDiscoverProductImage(img),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
                  SizedBox(height: 6.h),
                  Text(val, style: TextStyle(color: const Color(0xFFD677FF), fontSize: 14.sp, fontWeight: FontWeight.w900)),
                  Text(lookingFor, style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38, size: 20.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverProductImage(String imgStr, {BoxFit fit = BoxFit.cover}) {
    final placeholder = Container(
      color: const Color(0xFF1E1E2C),
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 28.sp),
      ),
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

  Widget _buildTrendingTagsSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(color: const Color(0xFF11111A), borderRadius: BorderRadius.circular(32.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Trending Tags", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900)),
              Text("Tap to search", style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 20.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: controller.trendingTags.map((tag) => GestureDetector(
              onTap: () => controller.onTagSelected(tag),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C28),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tag_rounded, color: const Color(0xFF8B9BFF), size: 14.sp),
                    SizedBox(width: 4.w),
                    Text(
                      tag.replaceAll('#', ''),
                      style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellersSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(color: const Color(0xFF11111A), borderRadius: BorderRadius.circular(32.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Top Sellers", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900)),
          SizedBox(height: 8.h),
          ...controller.topSellers.map((seller) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Row(
                children: [
                  Text(seller['rank']!, style: TextStyle(color: Colors.white24, fontSize: 14.sp, fontWeight: FontWeight.w900)),
                  SizedBox(width: 20.w),
                  CircleAvatar(radius: 24.r, backgroundImage: NetworkImage(seller['image']!)),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(seller['name']!, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                        Text(seller['rating']!, style: TextStyle(color: const Color(0xFFD677FF), fontSize: 12.sp, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Icon(Icons.verified, color: const Color(0xFF8B9BFF), size: 20.sp),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // --- REUSABLE COMPONENTS ---

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll, bool showFilter = false, String seeAllText = "SEE ALL"}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900)),
        if (onSeeAll != null)
          GestureDetector(onTap: onSeeAll, child: Text(seeAllText, style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w900))),
        if (showFilter) Icon(Icons.tune_rounded, color: Colors.white38, size: 20.sp),
      ],
    );
  }

  Widget _buildDiscoverGridSection() {
    return Row(
      children: [
        Expanded(child: _buildGridCard("Top Sellers", showAvatars: true)),
        SizedBox(width: 16.w),
        Expanded(child: _buildGridCard("Upcoming Shows", subtitle: "24 Shows Today", icon: Icons.calendar_today_outlined)),
      ],
    );
  }

  Widget _buildGridCard(String title, {String? subtitle, IconData? icon, bool showAvatars = false}) {
    return Container(
      height: 220.h,
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(color: const Color(0xFF11111A), borderRadius: BorderRadius.circular(32.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
          const Spacer(),
          if (showAvatars)
            Row(
              children: [
                _buildAvatarStack(),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: const BoxDecoration(color: Color(0xFF8B9BFF), shape: BoxShape.circle),
                  child: Text("+12", style: TextStyle(color: Colors.black, fontSize: 10.sp, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          if (subtitle != null)
            Row(
              children: [
                Icon(icon, color: const Color(0xFF8B9BFF), size: 16.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "24 Shows",
                        style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 13.sp, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        "Today",
                        style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 13.sp, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack() {
    return SizedBox(
      width: 60.w,
      height: 30.h,
      child: Stack(
        children: [
          CircleAvatar(radius: 15.r, backgroundImage: const NetworkImage("https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200")),
          Positioned(left: 20.w, child: CircleAvatar(radius: 15.r, backgroundImage: const NetworkImage("https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=200"))),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color color, {bool showDot = false, IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[Icon(Icons.circle, color: Colors.white, size: 6.sp), SizedBox(width: 6.w)],
          if (icon != null) ...[Icon(icon, color: Colors.white, size: 14.sp), SizedBox(width: 6.w)],
          Text(text, style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildLiveShowShimmer() {
    return Container(
      height: 320.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(32.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
              child: const CustomShimmer.rectangular(height: double.infinity),
            ),
          ),
          Container(
            padding: EdgeInsets.all(20.r),
            child: Row(
              children: [
                CustomShimmer.circular(width: 40.r, height: 40.r),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomShimmer.rectangular(height: 16.h, width: 150.w),
                      SizedBox(height: 8.h),
                      CustomShimmer.rectangular(height: 12.h, width: 80.w),
                    ],
                  ),
                ),
                CustomShimmer.rectangular(
                  height: 36.h,
                  width: 70.w,
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeItemShimmer() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        children: [
          CustomShimmer.rectangular(
            width: 80.w,
            height: 80.w,
            shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomShimmer.rectangular(height: 16.h, width: 140.w),
                SizedBox(height: 8.h),
                CustomShimmer.rectangular(height: 14.h, width: 60.w),
                SizedBox(height: 8.h),
                CustomShimmer.rectangular(height: 12.h, width: 180.w),
              ],
            ),
          ),
          CustomShimmer.rectangular(
            width: 20.w,
            height: 20.w,
            shapeBorder: const CircleBorder(),
          ),
        ],
      ),
    );
  }
}
