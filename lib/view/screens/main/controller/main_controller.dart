import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/socket_service.dart';
import '../../discover/screen/discover_screen.dart';
import '../../bidshwap/screen/bidshwap_screen.dart';
import '../../home/screen/home_screen.dart';
import '../../messages/screen/messages_screen.dart';
import '../../messages/controller/messages_controller.dart';
import '../../profile/screen/profile_screen.dart';

class MainController extends GetxController {
  var currentIndex = 0.obs; // Default to Home
  final RxInt unreadMessageCount = 0.obs;
  Timer? _badgeSyncTimer;

  final List<Widget> screens = [
    const HomeScreen(),
    const MessagesScreen(),
    const DiscoverScreen(),
    const BidShwapScreen(),
    const ProfileScreen(),
  ];

  @override
  void onInit() {
    super.onInit();
    // Ensure socket is active and listening
    if (Get.isRegistered<SocketService>()) {
      Get.find<SocketService>().initSocket();
    }
    fetchUnreadMessageCount();
    _listenToIncomingMessages();
    _startBadgeSyncTimer();
  }

  void _startBadgeSyncTimer() {
    _badgeSyncTimer?.cancel();
    // Sync unread badge every 6 seconds as a robust background fallback
    _badgeSyncTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      fetchUnreadMessageCount();
    });
  }

  final Set<String> _locallyReadChatIds = <String>{};

  void markChatAsRead(String chatId) {
    if (chatId.isEmpty) return;
    _locallyReadChatIds.add(chatId);
    fetchUnreadMessageCount();
  }

  Future<void> fetchUnreadMessageCount() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final client = Get.find<ApiClient>();
      final response = await client.getData(ApiUrl.chat);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rawData = decoded['data'];
        List chatsList = [];
        if (rawData is List) {
          chatsList = rawData;
        } else if (rawData is Map && rawData['chats'] is List) {
          chatsList = rawData['chats'];
        }

        final Set<String> allRead = {..._locallyReadChatIds};
        if (Get.isRegistered<MessagesController>()) {
          allRead.addAll(Get.find<MessagesController>().locallyReadChatIds);
        }

        int count = 0;
        for (var room in chatsList) {
          if (room is Map) {
            final String id = (room['_id'] ?? room['id'] ?? '').toString();
            if (allRead.contains(id)) continue;

            final unread = room['unreadCount'];
            if (unread is num && unread > 0) {
              count += unread.toInt();
            } else if (room['isUnread'] == true || room['isSpecial'] == true) {
              count += 1;
            }
          }
        }
        unreadMessageCount.value = count;
      }
    } catch (e) {
      Get.log("Note: fetchUnreadMessageCount exception: $e");
    }
  }

  void _listenToIncomingMessages() {
    try {
      if (Get.isRegistered<SocketService>()) {
        final socket = Get.find<SocketService>();
        void handleIncoming(_) {
          unreadMessageCount.value++;
          fetchUnreadMessageCount();
        }

        socket.on('message received', handleIncoming);
        socket.on('messageReceived', handleIncoming);
        socket.on('new message', handleIncoming);
        socket.on('newMessage', handleIncoming);
        socket.on('message', handleIncoming);
        socket.on('receive-message', handleIncoming);
        socket.on('receiveMessage', handleIncoming);
        socket.on('notification', (_) => fetchUnreadMessageCount());
      }
    } catch (_) {}
  }

  void changeIndex(int index) {
    currentIndex.value = index;
    if (index == 1) {
      // Navigating to Messages tab
      fetchUnreadMessageCount();
    }
  }

  @override
  void onClose() {
    _badgeSyncTimer?.cancel();
    super.onClose();
  }
}
