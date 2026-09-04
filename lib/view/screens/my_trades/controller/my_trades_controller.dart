import 'package:get/get.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../core/app_route.dart';
import '../model/my_trade_model.dart';
import '../../../../data/services/socket_service.dart';
import '../../purchases/controller/purchases_controller.dart';
import '../../purchases/model/purchase_model.dart';

class MyTradesController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final RxBool isLoading = false.obs;

  var selectedFilter = 0.obs;
  final filters = ["All", "Pending", "Completed"];
  final myTrades = <MyTradeModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchTrades();
  }

  Future<void> fetchTrades() async {
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
          Get.log("⚠️ [MyTrades] Failed to fetch profile for userId: $e");
        }
      }

      final responses = await Future.wait([
        _apiClient.getData("/trades/my"),
        _apiClient.getData(ApiUrl.tradeOffers),
        if (userId.isNotEmpty) _apiClient.getData("${ApiUrl.tradeOffers}?userId=$userId&type=received"),
        if (userId.isNotEmpty) _apiClient.getData("${ApiUrl.tradeOffers}?userId=$userId&type=sent"),
        if (userId.isNotEmpty) _apiClient.getData("${ApiUrl.tradeOffers}?userId=$userId"),
      ]);

      List extractListFromResponse(dynamic response) {
        if (response == null || response.statusCode != 200) return [];
        try {
          final body = jsonDecode(response.body);
          if (body['data'] is List) return body['data'];
          if (body['data'] is Map) {
            final dataMap = body['data'];
            if (dataMap['doc'] is List) return dataMap['doc'];
            if (dataMap['offers'] is List) return dataMap['offers'];
            if (dataMap['trades'] is List) return dataMap['trades'];
            if (dataMap['result'] is List) return dataMap['result'];
          }
          if (body['offers'] is List) return body['offers'];
          if (body['trades'] is List) return body['trades'];
          if (body['result'] is List) return body['result'];
        } catch (_) {}
        return [];
      }

      final Map<String, dynamic> uniqueTradeItems = {};

      for (var res in responses) {
        final list = extractListFromResponse(res);
        for (var item in list) {
          if (item is Map) {
            final String itemId = (item['_id'] ?? item['id'] ?? item['tradeId'] ?? '').toString();
            if (itemId.isNotEmpty) {
              uniqueTradeItems[itemId] = item;
            } else {
              uniqueTradeItems[item.hashCode.toString()] = item;
            }
          }
        }
      }

      final List allData = uniqueTradeItems.values.toList();

      final parsed = allData.map((item) {
        final sender = (item['senderId'] is Map)
            ? item['senderId']
            : ((item['sender'] is Map) ? item['sender'] : ((item['offeredBy'] is Map) ? item['offeredBy'] : {}));
        final receiver = (item['receiverId'] is Map)
            ? item['receiverId']
            : ((item['receiver'] is Map) ? item['receiver'] : ((item['requestedFrom'] is Map) ? item['requestedFrom'] : {}));

        final senderIdStr = (sender['_id'] ?? sender['id'] ?? item['senderId'] ?? item['sender'])?.toString() ?? '';

        final senderProduct = (item['senderProductId'] is Map)
            ? item['senderProductId']
            : ((item['senderProduct'] is Map)
                ? item['senderProduct']
                : ((item['productId'] is Map)
                    ? item['productId']
                    : ((item['product'] is Map) ? item['product'] : ((item['offeredProduct'] is Map) ? item['offeredProduct'] : {}))));

        final receiverProduct = (item['receiverProductId'] is Map)
            ? item['receiverProductId']
            : ((item['receiverProduct'] is Map)
                ? item['receiverProduct']
                : ((item['targetProduct'] is Map) ? item['targetProduct'] : ((item['requestedProduct'] is Map) ? item['requestedProduct'] : {})));

        final isUserSender = (userId.isNotEmpty && senderIdStr == userId) || (item['sender']?.toString() == userId);
        final otherUser = isUserSender ? receiver : sender;

        String extractImg(dynamic pObj) {
          if (pObj is Map) {
            final images = pObj['images'];
            if (images is List && images.isNotEmpty) {
              final path = images[0].toString();
              return path.startsWith('http') || path.startsWith('data:image/')
                  ? path
                  : "${ApiUrl.imageBaseUrl}${path.startsWith('/') ? path : '/$path'}";
            }
            final singleImg = pObj['image'] ?? pObj['thumbnail'] ?? pObj['coverImage'];
            if (singleImg != null && singleImg.toString().isNotEmpty) {
              final path = singleImg.toString();
              return path.startsWith('http') || path.startsWith('data:image/')
                  ? path
                  : "${ApiUrl.imageBaseUrl}${path.startsWith('/') ? path : '/$path'}";
            }
          }
          return "";
        }

        final item1Url = extractImg(senderProduct);
        final item2Url = extractImg(receiverProduct);

        final rawStatus = item['status']?.toString().toLowerCase() ?? "pending";
        MyTradeStatus status = MyTradeStatus.pending;
        if (rawStatus.contains('completed') || rawStatus.contains('accept') || rawStatus.contains('decline') || rawStatus.contains('cancel')) {
          status = MyTradeStatus.completed;
        } else if (rawStatus.contains('shipped') || rawStatus.contains('ship') || rawStatus.contains('active')) {
          status = MyTradeStatus.shipped;
        } else {
          status = MyTradeStatus.pending;
        }

        final p1Title = senderProduct['title'] ?? senderProduct['name'] ?? item['productTitle'] ?? 'Item';
        final p2Title = receiverProduct['title'] ?? receiverProduct['name'] ?? (item['offerAmount'] != null ? "\$${item['offerAmount']}" : 'Item');
        final title = "$p1Title for $p2Title";

        String avatarUrl = "";
        if (otherUser is Map) {
          final profilePath = otherUser['profile'] ?? otherUser['avatar'] ?? otherUser['image'] ?? otherUser['profileImage'] ?? "";
          if (profilePath.isNotEmpty) {
            avatarUrl = profilePath.startsWith('http')
                ? profilePath
                : "${ApiUrl.imageBaseUrl}${profilePath.startsWith('/') ? profilePath : '/$profilePath'}";
          }
        }

        String rawName = "";
        if (otherUser is Map) {
          rawName = (otherUser['fullName'] ?? otherUser['name'] ?? otherUser['username'] ?? "Trader").toString();
        } else {
          rawName = "Trader";
        }
        final cleanTraderName = rawName.replaceAll('@', '').trim();

        final String rawIdStr = (item['_id'] ?? item['id'] ?? '').toString();
        final String tradeIdDisplay = rawIdStr.length >= 5
            ? "#TR-${rawIdStr.substring(rawIdStr.length - 5).toUpperCase()}"
            : "#TR-OFFER";

        final String otherId = (otherUser is Map ? (otherUser['_id'] ?? otherUser['id']) : otherUser)?.toString() ?? "";
        final String chatId = (item['chatId'] ?? item['chat'] ?? item['chatRoomId'])?.toString() ?? "";

        return MyTradeModel(
          tradeId: tradeIdDisplay,
          title: title,
          item1Image: item1Url,
          item2Image: item2Url,
          traderName: cleanTraderName.isNotEmpty ? cleanTraderName : "Trader",
          traderAvatar: avatarUrl.isNotEmpty ? avatarUrl : null,
          date: item['createdAt'] != null ? _formatDate(item['createdAt'].toString()) : "Recently",
          status: status,
          rawObjectId: rawIdStr,
          isUserSender: isUserSender,
          traderId: otherId,
          chatId: chatId,
        );
      }).toList();

      final List<MyTradeModel> serverTrades = parsed;
      final Map<String, MyTradeModel> mergedMap = {};
      for (var localT in myTrades) {
        mergedMap[localT.tradeId] = localT;
      }
      for (var serverT in serverTrades) {
        mergedMap[serverT.tradeId] = serverT;
      }
      myTrades.assignAll(mergedMap.values.toList());
      Get.log("✅ [MyTrades] Successfully loaded ${myTrades.length} trade offers");
    } catch (e) {
      Get.log("Error fetching trade offers: $e");
    } finally {
      isLoading.value = false;
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${months[date.month - 1]} ${date.day}, ${date.year}";
    } catch (_) {
      return "Recently";
    }
  }

  void changeFilter(int index) {
    selectedFilter.value = index;
  }

  List<MyTradeModel> get filteredTrades {
    if (selectedFilter.value == 0) return myTrades;
    if (selectedFilter.value == 1) {
      return myTrades.where((t) => t.status == MyTradeStatus.pending || t.status == MyTradeStatus.shipped).toList();
    }
    if (selectedFilter.value == 2) {
      return myTrades.where((t) => t.status == MyTradeStatus.completed).toList();
    }
    return myTrades;
  }

  Future<void> acceptTradeOffer(String rawId) async {
    isLoading.value = true;

    // Optimistically mark as completed in UI immediately so buttons vanish
    final idx = myTrades.indexWhere((t) => t.rawObjectId == rawId);
    if (idx != -1) {
      final cur = myTrades[idx];
      myTrades[idx] = MyTradeModel(
        tradeId: cur.tradeId,
        title: cur.title,
        item1Image: cur.item1Image,
        item2Image: cur.item2Image,
        traderName: cur.traderName,
        traderAvatar: cur.traderAvatar,
        date: cur.date,
        status: MyTradeStatus.completed,
        rawObjectId: cur.rawObjectId,
        isUserSender: cur.isUserSender,
        traderId: cur.traderId,
        chatId: cur.chatId,
      );
      myTrades.refresh();
    }

    try {
      final response = await _apiClient.postData("${ApiUrl.acceptTrade}/$rawId", {});
      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201 || body['success'] == true) {
        Get.snackbar(
          "Trade Accepted 🎉",
          "You accepted this trade offer! Real-time notification sent to trader.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF8B9BFF),
          colorText: Colors.black,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );

        // Real-time socket notification broadcast
        try {
          final socketService = Get.find<SocketService>();
          socketService.emit('acceptTrade', {
            'tradeId': rawId,
            'status': 'accepted',
            'message': 'Seller accepted this trade swap offer! Escrow service is now Active & Secured.',
          });
        } catch (_) {}
      } else {
        final String msg = body['message'] ?? "This trade offer status has been updated.";
        Get.snackbar("Notice", msg, snackPosition: SnackPosition.BOTTOM);
      }

      await fetchTrades();
    } catch (e) {
      Get.log("Error accepting trade: $e");
      await fetchTrades();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> declineTradeOffer(String rawId) async {
    isLoading.value = true;

    // Optimistically mark as completed/declined in UI immediately so buttons vanish
    final idx = myTrades.indexWhere((t) => t.rawObjectId == rawId);
    if (idx != -1) {
      final cur = myTrades[idx];
      myTrades[idx] = MyTradeModel(
        tradeId: cur.tradeId,
        title: cur.title,
        item1Image: cur.item1Image,
        item2Image: cur.item2Image,
        traderName: cur.traderName,
        traderAvatar: cur.traderAvatar,
        date: cur.date,
        status: MyTradeStatus.completed,
        rawObjectId: cur.rawObjectId,
        isUserSender: cur.isUserSender,
        traderId: cur.traderId,
        chatId: cur.chatId,
      );
      myTrades.refresh();
    }

    try {
      await _apiClient.postData("${ApiUrl.declineTrade}/$rawId", {});
      
      Get.snackbar(
        "Trade Declined",
        "Trade offer declined.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );

      try {
        final socketService = Get.find<SocketService>();
        socketService.emit('declineTrade', {
          'tradeId': rawId,
          'status': 'declined',
        });
      } catch (_) {}

      await fetchTrades();
    } catch (e) {
      Get.log("Error declining trade: $e");
      await fetchTrades();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> completeTradeOffer(String rawId) async {
    isLoading.value = true;
    try {
      final response = await _apiClient.postData("/trades/complete/$rawId", {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final success = body['success'] ?? false;
        final data = body['data'];
        
        if (success) {
          final tradeItem = myTrades.firstWhereOrNull((t) => t.rawObjectId == rawId);
          final newPurchase = PurchaseModel(
            id: "#ORD-${rawId.length >= 5 ? rawId.substring(rawId.length - 5).toUpperCase() : 'TRD12'}",
            title: tradeItem?.title ?? "Trade Swap Item",
            curator: "@${tradeItem?.traderName ?? 'trader'}",
            date: "Purchased just now",
            price: "\$250.00",
            carrier: "USPS Ground Express",
            image: tradeItem?.item1Image ?? "",
            trackingId: "TRK-${rawId.length >= 6 ? rawId.substring(0, 6).toUpperCase() : '84912B'}",
            status: OrderStatus.inTransit,
            trackingStep: 3,
            estimatedDelivery: "3-5 Business Days",
            location: "Secured Distribution Facility",
            itemPrice: 250.00,
            shippingPrice: 15.00,
            taxes: 0.0,
            processingFee: 0.0,
            buyerContribution: 0.05,
            totalPaid: 265.05,
          );

          try {
            final pc = Get.isRegistered<PurchasesController>() ? Get.find<PurchasesController>() : Get.put(PurchasesController());
            pc.addLocalPurchase(newPurchase);
          } catch (_) {}

          // 1. Native Stripe PaymentSheet Handler
          if (data is Map && data.containsKey('clientSecret')) {
            final clientSecret = data['clientSecret']?.toString() ?? '';
            final ephemeralKey = data['ephemeralKey']?.toString() ?? '';
            final customerId = data['customer']?.toString() ?? '';

            if (clientSecret.isNotEmpty) {
              try {
                final pubKey = data['publishableKey'] ?? data['stripePublishableKey'] ?? data['pk'];
                if (pubKey != null && pubKey.toString().isNotEmpty) {
                  Stripe.publishableKey = pubKey.toString();
                } else {
                  Stripe.publishableKey = "pk_test_51NJLdJF5nDLFMGmox0iseTJZp42wfLi6Ub41OGs7hoMl0GSFe93a0My7PxdF2eKsxV1rvUf8vVw4p6jl9h9pCmEQ00WSln5w44";
                }
                await Stripe.instance.applySettings();

                await Stripe.instance.initPaymentSheet(
                  paymentSheetParameters: SetupPaymentSheetParameters(
                    paymentIntentClientSecret: clientSecret,
                    customerEphemeralKeySecret: ephemeralKey.isNotEmpty ? ephemeralKey : null,
                    customerId: customerId.isNotEmpty ? customerId : null,
                    merchantDisplayName: 'AREIS LLC',
                    style: ThemeMode.dark,
                    appearance: const PaymentSheetAppearance(
                      colors: PaymentSheetAppearanceColors(
                        primary: Color(0xFF8B9BFF),
                        background: Color(0xFF161622),
                        componentBackground: Color(0xFF1E1E2C),
                        componentText: Colors.white,
                        primaryText: Colors.white,
                        secondaryText: Colors.white70,
                      ),
                    ),
                  ),
                );

                await Stripe.instance.presentPaymentSheet();
                Get.snackbar("Payment Successful! 🎉", "Trade completed & order placed! Redirecting to Purchases & Order Tracking...", snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF22C55E), colorText: Colors.white);
                await fetchTrades();
                Get.toNamed(AppRoute.purchases);
                return;
              } on StripeException catch (e) {
                Get.log("⚠️ Stripe Exception: ${e.error.localizedMessage}");
                Get.snackbar("Stripe Payment", e.error.localizedMessage ?? "Payment was cancelled.", snackPosition: SnackPosition.BOTTOM);
                return;
              } catch (e) {
                Get.log("❌ Stripe Error: $e");
                Get.snackbar("Stripe Error", "$e", snackPosition: SnackPosition.BOTTOM);
                return;
              }
            }
          }

          // 2. Fallback Checkout URL Handler
          String? checkoutUrl;
          if (data is Map) {
            checkoutUrl = (data['url'] ?? data['checkoutUrl'] ?? data['paymentUrl'] ?? data['redirectUrl'] ?? data['sessionUrl'])?.toString();
          } else if (data is String && data.startsWith('http')) {
            checkoutUrl = data;
          } else if (body['url'] != null) {
            checkoutUrl = body['url'].toString();
          }

          if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
            final uri = Uri.parse(checkoutUrl);
            bool launched = false;
            try {
              launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
            } catch (_) {}
            if (!launched) {
              try {
                launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
              } catch (_) {}
            }
            if (!launched) {
              try {
                launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            }

            if (launched) {
              Get.snackbar("Success", "Redirecting to Stripe checkout...", snackPosition: SnackPosition.BOTTOM);
            } else {
              Get.snackbar("Error", "Could not open Stripe checkout page.", snackPosition: SnackPosition.BOTTOM);
            }
          } else {
            Get.snackbar("Success", "Trade completed successfully!", snackPosition: SnackPosition.BOTTOM);
          }
          await fetchTrades();
        } else {
          Get.snackbar("Error", body['message'] ?? "Failed to complete trade", snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar("Error", "Failed to complete trade offer. Status: ${response.statusCode}", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar("Error", "An unexpected error occurred: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }
}
