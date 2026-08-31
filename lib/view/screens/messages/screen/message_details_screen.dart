import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../purchases/model/purchase_model.dart';
import '../controller/message_details_controller.dart';
import '../../../../data/services/api_url.dart';

class MessageDetailsScreen extends GetView<MessageDetailsController> {
  const MessageDetailsScreen({super.key});

  PurchaseModel _getMockOrder() {
    return PurchaseModel(
      id: "ORD-24891",
      title: "Vintage Pokémon Card Pack",
      curator: "CardMaster",
      date: "Oct 21, 2023",
      price: "\$1,250",
      carrier: "USPS",
      image: "",
      trackingId: "9400 1112 3456 7890 1234 56",
      status: OrderStatus.inTransit,
      estimatedDelivery: "October 24",
      itemPrice: 1250,
      shippingPrice: 15.50,
      taxes: 42.00,
      processingFee: 12.00,
      buyerContribution: 0,
      totalPaid: 1319.50,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      safeAreaBottom: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Pinned Item — only when chat has an associated order
            Obx(() => controller.hasOrder.value
                ? _buildPinnedItem()
                : const SizedBox.shrink()),
            
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF8B9BFF),
                backgroundColor: const Color(0xFF161622),
                onRefresh: () => controller.fetchMessages(),
                child: Obx(() {
                  // Loading shimmer
                  if (controller.isLoading.value) {
                    return ListView(
                      padding: EdgeInsets.all(16.r),
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildBubbleShimmer(isMe: false),
                        _buildBubbleShimmer(isMe: true),
                        _buildBubbleShimmer(isMe: false),
                        _buildBubbleShimmer(isMe: true),
                      ],
                    );
                  }

                  // Empty state
                  if (controller.messages.isEmpty) {
                    return ListView(
                      controller: controller.scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 40.h),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(24.r),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E2C),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.forum_outlined, color: const Color(0xFF8B9BFF), size: 40.sp),
                              ),
                              SizedBox(height: 20.h),
                              Text("No messages yet", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
                              SizedBox(height: 8.h),
                              Text("Say hello to start the conversation!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 13.sp, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // Message list — starts from BOTTOM and stacks upward (Messenger style)
                  return ListView.builder(
                    controller: controller.scrollController,
                    reverse: true,
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    itemCount: controller.messages.length,
                    itemBuilder: (context, index) {
                      final reversedIndex = controller.messages.length - 1 - index;
                      final msg = controller.messages[reversedIndex];

                      // Date separator
                      if (msg['isDate'] == true) {
                        return _buildDateSeparator(msg['message'] ?? '');
                      }

                      // Order shipped card — special message type
                      if (msg['isOrderCard'] == true) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 8.h),
                            _buildTrackingCard(),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionChip(
                                    Icons.location_on_outlined,
                                    "TRACK ORDER",
                                    onTap: () => Get.toNamed(
                                      AppRoute.trackOrder,
                                      arguments: _getMockOrder(),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: _buildActionChip(
                                    Icons.check_circle_outline,
                                    "CONFIRM DELIVERY",
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                          ],
                        );
                      }

                      final bool isMe = msg['isMe'] == true;
                      final bool isRead = msg['isRead'] == true;
                      final String messageText = msg['message'] ?? '';

                      if (messageText.contains("Proposed a new trade swap offer:")) {
                        return _buildTradeOfferBubble(msg);
                      }

                      return _buildMessageBubble(
                        message: messageText,
                        time: msg['time'] ?? 'Now',
                        isMe: isMe,
                        isRead: isRead,
                      );
                    },
                  );
                }),
              ),
            ),

            // Input Bar
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      title: Obx(() {
        final avatar = controller.partnerAvatar.value;
        final name = controller.partnerName.value;
        final avatarUrl = (avatar.isNotEmpty && !avatar.startsWith('http') && !avatar.startsWith('data:image/'))
            ? "${ApiUrl.imageBaseUrl}${avatar.startsWith('/') ? avatar : '/$avatar'}"
            : avatar;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final String pid = controller.partnerId.value;
            if (pid.isNotEmpty) {
              Get.toNamed(AppRoute.traderProfile, arguments: {
                "id": pid,
                "name": name,
                "avatar": avatarUrl,
              });
            }
          },
          child: Row(
            children: [
              Container(
                width: 38.r,
                height: 38.r,
                decoration: BoxDecoration(
                  color: const Color(0xFF28283E),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.3), width: 1.5),
                ),
                child: ClipOval(
                  child: Builder(
                    builder: (context) {
                      if (avatarUrl.isEmpty) {
                        return Icon(Icons.person_rounded, color: Colors.white54, size: 22.sp);
                      }
                      if (avatarUrl.startsWith('data:image/') && avatarUrl.contains('base64,')) {
                        try {
                          final bytes = base64Decode(avatarUrl.split('base64,').last);
                          return Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: Colors.white54, size: 22.sp),
                          );
                        } catch (_) {
                          return Icon(Icons.person_rounded, color: Colors.white54, size: 22.sp);
                        }
                      }
                      return Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: Colors.white54, size: 22.sp),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Flexible(
                child: Text(
                  (name.isNotEmpty && name.toLowerCase() != 'user') ? name : "Chat",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildPinnedItem() {
    final order = controller.orderData;
    final String title = order['title'] ?? (order['productId'] is Map ? order['productId']['title'] : null) ?? "Vintage Pokémon Card Pack";
    final String orderId = order['id'] ?? order['_id'] ?? "ORD-24891";
    
    // Extract image path
    String imgPath = "";
    final List? prodImages = (order['productId'] is Map) ? (order['productId']['images'] as List?) : null;
    if (prodImages != null && prodImages.isNotEmpty) {
      imgPath = prodImages[0].toString();
    } else {
      imgPath = order['image'] ?? (order['productId'] is Map ? order['productId']['image'] : null) ?? "";
    }
    
    final String imgUrl = (imgPath.isNotEmpty)
        ? (imgPath.startsWith('http') ? imgPath : "${ApiUrl.imageBaseUrl}${imgPath.startsWith('/') ? imgPath : '/$imgPath'}")
        : "";

    return Container(
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10.r),
              image: imgUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imgUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imgUrl.isEmpty
                ? const Center(child: Icon(Icons.image, color: Colors.white24))
                : null,
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ORDER #$orderId", style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                SizedBox(height: 2.h),
                Text(title, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(color: const Color(0xFF161622), borderRadius: BorderRadius.circular(16.r)),
          child: Text(label, style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({required String message, required String time, required bool isMe, bool isRead = false}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: 0.75.sw),
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF8B9BFF) : const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24.r),
                topRight: Radius.circular(24.r),
                bottomLeft: Radius.circular(isMe ? 24.r : 4.r),
                bottomRight: Radius.circular(isMe ? 4.r : 24.r),
              ),
            ),
            child: Text(
              message,
              style: TextStyle(color: isMe ? Colors.black : Colors.white70, fontSize: 14.sp, height: 1.5, fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 8.h, bottom: 16.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: TextStyle(color: Colors.white24, fontSize: 10.sp, fontWeight: FontWeight.w700)),
                if (isMe && isRead) ...[
                  SizedBox(width: 4.w),
                  Icon(Icons.done_all_rounded, color: const Color(0xFF8B9BFF), size: 14.sp),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeOfferBubble(Map<String, dynamic> msg) {
    return Obx(() {
      final bool isMe = msg['isMe'] == true;
      final String text = msg['message'] ?? '';
      final String time = msg['time'] ?? 'Now';

      // Parse items
      final pattern = RegExp(r'Proposed a new trade swap offer:\s*(.*?)\s+for\s+(.*)', caseSensitive: false);
      final match = pattern.firstMatch(text);
      
      String offeredTitle = "Offered Item";
      String requestedTitle = "Requested Item";
      if (match != null) {
        offeredTitle = match.group(1)?.trim() ?? "";
        requestedTitle = match.group(2)?.trim() ?? "";
        if (requestedTitle.endsWith('.')) {
          requestedTitle = requestedTitle.substring(0, requestedTitle.length - 1).trim();
        }
      }

      Get.log("🔍 [TradeBubble] Parsed text: '$text'");
      Get.log("🔍 [TradeBubble] Parsed Offered: '$offeredTitle', Requested: '$requestedTitle'");
      Get.log("🔍 [TradeBubble] Total trades in memory: ${controller.associatedTrades.length}");

      // Look up trade details
      Map<String, dynamic>? tradeDetail;
      for (var trade in controller.associatedTrades) {
        final senderProduct = trade['senderProductId'] ?? {};
        final receiverProduct = trade['receiverProductId'] ?? {};

        final String sTitle = (senderProduct['title'] ?? '').toString().trim();
        final String rTitle = (receiverProduct['title'] ?? '').toString().trim();
        
        Get.log("   - Checking trade: senderProdTitle='$sTitle', receiverProdTitle='$rTitle'");

        if (sTitle.toLowerCase() == offeredTitle.toLowerCase() &&
            rTitle.toLowerCase() == requestedTitle.toLowerCase()) {
          tradeDetail = Map<String, dynamic>.from(trade);
          Get.log("   - Match found! Trade ID: ${tradeDetail['_id']}");
          break;
        }
      }

      // Get image URLs and cash supplement
      String offeredImg = "";
      String requestedImg = "";
      double cash = 0.0;
      double offeredValue = 0.0;
      double requestedValue = 0.0;
      String status = "pending";
      String tradeId = "";

      if (tradeDetail != null) {
        tradeId = tradeDetail['_id']?.toString() ?? "";
        status = tradeDetail['status']?.toString().toLowerCase() ?? "pending";
        cash = double.tryParse(tradeDetail['cashSupplement']?.toString() ?? '0') ?? 0.0;

        final senderProduct = tradeDetail['senderProductId'] ?? {};
        final receiverProduct = tradeDetail['receiverProductId'] ?? {};

        offeredValue = double.tryParse(senderProduct['estValue']?.toString() ?? '0') ?? 0.0;
        requestedValue = double.tryParse(receiverProduct['estValue']?.toString() ?? '0') ?? 0.0;

        final senderImages = senderProduct['images'];
        if (senderImages != null && senderImages is List && senderImages.isNotEmpty) {
          offeredImg = senderImages[0].toString();
        }

        final receiverImages = receiverProduct['images'];
        if (receiverImages != null && receiverImages is List && receiverImages.isNotEmpty) {
          requestedImg = receiverImages[0].toString();
        }
      }

      Get.log("🔍 [TradeBubble] Resolved OfferedImg: '$offeredImg'");
      Get.log("🔍 [TradeBubble] Resolved RequestedImg: '$requestedImg'");

      // Color scheme
      final Color cardBg = const Color(0xFF161622);
      final Color borderColor = const Color(0xFF8B9BFF).withOpacity(0.15);

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(bottom: 16.h),
          width: 0.82.sw,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B9BFF).withOpacity(0.05),
                blurRadius: 16.r,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22.r),
                    topRight: Radius.circular(22.r),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.swap_horizontal_circle_outlined, color: const Color(0xFF8B9BFF), size: 18.sp),
                        SizedBox(width: 8.w),
                        Text(
                          "TRADE PROPOSAL",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: status == "pending"
                            ? const Color(0xFF8B9BFF).withOpacity(0.1)
                            : (status == "accepted" || status == "completed"
                                ? const Color(0xFF22C55E).withOpacity(0.1)
                                : const Color(0xFFFF4B4B).withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: status == "pending"
                              ? const Color(0xFF8B9BFF)
                              : (status == "accepted" || status == "completed"
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFFF4B4B)),
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Swap comparison
              Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Offered Item (Sender)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMe ? "YOU OFFER" : "THEY OFFER",
                                style: TextStyle(color: Colors.white38, fontSize: 9.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                              SizedBox(height: 8.h),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12.r),
                                child: _buildProductImage(offeredImg, height: 90.h, width: double.infinity),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                offeredTitle,
                                style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (offeredValue > 0) ...[
                                SizedBox(height: 2.h),
                                Text(
                                  "Est. \$${offeredValue.toInt()}",
                                  style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Swap Icon
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E2C),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Icon(Icons.sync_alt_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                          ),
                        ),

                        // Requested Item (Receiver)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMe ? "YOU RECEIVE" : "THEY REQUEST",
                                style: TextStyle(color: Colors.white38, fontSize: 9.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                              SizedBox(height: 8.h),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12.r),
                                child: _buildProductImage(requestedImg, height: 90.h, width: double.infinity),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                requestedTitle,
                                style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (requestedValue > 0) ...[
                                SizedBox(height: 2.h),
                                Text(
                                  "Est. \$${requestedValue.toInt()}",
                                  style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Cash supplement if > 0
                    if (cash > 0) ...[
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B9BFF).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_card_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                            SizedBox(width: 8.w),
                            Text(
                              isMe 
                                  ? "+ \$${cash.toInt()} Cash Supplement Offered" 
                                  : "+ \$${cash.toInt()} Cash Supplement Included",
                              style: TextStyle(
                                color: const Color(0xFF8B9BFF),
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons — only when status is pending, and tradeId is available
              if (status == "pending" && tradeId.isNotEmpty) ...[
                if (!isMe) ...[
                  // Receiver's view: Accept / Decline buttons
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => controller.handleDeclineTrade(tradeId),
                            child: Container(
                              height: 44.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(22.r),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Text(
                                "Decline",
                                style: TextStyle(color: const Color(0xFFFF4B4B), fontSize: 12.sp, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => controller.handleAcceptTrade(tradeId),
                            child: Container(
                              height: 44.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8B9BFF), Color(0xFFBD8BFF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B9BFF).withOpacity(0.2),
                                    blurRadius: 8.r,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                "Accept Offer",
                                style: TextStyle(color: Colors.black, fontSize: 12.sp, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Sender's view: "Waiting for response" text
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                    child: Center(
                      child: Text(
                        "Waiting for trader's response...",
                        style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ],
              ] else if (status == "accepted" && tradeId.isNotEmpty) ...[
                // Accepted but pending completion status
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  child: Builder(
                    builder: (context) {
                      if (isMe) {
                        // Sender (Buyer) who proposed the offer can complete/pay
                        return GestureDetector(
                          onTap: () => controller.completeTradeOffer(tradeId),
                          child: Container(
                            height: 44.h,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B9BFF), Color(0xFFBD8BFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22.r),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B9BFF).withOpacity(0.2),
                                  blurRadius: 8.r,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  cash > 0 ? Icons.payment_rounded : Icons.check_circle_rounded,
                                  color: Colors.black,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  cash > 0 ? "Pay & Complete" : "Complete Swap",
                                  style: TextStyle(color: Colors.black, fontSize: 12.sp, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        // Receiver (Seller) who accepted the offer sees "Accepted" status
                        return Container(
                          height: 44.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(22.r),
                            border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: const Color(0xFF22C55E), size: 16.sp),
                              SizedBox(width: 8.w),
                              Text(
                                "Accepted",
                                style: TextStyle(color: const Color(0xFF22C55E), fontSize: 12.sp, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ] else if (status != "pending" && status != "accepted" && tradeId.isNotEmpty) ...[
                // Status feedback message (Decline or Completed)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  child: Center(
                    child: Text(
                      status == "completed"
                          ? "Trade Completed Successfully! ✅"
                          : "Trade Proposal Declined",
                      style: TextStyle(
                        color: status == "completed" ? const Color(0xFF22C55E) : const Color(0xFFFF4B4B),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
              
              // Time details footer
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(time, style: TextStyle(color: Colors.white24, fontSize: 9.sp, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildProductImage(String imgStr, {double? height, double? width, BoxFit fit = BoxFit.cover}) {
    if (imgStr.isEmpty) {
      return Container(
        height: height,
        width: width,
        color: Colors.black26,
        child: const Center(child: Icon(Icons.image, color: Colors.white24)),
      );
    }
    if (imgStr.startsWith('data:image/') && imgStr.contains('base64,')) {
      try {
        final bytes = base64Decode(imgStr.split('base64,').last);
        return Image.memory(
          bytes,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(
            height: height,
            width: width,
            color: Colors.black26,
            child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24)),
          ),
        );
      } catch (_) {
        return Container(
          height: height,
          width: width,
          color: Colors.black26,
          child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24)),
        );
      }
    }
    final cleanUrl = imgStr.startsWith('http') ? imgStr : "${ApiUrl.imageBaseUrl}${imgStr.startsWith('/') ? imgStr : '/$imgStr'}";
    return Image.network(
      cleanUrl,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: width,
        color: Colors.black26,
        child: const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white24)),
      ),
    );
  }

  Widget _buildTrackingCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text("ORDER SHIPPED 🚚", style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900)),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8.r)),
                    child: Text("IN TRANSIT", style: TextStyle(color: Colors.white38, fontSize: 9.sp, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              Icon(Icons.local_shipping_outlined, color: Colors.white24, size: 24.sp),
            ],
          ),
          SizedBox(height: 4.h),
          Text("Your order is on the way!", style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w700)),
          
          SizedBox(height: 40.h),
          
          // Map Placeholder / Timeline
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 250.w,
                  height: 2.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white10, const Color(0xFF8B9BFF).withOpacity(0.5), Colors.white10],
                    ),
                  ),
                ),
                Positioned(
                  child: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: const BoxDecoration(color: Color(0xFF161622), shape: BoxShape.circle),
                    child: Icon(Icons.location_on, color: const Color(0xFF8B9BFF), size: 28.sp),
                  ),
                ),
                Positioned(
                  top: -40.h,
                  right: -20.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(color: const Color(0xFFFF8BFF).withOpacity(0.2), borderRadius: BorderRadius.circular(10.r)),
                    child: Text("ETA: 2 Days", style: TextStyle(color: const Color(0xFFFF8BFF), fontSize: 10.sp, fontWeight: FontWeight.w900)),
                  ),
                ),
                Positioned(
                  bottom: -30.h,
                  child: Column(
                    children: [
                      Text("📍 Current Location", style: TextStyle(color: Colors.white38, fontSize: 9.sp, fontWeight: FontWeight.w900)),
                      Text("Moving towards destination", style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 60.h),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTrackingInfo("CARRIER", "USPS"),
              _buildTrackingInfo("ESTIMATED DELIVERY", "October 24", isAccent: true),
            ],
          ),
          SizedBox(height: 20.h),
          _buildTrackingInfo("TRACKING NUMBER", "9400 1112 3456 7890 1234 56", isCopyable: true),
          
          SizedBox(height: 24.h),
          
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16.r)),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.white38, size: 18.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("LAST UPDATE", style: TextStyle(color: Colors.white38, fontSize: 9.sp, fontWeight: FontWeight.w900)),
                      Text("Departed USPS Facility Chicago, IL — Oct 21, 8:14 AM", style: TextStyle(color: Colors.white70, fontSize: 10.sp, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24.h),
          
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: () => Get.toNamed(AppRoute.trackOrder, arguments: _getMockOrder()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B9BFF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
                elevation: 0,
              ),
              child: Text("TRACK ORDER", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingInfo(String label, String value, {bool isAccent = false, bool isCopyable = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        SizedBox(height: 4.h),
        Row(
          children: [
            Text(value, style: TextStyle(color: isAccent ? const Color(0xFFFF8BFF) : Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900)),
            if (isCopyable) ...[
              SizedBox(width: 8.w),
              Icon(Icons.copy, color: Colors.white24, size: 16.sp),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBubbleShimmer({required bool isMe}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        width: 200.w,
        height: 44.h,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
            bottomLeft: Radius.circular(isMe ? 24.r : 4.r),
            bottomRight: Radius.circular(isMe ? 4.r : 24.r),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF8B9BFF), size: 18.sp),
            SizedBox(width: 8.w),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, (bottomPadding > 0 ? bottomPadding : 16.h) + 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D15),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(Icons.add, color: Colors.white, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Container(
              height: 56.h,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(28.r),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.chatInputController,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (val) {
                        controller.sendMessage(val);
                      },
                    ),
                  ),
                  Icon(Icons.sentiment_satisfied_alt_outlined, color: Colors.white24, size: 24.sp),
                ],
              ),
            ),
          ),
          SizedBox(width: 16.w),
          GestureDetector(
            onTap: () {
              controller.sendMessage(controller.chatInputController.text);
            },
            child: Container(
              height: 56.h,
              width: 56.h,
              decoration: const BoxDecoration(color: Color(0xFF8B9BFF), shape: BoxShape.circle),
              child: Icon(Icons.send_rounded, color: Colors.black, size: 24.sp),
            ),
          ),
        ],
      ),
    );
  }
}
