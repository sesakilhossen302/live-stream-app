import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../../../global/widgets/custom_background.dart';
import '../../../../../../global/widgets/custom_bottom_navbar.dart';
import '../../../../../../data/services/api_url.dart';
import '../../../../../../core/app_route.dart';
import '../controller/track_order_controller.dart';

class TrackOrderScreen extends StatelessWidget {
  const TrackOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TrackOrderController());

    return CustomBackground(
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Get.back(),
                          child: Icon(Icons.close, color: Colors.white, size: 24.sp),
                        ),
                      ),
                      Obx(() {
                        final _ = controller.orderData.length;
                        return Text(
                          "Order ${controller.displayOrderId}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                        );
                      }),
                    ],
                  ),
                ),
                
                const Divider(color: Colors.white10, thickness: 1),
                
                Expanded(
                  child: Obx(() {
                    final _ = controller.orderData.length;
                    if (controller.isLoading.value) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B9BFF)));
                    }

                    return SingleChildScrollView(
                      padding: EdgeInsets.only(left: 24.w, right: 24.w, bottom: 120.h),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          
                          // Status Card
                          _buildStatusCard(controller),
                          
                          SizedBox(height: 32.h),
                          
                          // Journey Updates
                          Text("JOURNEY UPDATES", style: TextStyle(color: Colors.white54, fontSize: 12.sp, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                          SizedBox(height: 24.h),
                          _buildJourneyTimeline(controller),
                          
                          SizedBox(height: 32.h),
                          
                          // Order Summary Card
                          _buildOrderSummaryCard(controller),
                          
                          SizedBox(height: 32.h),

                          // Shipping Address Section
                          _buildShippingAddressCard(controller),

                          SizedBox(height: 32.h),
                          
                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildButton(
                                  "Contact Seller",
                                  const Color(0xFF1E1E2C).withOpacity(0.9),
                                  Colors.white,
                                  onTap: () {
                                    final sName = controller.sellerName;
                                    final sId = controller.sellerId;
                                    final sAvatar = controller.sellerAvatar;

                                    Get.toNamed(AppRoute.messageDetails, arguments: {
                                      "chatId": sId.isNotEmpty ? "chat_$sId" : "chat_seller",
                                      "name": sName,
                                      "avatar": sAvatar,
                                      "traderId": sId,
                                      "orderId": controller.displayOrderId,
                                      "productTitle": controller.productTitle,
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: _buildButton(
                                  "View Receipt",
                                  const Color(0xFF8B9BFF),
                                  Colors.black,
                                  onTap: () => Get.snackbar("Receipt", "Order Receipt generated for ${controller.displayOrderId}", snackPosition: SnackPosition.BOTTOM),
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 14.h),

                          // ── Print Shipping Label (Feature 1) ──────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52.h,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E1E2C),
                                foregroundColor: const Color(0xFF8B9BFF),
                                side: BorderSide(color: const Color(0xFF8B9BFF).withValues(alpha: 0.35), width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Get.toNamed(AppRoute.shippingLabel, arguments: {
                                  "orderId": controller.displayOrderId,
                                  "rawOrderId": controller.orderId,
                                  "productTitle": controller.productTitle,
                                  "productImage": controller.productImage,
                                  "trackingNumber": controller.trackingNumber,
                                  "carrier": controller.carrierName,
                                  "sellerName": controller.sellerName,
                                  "shippingAddress": controller.shippingAddressFormatted,
                                  "shippingWeight": controller.orderData['shippingWeight'] ?? controller.orderData['product']?['shippingWeight'] ?? '1.5 lbs',
                                  "shippingLabelUrl": controller.orderData['shippingLabelUrl'] ?? '',
                                  "isSeller": controller.isSeller,
                                });
                              },
                              icon: Icon(Icons.print_rounded, color: const Color(0xFF8B9BFF), size: 20.sp),
                              label: Text(
                                "Print Shipping Label",
                                style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 15.sp, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 16.h),

                          // "Update Shipping Status" — SELLER ONLY
                          if (controller.isSeller) ...[                           
                            SizedBox(
                              width: double.infinity,
                              height: 52.h,
                              child: Obx(() => ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5D2EEF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                                ),
                                onPressed: controller.isUpdatingStatus.value
                                    ? null
                                    : () => _showUpdateStatusBottomSheet(context, controller),
                                icon: controller.isUpdatingStatus.value
                                    ? SizedBox(
                                        width: 20.w,
                                        height: 20.w,
                                        child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20.sp),
                                label: Text(
                                  controller.isUpdatingStatus.value ? "Updating..." : "Update Shipping Status",
                                  style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w800),
                                ),
                              )),
                            ),
                          ],

                          // Buyer-only: delivery confirmation info
                          if (controller.isBuyer && controller.progressFraction >= 1.0)
                            Container(
                              margin: EdgeInsets.only(top: 8.h),
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4BFF8B).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: const Color(0xFF4BFF8B).withOpacity(0.25)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: const Color(0xFF4BFF8B), size: 22.sp),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Text(
                                      "Your order has been delivered! Enjoy your purchase.",
                                      style: TextStyle(color: const Color(0xFF4BFF8B), fontSize: 13.sp, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          SizedBox(height: 40.h),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomBottomNavbar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(TrackOrderController controller) {
    final rawStatus = controller.deliveryStatus;
    final statusText = rawStatus.replaceAll('_', ' ').capitalizeFirst ?? rawStatus;
    final progress = controller.progressFraction;
    final progressLabel = controller.progressLabel;
    final isDelivered = progress >= 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth - 56.w; // account for card padding
        final filledWidth = barWidth * progress;
        final dotOffset = (filledWidth - 5.w).clamp(0.0, barWidth - 10.w);

        return Container(
          padding: EdgeInsets.all(28.r),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(30.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("STATUS", style: TextStyle(color: Colors.white24, fontSize: 11.sp, fontWeight: FontWeight.w800)),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: isDelivered ? const Color(0xFF4BFF8B) : const Color(0xFFAC8AFF),
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("EST. DELIVERY", style: TextStyle(color: Colors.white24, fontSize: 11.sp, fontWeight: FontWeight.w800)),
                      Text(
                        isDelivered ? "Delivered ✅" : controller.estimatedDelivery,
                        style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 28.h),
              // Dynamic Progress Bar
              Stack(
                children: [
                  Container(
                    height: 10.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: 10.h,
                    width: filledWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDelivered
                            ? [const Color(0xFF4BFF8B), const Color(0xFF22C55E)]
                            : [const Color(0xFF8B9BFF), const Color(0xFF5D2EEF)],
                      ),
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                  ),
                  if (!isDelivered)
                    Positioned(
                      left: dotOffset,
                      top: 0,
                      child: Container(
                        height: 10.h,
                        width: 10.w,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "SHIPPED",
                    style: TextStyle(
                      color: progress >= 0.5 ? Colors.white38 : Colors.white24,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    "ARRIVING SOON",
                    style: TextStyle(
                      color: progressLabel == "ARRIVING SOON" ? const Color(0xFF8B9BFF) : Colors.white24,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    "DELIVERED",
                    style: TextStyle(
                      color: isDelivered ? const Color(0xFF4BFF8B) : Colors.white24,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJourneyTimeline(TrackOrderController controller) {
    final updates = controller.journeyUpdates;
    return Column(
      children: List.generate(updates.length, (index) {
        final item = updates[index];
        final title = item['status']?.toString() ?? item['title']?.toString() ?? 'Update';
        final description = item['description']?.toString() ?? item['text']?.toString() ?? '';
        final time = item['timestamp']?.toString() ?? item['time']?.toString() ?? '';
        final isFirst = index == 0;
        final isLast = index == updates.length - 1;

        IconData icon = Icons.local_shipping_rounded;
        if (title.toLowerCase().contains('shipped')) {
          icon = Icons.inventory_2_rounded;
        } else if (title.toLowerCase().contains('confirm') || title.toLowerCase().contains('order')) {
          icon = Icons.check_circle_outline_rounded;
        }

        return _timelineItem(
          icon: icon,
          title: title,
          subtitle: description,
          time: _formatJourneyTime(time),
          isActive: isFirst,
          isFirst: isFirst,
          isLast: isLast,
        );
      }),
    );
  }

  String _formatJourneyTime(String rawTime) {
    if (rawTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawTime).toLocal();
      final now = DateTime.now();
      final diffDays = now.difference(dt).inDays;
      
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final timeStr = "$hour:$minute $period";

      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return "Today • $timeStr";
      } else if (diffDays == 1) {
        return "Yesterday • $timeStr";
      }
      
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${months[dt.month - 1]} ${dt.day} • $timeStr";
    } catch (e) {
      return rawTime;
    }
  }

  Widget _timelineItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    bool isActive = false,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF5D2EEF).withOpacity(0.4) : Colors.white.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isActive ? const Color(0xFF8B9BFF) : Colors.white24, size: 20.sp),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.w,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
            ],
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 32.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(title, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900))),
                      Text(time, style: TextStyle(color: const Color(0xFF8B9BFF).withOpacity(0.7), fontSize: 10.sp, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(subtitle, style: TextStyle(color: Colors.white24, fontSize: 14.sp, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(TrackOrderController controller) {
    final rawImg = controller.productImage;

    return Container(
      padding: EdgeInsets.all(28.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildSummaryProductImage(rawImg),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(controller.displayOrderId, style: TextStyle(color: const Color(0xFFAC8AFF), fontSize: 11.sp, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4.h),
                    Text(controller.productTitle, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 28.h),
          const Divider(color: Colors.white10, thickness: 1),
          SizedBox(height: 24.h),
          _summaryRow("Item", "\$${controller.itemSubtotal.toStringAsFixed(2)}"),
          _summaryRow("Shipping", "\$${controller.shipping.toStringAsFixed(2)}"),
          _summaryRow("Taxes", "\$${controller.taxes.toStringAsFixed(2)}"),
          _summaryRow("Processing Fee", "\$${controller.processingFee.toStringAsFixed(2)}"),
          _summaryRow("Buyer Contribution", "\$${controller.charityContribution.toStringAsFixed(2)}", isHighlight: true),
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("TOTAL PAID", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900)),
              Text("\$${controller.totalPaid.toStringAsFixed(2)}", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 26.sp, fontWeight: FontWeight.w900)),
            ],
          ),
          SizedBox(height: 28.h),
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(color: Colors.white24, fontSize: 11.sp, height: 1.5),
                children: [
                  const TextSpan(text: "No platform markup added... \$0.05 contribution supports "),
                  TextSpan(
                    text: "Better Futures Foundation.",
                    style: TextStyle(color: const Color(0xFFFF8BFF), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isHighlight ? const Color(0xFFFF8BFF) : Colors.white38, fontSize: 15.sp, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: isHighlight ? const Color(0xFFFF8BFF) : Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildButton(String text, Color bg, Color textCol, {VoidCallback? onTap}) {
    return SizedBox(
      height: 60.h,
      child: ElevatedButton(
        onPressed: onTap ?? () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: textCol,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
          elevation: 0,
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildShippingAddressCard(TrackOrderController controller) {
    final addr = controller.shippingAddress;
    final street = addr['street']?.toString() ?? '123 Main St';
    final city = addr['city']?.toString() ?? 'New York';
    final state = addr['state']?.toString() ?? 'NY';
    final postalCode = addr['postalCode']?.toString() ?? '10001';
    final country = addr['country']?.toString() ?? 'USA';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: const Color(0xFF8B9BFF), size: 20.sp),
              SizedBox(width: 10.w),
              Text(
                "SHIPPING ADDRESS",
                style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            "$street\n$city, $state $postalCode\n$country",
            style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
      ),
    );
  }

  void _showUpdateStatusBottomSheet(BuildContext context, TrackOrderController controller) {
    String selectedDeliveryStatus = 'shipped';
    final statusTextController = TextEditingController(text: 'Shipped');
    final descTextController = TextEditingController(text: 'Package handed over to courier');
    final locationTextController = TextEditingController(text: 'Distribution Center');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24.w,
                right: 24.w,
                top: 24.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32.h,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
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
                    SizedBox(height: 20.h),
                    Text(
                      "Update Shipping Status",
                      style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      "Update tracking journey for ${controller.displayOrderId}",
                      style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                    ),
                    SizedBox(height: 24.h),

                    // Delivery Status Dropdown
                    Text("DELIVERY STATUS", style: TextStyle(color: Colors.white54, fontSize: 11.sp, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedDeliveryStatus,
                          dropdownColor: const Color(0xFF1E1E2C),
                          isExpanded: true,
                          style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700),
                          items: const [
                            DropdownMenuItem(value: 'pending', child: Text("Pending")),
                            DropdownMenuItem(value: 'shipped', child: Text("Shipped")),
                            DropdownMenuItem(value: 'delivered', child: Text("Delivered")),
                            DropdownMenuItem(value: 'cancelled', child: Text("Cancelled")),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                selectedDeliveryStatus = val;
                                if (val == 'shipped') statusTextController.text = 'Shipped';
                                if (val == 'delivered') statusTextController.text = 'Delivered';
                                if (val == 'cancelled') statusTextController.text = 'Cancelled';
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Checkpoint Status
                    Text("CHECKPOINT STATUS", style: TextStyle(color: Colors.white54, fontSize: 11.sp, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: statusTextController,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: "e.g. In Transit / Shipped",
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp),
                        filled: true,
                        fillColor: const Color(0xFF1E1E2C),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide.none),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Description
                    Text("DESCRIPTION", style: TextStyle(color: Colors.white54, fontSize: 11.sp, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: descTextController,
                      maxLines: 2,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: "e.g. Package handed over to FedEx",
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp),
                        filled: true,
                        fillColor: const Color(0xFF1E1E2C),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide.none),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Location
                    Text("LOCATION (OPTIONAL)", style: TextStyle(color: Colors.white54, fontSize: 11.sp, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: locationTextController,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: "e.g. New York Distribution Center",
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp),
                        filled: true,
                        fillColor: const Color(0xFF1E1E2C),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide.none),
                      ),
                    ),

                    SizedBox(height: 28.h),

                    // Submit Button
                    Obx(() => SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B9BFF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
                        ),
                        onPressed: controller.isUpdatingStatus.value
                            ? null
                            : () async {
                                final success = await controller.updateShippingStatus(
                                  status: statusTextController.text.trim(),
                                  description: descTextController.text.trim(),
                                  location: locationTextController.text.trim(),
                                  deliveryStatus: selectedDeliveryStatus,
                                );
                                if (success && context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                        child: controller.isUpdatingStatus.value
                            ? SizedBox(
                                width: 22.r,
                                height: 22.r,
                                child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text("Update Tracking", style: TextStyle(color: Colors.black, fontSize: 16.sp, fontWeight: FontWeight.w800)),
                      ),
                    )),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryProductImage(String rawImg) {
    final String formattedUrl = rawImg.startsWith('http') || rawImg.startsWith('data:image/')
        ? rawImg
        : (rawImg.isNotEmpty ? "${ApiUrl.imageBaseUrl}${rawImg.startsWith('/') ? rawImg : '/$rawImg'}" : "");

    return Container(
      width: 72.w,
      height: 72.w,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white10),
      ),
      child: formattedUrl.isNotEmpty
          ? (formattedUrl.startsWith('data:image/')
              ? Image.memory(
                  base64Decode(formattedUrl.split(',').last),
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, __) => _buildSummaryFallbackImage(),
                )
              : Image.network(
                  formattedUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF8B9BFF),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, e, __) => _buildSummaryFallbackImage(),
                ))
          : _buildSummaryFallbackImage(),
    );
  }

  Widget _buildSummaryFallbackImage() {
    return Container(
      color: const Color(0xFF1E1E2C),
      child: Center(
        child: Icon(
          Icons.shopping_bag_rounded,
          color: const Color(0xFF8B9BFF),
          size: 32.sp,
        ),
      ),
    );
  }
}
