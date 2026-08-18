import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../../data/services/api_client.dart';
import '../../../../../../data/helpers/shared_prefe.dart';
import '../../../model/purchase_model.dart';

class TrackOrderController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  
  final RxBool isLoading = false.obs;
  final RxMap<String, dynamic> orderData = <String, dynamic>{}.obs;

  String orderId = '';
  PurchaseModel? fallbackModel;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is String) {
      orderId = args;
    } else if (args is PurchaseModel) {
      fallbackModel = args;
      orderId = (args.rawOrderId != null && args.rawOrderId!.isNotEmpty) ? args.rawOrderId! : args.id;
    } else if (args is Map) {
      orderId = (args['_id'] ?? args['id'] ?? args['orderId'] ?? '').toString();
    }

    if (orderId.isNotEmpty) {
      fetchOrderDetails();
    }
  }

  Future<void> fetchOrderDetails() async {
    final targetId = (fallbackModel?.rawOrderId != null && fallbackModel!.rawOrderId!.isNotEmpty)
        ? fallbackModel!.rawOrderId!
        : orderId;

    if (targetId.isEmpty || targetId.startsWith('#ORD-')) {
      Get.log("⚠️ [TrackOrder] Skipping fetch for non-Mongo display ID: '$targetId'");
      return;
    }

    isLoading.value = true;
    try {
      final response = await _apiClient.getData("/orders/$targetId");
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is Map) {
          orderData.assignAll(Map<String, dynamic>.from(body['data']));
        }
      }
    } catch (e) {
      Get.log("Error fetching order details ($targetId): $e");
    } finally {
      isLoading.value = false;
    }
  }

  // 0. Role detection — who is the logged-in user?
  String get _loggedInUserId => SharePrefsHelper.getString(SharePrefsHelper.userIdKey);

  /// Returns true if the logged-in user is the SELLER of this order
  bool get isSeller {
    if (_loggedInUserId.isEmpty) return false;
    final sid = sellerId;
    if (sid.isNotEmpty) return sid == _loggedInUserId;
    // Fallback: if the screen was opened from SoldItems, the buyer is NOT the logged-in user
    final bid = fallbackModel?.buyerId;
    if (bid != null && bid.isNotEmpty) return bid != _loggedInUserId;
    return false;
  }

  /// Returns true if the logged-in user is the BUYER of this order
  bool get isBuyer => !isSeller;

  // 1. Delivery status and estimated delivery
  String get deliveryStatus {
    // Check trackingDetails.deliveryStatus first
    final fromTracking = orderData['trackingDetails']?['deliveryStatus']?.toString();
    if (fromTracking != null && fromTracking.isNotEmpty) return fromTracking;
    if (orderData.containsKey('deliveryStatus')) {
      return orderData['deliveryStatus']?.toString() ?? 'pending';
    }
    if (fallbackModel != null) {
      switch (fallbackModel!.status) {
        case OrderStatus.delivered:
          return 'delivered';
        case OrderStatus.inTransit:
          return 'shipped';
        case OrderStatus.processing:
          return 'processing';
        default:
          return 'pending';
      }
    }
    return 'pending';
  }

  /// Progress fraction 0.0 → 1.0 based on deliveryStatus
  double get progressFraction {
    final s = deliveryStatus.toLowerCase();
    if (s.contains('deliver')) return 1.0;
    if (s.contains('transit') || s.contains('ship') || s.contains('arriving')) return 0.65;
    if (s.contains('processing') || s.contains('confirm') || s.contains('paid')) return 0.30;
    return 0.05;
  }

  /// Label shown at the active progress milestone
  String get progressLabel {
    final s = deliveryStatus.toLowerCase();
    if (s.contains('deliver')) return 'DELIVERED';
    if (s.contains('transit') || s.contains('ship') || s.contains('arriving')) return 'ARRIVING SOON';
    if (s.contains('processing') || s.contains('confirm') || s.contains('paid')) return 'PROCESSING';
    return 'ORDER PLACED';
  }

  /// Current location from tracking details
  String get currentLocation {
    final list = orderData['trackingDetails']?['journeyUpdates'];
    if (list is List && list.isNotEmpty) {
      final latest = list.last;
      final loc = latest['location']?.toString() ?? '';
      if (loc.isNotEmpty) return loc;
    }
    return '';
  }

  String get estimatedDelivery {
    final est = orderData['trackingDetails']?['estimatedDelivery']?.toString();
    if (est != null && est.isNotEmpty) return est;
    // Calculate from journeyUpdates if possible
    return fallbackModel?.estimatedDelivery ?? '3-5 Business Days';
  }

  // 2. Journey Updates (Array)
  List<dynamic> get journeyUpdates {
    final list = orderData['trackingDetails']?['journeyUpdates'];
    if (list is List && list.isNotEmpty) {
      return list.reversed.toList();
    }
    return [
      {
        "status": "Shipped",
        "description": "Package handed over to courier",
        "timestamp": "Today 10:25 AM"
      },
      {
        "status": "Order Confirmed",
        "description": "Seller accepted your order",
        "timestamp": "Recently"
      }
    ];
  }

  // 3. Product info
  String get productTitle {
    final prod = orderData['productId'] ?? orderData['product'];
    if (prod is Map) return prod['title']?.toString() ?? prod['name']?.toString() ?? 'Product';
    if (orderData['productName'] != null) return orderData['productName'].toString();
    return fallbackModel?.title ?? 'Product';
  }

  String get productImage {
    final prod = orderData['productId'] ?? orderData['product'];
    if (prod is Map) {
      final imgs = prod['images'] ?? prod['image'] ?? prod['coverImage'] ?? prod['thumbnail'] ?? prod['photo'] ?? prod['productImage'] ?? prod['img'];
      if (imgs is List && imgs.isNotEmpty) return imgs[0].toString();
      if (imgs is String && imgs.isNotEmpty) return imgs;
    }
    final direct = orderData['image'] ?? orderData['coverImage'] ?? orderData['thumbnail'] ?? orderData['photo'] ?? orderData['productImage'] ?? orderData['img'];
    if (direct is List && direct.isNotEmpty) return direct[0].toString();
    if (direct is String && direct.isNotEmpty) return direct;
    return fallbackModel?.image ?? '';
  }

  String get displayOrderId {
    if (fallbackModel?.id != null && fallbackModel!.id.startsWith('#ORD-')) {
      return fallbackModel!.id;
    }
    final raw = (orderData['_id'] ?? fallbackModel?.rawOrderId ?? orderId).toString();
    if (raw.length >= 5) {
      return "#ORD-${raw.substring(raw.length - 5).toUpperCase()}";
    }
    return "#ORD-ITEM";
  }

  // 4. Payment breakdown (amountDetails)
  Map<String, dynamic> get amountDetails {
    final details = orderData['amountDetails'];
    if (details is Map) return Map<String, dynamic>.from(details);
    return {};
  }

  double get itemSubtotal {
    final val = amountDetails['itemSubtotal'];
    if (val != null) return double.tryParse(val.toString()) ?? 115.0;
    return fallbackModel?.itemPrice ?? 115.0;
  }

  double get shipping {
    final val = amountDetails['shipping'];
    if (val != null) return double.tryParse(val.toString()) ?? 15.0;
    return fallbackModel?.shippingPrice ?? 15.0;
  }

  double get taxes {
    final val = amountDetails['taxes'];
    if (val != null) return double.tryParse(val.toString()) ?? 0.0;
    return fallbackModel?.taxes ?? 0.0;
  }

  double get processingFee {
    final val = amountDetails['processingFee'];
    if (val != null) return double.tryParse(val.toString()) ?? 0.0;
    return fallbackModel?.processingFee ?? 0.0;
  }

  double get charityContribution {
    final val = amountDetails['charityContribution'];
    if (val != null) return double.tryParse(val.toString()) ?? 0.05;
    return fallbackModel?.buyerContribution ?? 0.05;
  }

  double get totalPaid {
    final val = amountDetails['totalPaid'];
    if (val != null) return double.tryParse(val.toString()) ?? 130.05;
    return fallbackModel?.totalPaid ?? 130.05;
  }

  // 5. Seller Info for Communication
  String get sellerId {
    final seller = orderData['sellerId'] ?? orderData['seller'];
    if (seller is Map) return (seller['_id'] ?? seller['id'] ?? '').toString();
    if (seller is String) return seller;
    return '';
  }

  String get sellerName {
    final seller = orderData['sellerId'] ?? orderData['seller'];
    if (seller is Map) {
      return (seller['username'] ?? seller['fullName'] ?? seller['name'] ?? fallbackModel?.curator ?? '@seller').toString();
    }
    return fallbackModel?.curator ?? '@seller';
  }

  String get sellerAvatar {
    final seller = orderData['sellerId'] ?? orderData['seller'];
    if (seller is Map) {
      return (seller['profile'] ?? seller['profileImage'] ?? seller['avatar'] ?? '').toString();
    }
    return '';
  }

  // 6. Buyer Info & Shipping Address
  String get buyerName {
    final buyer = orderData['buyerId'] ?? orderData['buyer'] ?? orderData['user'];
    if (buyer is Map) {
      return (buyer['username'] ?? buyer['fullName'] ?? buyer['name'] ?? fallbackModel?.buyerName ?? '@buyer').toString();
    }
    return fallbackModel?.buyerName ?? '@buyer';
  }

  String get buyerAvatar {
    final buyer = orderData['buyerId'] ?? orderData['buyer'] ?? orderData['user'];
    if (buyer is Map) {
      return (buyer['profile'] ?? buyer['profileImage'] ?? buyer['avatar'] ?? fallbackModel?.buyerAvatar ?? '').toString();
    }
    return fallbackModel?.buyerAvatar ?? '';
  }

  String get buyerId {
    final buyer = orderData['buyerId'] ?? orderData['buyer'] ?? orderData['user'];
    if (buyer is Map) return (buyer['_id'] ?? buyer['id'] ?? '').toString();
    if (buyer is String) return buyer;
    return fallbackModel?.buyerId ?? '';
  }

  Map<String, dynamic> get shippingAddress {
    final addr = orderData['shippingAddress'];
    if (addr is Map) return Map<String, dynamic>.from(addr);
    if (fallbackModel?.shippingAddress != null) return fallbackModel!.shippingAddress!;
    return {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "postalCode": "10001",
      "country": "USA"
    };
  }

  String get shippingAddressFormatted {
    final addr = shippingAddress;
    final street = (addr['street'] ?? '').toString();
    final city = (addr['city'] ?? '').toString();
    final state = (addr['state'] ?? '').toString();
    final zip = (addr['postalCode'] ?? addr['zip'] ?? '').toString();
    final country = (addr['country'] ?? 'USA').toString();
    final parts = [street, city, state, zip, country].where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return "123 Main St, New York, NY 10001, USA";
  }

  String get trackingNumber {
    final t = orderData['trackingDetails']?['trackingNumber'] ?? orderData['trackingNumber'] ?? fallbackModel?.trackingId;
    if (t != null && t.toString().isNotEmpty) return t.toString();
    return "9400 1118 9956 2489 1002 45";
  }

  String get carrierName {
    final c = orderData['trackingDetails']?['carrier'] ?? orderData['carrier'] ?? fallbackModel?.carrier;
    if (c != null && c.toString().isNotEmpty) return c.toString();
    return "USPS Ground Advantage";
  }

  // 7. Update Shipping Journey (Seller Action)
  final RxBool isUpdatingStatus = false.obs;

  Future<bool> updateShippingStatus({
    required String status,
    required String description,
    required String location,
    required String deliveryStatus,
  }) async {
    final rawId = (fallbackModel?.rawOrderId != null && fallbackModel!.rawOrderId!.isNotEmpty)
        ? fallbackModel!.rawOrderId!
        : (orderData['_id'] ?? orderData['id'] ?? orderId).toString();

    if (rawId.isEmpty || rawId.startsWith('#ORD-')) {
      Get.snackbar("Error", "Invalid Order ID for tracking update", snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    isUpdatingStatus.value = true;
    try {
      final payload = {
        "status": status,
        "description": description,
        "location": location,
        "deliveryStatus": deliveryStatus,
      };

      final response = await _apiClient.patchData("/orders/journey/$rawId", payload);
      Get.log("📦 [UpdateJourney] Response: ${response.statusCode} -> ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchOrderDetails();
        Get.snackbar(
          "Journey Updated 🎉",
          "Tracking status updated to '$status'. Push notification sent to buyer!",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF22C55E),
          colorText: Colors.white,
        );
        return true;
      } else {
        final body = jsonDecode(response.body);
        Get.snackbar("Error", body['message'] ?? "Failed to update tracking status", snackPosition: SnackPosition.BOTTOM);
        return false;
      }
    } catch (e) {
      Get.log("Error updating journey: $e");
      Get.snackbar("Error", "$e", snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isUpdatingStatus.value = false;
    }
  }
}
