import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../model/trade_vote_model.dart';
import 'trade_vote_card.dart';

/// A premium, Tinder-style interactive swipeable container for Trade Voting cards.
///
/// Features:
/// - Realistic physical drag offset and tilt rotation (Tinder effect)
/// - Stacked background card preview with dynamic scaling and elevation
/// - Glowing contextual swipe indicators ("NEXT ➔" / "PREV ➔")
/// - Velocity and threshold-aware dismiss physics
/// - Smooth spring-back on cancel
/// - Backward-compatible tap arrow controls
class TinderSwipeableTradeVoting extends StatefulWidget {
  final List<TradeVoteModel> trades;
  final int currentIndex;
  final Function(TradeVoteModel trade, String option) onVote;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const TinderSwipeableTradeVoting({
    super.key,
    required this.trades,
    required this.currentIndex,
    required this.onVote,
    required this.onNext,
    required this.onPrev,
  });

  @override
  State<TinderSwipeableTradeVoting> createState() =>
      _TinderSwipeableTradeVotingState();
}

class _TinderSwipeableTradeVotingState
    extends State<TinderSwipeableTradeVoting>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Animation<Offset>? _flyAnimation;

  Offset _dragOffset = Offset.zero;
  bool _isAnimating = false;

  // Swipe dismiss threshold in logical pixels
  static const double _dismissThreshold = 85.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _animController.addListener(() {
      if (_flyAnimation != null && mounted) {
        setState(() {
          _dragOffset = _flyAnimation!.value;
        });
      }
    });
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationCompleted();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onAnimationCompleted() {
    if (!mounted) return;
    final isDismissRight = _dragOffset.dx > 0;
    _dragOffset = Offset.zero;
    _flyAnimation = null;
    _isAnimating = false;
    setState(() {});

    if (isDismissRight) {
      widget.onPrev();
    } else {
      widget.onNext();
    }
  }

  void _handlePanStart(DragStartDetails details) {
    if (_isAnimating || widget.trades.length <= 1) return;
    _animController.stop();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isAnimating || widget.trades.length <= 1) return;
    setState(() {
      _dragOffset += Offset(details.delta.dx, details.delta.dy * 0.35);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isAnimating || widget.trades.length <= 1) return;

    final dx = _dragOffset.dx;
    final vx = details.velocity.pixelsPerSecond.dx;

    // Check if user swiped fast or past threshold
    final swipedLeft = dx < -_dismissThreshold || vx < -450;
    final swipedRight = dx > _dismissThreshold || vx > 450;

    if (swipedLeft || swipedRight) {
      // Haptic feedback on swipe trigger
      HapticFeedback.lightImpact();
      _isAnimating = true;
      final targetX = swipedLeft ? -500.0 : 500.0;
      _flyAnimation = Tween<Offset>(
        begin: _dragOffset,
        end: Offset(targetX, _dragOffset.dy),
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ));
      _animController.forward(from: 0);
    } else {
      // Snap back to center
      _isAnimating = true;
      _flyAnimation = Tween<Offset>(
        begin: _dragOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.elasticOut,
      ));
      _animController.forward(from: 0).whenComplete(() {
        if (mounted) {
          setState(() {
            _dragOffset = Offset.zero;
            _flyAnimation = null;
            _isAnimating = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trades.isEmpty) return const SizedBox.shrink();

    final currentIdx = widget.currentIndex % widget.trades.length;
    final nextIdx = (widget.currentIndex + 1) % widget.trades.length;
    final thirdIdx = (widget.currentIndex + 2) % widget.trades.length;
    final currentTrade = widget.trades[currentIdx];
    final nextTrade = widget.trades[nextIdx];
    final thirdTrade = widget.trades[thirdIdx];
    final hasMultiple = widget.trades.length > 1;
    final hasThree = widget.trades.length >= 3;

    // Progress 0.0 to 1.0 based on how far current card is dragged
    final dragProgress = (_dragOffset.dx.abs() / 250.0).clamp(0.0, 1.0);

    // Subtle rotation tilt (radians)
    final rotationAngle = (_dragOffset.dx / 320.0) * (math.pi / 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Swipe gesture instruction bar
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6584).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: const Color(0xFFFF6584).withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: const Color(0xFFFF6584),
                          size: 13.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          "SWIPE DECK",
                          style: TextStyle(
                            color: const Color(0xFFFF6584),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    "Swipe card left or right",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.swipe_rounded, color: const Color(0xFF8B9BFF), size: 14.sp),
                  SizedBox(width: 4.w),
                  Text(
                    "${currentIdx + 1} of ${widget.trades.length}",
                    style: TextStyle(
                      color: const Color(0xFF8B9BFF),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Stacked Deck Area with top margin for layered cards
        Padding(
          padding: EdgeInsets.only(top: hasThree ? 18.h : (hasMultiple ? 10.h : 0)),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // ─── 3rd Card in Deck (deepest background card) ───
              if (hasThree)
                Transform.translate(
                  offset: Offset(0, -18.h + (9.h * dragProgress)),
                  child: Transform.scale(
                    scale: 0.88 + (0.06 * dragProgress),
                    child: Opacity(
                      opacity: (0.35 + (0.30 * dragProgress)).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        child: TradeVoteCard(
                          trade: thirdTrade,
                          onVote: (_, __) {},
                          showHeaderArrows: false,
                          counterText: "${thirdIdx + 1}/${widget.trades.length}",
                          isCompact: true,
                        ),
                      ),
                    ),
                  ),
                ),

              // ─── 2nd Card in Deck (middle preview card) ───
              if (hasMultiple)
                Transform.translate(
                  offset: Offset(0, -9.h + (9.h * dragProgress)),
                  child: Transform.scale(
                    scale: 0.94 + (0.06 * dragProgress),
                    child: Opacity(
                      opacity: (0.65 + (0.35 * dragProgress)).clamp(0.0, 1.0),
                      child: IgnorePointer(
                        child: TradeVoteCard(
                          trade: nextTrade,
                          onVote: (_, __) {},
                          showHeaderArrows: false,
                          counterText: "${nextIdx + 1}/${widget.trades.length}",
                          isCompact: true,
                        ),
                      ),
                    ),
                  ),
                ),

              // ─── 1st Card in Deck (Foreground Active Swipeable Card) ───
              GestureDetector(
                onHorizontalDragStart: _handlePanStart,
                onHorizontalDragUpdate: _handlePanUpdate,
                onHorizontalDragEnd: _handlePanEnd,
                behavior: HitTestBehavior.translucent,
                child: Transform.translate(
                  offset: _dragOffset,
                  child: Transform.rotate(
                    angle: rotationAngle,
                    alignment: Alignment.bottomCenter,
                    child: Stack(
                      children: [
                        TradeVoteCard(
                          trade: currentTrade,
                          onVote: widget.onVote,
                          showHeaderArrows: true,
                          onPrev: widget.onPrev,
                          onNext: widget.onNext,
                          counterText:
                              "${currentIdx + 1}/${widget.trades.length}",
                          isCompact: true,
                        ),

                      // Swipe Overlay Indicator (Next Trade - swiping Left)
                      if (_dragOffset.dx < -15)
                        Positioned(
                          top: 24.h,
                          right: 20.w,
                          child: Opacity(
                            opacity: (_dragOffset.dx.abs() / 100.0).clamp(0.0, 1.0),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B9BFF).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B9BFF).withValues(alpha: 0.5),
                                    blurRadius: 12.r,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "NEXT TRADE",
                                    style: TextStyle(
                                      color: const Color(0xFF0F0B1E),
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: const Color(0xFF0F0B1E),
                                    size: 14.sp,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Swipe Overlay Indicator (Previous Trade - swiping Right)
                      if (_dragOffset.dx > 15)
                        Positioned(
                          top: 24.h,
                          left: 20.w,
                          child: Opacity(
                            opacity: (_dragOffset.dx / 100.0).clamp(0.0, 1.0),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6584).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6584).withValues(alpha: 0.5),
                                    blurRadius: 12.r,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 14.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    "PREVIOUS",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  }
}
