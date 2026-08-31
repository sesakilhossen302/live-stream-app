import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../../../../global/widgets/custom_background.dart';
import '../../../../data/services/api_url.dart';
import '../controller/order_checkout_controller.dart';

class OrderCheckoutScreen extends StatelessWidget {
  const OrderCheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OrderCheckoutController());

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
            "Order Checkout",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          centerTitle: true,
        ),
        body: Obx(() {
          final product = controller.product;
          final title = product['title'] ?? product['name'] ?? 'Collectible Item';
          final images = product['images'] ?? product['image'];
          String imgUrl = '';
          if (images is List && images.isNotEmpty) {
            imgUrl = images.first.toString();
          } else if (images is String) {
            imgUrl = images;
          }

          final seller = product['sellerId'] ?? product['seller'];
          String sellerName = 'Verified Curator';
          if (seller is Map) {
            sellerName = seller['fullName'] ?? seller['name'] ?? seller['username'] ?? 'Verified Curator';
          } else if (seller != null) {
            sellerName = seller.toString();
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Product Summary Card
                _buildProductSummaryCard(imgUrl, title, sellerName, product),

                SizedBox(height: 24.h),

                // 2. Shipping Address Section
                _buildSectionHeader("SHIPPING ADDRESS", Icons.location_on_outlined),
                SizedBox(height: 12.h),
                _buildAddressCard(controller),

                SizedBox(height: 24.h),

                // 3. Price Breakdown Section
                _buildSectionHeader("PAYMENT SUMMARY", Icons.receipt_long_outlined),
                SizedBox(height: 12.h),
                _buildPriceBreakdownCard(controller),

                SizedBox(height: 20.h),

                // 4. Guarantee / Trust Badge
                _buildBuyerProtectionBadge(),

                SizedBox(height: 120.h),
              ],
            ),
          );
        }),
        bottomNavigationBar: _buildBottomPayBar(controller),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8B9BFF), size: 16.sp),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF8B9BFF),
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildProductSummaryCard(String imgUrl, String title, String sellerName, Map<String, dynamic> product) {
    final condition = product['condition'] ?? 'MINT';

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20.r,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Container(
              width: 80.w,
              height: 80.w,
              color: const Color(0xFF1E1E2C),
              child: imgUrl.isNotEmpty
                  ? (imgUrl.startsWith('data:image/')
                      ? Image.memory(base64Decode(imgUrl.split(',').last), fit: BoxFit.cover)
                      : Image.network(
                          imgUrl.startsWith('http') ? imgUrl : "${ApiUrl.imageBaseUrl}${imgUrl.startsWith('/') ? imgUrl : '/$imgUrl'}",
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: Colors.white24, size: 30.sp),
                        ))
                  : Icon(Icons.style_outlined, color: Colors.white24, size: 30.sp),
            ),
          ),
          SizedBox(width: 16.w),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    condition.toString().toUpperCase(),
                    style: TextStyle(
                      color: const Color(0xFF8B9BFF),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.storefront_rounded, color: Colors.white38, size: 13.sp),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        "Seller: $sellerName",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(OrderCheckoutController controller) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name & Phone
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: "RECIPIENT NAME",
                  controller: controller.fullNameController,
                  hint: "Full Name",
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildInputField(
                  label: "PHONE NUMBER",
                  controller: controller.phoneController,
                  hint: "+1 (555) 000-0000",
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // Street
          _buildInputField(
            label: "STREET ADDRESS",
            controller: controller.streetController,
            hint: "123 Main Street, Apt 4B",
          ),
          SizedBox(height: 14.h),

          // City, State, ZIP
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInputField(
                  label: "CITY",
                  controller: controller.cityController,
                  hint: "City",
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 1,
                child: _buildInputField(
                  label: "STATE",
                  controller: controller.stateController,
                  hint: "NY",
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 2,
                child: _buildInputField(
                  label: "ZIP CODE",
                  controller: controller.zipCodeController,
                  hint: "10001",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 9.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10.h),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceBreakdownCard(OrderCheckoutController controller) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          _buildSummaryRow("Item Subtotal", "\$${controller.itemSubtotal.value.toStringAsFixed(2)}"),
          SizedBox(height: 12.h),
          _buildSummaryRow("Shipping & Handling", "\$${controller.shippingFee.value.toStringAsFixed(2)}"),
          SizedBox(height: 12.h),
          _buildSummaryRow(
            "CultureCards Authentication",
            "FREE",
            valueColor: const Color(0xFF22C55E),
            isBold: true,
          ),
          SizedBox(height: 12.h),
          _buildSummaryRow("Estimated Sales Tax (5%)", "\$${controller.estimatedTax.value.toStringAsFixed(2)}"),
          SizedBox(height: 16.h),
          Divider(color: Colors.white.withOpacity(0.08)),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Amount",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                "\$${controller.totalAmount.value.toStringAsFixed(2)}",
                style: TextStyle(
                  color: const Color(0xFF8B9BFF),
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 13.sp,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBuyerProtectionBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: const Color(0xFF22C55E), size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "100% Buyer Guarantee & Vault Authentication",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  "Items are verified for authenticity before payout release.",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPayBar(OrderCheckoutController controller) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0B1E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20.r,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Obx(() => Row(
        children: [
          // Total amount summary on left
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TOTAL PAYABLE",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                "\$${controller.totalAmount.value.toStringAsFixed(2)}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(width: 20.w),

          // Pay Button on right
          Expanded(
            child: SizedBox(
              height: 56.h,
              child: ElevatedButton(
                onPressed: controller.isProcessing.value ? null : () => controller.proceedToPayment(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B9BFF),
                  disabledBackgroundColor: const Color(0xFF8B9BFF).withOpacity(0.6),
                  foregroundColor: const Color(0xFF0F0B1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28.r),
                  ),
                  elevation: 0,
                ),
                child: controller.isProcessing.value
                    ? SizedBox(
                        width: 22.r,
                        height: 22.r,
                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 18.sp, color: const Color(0xFF0F0B1E)),
                          SizedBox(width: 8.w),
                          Text(
                            "Pay with Stripe",
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F0B1E),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      )),
    );
  }
}
