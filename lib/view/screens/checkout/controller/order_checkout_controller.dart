import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/socket_service.dart';

class OrderCheckoutController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  final RxMap<String, dynamic> product = <String, dynamic>{}.obs;
  final RxBool isProcessing = false.obs;

  // Address Controllers
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final streetController = TextEditingController(text: "123 Broadway St");
  final cityController = TextEditingController(text: "New York");
  final stateController = TextEditingController(text: "NY");
  final zipCodeController = TextEditingController(text: "10001");
  final countryController = TextEditingController(text: "USA");

  // Pricing
  final RxDouble itemSubtotal = 0.0.obs;
  final RxDouble shippingFee = 15.00.obs;
  final RxDouble authenticationFee = 0.00.obs;
  final RxDouble estimatedTax = 0.0.obs;
  final RxDouble totalAmount = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments is Map) {
      product.assignAll(Map<String, dynamic>.from(Get.arguments));
      _calculatePricing();
    }
    _loadUserSavedAddress();
  }

  void _calculatePricing() {
    final rawPrice = product['buyNowPrice'] ?? product['price'] ?? product['estValue'] ?? '250';
    final double sub = double.tryParse(rawPrice.toString()) ?? 250.0;
    itemSubtotal.value = sub;

    // Optional custom shipping fee from product
    if (product['shippingFee'] != null) {
      shippingFee.value = double.tryParse(product['shippingFee'].toString()) ?? 15.00;
    } else {
      shippingFee.value = 15.00;
    }

    // 5% sales tax calculation (rounded)
    estimatedTax.value = double.parse((sub * 0.05).toStringAsFixed(2));

    totalAmount.value = double.parse((itemSubtotal.value + shippingFee.value + estimatedTax.value).toStringAsFixed(2));
  }

  Future<void> _loadUserSavedAddress() async {
    try {
      final savedName = SharePrefsHelper.getString('fullName');
      if (savedName.isNotEmpty) {
        fullNameController.text = savedName;
      }

      final response = await _apiClient.getData(ApiUrl.profile);
      if (response.statusCode == 200) {
        final profileData = jsonDecode(response.body)['data'];
        if (profileData is Map) {
          if (fullNameController.text.isEmpty && profileData['fullName'] != null) {
            fullNameController.text = profileData['fullName'].toString();
          }
          if (profileData['phone'] != null && profileData['phone'].toString().isNotEmpty) {
            phoneController.text = profileData['phone'].toString();
          }
          if (profileData['address'] is Map) {
            final addr = profileData['address'];
            if (addr['street'] != null) streetController.text = addr['street'].toString();
            if (addr['city'] != null) cityController.text = addr['city'].toString();
            if (addr['state'] != null) stateController.text = addr['state'].toString();
            if (addr['zipCode'] != null) zipCodeController.text = addr['zipCode'].toString();
            if (addr['country'] != null) countryController.text = addr['country'].toString();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> proceedToPayment() async {
    if (isProcessing.value) return;

    if (streetController.text.trim().isEmpty || cityController.text.trim().isEmpty || zipCodeController.text.trim().isEmpty) {
      Get.snackbar(
        "Address Required",
        "Please fill in your delivery street, city, and ZIP code.",
        backgroundColor: const Color(0xFFFF6B35),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isProcessing.value = true;

    try {
      final productId = product['_id'] ?? product['id'] ?? "";
      final productTitle = product['title'] ?? 'Collector Item Purchase';

      final payload = {
        "amount": totalAmount.value,
        "currency": "USD",
        "productName": productTitle,
        "metadata": {
          "purchaseType": "buy_now",
          "productId": productId,
          "shippingStreet": streetController.text.trim(),
          "shippingCity": cityController.text.trim(),
          "shippingZip": zipCodeController.text.trim(),
        }
      };

      final response = await _apiClient.postData(ApiUrl.createCheckoutSession, payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final resBody = jsonDecode(response.body);
        final success = resBody['success'] ?? false;
        final data = resBody['data'];

        // 1. Native Stripe PaymentSheet Handler
        if (success && data is Map && data.containsKey('clientSecret')) {
          await _initAndPresentPaymentSheet(data);
          return;
        }

        // 2. Checkout URL Handler
        String? checkoutUrl;
        if (data is Map) {
          checkoutUrl = (data['url'] ?? data['checkoutUrl'] ?? data['paymentUrl'] ?? data['redirectUrl'] ?? data['sessionUrl'])?.toString();
        } else if (data is String && data.startsWith('http')) {
          checkoutUrl = data;
        } else if (resBody['url'] != null) {
          checkoutUrl = resBody['url'].toString();
        }

        if (success && checkoutUrl != null && checkoutUrl.isNotEmpty) {
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
            await _createOrderRecordAndNotifySeller();
            Get.snackbar("Success", "Redirecting to Stripe checkout...", snackPosition: SnackPosition.BOTTOM);
          } else {
            Get.snackbar("Error", "Could not open Stripe checkout page.", snackPosition: SnackPosition.BOTTOM);
          }
        } else {
          Get.snackbar("Error", resBody['message'] ?? "Failed to initiate payment session", snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        Get.snackbar("Error", "Failed to initiate payment. Status: ${response.statusCode}", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar("Error", "An unexpected error occurred: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isProcessing.value = false;
    }
  }

  Future<bool> _initAndPresentPaymentSheet(Map<dynamic, dynamic> data) async {
    try {
      final clientSecret = data['clientSecret']?.toString() ?? '';
      final ephemeralKey = data['ephemeralKey']?.toString() ?? '';
      final customerId = data['customer']?.toString() ?? '';

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
          merchantDisplayName: 'Culture Cards LLC',
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
      await _createOrderRecordAndNotifySeller();

      Get.snackbar(
        "Payment Successful! 🎉",
        "Your order has been placed and sent to the seller! Redirecting to Purchases...",
        backgroundColor: const Color(0xFF22C55E),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );

      Get.offAllNamed(AppRoute.main);
      Get.toNamed(AppRoute.purchases);
      return true;
    } on StripeException catch (e) {
      Get.log("⚠️ Stripe Exception: ${e.error.localizedMessage}");
      Get.snackbar("Stripe Error", e.error.localizedMessage ?? "Payment was cancelled.", snackPosition: SnackPosition.BOTTOM);
      return false;
    } catch (e) {
      Get.log("❌ Stripe Error: $e");
      Get.snackbar("Error", "$e", snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<void> _createOrderRecordAndNotifySeller() async {
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
        } catch (_) {}
      }

      final productId = product['_id'] ?? product['id'] ?? "";
      final seller = product['sellerId'];
      final sellerId = (seller is Map) ? (seller['_id'] ?? seller['id'] ?? '') : seller.toString();

      final orderPayload = {
        "productId": productId,
        if (sellerId.isNotEmpty) "sellerId": sellerId,
        if (userId.isNotEmpty) "buyerId": userId,
        "totalPaid": totalAmount.value,
        "amountDetails": {
          "itemSubtotal": itemSubtotal.value,
          "shipping": shippingFee.value,
          "taxes": estimatedTax.value,
          "processingFee": 0.0,
          "authenticationFee": 0.0
        },
        "shippingAddress": {
          "fullName": fullNameController.text.trim(),
          "phone": phoneController.text.trim(),
          "street": streetController.text.trim(),
          "city": cityController.text.trim(),
          "state": stateController.text.trim(),
          "zipCode": zipCodeController.text.trim(),
          "country": countryController.text.trim().isNotEmpty ? countryController.text.trim() : "USA"
        },
        "trackingDetails": {
          "carrier": "USPS Priority",
          "trackingNumber": "TRK-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}",
          "status": "Order Placed",
          "estimatedDelivery": "3-5 Business Days",
          "currentLocation": "Vault Facility"
        }
      };

      final orderRes = await _apiClient.postData(ApiUrl.orders, orderPayload);
      if (orderRes.statusCode == 200 || orderRes.statusCode == 201) {
        Get.log("✅ Order created in database successfully.");
      }

      // Socket notification to seller
      if (sellerId.isNotEmpty && Get.isRegistered<SocketService>()) {
        try {
          Get.find<SocketService>().socket?.emit('order_created', {
            'sellerId': sellerId,
            'productId': productId,
            'totalPaid': totalAmount.value,
            'buyerId': userId,
          });
        } catch (_) {}
      }
    } catch (e) {
      Get.log("⚠️ Failed to create backend order record: $e");
    }
  }

  @override
  void onClose() {
    fullNameController.dispose();
    phoneController.dispose();
    streetController.dispose();
    cityController.dispose();
    stateController.dispose();
    zipCodeController.dispose();
    countryController.dispose();
    super.onClose();
  }
}
