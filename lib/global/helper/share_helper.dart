import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  /// Opens a modern, dark-themed bottom sheet modal for sharing a Trade / Product.
  static void shareTrade({
    required BuildContext context,
    required String title,
    required String priceOrValue,
    required String productId,
    String? imageUrl,
  }) {
    final String shareUrl = "https://culturecards.app/trade/$productId";
    final String shareMessage = "Check out '$title' listed on Culture Cards for $priceOrValue! 🃏✨\nView deal: $shareUrl";

    _showShareBottomSheet(
      context: context,
      heading: "Share Trade Listing",
      itemTitle: title,
      itemSubtitle: priceOrValue,
      shareUrl: shareUrl,
      shareMessage: shareMessage,
      subject: "Culture Cards: $title",
    );
  }

  /// Opens a modern bottom sheet modal for sharing a Trader's Profile.
  static void shareProfile({
    required BuildContext context,
    required String username,
    required String traderId,
    String? rating,
  }) {
    final String shareUrl = "https://culturecards.app/profile/$traderId";
    final String shareMessage = "Check out @$username's collector profile on Culture Cards! 🌟\nRating: ${rating ?? '5.0'} ⭐\nView profile: $shareUrl";

    _showShareBottomSheet(
      context: context,
      heading: "Share Trader Profile",
      itemTitle: "@$username",
      itemSubtitle: rating != null ? "Rating: $rating ⭐" : "Verified Trader",
      shareUrl: shareUrl,
      shareMessage: shareMessage,
      subject: "Culture Cards: @$username",
    );
  }

  static void _showShareBottomSheet({
    required BuildContext context,
    required String heading,
    required String itemTitle,
    required String itemSubtitle,
    required String shareUrl,
    required String shareMessage,
    required String subject,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32.r),
              topRight: Radius.circular(32.r),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30.r,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 20.h),

              // Header
              Text(
                heading,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                itemTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF8B9BFF),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (itemSubtitle.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  itemSubtitle,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: 28.h),

              // Action 1: System Share (WhatsApp, Messages, etc.)
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await Share.share(
                      shareMessage,
                      subject: subject,
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: Text(
                    "Share via Other Apps",
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    foregroundColor: const Color(0xFF0F0B1E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Action 2: Copy Link
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareUrl));
                    Navigator.of(ctx).pop();
                    Get.snackbar(
                      "Link Copied! 📋",
                      "Trade link copied to clipboard.",
                      backgroundColor: const Color(0xFF8B9BFF).withOpacity(0.9),
                      colorText: const Color(0xFF0F0B1E),
                      snackPosition: SnackPosition.BOTTOM,
                      margin: EdgeInsets.all(16.r),
                      duration: const Duration(seconds: 2),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(
                    "Copy Share Link",
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }
}
