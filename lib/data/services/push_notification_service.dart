import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_route.dart';
import '../../firebase_options.dart';
import '../helpers/shared_prefe.dart';
import 'api_client.dart';
import 'api_url.dart';
import '../../view/screens/main/controller/main_controller.dart';
import '../../view/screens/messages/controller/messages_controller.dart';

/// Top-level background message handler required by FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  debugPrint("🔔 [FCM Background] Message ID: ${message.messageId} | Data: ${message.data}");
}

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._internal();
  factory PushNotificationService() => instance;
  PushNotificationService._internal();

  FirebaseMessaging? get _fcm {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseMessaging.instance;
      }
    } catch (_) {}
    return null;
  }

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDescription = 'Push notifications for CultureCards live streams, trades, orders, and chats.';

  bool _isInitialized = false;

  /// Initialize Firebase, FCM, and Local Notifications
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint("✅ [PushNotificationService] Firebase initialized successfully");
      } catch (e) {
        debugPrint("⚠️ [PushNotificationService] Firebase init fallback: $e");
        try {
          await Firebase.initializeApp();
        } catch (e2) {
          debugPrint("⚠️ [PushNotificationService] Native Firebase init note: $e2");
        }
      }

      // 2. Setup Local Notifications (for Foreground Banner)
      await _setupLocalNotifications();

      // If Firebase app is ready, setup FCM listeners
      final fcm = _fcm;
      if (fcm != null) {
        // Register Background Handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Request Permissions
        await requestPermission();

        // Get & Cache Device Token
        await getDeviceToken();

        // Listen for Token Rotation / Refresh
        _listenToTokenRefresh();

        // Setup Foreground, Background, and Terminated message handlers
        _setupMessageHandlers();
      } else {
        debugPrint("ℹ️ [PushNotificationService] Firebase not active, FCM listeners skipped.");
      }

      _isInitialized = true;
      debugPrint("🚀 [PushNotificationService] Initialized");
    } catch (e) {
      debugPrint("❌ [PushNotificationService] Init error: $e");
    }
  }

  /// Request Notification Permission (iOS + Android 13+)
  Future<bool> requestPermission() async {
    try {
      final fcm = _fcm;
      if (fcm == null) return false;

      // iOS / macOS permission
      final NotificationSettings settings = await fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Set foreground presentation options
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Android 13+ runtime permission
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        if (status.isDenied) {
          await Permission.notification.request();
        }
      }

      debugPrint("🔔 [PushNotificationService] Authorization Status: ${settings.authorizationStatus}");
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint("⚠️ [PushNotificationService] requestPermission error: $e");
      return false;
    }
  }

  /// Setup Flutter Local Notifications plugin and Android Notification Channel
  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            debugPrint("🔔 [PushNotificationService] Local Notification Tapped with payload: $data");
            handleNotificationRedirection(data);
          } catch (e) {
            debugPrint("⚠️ [PushNotificationService] Payload parse error: $e");
          }
        }
      },
    );

    // Create high-importance Android Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  /// Get FCM Device Token and cache in SharedPreferences
  Future<String?> getDeviceToken() async {
    try {
      final fcm = _fcm;
      if (fcm == null) return SharePrefsHelper.getString(SharePrefsHelper.fcmTokenKey);

      // On iOS, ensure APNs token is set before requesting FCM token
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await fcm.getAPNSToken().timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
        if (apnsToken == null) {
          debugPrint("ℹ️ [PushNotificationService] APNs token not yet available, will fetch FCM token on refresh.");
          return SharePrefsHelper.getString(SharePrefsHelper.fcmTokenKey);
        }
      }

      String? token = await fcm.getToken().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (token != null && token.isNotEmpty) {
        await SharePrefsHelper.setString(SharePrefsHelper.fcmTokenKey, token);
        debugPrint("🔑 [FCM Token]: $token");
      }
      return token;
    } catch (e) {
      debugPrint("⚠️ [PushNotificationService] getDeviceToken note: $e");
      return SharePrefsHelper.getString(SharePrefsHelper.fcmTokenKey);
    }
  }

  /// Sync active FCM Device Token with the backend (PATCH /users/profile)
  Future<bool> syncDeviceToken({String? token}) async {
    final String targetToken = token ?? await getDeviceToken() ?? "";
    if (targetToken.isEmpty) {
      debugPrint("⚠️ [PushNotificationService] No device token to sync");
      return false;
    }

    final String accessToken = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);
    if (accessToken.isEmpty) {
      debugPrint("ℹ️ [PushNotificationService] User not logged in, skipping device token sync to server");
      return false;
    }

    try {
      if (Get.isRegistered<ApiClient>()) {
        final ApiClient client = Get.find<ApiClient>();
        final response = await client.patchData(
          ApiUrl.updateProfile,
          {"deviceToken": targetToken},
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint("✅ [PushNotificationService] Device token synced successfully to server");
          return true;
        } else {
          debugPrint("⚠️ [PushNotificationService] Sync device token failed: ${response.statusCode} | ${response.body}");
        }
      }
    } catch (e) {
      debugPrint("❌ [PushNotificationService] Sync device token exception: $e");
    }
    return false;
  }

  /// Clear FCM Device Token on backend when user logs out (PATCH /users/profile with deviceToken: "")
  Future<void> clearDeviceToken() async {
    final String accessToken = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);
    if (accessToken.isEmpty) return;

    try {
      if (Get.isRegistered<ApiClient>()) {
        final ApiClient client = Get.find<ApiClient>();
        debugPrint("🚪 [PushNotificationService] Clearing device token on backend...");
        await client.patchData(
          ApiUrl.updateProfile,
          {"deviceToken": ""},
        ).timeout(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint("⚠️ [PushNotificationService] Clear device token error: $e");
    }
  }

  /// Listen for token rotation/refresh from Firebase
  void _listenToTokenRefresh() {
    _fcm?.onTokenRefresh.listen((newToken) {
      debugPrint("🔄 [PushNotificationService] FCM Token refreshed: $newToken");
      SharePrefsHelper.setString(SharePrefsHelper.fcmTokenKey, newToken);
      syncDeviceToken(token: newToken);
    }).onError((err) {
      debugPrint("⚠️ [PushNotificationService] Token refresh stream error: $err");
    });
  }

  /// Setup message listeners for Foreground, Background Tap, and Terminated Launch
  void _setupMessageHandlers() {
    // 1. Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📩 [FCM Foreground] Received: ${message.notification?.title} | ${message.notification?.body}");
      _showForegroundNotification(message);

      // Instantly sync unread message badge count across app
      if (Get.isRegistered<MainController>()) {
        Get.find<MainController>().unreadMessageCount.value++;
        Get.find<MainController>().fetchUnreadMessageCount();
      }
      if (Get.isRegistered<MessagesController>()) {
        Get.find<MessagesController>().fetchChatRooms();
      }
    });

    // 2. Background -> App opened via Notification Tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📲 [FCM OpenedApp] User tapped notification from background: ${message.data}");
      handleNotificationRedirection(message.data);
    });

    // 3. Terminated -> App launched via Notification Tap
    _fcm?.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("🚀 [FCM InitialMessage] App opened from terminated state via notification: ${message.data}");
        // Add a slight delay to allow navigation stack / GetMaterialApp to initialize
        Future.delayed(const Duration(milliseconds: 600), () {
          handleNotificationRedirection(message.data);
        });
      }
    });
  }

  /// Display a local notification banner when notification arrives in the foreground
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final String title = notification?.title ?? data['title'] ?? 'Notification';
    final String body = notification?.body ?? data['body'] ?? '';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF8B9BFF),
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String payloadJson = jsonEncode(data);

    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payloadJson,
    );
  }

  /// 4️⃣ FCM Redirection Map (Deep-Linking Actions)
  /// Dispatches the user to the appropriate screen according to data.type
  static void handleNotificationRedirection(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final String type = (data['type'] ?? '').toString().toUpperCase().trim();
    debugPrint("🧭 [PushNotificationService] Handling redirection for type: '$type' with payload: $data");

    switch (type) {
      // 1. NEW_MESSAGE -> Open Chat room with senderId
      case 'NEW_MESSAGE':
        final String senderId = (data['senderId'] ?? data['participantId'] ?? data['userId'] ?? '').toString();
        final String messagePreview = (data['messagePreview'] ?? '').toString();
        if (senderId.isNotEmpty) {
          Get.toNamed(AppRoute.messageDetails, arguments: {
            'senderId': senderId,
            'partnerId': senderId,
            'participantId': senderId,
            'fullName': data['senderName'] ?? data['name'] ?? 'Chat',
            'preview': messagePreview,
          });
        } else {
          Get.toNamed(AppRoute.main);
        }
        break;

      // 2. TRADE_ACCEPTED -> Open Trade/Escrow detail screen for tradeOfferId
      case 'TRADE_ACCEPTED':
        final String tradeOfferId = (data['tradeOfferId'] ?? data['tradeId'] ?? data['offerId'] ?? '').toString();
        if (tradeOfferId.isNotEmpty) {
          Get.toNamed(AppRoute.tradeDetails, arguments: {
            'id': tradeOfferId,
            '_id': tradeOfferId,
            'tradeOfferId': tradeOfferId,
          });
        } else {
          Get.toNamed(AppRoute.myTrades);
        }
        break;

      // 3. TRADE_DECLINED -> Open Trade details / Trade list
      case 'TRADE_DECLINED':
        final String tradeOfferId = (data['tradeOfferId'] ?? data['tradeId'] ?? data['offerId'] ?? '').toString();
        Get.toNamed(AppRoute.myTrades, arguments: {
          'tradeOfferId': tradeOfferId,
        });
        break;

      // 4. ORDER_UPDATE -> Open Order Tracking/Shipment screen for orderId
      case 'ORDER_UPDATE':
        final String orderId = (data['orderId'] ?? data['id'] ?? data['_id'] ?? '').toString();
        if (orderId.isNotEmpty) {
          Get.toNamed(AppRoute.trackOrder, arguments: {
            'orderId': orderId,
            'id': orderId,
            '_id': orderId,
          });
        } else {
          Get.toNamed(AppRoute.purchases);
        }
        break;

      // 5. AUCTION_WON -> Open in-app Order Checkout / Summary screen
      case 'AUCTION_WON':
        final String prodTitle = (data['productTitle'] ?? data['title'] ?? data['name'] ?? 'Auction Item').toString();
        final String price = (data['amount'] ?? data['winningBid'] ?? data['price'] ?? '150').toString().replaceAll('\$', '').trim();
        final String auctionItemId = (data['auctionItemId'] ?? data['itemId'] ?? data['productId'] ?? '').toString();
        final String sellerId = (data['sellerId'] ?? '').toString();
        final String img = (data['imageUrl'] ?? data['image'] ?? '').toString();

        Get.toNamed(AppRoute.checkout, arguments: {
          "title": prodTitle,
          "buyNowPrice": price,
          "estValue": price,
          "images": img.isNotEmpty ? [img] : [],
          "sellerId": sellerId,
          "condition": "AUTHENTICATED",
          "productId": auctionItemId,
        });
        break;

      // 6. STREAM_LIVE -> Join Agora live stream room for streamId
      case 'STREAM_LIVE':
        final String streamId = (data['streamId'] ?? data['channelName'] ?? '').toString();
        final String sellerId = (data['sellerId'] ?? '').toString();
        final String actionUrl = (data['actionUrl'] ?? '').toString();

        Get.toNamed(AppRoute.viewerLive, arguments: {
          'streamId': streamId,
          'channelName': streamId,
          '_id': streamId,
          'id': streamId,
          'sellerId': sellerId,
          'actionUrl': actionUrl,
        });
        break;

      // 7. NEW_REVIEW -> Open User Profile Reviews tab
      case 'NEW_REVIEW':
        final String reviewerId = (data['reviewerId'] ?? '').toString();
        final String reviewId = (data['reviewId'] ?? '').toString();
        if (reviewerId.isNotEmpty) {
          Get.toNamed(AppRoute.traderProfile, arguments: {
            'userId': reviewerId,
            'reviewerId': reviewerId,
            'reviewId': reviewId,
            'initialTab': 'Reviews',
          });
        } else {
          Get.toNamed(AppRoute.main);
        }
        break;

      // 8. NEW_REPORT -> (Admin Only) Open admin reporting ticket details
      case 'NEW_REPORT':
        final String reportId = (data['reportId'] ?? '').toString();
        Get.toNamed(AppRoute.notifications, arguments: {
          'reportId': reportId,
        });
        break;

      default:
        // Optional deep linking via actionUrl if provided
        final String? actionUrl = data['actionUrl']?.toString();
        if (actionUrl != null && actionUrl.isNotEmpty) {
          final uri = Uri.tryParse(actionUrl);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
        }
        // Fallback to notifications screen
        Get.toNamed(AppRoute.notifications);
        break;
    }
  }
}
