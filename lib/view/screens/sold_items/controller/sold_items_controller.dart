import 'dart:convert';
import 'package:get/get.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../purchases/model/purchase_model.dart';

class SoldItemsController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final RxBool isLoading = false.obs;
  
  var selectedTab = 0.obs;
  final tabs = ["All", "Processing", "Shipped", "Delivered", "Cancelled"];
  final soldItems = <PurchaseModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchSoldItems();
  }

  Future<void> fetchSoldItems() async {
    isLoading.value = true;
    try {
      String userId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      if (userId.isEmpty) {
        try {
          final profileRes = await _apiClient.getData(ApiUrl.profile);
          if (profileRes.statusCode == 200) {
            final profileData = jsonDecode(profileRes.body)['data'];
            if (profileData != null) {
              userId = (profileData['id'] ?? profileData['_id'] ?? '').toString();
              if (userId.isNotEmpty) {
                await SharePrefsHelper.setString(SharePrefsHelper.userIdKey, userId);
              }
            }
          }
        } catch (e) {
          Get.log("⚠️ [SoldItems] Profile fetch failed: $e");
        }
      }

      final responses = await Future.wait([
        _apiClient.getData("${ApiUrl.userOrders}?role=seller"),
        _apiClient.getData(ApiUrl.userOrders),
        if (userId.isNotEmpty) _apiClient.getData("${ApiUrl.userOrders}?userId=$userId&role=seller"),
        if (userId.isNotEmpty) _apiClient.getData("${ApiUrl.userOrders}?userId=$userId"),
      ]);

      List extractListFromResponse(dynamic response) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = jsonDecode(response.body);
          if (body['success'] == true && body['data'] != null) {
            final data = body['data'];
            if (data is List) return data;
            if (data is Map && data['orders'] is List) return data['orders'];
          }
        }
        return [];
      }

      Set<String> seenIds = {};
      List<PurchaseModel> loadedList = [];

      for (var response in responses) {
        final rawList = extractListFromResponse(response);
        for (var item in rawList) {
          if (item is Map) {
            final id = (item['_id'] ?? item['id'] ?? item['orderId'] ?? '').toString();
            if (id.isEmpty || seenIds.contains(id)) continue;

            // Check if seller matches or item is sold
            final sellerObj = item['sellerId'] ?? item['seller'];
            String sellerIdStr = '';
            if (sellerObj is Map) {
              sellerIdStr = (sellerObj['_id'] ?? sellerObj['id'] ?? '').toString();
            } else if (sellerObj is String) {
              sellerIdStr = sellerObj;
            }

            // Parse product details
            final prod = item['productId'] ?? item['product'];
            String title = 'Sold Item';
            String imgUrl = '';

            if (prod is Map) {
              title = (prod['title'] ?? prod['name'] ?? 'Sold Item').toString();
              final imgs = prod['images'] ?? prod['image'];
              if (imgs is List && imgs.isNotEmpty) {
                imgUrl = imgs[0].toString();
              } else if (imgs is String) {
                imgUrl = imgs;
              }
            } else if (item['productName'] != null) {
              title = item['productName'].toString();
            }

            if (imgUrl.isEmpty) {
              final directImg = item['image'] ?? item['coverImage'] ?? item['thumbnail'] ?? item['photo'] ?? item['productImage'] ?? item['img'];
              if (directImg is List && directImg.isNotEmpty) {
                imgUrl = directImg[0].toString();
              } else if (directImg is String) {
                imgUrl = directImg;
              }
            }

            // Buyer info
            final buyerObj = item['buyerId'] ?? item['buyer'] ?? item['user'];
            String bName = '@buyer';
            String bAvatar = '';
            String bId = '';

            if (buyerObj is Map) {
              bName = (buyerObj['username'] ?? buyerObj['fullName'] ?? buyerObj['name'] ?? '@buyer').toString();
              bAvatar = (buyerObj['profile'] ?? buyerObj['profileImage'] ?? buyerObj['avatar'] ?? '').toString();
              bId = (buyerObj['_id'] ?? buyerObj['id'] ?? '').toString();
            } else if (buyerObj is String) {
              bId = buyerObj;
            }

            // Pricing
            final amountDetails = item['amountDetails'];
            double totalPaidVal = 0.0;
            if (amountDetails is Map && amountDetails['totalPaid'] != null) {
              totalPaidVal = double.tryParse(amountDetails['totalPaid'].toString()) ?? 0.0;
            } else if (item['totalAmount'] != null) {
              totalPaidVal = double.tryParse(item['totalAmount'].toString()) ?? 0.0;
            }

            // Status
            final delStatus = (item['deliveryStatus'] ?? item['status'] ?? 'pending').toString().toLowerCase();
            OrderStatus oStatus = OrderStatus.processing;
            int tStep = 2;

            if (delStatus == 'shipped' || delStatus == 'in transit' || delStatus == 'in_transit') {
              oStatus = OrderStatus.inTransit;
              tStep = 3;
            } else if (delStatus == 'delivered' || delStatus == 'completed') {
              oStatus = OrderStatus.delivered;
              tStep = 5;
            } else if (delStatus == 'cancelled') {
              oStatus = OrderStatus.cancelled;
              tStep = 1;
            }

            // Shipping Address
            Map<String, dynamic>? shipAddr;
            if (item['shippingAddress'] is Map) {
              shipAddr = Map<String, dynamic>.from(item['shippingAddress']);
            }

            final model = PurchaseModel(
              id: "#ORD-${id.length > 5 ? id.substring(id.length - 5).toUpperCase() : id.toUpperCase()}",
              title: title,
              curator: bName,
              date: item['createdAt'] != null ? item['createdAt'].toString().split('T').first : "Recently Sold",
              price: "\$${totalPaidVal.toStringAsFixed(2)}",
              carrier: item['trackingDetails']?['carrier']?.toString() ?? "USPS Ground",
              image: imgUrl,
              trackingId: item['trackingDetails']?['trackingNumber']?.toString() ?? "TRK-${id.substring(0, id.length > 6 ? 6 : id.length).toUpperCase()}",
              status: oStatus,
              trackingStep: tStep,
              estimatedDelivery: item['trackingDetails']?['estimatedDelivery']?.toString() ?? "3-5 Business Days",
              location: item['trackingDetails']?['currentLocation']?.toString() ?? "Processing Facility",
              itemPrice: amountDetails is Map ? double.tryParse(amountDetails['itemSubtotal']?.toString() ?? '0') : null,
              shippingPrice: amountDetails is Map ? double.tryParse(amountDetails['shipping']?.toString() ?? '0') : null,
              taxes: amountDetails is Map ? double.tryParse(amountDetails['taxes']?.toString() ?? '0') : null,
              processingFee: amountDetails is Map ? double.tryParse(amountDetails['processingFee']?.toString() ?? '0') : null,
              buyerContribution: amountDetails is Map ? double.tryParse(amountDetails['charityContribution']?.toString() ?? '0') : null,
              totalPaid: totalPaidVal,
              buyerName: bName,
              buyerAvatar: bAvatar,
              buyerId: bId,
              shippingAddress: shipAddr,
              rawOrderId: id,
              shippingLabelUrl: item['shippingLabelUrl']?.toString(),
            );

            seenIds.add(id);
            loadedList.add(model);
          }
        }
      }

      soldItems.assignAll(loadedList);
    } catch (e) {
      Get.log("❌ [SoldItems] Fetch Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  List<PurchaseModel> get filteredSoldItems {
    final tabName = tabs[selectedTab.value];
    if (tabName == "All") return soldItems;
    if (tabName == "Processing") return soldItems.where((e) => e.status == OrderStatus.processing).toList();
    if (tabName == "Shipped") return soldItems.where((e) => e.status == OrderStatus.inTransit).toList();
    if (tabName == "Delivered") return soldItems.where((e) => e.status == OrderStatus.delivered).toList();
    if (tabName == "Cancelled") return soldItems.where((e) => e.status == OrderStatus.cancelled).toList();
    return soldItems;
  }
}
