import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../model/trade_vote_model.dart';
import '../../../../global/widgets/custom_shimmer.dart';

class TradeVoteCard extends StatelessWidget {
  final TradeVoteModel trade;
  final Function(TradeVoteModel trade, String option) onVote;
  final bool showHeaderArrows;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final String? counterText;
  final bool isCompact;

  const TradeVoteCard({
    super.key,
    required this.trade,
    required this.onVote,
    this.showHeaderArrows = false,
    this.onPrev,
    this.onNext,
    this.counterText,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF130F26),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 24.r),
        border: Border.all(
          color: const Color(0xFF2E2452),
          width: 1.2.w,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20.r,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(isCompact ? 12.r : 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category, TimeAgo, and optional Carousel controls
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B9BFF), Color(0xFF6C5CE7)],
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.how_to_vote_rounded, color: Colors.black, size: 12.sp),
                          SizedBox(width: 4.w),
                          Text(
                            trade.category.toUpperCase(),
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        trade.timeAgo,
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
              ),

              if (showHeaderArrows)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onPrev != null)
                      GestureDetector(
                        onTap: onPrev,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 12.sp),
                        ),
                      ),
                    if (counterText != null)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Text(
                          counterText!,
                          style: TextStyle(
                            color: const Color(0xFF8B9BFF),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (onNext != null)
                      GestureDetector(
                        onTap: onNext,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 12.sp),
                        ),
                      ),
                  ],
                )
              else
                Obx(() => Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(
                        "${trade.totalVotes.value} votes",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )),
            ],
          ),

          SizedBox(height: isCompact ? 8.h : 12.h),

          Text(
            "Who won this trade? 🔥",
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 15.sp : 17.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            "Community verdict • Tap to pick the winning side",
            style: TextStyle(
              color: Colors.white38,
              fontSize: isCompact ? 10.sp : 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),

          SizedBox(height: isCompact ? 10.h : 16.h),

          // Comparison: Trader A vs Trader B
          Obx(() {
            final hasVoted = trade.hasVoted.value;
            final votedOption = trade.votedOption.value;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trader A Card
                Expanded(
                  child: _buildItemCard(
                    sideTag: "Trader A",
                    traderName: trade.itemA.traderName,
                    name: trade.itemA.name,
                    value: trade.itemA.value,
                    imageUrl: trade.itemA.formattedImageUrl,
                    isVoted: hasVoted && votedOption == "A",
                    accentColor: const Color(0xFF8B9BFF),
                  ),
                ),

                // VS Badge
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 6.w : 8.w, vertical: isCompact ? 26.h : 40.h),
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 6.r : 8.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F183C),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF8B9BFF).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B9BFF).withValues(alpha: 0.25),
                          blurRadius: 10.r,
                        ),
                      ],
                    ),
                    child: Text(
                      "VS",
                      style: TextStyle(
                        color: const Color(0xFF8B9BFF),
                        fontSize: isCompact ? 9.5.sp : 11.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

                // Trader B Card
                Expanded(
                  child: _buildItemCard(
                    sideTag: "Trader B",
                    traderName: trade.itemB.traderName,
                    name: trade.itemB.name,
                    value: trade.itemB.value,
                    imageUrl: trade.itemB.formattedImageUrl,
                    isVoted: hasVoted && votedOption == "B",
                    accentColor: const Color(0xFFD677FF),
                  ),
                ),
              ],
            );
          }),

          SizedBox(height: isCompact ? 10.h : 16.h),

          // Action Area: Vote Buttons OR Result Bar
          Obx(() {
            final hasVoted = trade.hasVoted.value;
            final isVoting = trade.isVoting.value;

            if (!hasVoted) {
              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isVoting ? null : () => onVote(trade, "A"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        foregroundColor: const Color(0xFF0F0B1E),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: isCompact ? 9.h : 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isCompact ? 12.r : 16.r),
                        ),
                      ),
                      child: isVoting
                          ? SizedBox(
                              height: 16.h,
                              width: 16.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F0B1E),
                              ),
                            )
                          : Text(
                              trade.itemA.traderName.isNotEmpty
                                  ? "Vote ${trade.itemA.traderName}"
                                  : "Vote Trader A",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isCompact ? 11.sp : 12.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: isCompact ? 8.w : 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isVoting ? null : () => onVote(trade, "B"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD677FF),
                        foregroundColor: const Color(0xFF0F0B1E),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: isCompact ? 9.h : 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isCompact ? 12.r : 16.r),
                        ),
                      ),
                      child: isVoting
                          ? SizedBox(
                              height: 16.h,
                              width: 16.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F0B1E),
                              ),
                            )
                          : Text(
                              trade.itemB.traderName.isNotEmpty
                                  ? "Vote ${trade.itemB.traderName}"
                                  : "Vote Trader B",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isCompact ? 11.sp : 12.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            }

            // User has voted: Show results and chosen trader banner
            final pctA = trade.percentageA.value;
            final pctB = trade.percentageB.value;
            final chosenSide = trade.votedOption.value;
            final chosenTrader = chosenSide == "A"
                ? (trade.itemA.traderName.isNotEmpty ? trade.itemA.traderName : "Trader A")
                : (trade.itemB.traderName.isNotEmpty ? trade.itemB.traderName : "Trader B");

            return Column(
              children: [
                // "You voted for Trader X" Banner
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: (chosenSide == "A" ? const Color(0xFF8B9BFF) : const Color(0xFFD677FF))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: (chosenSide == "A" ? const Color(0xFF8B9BFF) : const Color(0xFFD677FF))
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: chosenSide == "A" ? const Color(0xFF8B9BFF) : const Color(0xFFD677FF),
                        size: 16.sp,
                      ),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          "You voted for $chosenTrader",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12.h),

                // Labels & Percentages
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (chosenSide == "A")
                          Icon(Icons.check_rounded, color: const Color(0xFF8B9BFF), size: 14.sp),
                        Text(
                          "Trader A: $pctA%",
                          style: TextStyle(
                            color: chosenSide == "A" ? const Color(0xFF8B9BFF) : Colors.white70,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "${trade.totalVotes.value} votes",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "Trader B: $pctB%",
                          style: TextStyle(
                            color: chosenSide == "B" ? const Color(0xFFD677FF) : Colors.white70,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (chosenSide == "B")
                          Icon(Icons.check_rounded, color: const Color(0xFFD677FF), size: 14.sp),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 8.h),

                // Dual Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: SizedBox(
                    height: 10.h,
                    child: Row(
                      children: [
                        Expanded(
                          flex: pctA > 0 ? pctA : 1,
                          child: Container(
                            color: const Color(0xFF8B9BFF),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          flex: pctB > 0 ? pctB : 1,
                          child: Container(
                            color: const Color(0xFFD677FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemCard({
    required String sideTag,
    required String traderName,
    required String name,
    required String value,
    required String imageUrl,
    required bool isVoted,
    required Color accentColor,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8.r : 10.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1434),
        borderRadius: BorderRadius.circular(isCompact ? 14.r : 18.r),
        border: Border.all(
          color: isVoted ? accentColor : Colors.white.withValues(alpha: 0.06),
          width: isVoted ? 1.8 : 1,
        ),
        boxShadow: isVoted
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.2),
                  blurRadius: 12.r,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Side badge & Trader Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isVoted ? accentColor : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  sideTag,
                  style: TextStyle(
                    color: isVoted ? const Color(0xFF0F0B1E) : Colors.white70,
                    fontSize: isCompact ? 9.sp : 9.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isVoted)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, color: accentColor, size: 10.sp),
                      SizedBox(width: 2.w),
                      Text(
                        "PICK",
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 8.5.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (traderName.isNotEmpty) ...[
            SizedBox(height: 3.h),
            Text(
              traderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white54,
                fontSize: isCompact ? 9.5.sp : 10.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          SizedBox(height: isCompact ? 6.h : 8.h),

          // Item Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              height: isCompact ? 76.h : 100.h,
              width: double.infinity,
              color: Colors.black26,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => CustomShimmer.rectangular(
                        width: double.infinity,
                        height: isCompact ? 76.h : 100.h,
                        shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      errorWidget: (context, url, error) => _buildImageFallback(),
                    )
                  : _buildImageFallback(),
            ),
          ),

          SizedBox(height: isCompact ? 6.h : 8.h),

          // Item Name
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 11.5.sp : 12.sp,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),

          SizedBox(height: 3.h),

          // Value
          if (value.isNotEmpty)
            Text(
              value,
              style: TextStyle(
                color: const Color(0xFF22C55E),
                fontSize: isCompact ? 11.sp : 12.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.04),
      alignment: Alignment.center,
      child: Icon(
        Icons.style_rounded,
        color: Colors.white24,
        size: 32.sp,
      ),
    );
  }
}
