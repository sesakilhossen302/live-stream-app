import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:url_launcher/url_launcher.dart';
import '../helpers/shared_prefe.dart';
import 'api_url.dart';
import '../../view/screens/main/controller/main_controller.dart';
import '../../view/screens/messages/controller/messages_controller.dart';

class _SocketListener {
  final String event;
  final Function(dynamic) handler;
  _SocketListener(this.event, this.handler);
}

class SocketService extends GetxService {
  static SocketService get to => Get.find();

  IO.Socket? socket;
  final RxBool isConnected = false.obs;
  String? _activeChatId;

  // Pending listeners registered before socket was ready
  final List<_SocketListener> _pendingListeners = [];

  void initSocket() {
    final token = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);
    final userId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);

    if (token.isEmpty || userId.isEmpty) {
      Get.log('⚡ [SocketService] Skipped: token or userId empty.');
      return;
    }

    if (socket != null) {
      if (socket!.connected) {
        Get.log('⚡ [SocketService] Already connected.');
        _attachPendingListeners();
        return;
      } else {
        Get.log('⚡ [SocketService] Reconnecting existing socket...');
        socket!.connect();
        return;
      }
    }

    try {
      final socketUrl = ApiUrl.imageBaseUrl;
      Get.log('⚡ [SocketService] Connecting to: $socketUrl');

      socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection() // Enable reconnection to make sockets robust!
            .setReconnectionAttempts(10)
            .setReconnectionDelay(2000)
            .setQuery({'token': token, 'userId': userId})
            .build(),
      );

      // Register global real-time notifications
      void handleGlobalMessageReceived(dynamic data) {
        Get.log('💬 [SocketService] Global message received: $data');
        if (Get.isRegistered<MainController>()) {
          Get.find<MainController>().unreadMessageCount.value++;
          Get.find<MainController>().fetchUnreadMessageCount();
        }
        if (Get.isRegistered<MessagesController>()) {
          Get.find<MessagesController>().fetchChatRooms();
        }
      }

      socket?.on('message received', handleGlobalMessageReceived);
      socket?.on('messageReceived', handleGlobalMessageReceived);
      socket?.on('new message', handleGlobalMessageReceived);
      socket?.on('newMessage', handleGlobalMessageReceived);
      socket?.on('message', handleGlobalMessageReceived);
      socket?.on('chat-message', handleGlobalMessageReceived);
      socket?.on('receive-message', handleGlobalMessageReceived);
      socket?.on('receiveMessage', handleGlobalMessageReceived);
      socket?.on('notification', (_) {
        if (Get.isRegistered<MainController>()) {
          Get.find<MainController>().fetchUnreadMessageCount();
        }
        if (Get.isRegistered<MessagesController>()) {
          Get.find<MessagesController>().fetchChatRooms();
        }
      });

      socket?.on('auction-won', (data) {
        Get.log('🏆 [SocketService] auction-won event: $data');
        if (data is Map) {
          final bid = data['winningBid'] ?? '0';
          final checkoutUrl = data['checkoutUrl']?.toString() ?? '';
          final message = data['message'] ?? 'You won the auction!';
          
          Get.snackbar(
            "Auction Won! 🏆",
            "$message\nWinning Bid: \$$bid",
            duration: const Duration(seconds: 10),
            backgroundColor: const Color(0xFF22C55E),
            colorText: Colors.white,
            mainButton: checkoutUrl.isNotEmpty
                ? TextButton(
                    onPressed: () async {
                      final uri = Uri.parse(checkoutUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text("PAY NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                : null,
          );
        }
      });

      socket?.on('auction-payment-received', (data) {
        Get.log('💰 [SocketService] auction-payment-received: $data');
        if (data is Map) {
          final message = data['message'] ?? 'Winner has completed payment!';
          Get.snackbar(
            "Payment Received 💰",
            message,
            backgroundColor: const Color(0xFF8B9BFF),
            colorText: Colors.white,
          );
        }
      });

      socket?.on('trade-accepted', (data) {
        Get.log('🤝 [SocketService] trade-accepted: $data');
        if (data is Map) {
          final message = data['message'] ?? 'Your trade offer was accepted!';
          Get.snackbar(
            "Trade Accepted 🤝",
            message,
            backgroundColor: const Color(0xFF22C55E),
            colorText: Colors.white,
          );
        }
      });

      socket?.on('trade-declined', (data) {
        Get.log('❌ [SocketService] trade-declined: $data');
        if (data is Map) {
          final message = data['message'] ?? 'Your trade offer was declined.';
          Get.snackbar(
            "Trade Declined ❌",
            message,
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
        }
      });

      socket?.on('trade-completed', (data) {
        Get.log('✅ [SocketService] trade-completed: $data');
        if (data is Map) {
          final message = data['message'] ?? 'Trade completed successfully!';
          Get.snackbar(
            "Trade Completed ✅",
            message,
            backgroundColor: const Color(0xFFBD8BFF),
            colorText: Colors.white,
          );
        }
      });

      socket?.on('trade-expired', (data) {
        Get.log('⏳ [SocketService] trade-expired: $data');
        if (data is Map) {
          final message = data['message'] ?? 'Trade offer has expired.';
          Get.snackbar(
            "Trade Expired ⏳",
            message,
            backgroundColor: Colors.grey,
            colorText: Colors.white,
          );
        }
      });

      socket?.onConnect((_) {
        isConnected.value = true;
        Get.log('✅ [SocketService] Connected: ${socket?.id}');
        socket?.emit('setup', userId);
        socket?.emit('join', userId);
        socket?.emit('join-user', userId);
        socket?.emit('join user', userId);
        socket?.emit('user-online', userId);
        socket?.emit('user-connected', userId);

        // Rejoin active chat room
        if (_activeChatId != null) {
          Get.log('🎯 [SocketService] Auto-joining: $_activeChatId');
          socket?.emit('join chat', _activeChatId);
        }

        // Attach all pending listeners now that socket is ready
        _attachPendingListeners();
      });

      socket?.onDisconnect((_) {
        isConnected.value = false;
        Get.log('🔌 [SocketService] Disconnected');
      });

      socket?.onConnectError((data) => Get.log('❌ [SocketService] Connect Error: $data'));
      socket?.onError((data) => Get.log('❌ [SocketService] Error: $data'));

      socket?.on('reconnect', (_) {
        Get.log('♻️ [SocketService] Reconnected!');
        if (_activeChatId != null) {
          socket?.emit('join chat', _activeChatId);
        }
      });
    } catch (e) {
      Get.log('❌ [SocketService] Init Exception: $e');
    }
  }

  /// Register a named listener. Supports multiple listeners for the same event name.
  void on(String event, Function(dynamic) handler) {
    _pendingListeners.add(_SocketListener(event, handler));
    if (socket != null && isConnected.value) {
      socket?.on(event, handler);
      Get.log('🎧 [SocketService] Listener attached for: $event');
    } else {
      Get.log('⏳ [SocketService] Listener queued for: $event (will attach on connect)');
    }
  }

  /// Remove a named listener
  void off(String event, [Function(dynamic)? handler]) {
    if (handler != null) {
      _pendingListeners.removeWhere((l) => l.event == event && l.handler == handler);
      socket?.off(event, handler);
    } else {
      _pendingListeners.removeWhere((l) => l.event == event);
      socket?.off(event);
    }
    Get.log('🚫 [SocketService] Listener(s) removed for: $event');
  }

  void _attachPendingListeners() {
    for (final listener in _pendingListeners) {
      socket?.off(listener.event, listener.handler); // avoid duplicates
      socket?.on(listener.event, listener.handler);
      Get.log('🎧 [SocketService] Attached queued listener: ${listener.event}');
    }
  }

  void joinChat(String chatId) {
    _activeChatId = chatId;
    if (socket == null || !isConnected.value) {
      Get.log('⚠️ [SocketService] Will join $chatId once connected.');
      return;
    }
    Get.log('🎯 [SocketService] Joining: $chatId');
    socket?.emit('join chat', chatId);
  }

  void leaveChat(String chatId) {
    if (_activeChatId == chatId) _activeChatId = null;
    if (socket == null || !isConnected.value) return;
    Get.log('🚪 [SocketService] Leaving: $chatId');
    socket?.emit('leave chat', chatId);
  }

  void emitEvent(String event, dynamic data) {
    if (socket != null && isConnected.value) {
      socket?.emit(event, data);
      Get.log('📤 [SocketService] Emitted [$event]');
    } else {
      Get.log('⚠️ [SocketService] Cannot emit [$event]: not connected');
    }
  }

  void emit(String event, [dynamic data]) {
    emitEvent(event, data);
  }

  void disconnectSocket() {
    socket?.disconnect();
    socket = null;
    isConnected.value = false;
    _activeChatId = null;
    Get.log('🔌 [SocketService] Disconnected manually.');
  }

  @override
  void onClose() {
    disconnectSocket();
    super.onClose();
  }
}
