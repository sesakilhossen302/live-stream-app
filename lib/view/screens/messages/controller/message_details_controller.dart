import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/helpers/user_cache.dart';
import '../../../../data/services/socket_service.dart';
import '../../main/controller/main_controller.dart';
import 'messages_controller.dart';

class MessageDetailsController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  final chatId = ''.obs;
  final partnerName = 'User'.obs;
  final partnerAvatar = ''.obs;
  final partnerId = ''.obs;
  final isLoading = true.obs;

  final messages = <Map<String, dynamic>>[].obs;

  // Trade info
  final associatedTrades = <dynamic>[].obs;

  // Order info — only populated when this chat is linked to a real order
  final hasOrder = false.obs;
  final orderData = <String, dynamic>{}.obs;

  final chatInputController = TextEditingController();
  final scrollController = ScrollController();

  // Known message IDs — used to detect new messages from polling
  final Set<String> _knownMessageIds = {};
  // Track sent message IDs to suppress socket echo duplicates
  final Set<String> _sentMessageIds = {};

  Timer? _pollingTimer;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    chatId.value = args['chatId'] ?? '';
    
    partnerId.value = (args['participantId'] ?? args['partnerId'] ?? args['userId'] ?? args['sellerId'] ?? args['receiverId'] ?? '').toString();
    partnerAvatar.value = args['avatar'] ?? '';

    final String initialName = (args['name'] ?? args['fullName'] ?? '').toString();
    if (initialName.isNotEmpty && initialName.toLowerCase() != 'user') {
      partnerName.value = initialName.replaceAll('@', '').trim();
    } else {
      partnerName.value = '';
    }

    // Check instant in-memory UserCache
    if (partnerId.value.isNotEmpty) {
      final cached = UserCache.get(partnerId.value);
      if (cached != null) {
        if (cached['name']?.isNotEmpty == true) partnerName.value = cached['name']!;
        if (cached['avatar']?.isNotEmpty == true && partnerAvatar.value.isEmpty) {
          partnerAvatar.value = cached['avatar']!;
        }
      }
    }

    // Populate order info if passed from a purchase flow
    final order = args['order'];
    if (order != null && order is Map) {
      orderData.value = Map<String, dynamic>.from(order);
      hasOrder.value = true;
    }

    if (partnerId.value.isNotEmpty) {
      fetchPartnerDetails(partnerId.value);
    }

    if (chatId.value.isNotEmpty) {
      markAsSeen();
      fetchAssociatedTrades();
      fetchMessages(); // initial full load
      _setupSocketListener();
      _startPolling(); // fallback polling every 3s
    } else if (partnerId.value.isNotEmpty) {
      _resolveExistingChatRoom(partnerId.value);
    } else {
      _loadMockMessages();
    }
  }

  void markAsSeen() {
    if (chatId.value.isEmpty || chatId.value.startsWith('mock_')) return;

    // 1. Mark in MessagesController
    if (Get.isRegistered<MessagesController>()) {
      Get.find<MessagesController>().markRoomAsRead(chatId.value);
    }

    // 2. Mark in MainController
    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().markChatAsRead(chatId.value);
    }

    // 3. Emit socket events to backend
    try {
      if (Get.isRegistered<SocketService>()) {
        final socket = Get.find<SocketService>();
        final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
        socket.emitEvent('mark-as-read', {'chatId': chatId.value, 'userId': currentUserId});
        socket.emitEvent('read-message', {'chatId': chatId.value, 'userId': currentUserId});
        socket.emitEvent('seen', {'chatId': chatId.value, 'userId': currentUserId});
      }
    } catch (_) {}

    // 4. Send API call to backend to mark read in DB
    try {
      _apiClient.patchData('${ApiUrl.chat}/${chatId.value}/read', {});
      _apiClient.patchData('${ApiUrl.message}/read/${chatId.value}', {});
      _apiClient.postData('${ApiUrl.chat}/read', {'chatId': chatId.value});
    } catch (_) {}
  }

  Future<void> _resolveExistingChatRoom(String targetPartnerId) async {
    try {
      final chatListRes = await _apiClient.getData(ApiUrl.chat);
      if (chatListRes.statusCode == 200) {
        final resBody = jsonDecode(chatListRes.body);
        final List chats = (resBody['data'] is List)
            ? resBody['data']
            : (resBody['chats'] is List ? resBody['chats'] : []);
        for (var c in chats) {
          if (c is Map) {
            final String cId = (c['_id'] ?? c['id'] ?? '').toString();
            final participants = c['participants'] ?? [];
            bool matches = false;
            if (participants is List) {
              for (var p in participants) {
                final pId = (p is Map ? (p['_id'] ?? p['id']) : p).toString();
                if (pId == targetPartnerId) {
                  matches = true;
                  break;
                }
              }
            }
            if (matches && cId.isNotEmpty) {
              chatId.value = cId;
              Get.log("💬 [MessageCtrl] Joined existing chat room: $cId for partner: $targetPartnerId");
              markAsSeen();
              fetchAssociatedTrades();
              fetchMessages();
              _setupSocketListener();
              _startPolling();
              return;
            }
          }
        }
      }

      final createChatRes = await _apiClient.postData(ApiUrl.chat, {
        'receiverId': targetPartnerId,
        'participants': [targetPartnerId],
      });
      if (createChatRes.statusCode == 200 || createChatRes.statusCode == 201) {
        final resBody = jsonDecode(createChatRes.body);
        final chatData = resBody['data'] ?? resBody;
        if (chatData is Map) {
          final String newChatId = (chatData['_id'] ?? chatData['id'] ?? '').toString();
          if (newChatId.isNotEmpty) {
            chatId.value = newChatId;
            Get.log("💬 [MessageCtrl] Resolved new chat room: $newChatId");
            markAsSeen();
            fetchAssociatedTrades();
            fetchMessages();
            _setupSocketListener();
            _startPolling();
            return;
          }
        }
      }
    } catch (e) {
      Get.log("⚠️ [MessageCtrl] Resolve existing chat error: $e");
    }

    _loadMockMessages();
  }

  Future<void> fetchPartnerDetails(String userId) async {
    if (userId.isEmpty) return;
    try {
      final cached = UserCache.get(userId);
      if (cached != null && cached['name']?.isNotEmpty == true) {
        partnerName.value = cached['name']!;
        if (cached['avatar']?.isNotEmpty == true) {
          partnerAvatar.value = cached['avatar']!;
        }
        return;
      }

      final uData = await UserCache.fetchUser(_apiClient, userId);
      if (uData['name']?.isNotEmpty == true) {
        partnerName.value = uData['name']!;
        if (uData['avatar']?.isNotEmpty == true) {
          partnerAvatar.value = uData['avatar']!;
        }
      }
    } catch (_) {}
  }

  // ─── SOCKET ────────────────────────────────────────────────────────────────

  void _setupSocketListener() {
    try {
      final socketService = Get.find<SocketService>();
      socketService.joinChat(chatId.value);
      socketService.on('messageReceived', _onSocketMessage);
      socketService.on('newMessage', _onSocketMessage);
      socketService.on('new message', _onSocketMessage);
      socketService.initSocket();
      Get.log('🔧 [MessageCtrl] Socket ready for room: ${chatId.value}');
    } catch (e) {
      Get.log('❌ [MessageCtrl] Socket setup error: $e');
    }
  }

  void _onSocketMessage(dynamic data) {
    Get.log('📩 [Socket] Raw: $data');
    if (data == null) return;
    try {
      Map<String, dynamic> msgMap;
      if (data is String) {
        msgMap = Map<String, dynamic>.from(jsonDecode(data));
      } else if (data is Map) {
        msgMap = Map<String, dynamic>.from(data);
      } else {
        return;
      }

      final String text = msgMap['text'] ?? msgMap['message'] ?? '';
      if (text.isEmpty) return;

      // Only for this chat room
      final String incomingChat = msgMap['chatId'] ?? '';
      if (incomingChat.isNotEmpty && incomingChat != chatId.value) return;

      final senderId = msgMap['senderId'] ?? msgMap['sender'] ?? '';
      final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      bool isMe = false;
      if (senderId is String) {
        isMe = senderId == currentUserId;
      } else if (senderId is Map) {
        isMe = senderId['_id'] == currentUserId || senderId['id'] == currentUserId;
      }

      final String msgId = msgMap['_id'] ?? msgMap['id'] ?? '';

      // If it's my own sent message, update the optimistic bubble instead of adding new
      if (isMe) {
        final idx = messages.indexWhere(
            (m) => m['isMe'] == true && m['message'] == text && m['time'] == 'Now');
        if (idx != -1) {
          messages[idx] = {
            '_id': msgId,
            'isMe': true,
            'message': text,
            'time': _formatTime(msgMap['createdAt'] ?? ''),
            'isRead': msgMap['isRead'] == true,
          };
          messages.refresh();
          if (msgId.isNotEmpty) _knownMessageIds.add(msgId);
          return;
        }
      }

      // Skip if already known
      if (msgId.isNotEmpty && _knownMessageIds.contains(msgId)) return;
      if (msgId.isNotEmpty) _knownMessageIds.add(msgId);

      // Add at BOTTOM
      messages.add({
        '_id': msgId,
        'isMe': isMe,
        'message': text,
        'time': _formatTime(msgMap['createdAt'] ?? ''),
        'isRead': msgMap['isRead'] == true,
        'raw': msgMap,
      });
      markAsSeen();
      _scrollToBottom();
    } catch (e) {
      Get.log('❌ [Socket] Parse error: $e');
    }
  }

  // ─── POLLING FALLBACK ───────────────────────────────────────────────────────

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (chatId.value.isEmpty || chatId.value.startsWith('mock_')) return;
      await _pollNewMessages();
    });
  }

  Future<void> _pollNewMessages() async {
    try {
      fetchAssociatedTrades();
      final response = await _apiClient.getData('${ApiUrl.message}/${chatId.value}');
      if (response.statusCode != 200) return;

      final List data = jsonDecode(response.body)['data'] ?? [];
      if (data.isEmpty) return;

      // Sort data oldest first (ascending chronological order)
      final List sortedData = List.from(data);
      sortedData.sort((a, b) {
        final String timeA = a['createdAt'] ?? '';
        final String timeB = b['createdAt'] ?? '';
        return timeA.compareTo(timeB);
      });

      final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      bool hasNew = false;

      for (var msg in sortedData) {
        final String msgId = msg['_id'] ?? msg['id'] ?? '';
        if (msgId.isEmpty || _knownMessageIds.contains(msgId)) continue;

        // This is a new message not yet in our list
        _knownMessageIds.add(msgId);
        hasNew = true;

        final sender = msg['senderId'] ?? msg['sender'];
        final isMe = sender == currentUserId ||
            (sender is Map &&
                (sender['_id'] == currentUserId || sender['id'] == currentUserId));

        // If it's my optimistic bubble, update it
        final String text = msg['text'] ?? '';
        if (isMe) {
          final idx = messages.indexWhere(
              (m) => m['isMe'] == true && m['message'] == text && m['time'] == 'Now');
          if (idx != -1) {
            messages[idx] = {
              '_id': msgId,
              'isMe': true,
              'message': text,
              'time': _formatTime(msg['createdAt'] ?? ''),
              'isRead': msg['isRead'] == true,
            };
            messages.refresh();
            continue;
          }
        }

        // Add new message at BOTTOM
        messages.add({
          '_id': msgId,
          'isMe': isMe,
          'message': text,
          'time': _formatTime(msg['createdAt'] ?? ''),
          'isRead': msg['isRead'] == true,
          'raw': msg,
        });
      }

      if (hasNew) {
        markAsSeen();
        _scrollToBottom();
      }
    } catch (e) {
      // Silently ignore polling errors
    }
  }

  void _loadMockMessages() {
    isLoading.value = false;
    messages.clear();
  }

  // ─── FETCH (initial full load) ──────────────────────────────────────────────

  Future<void> fetchMessages() async {
    isLoading.value = true;
    try {
      if (chatId.value.startsWith('mock_')) {
        _loadMockMessages();
        return;
      }

      final response = await _apiClient.getData('${ApiUrl.message}/${chatId.value}');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body)['data'] ?? [];
        final List<Map<String, dynamic>> parsedList = [];
        _knownMessageIds.clear();

        // Sort data oldest first (ascending chronological order)
        final List sortedData = List.from(data);
        sortedData.sort((a, b) {
          final String timeA = a['createdAt'] ?? '';
          final String timeB = b['createdAt'] ?? '';
          return timeA.compareTo(timeB);
        });

        if (sortedData.isNotEmpty) {
          parsedList.add({'isDate': true, 'message': 'TODAY'});
        }

        final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);

        for (var msg in sortedData) {
          final String msgId = msg['_id'] ?? msg['id'] ?? '';
          if (msgId.isNotEmpty) _knownMessageIds.add(msgId);

          final sender = msg['senderId'] ?? msg['sender'];
          final isMe = sender == currentUserId ||
              (sender is Map &&
                  (sender['_id'] == currentUserId || sender['id'] == currentUserId));

          parsedList.add({
            '_id': msgId,
            'isMe': isMe,
            'message': msg['text'] ?? '',
            'time': _formatTime(msg['createdAt'] ?? ''),
            'isRead': msg['isRead'] == true,
            'raw': msg,
          });
        }

        // Oldest first → newest at BOTTOM
        messages.assignAll(parsedList);
        markAsSeen();
      } else {
        messages.clear();
      }
    } catch (e) {
      Get.log('❌ [MessageCtrl] fetchMessages error: $e');
      messages.clear();
    } finally {
      isLoading.value = false;
      _scrollToBottom();
    }
  }

  // ─── SEND ───────────────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final msgText = text.trim();

    // Optimistic bubble — appears immediately on the RIGHT (isMe: true)
    messages.add({
      'isMe': true,
      'message': msgText,
      'time': 'Now',
      'isRead': false,
    });
    chatInputController.clear();
    _scrollToBottom();

    try {
      if (chatId.value.isEmpty || chatId.value.startsWith('mock_')) {
        // Create chat room dynamically via API
        final createChatRes = await _apiClient.postData(ApiUrl.chat, {
          'receiverId': partnerId.value,
          'participants': [partnerId.value],
        });
        if (createChatRes.statusCode == 200 || createChatRes.statusCode == 201) {
          final resBody = jsonDecode(createChatRes.body);
          final chatData = resBody['data'] ?? resBody;
          if (chatData is Map) {
            chatId.value = (chatData['_id'] ?? chatData['id'] ?? '').toString();
            _setupSocketListener();
            _startPolling();
          }
        }
      }

      if (chatId.value.isNotEmpty && !chatId.value.startsWith('mock_')) {
        final response = await _apiClient.postData(ApiUrl.message, {
          'chatId': chatId.value,
          'text': msgText,
        });

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resBody = jsonDecode(response.body);
          final messageData = resBody['data'];
          if (messageData != null) {
            final msgId = messageData['_id'] ?? messageData['id'] ?? '';
            if (msgId.isNotEmpty) {
              _sentMessageIds.add(msgId);
              _knownMessageIds.add(msgId); // prevent polling from re-adding
            }
            // Emit to socket so the OTHER user gets it instantly
            try {
              final socketService = Get.find<SocketService>();
              socketService.emitEvent('new message', messageData);
            } catch (e) {
              Get.log('❌ [MessageCtrl] Socket emit error: $e');
            }
          }
        }
      }
    } catch (e) {
      Get.log('❌ [MessageCtrl] sendMessage error: $e');
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return 'Now';
    try {
      final parsed = DateTime.parse(timeStr).toLocal();
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Now';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── LIFECYCLE ──────────────────────────────────────────────────────────────

  @override
  void onClose() {
    _pollingTimer?.cancel();
    if (chatId.value.isNotEmpty) {
      try {
        final socketService = Get.find<SocketService>();
        socketService.leaveChat(chatId.value);
        socketService.off('messageReceived');
        socketService.off('newMessage');
        socketService.off('new message');
      } catch (e) {
        Get.log('❌ [MessageCtrl] onClose cleanup error: $e');
      }
    }
    chatInputController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  // ─── TRADE OPERATIONS ────────────────────────────────────────────────────────
  Future<void> fetchAssociatedTrades() async {
    final userId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    if (userId.isEmpty) return;

    try {
      final receivedResponse = await _apiClient.getData("${ApiUrl.tradeOffers}?userId=$userId&type=received");
      final sentResponse = await _apiClient.getData("${ApiUrl.tradeOffers}?userId=$userId&type=sent");

      List receivedData = [];
      List sentData = [];

      if (receivedResponse.statusCode == 200) {
        receivedData = jsonDecode(receivedResponse.body)['data'] ?? [];
      }
      if (sentResponse.statusCode == 200) {
        sentData = jsonDecode(sentResponse.body)['data'] ?? [];
      }

      associatedTrades.assignAll([...receivedData, ...sentData]);
    } catch (e) {
      Get.log("Error fetching associated trades: $e");
    }
  }

  Future<void> handleAcceptTrade(String tradeId) async {
    isLoading.value = true;
    try {
      final response = await _apiClient.postData("${ApiUrl.acceptTrade}/$tradeId", {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.snackbar("Success", "Trade offer accepted successfully!", snackPosition: SnackPosition.BOTTOM);
        await fetchAssociatedTrades();
        await fetchMessages();
      } else {
        Get.snackbar("Error", "Failed to accept trade offer", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar("Error", "An unexpected error occurred: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> handleDeclineTrade(String tradeId) async {
    isLoading.value = true;
    try {
      final response = await _apiClient.postData("${ApiUrl.declineTrade}/$tradeId", {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.snackbar("Success", "Trade offer declined.", snackPosition: SnackPosition.BOTTOM);
        await fetchAssociatedTrades();
        await fetchMessages();
      } else {
        Get.snackbar("Error", "Failed to decline trade offer", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar("Error", "An unexpected error occurred: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> completeTradeOffer(String tradeId) async {
    isLoading.value = true;
    try {
      final response = await _apiClient.postData("/trades/complete/$tradeId", {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final success = body['success'] ?? false;
        final data = body['data'];
        
        if (success) {
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
                  await Stripe.instance.applySettings();
                }

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
                Get.snackbar("Success", "Payment completed & trade finalized! ✅", snackPosition: SnackPosition.BOTTOM);
                await fetchAssociatedTrades();
                await fetchMessages();
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
          await fetchAssociatedTrades();
          await fetchMessages();
          await fetchAssociatedTrades();
          await fetchMessages();
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
