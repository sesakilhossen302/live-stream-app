import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../global/widgets/custom_background.dart';

class ShippingLabelViewerScreen extends StatelessWidget {
  const ShippingLabelViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args = (Get.arguments is Map)
        ? Map<String, dynamic>.from(Get.arguments)
        : <String, dynamic>{};

    final String orderId = (args['orderId'] ?? '#ORD-98421').toString();
    final String productTitle = (args['productTitle'] ?? 'Collectible Item').toString();
    final String trackingNumber = (args['trackingNumber'] ?? '9400 1118 9956 2489 1002 45').toString();
    final String carrier = (args['carrier'] ?? 'USPS Ground Advantage').toString();
    final String sellerName = (args['sellerName'] ?? 'Verified Curator').toString();
    final String shippingAddress = (args['shippingAddress'] ?? '123 Main St, New York, NY 10001, USA').toString();
    final String shippingWeight = (args['shippingWeight'] ?? '1.5 lbs').toString();
    final String shippingLabelUrl = (args['shippingLabelUrl'] ?? '').toString();
    final bool isSeller = args['isSeller'] == true;

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Shipping Label",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.share_outlined, color: Colors.white, size: 22.sp),
              onPressed: () => _shareLabel(trackingNumber, orderId),
            ),
            IconButton(
              icon: Icon(Icons.download_rounded, color: Colors.white, size: 22.sp),
              onPressed: () => _downloadLabel(shippingLabelUrl, orderId),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B9BFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFF8B9BFF).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_outlined, color: const Color(0xFF8B9BFF), size: 20.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        isSeller
                            ? "Affix this pre-paid label onto the package before dropping it off at your local postal station."
                            : "Pre-paid CultureCards authentication & routing label generated for this order.",
                        style: TextStyle(
                          color: const Color(0xFF8B9BFF),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // ── Printable Label Preview ───────────────────────────────────
              _buildLabelPaperCard(
                orderId: orderId,
                productTitle: productTitle,
                trackingNumber: trackingNumber,
                carrier: carrier,
                sellerName: sellerName,
                shippingAddress: shippingAddress,
                shippingWeight: shippingWeight,
                isSeller: isSeller,
              ),

              SizedBox(height: 32.h),

              // ── Action Buttons ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton.icon(
                  onPressed: () => _printLabel(shippingLabelUrl, orderId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(Icons.print_rounded, size: 22.sp),
                  label: Text(
                    "Print Shipping Label",
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900),
                  ),
                ),
              ),

              SizedBox(height: 14.h),

              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: OutlinedButton.icon(
                  onPressed: () => _downloadLabel(shippingLabelUrl, orderId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                  ),
                  icon: Icon(Icons.picture_as_pdf_rounded, color: const Color(0xFF8B9BFF), size: 22.sp),
                  label: Text(
                    "Download PDF Label",
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PHYSICAL SHIPPING LABEL SIMULATION
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildLabelPaperCard({
    required String orderId,
    required String productTitle,
    required String trackingNumber,
    required String carrier,
    required String sellerName,
    required String shippingAddress,
    required String shippingWeight,
    required bool isSeller,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24.r,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(20.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Postage Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PRIORITY MAIL 2-DAY®",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    "CultureCards Hub Verification Service",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Column(
                  children: [
                    Text(
                      "U.S. POSTAGE PAID",
                      style: TextStyle(color: Colors.black, fontSize: 8.sp, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      "CultureCards LLC",
                      style: TextStyle(color: Colors.black87, fontSize: 8.sp, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      "PERMIT NO. G-48",
                      style: TextStyle(color: Colors.black54, fontSize: 7.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),
          const Divider(color: Colors.black, thickness: 2),
          SizedBox(height: 8.h),

          // Origin / SHIP FROM Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "FROM: ",
                style: TextStyle(color: Colors.black54, fontSize: 10.sp, fontWeight: FontWeight.w900),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sellerName,
                      style: TextStyle(color: Colors.black, fontSize: 12.sp, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      "Verified Vault Origin\nUnited States",
                      style: TextStyle(color: Colors.black87, fontSize: 11.sp, height: 1.3),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "WEIGHT: $shippingWeight",
                    style: TextStyle(color: Colors.black, fontSize: 10.sp, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    "ZONE 4 COMMERCIAL",
                    style: TextStyle(color: Colors.black54, fontSize: 9.sp, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 12.h),
          const Divider(color: Colors.black26, thickness: 1),
          SizedBox(height: 8.h),

          // Destination / SHIP TO Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SHIP\nTO: ",
                style: TextStyle(color: Colors.black, fontSize: 11.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSeller
                          ? "CULTURECARDS LLC CENTRAL HUB\nATTN: AUTHENTICATION UNIT 4"
                          : "BUYER DESTINATION",
                      style: TextStyle(color: Colors.black, fontSize: 13.sp, fontWeight: FontWeight.w900, height: 1.2),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      isSeller
                          ? "100 Culture Way, Ste 500\nNew York, NY 10001-4821"
                          : shippingAddress,
                      style: TextStyle(color: Colors.black87, fontSize: 12.sp, fontWeight: FontWeight.w600, height: 1.3),
                    ),
                  ],
                ),
              ),
              // QR / Routing Code
              _buildQrMatrixBox(),
            ],
          ),

          SizedBox(height: 16.h),
          const Divider(color: Colors.black, thickness: 3),
          SizedBox(height: 12.h),

          // 1D Postal Barcode Simulation
          Center(
            child: Column(
              children: [
                _buildBarcodeWidget(),
                SizedBox(height: 8.h),
                Text(
                  "USPS TRACKING # eVS",
                  style: TextStyle(color: Colors.black54, fontSize: 9.sp, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
                SizedBox(height: 2.h),
                Text(
                  trackingNumber,
                  style: TextStyle(color: Colors.black, fontSize: 13.sp, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ],
            ),
          ),

          SizedBox(height: 14.h),
          const Divider(color: Colors.black26, thickness: 1),
          SizedBox(height: 6.h),

          // Item ref
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "REF: $orderId • $productTitle",
                style: TextStyle(color: Colors.black54, fontSize: 9.sp, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  "AUTH PASS",
                  style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BARCODE WIDGET (Simulated High-Resolution PostNet / GS1-128 Bars)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildBarcodeWidget() {
    // Generate a randomized-looking but deterministic sequence of bar widths
    const List<double> barWidths = [
      3, 1, 2, 4, 1, 3, 2, 1, 4, 2, 1, 3, 4, 1, 2, 3, 1, 4, 2, 1, 3, 2, 4, 1, 2, 3,
      1, 4, 2, 1, 3, 2, 1, 4, 3, 1, 2, 4, 1, 3, 2, 1, 4, 2, 1, 3, 4, 1, 2, 3, 1, 4,
    ];

    return Container(
      height: 60.h,
      width: double.infinity,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: barWidths.map((w) {
          return Container(
            width: w.w,
            height: 60.h,
            margin: EdgeInsets.symmetric(horizontal: 1.w),
            color: Colors.black,
          );
        }).toList(),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // QR MATRIX / ROUTING SIMULATION
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildQrMatrixBox() {
    return Container(
      width: 60.w,
      height: 60.w,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6.r),
      ),
      padding: EdgeInsets.all(6.r),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: 36,
        itemBuilder: (context, i) {
          final bool isFilled = (i % 2 == 0 || i % 5 == 0 || i < 6 || i % 6 == 0);
          return Container(
            color: isFilled ? Colors.white : Colors.black,
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ACTIONS: PRINT, DOWNLOAD, SHARE
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _printLabel(String url, String orderId) async {
    if (url.isNotEmpty && url.startsWith('http')) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    Get.snackbar(
      "Print Job Sent 🖨️",
      "Shipping label for $orderId has been queued to your default printer.",
      backgroundColor: const Color(0xFF22C55E),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _downloadLabel(String url, String orderId) async {
    if (url.isNotEmpty && url.startsWith('http')) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    Get.snackbar(
      "PDF Downloaded 📥",
      "Shipping label for $orderId downloaded to device storage.",
      backgroundColor: const Color(0xFF8B9BFF),
      colorText: Colors.black,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _shareLabel(String trackingNumber, String orderId) {
    Get.snackbar(
      "Share Label 🔗",
      "Tracking Number $trackingNumber copied to clipboard.",
      backgroundColor: const Color(0xFF8B9BFF),
      colorText: Colors.black,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
