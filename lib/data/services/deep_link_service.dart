import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_route.dart';

class DeepLinkService extends GetxService {
  static DeepLinkService get to => Get.find();
  
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  @override
  void onInit() {
    super.onInit();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle incoming link when app is launched from terminated state (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('🔗 [DeepLinkService] Initial URI: $initialUri');
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('⚠️ [DeepLinkService] Error getting initial link: $e');
    }

    // Handle incoming links while app is running (foreground or background)
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('🔗 [DeepLinkService] Stream URI: $uri');
        _handleUri(uri);
      },
      onError: (err) {
        debugPrint('⚠️ [DeepLinkService] URI Stream error: $err');
      },
    );
  }

  void _handleUri(Uri uri) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pathSegments = uri.pathSegments;
      final host = uri.host; // Can be 'trade', 'profile' if custom scheme culturecards://trade/123

      debugPrint('🔗 [DeepLinkService] Handling host: $host, segments: $pathSegments');

      // Case 1: Custom Scheme: culturecards://trade/:id or HTTPS: https://.../trade/:id
      if (host == 'trade' || (pathSegments.isNotEmpty && pathSegments[0] == 'trade')) {
        final String productId = host == 'trade' 
            ? (pathSegments.isNotEmpty ? pathSegments[0] : '')
            : (pathSegments.length > 1 ? pathSegments[1] : '');

        if (productId.isNotEmpty) {
          Get.toNamed(
            AppRoute.tradeDetails,
            arguments: {
              '_id': productId,
              'id': productId,
            },
          );
        }
      } 
      // Case 2: Custom Scheme: culturecards://profile/:id or HTTPS: https://.../profile/:id
      else if (host == 'profile' || (pathSegments.isNotEmpty && pathSegments[0] == 'profile')) {
        final String traderId = host == 'profile'
            ? (pathSegments.isNotEmpty ? pathSegments[0] : '')
            : (pathSegments.length > 1 ? pathSegments[1] : '');

        if (traderId.isNotEmpty) {
          Get.toNamed(
            AppRoute.traderProfile,
            arguments: {
              'traderId': traderId,
              'id': traderId,
            },
          );
        }
      }
    });
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
