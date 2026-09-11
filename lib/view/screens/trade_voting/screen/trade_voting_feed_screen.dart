import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../../../global/widgets/custom_empty_state.dart';
import '../controller/trade_voting_controller.dart';
import '../widgets/trade_vote_card.dart';

class TradeVotingFeedScreen extends GetView<TradeVotingController> {
  const TradeVotingFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure controller is registered
    final TradeVotingController controller = Get.isRegistered<TradeVotingController>()
        ? Get.find<TradeVotingController>()
        : Get.put(TradeVotingController());

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18.sp),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Who Won The Trade?",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text("🔥", style: TextStyle(fontSize: 16.sp)),
                            ],
                          ),
                          Text(
                            "Community card trade voting feed",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10, height: 1),

              // Content Area
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF8B9BFF),
                  backgroundColor: const Color(0xFF161622),
                  onRefresh: () async {
                    await controller.fetchFeed(isRefresh: true);
                  },
                  child: Obx(() {
                    if (controller.isInitialLoading.value) {
                      return _buildLoadingShimmer();
                    }

                    if (controller.errorMessage.value.isNotEmpty && controller.feedItems.isEmpty) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 80.h),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 48.sp),
                              SizedBox(height: 16.h),
                              Text(
                                controller.errorMessage.value,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, fontSize: 13.5.sp),
                              ),
                              SizedBox(height: 20.h),
                              ElevatedButton(
                                onPressed: () => controller.fetchFeed(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B9BFF),
                                  foregroundColor: const Color(0xFF0F0B1E),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (controller.feedItems.isEmpty) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.only(top: 80.h),
                          child: const CustomEmptyState(
                            title: "No Completed Trades",
                            description: "Completed card trades will automatically appear here for community voting.",
                            icon: Icons.how_to_vote_outlined,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: controller.scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                      itemCount: controller.feedItems.length + (controller.isLoadingMore.value ? 1 : 0),
                      separatorBuilder: (context, index) => SizedBox(height: 20.h),
                      itemBuilder: (context, index) {
                        if (index == controller.feedItems.length) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF8B9BFF),
                              ),
                            ),
                          );
                        }

                        final trade = controller.feedItems[index];
                        return TradeVoteCard(
                          trade: trade,
                          onVote: (item, option) => controller.castVote(item, option),
                        );
                      },
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => SizedBox(height: 20.h),
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: const Color(0xFF130F26),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: const Color(0xFF2E2452)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CustomShimmer.rectangular(
                    width: 80.w,
                    height: 20.h,
                    shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  SizedBox(width: 12.w),
                  CustomShimmer.rectangular(
                    width: 100.w,
                    height: 16.h,
                    shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: CustomShimmer.rectangular(
                      width: double.infinity,
                      height: 160.h,
                      shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                  ),
                  SizedBox(width: 20.w),
                  Expanded(
                    child: CustomShimmer.rectangular(
                      width: double.infinity,
                      height: 160.h,
                      shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              CustomShimmer.rectangular(
                width: double.infinity,
                height: 44.h,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
            ],
          ),
        );
      },
    );
  }
}
