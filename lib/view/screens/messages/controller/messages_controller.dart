import 'dart:convert';
import 'package:get/get.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/helpers/user_cache.dart';
import '../../main/controller/main_controller.dart';

class MessagesController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  
  var selectedFilter = 0.obs;
  var isLoading = true.obs;
  final filters = ["All", "Unread", "Orders", "Trades"];

  final chatRooms = <Map<String, dynamic>>[].obs;
  final updateLogs = <Map<String, dynamic>>[].obs;
  final Set<String> locallyReadChatIds = <String>{};

  void markRoomAsRead(String roomId) {
    if (roomId.isEmpty) return;
    locallyReadChatIds.add(roomId);

    final index = chatRooms.indexWhere((r) => r['id'] == roomId);
    if (index != -1) {
      final updated = Map<String, dynamic>.from(chatRooms[index]);
      updated['isSpecial'] = false;
      updated['isUnread'] = false;
      updated['unreadCount'] = 0;
      chatRooms[index] = updated;
      chatRooms.refresh();
    }

    _updateGlobalBadge();
  }

  void _updateGlobalBadge() {
    int totalUnread = 0;
    for (var r in chatRooms) {
      final String id = r['id']?.toString() ?? '';
      if (locallyReadChatIds.contains(id)) continue;
      if (r['isSpecial'] == true || r['isUnread'] == true) {
        totalUnread++;
      }
    }
    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().unreadMessageCount.value = totalUnread;
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchChatRooms();
    fetchNotifications();
  }

  Future<void> fetchChatRooms() async {
    if (SharePrefsHelper.isGuest || SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey).isEmpty) {
      isLoading.value = false;
      chatRooms.clear();
      return;
    }
    isLoading.value = true;
    try {
      final response = await _apiClient.getData(ApiUrl.chat);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rawData = decoded['data'];
        
        List chatsList = [];
        if (rawData is List) {
          chatsList = rawData;
        } else if (rawData is Map && rawData['chats'] is List) {
          chatsList = rawData['chats'];
        }

        if (chatsList.isNotEmpty) {
          final List<Map<String, dynamic>> parsedRooms = [];
          final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);

          for (var room in chatsList) {
            final participants = room['participants'] as List? ?? [];
            
            dynamic otherParticipant;
            for (var p in participants) {
              final pid = (p is Map ? (p['_id'] ?? p['id']) : p).toString();
              if (pid.isNotEmpty && pid != currentUserId) {
                otherParticipant = p;
                break;
              }
            }
            otherParticipant ??= (participants.isNotEmpty ? participants.first : null);
            if (otherParticipant == null) continue;

            String otherId = "";
            Map<String, dynamic>? pMap;
            if (otherParticipant is Map) {
              pMap = Map<String, dynamic>.from(otherParticipant);
              otherId = (pMap['_id'] ?? pMap['id'] ?? '').toString();
            } else {
              otherId = otherParticipant.toString();
            }

            final dynamic rawName = pMap?['fullName'] ?? pMap?['name'] ?? pMap?['username'] ?? (pMap?['user'] is Map ? pMap!['user']['fullName'] : null);
            String name = (rawName != null && rawName.toString().trim().isNotEmpty && rawName.toString().trim().toLowerCase() != 'user') 
                ? rawName.toString() 
                : "";

            final dynamic rawAvatar = pMap?['profile'] ?? 
                pMap?['profileImage'] ?? 
                pMap?['avatar'] ?? 
                pMap?['image'] ??
                (pMap?['user'] is Map ? pMap!['user']['profile'] : null);
            String avatar = rawAvatar != null ? rawAvatar.toString() : "";

            // Check cache or populate cache
            if (name.isNotEmpty) {
              UserCache.set(otherId, name, avatar);
            } else if (UserCache.get(otherId) != null) {
              final cached = UserCache.get(otherId)!;
              name = cached['name'] ?? '';
              if (avatar.isEmpty) avatar = cached['avatar'] ?? '';
            }
            
            String imageUrl = "";
            if (avatar.isNotEmpty) {
              imageUrl = (avatar.startsWith('http') || avatar.startsWith('data:image/'))
                  ? avatar
                  : "${ApiUrl.imageBaseUrl}${avatar.startsWith('/') ? avatar : '/$avatar'}";
            }

            final lastMsg = room['lastMessage'] != null 
                ? (room['lastMessage']['text'] ?? "Sent a message") 
                : "No messages yet";
            final time = room['updatedAt'] ?? "";

            final isOrder = room['orderId'] != null || room['order'] != null;
            final isTrade = room['tradeId'] != null || room['trade'] != null || room['swap'] != null;
            final String roomId = (room['_id'] ?? room['id'] ?? '').toString();
            final bool isLocallyRead = locallyReadChatIds.contains(roomId);
            final bool isUnread = !isLocallyRead &&
                ((room['unreadCount'] != null && (room['unreadCount'] as num) > 0) ||
                    room['isUnread'] == true);

            parsedRooms.add({
              "id": roomId,
              "name": name.replaceAll('@', '').trim(),
              "message": lastMsg,
              "time": _formatTime(time),
              "avatar": imageUrl,
              "isSpecial": isUnread,
              "isUnread": isUnread,
              "unreadCount": isLocallyRead ? 0 : (room['unreadCount'] ?? 0),
              "isOrder": isOrder,
              "isTrade": isTrade,
              "participantId": otherId,
            });
          }

          chatRooms.assignAll(parsedRooms);

          int totalUnread = 0;
          for (var r in parsedRooms) {
            final String id = r['id']?.toString() ?? '';
            if (locallyReadChatIds.contains(id)) continue;
            if (r['isSpecial'] == true || r['isUnread'] == true) {
              totalUnread++;
            }
          }
          if (Get.isRegistered<MainController>()) {
            Get.find<MainController>().unreadMessageCount.value = totalUnread;
          }

          // Asynchronously fetch missing profiles in parallel
          final List<Future> fetchTasks = [];
          for (int i = 0; i < parsedRooms.length; i++) {
            final room = parsedRooms[i];
            final pId = room['participantId']?.toString() ?? "";
            final curName = room['name']?.toString() ?? "";
            if (pId.isNotEmpty && (curName.isEmpty || curName.toLowerCase() == 'user')) {
              fetchTasks.add(() async {
                final uData = await UserCache.fetchUser(_apiClient, pId);
                if (uData['name']?.isNotEmpty == true) {
                  _applyParticipantNameAndAvatar(i, uData['name']!, uData['avatar'] ?? '');
                }
              }());
            }
          }
          if (fetchTasks.isNotEmpty) {
            Future.wait(fetchTasks);
          }
        } else {
          // Genuinely empty chat rooms from server database
          chatRooms.clear();
        }
      } else {
        _loadMockChatRooms();
      }
    } catch (e) {
      Get.log("Error fetching chat rooms: $e");
      _loadMockChatRooms();
    } finally {
      isLoading.value = false;
    }
  }

  void _applyParticipantNameAndAvatar(int index, String name, String avatar) {
    if (index < chatRooms.length) {
      final current = Map<String, dynamic>.from(chatRooms[index]);
      if (name.isNotEmpty && name.toLowerCase() != 'user') {
        current['name'] = name.replaceAll('@', '').trim();
      }
      if (avatar.isNotEmpty) {
        current['avatar'] = (avatar.startsWith('http') || avatar.startsWith('data:image/'))
            ? avatar
            : "${ApiUrl.imageBaseUrl}${avatar.startsWith('/') ? avatar : '/$avatar'}";
      }
      chatRooms[index] = current;
      chatRooms.refresh();
    }
  }

  void _loadMockChatRooms() {
    chatRooms.assignAll([
      {
        "id": "mock_room_1",
        "name": "Retro_Rick",
        "message": "can do \$450 if we close tonight. Let me know.",
        "time": "Oct 24",
        "avatar": "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?q=80&w=1974&auto=format&fit=crop",
        "isTrade": true,
      },
      {
        "id": "mock_room_2",
        "name": "AuctionQueen",
        "message": "Congratulations! You won the Crimson Blade auction.",
        "time": "Oct 20",
        "avatar": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=1974&auto=format&fit=crop",
        "isSpecial": true,
        "isOrder": true,
      },
      {
        "id": "mock_room_3",
        "name": "Silent_Bidder",
        "message": "Thanks for the smooth transaction. Left 5 stars.",
        "time": "Oct 15",
        "avatar": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?q=80&w=1974&auto=format&fit=crop",
        "isOrder": true,
      },
    ]);

    updateLogs.assignAll([
      {
        "name": "CardMaster",
        "message": "Your order has been shipped",
        "time": "14:22",
        "hasNew": true,
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=1974&auto=format&fit=crop",
        "tags": ["#ORD-24891", "Shipped 🚚"],
      },
      {
        "name": "LuxeVault",
        "message": "Trade request accepted",
        "time": "Yesterday",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=1974&auto=format&fit=crop",
        "tags": ["TRADE", "Completed 🤝"],
      },
    ]);
  }

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return "Now";
    try {
      final parsed = DateTime.parse(timeStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(parsed);
      if (diff.inDays == 0) {
        return "${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}";
      } else if (diff.inDays == 1) {
        return "Yesterday";
      } else {
        return "${parsed.day} ${_getMonthName(parsed.month)}";
      }
    } catch (_) {
      return "Now";
    }
  }

  String _getMonthName(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[month - 1];
  }

  Future<void> fetchNotifications() async {
    if (SharePrefsHelper.isGuest || SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey).isEmpty) {
      updateLogs.clear();
      return;
    }
    try {
      final response = await _apiClient.getData(ApiUrl.myNotifications);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body)['data'] ?? [];
        if (data.isNotEmpty) {
          final List<Map<String, dynamic>> parsedUpdates = [];
          for (var item in data) {
            final title = (item['title'] ?? "Notification").toString();
            final String rawType = (item['type'] ?? 'Alert').toString();
            final itemData = item['data'] is Map ? item['data'] : <String, dynamic>{};

            // Extract product title/name if available
            String prodTitle = (item['productTitle'] ??
                item['productName'] ??
                item['itemName'] ??
                itemData['productTitle'] ??
                itemData['title'] ??
                itemData['name'] ??
                '')?.toString() ?? '';

            if (prodTitle.isEmpty && item['product'] != null) {
              if (item['product'] is Map) {
                prodTitle = (item['product']['title'] ?? item['product']['name'] ?? '').toString();
              } else if (item['product'] is String) {
                prodTitle = item['product'].toString();
              }
            }

            // Extract winning bid / price if available
            final rawAmount = item['winningBid'] ??
                item['amount'] ??
                item['bidAmount'] ??
                item['price'] ??
                itemData['winningBid'] ??
                itemData['amount'] ??
                itemData['bidAmount'];
            final String amountStr = rawAmount != null ? "\$$rawAmount" : "";

            // Determine message text
            String msg = (item['text'] ??
                item['message'] ??
                item['body'] ??
                item['description'] ??
                itemData['message'] ??
                itemData['text'] ??
                '')?.toString() ?? '';

            if (rawType.toUpperCase().contains('AUCTION_WON') || title.toUpperCase().contains('AUCTION WON')) {
              if (prodTitle.isNotEmpty && amountStr.isNotEmpty) {
                msg = "Won '$prodTitle' for $amountStr! Tap to view details and complete order.";
              } else if (prodTitle.isNotEmpty) {
                msg = "Won '$prodTitle'! Tap to view details and complete order.";
              } else if (amountStr.isNotEmpty) {
                msg = "Winning Bid: $amountStr! Tap to view details and complete order.";
              } else if (msg.isEmpty) {
                msg = "Congratulations! You won the live auction. Tap to view item & shipping.";
              }
            } else if (msg.isEmpty && prodTitle.isNotEmpty) {
              msg = "Item: $prodTitle ${amountStr.isNotEmpty ? '($amountStr)' : ''}";
            }

            // Extract avatar / image
            String itemAvatar = (item['avatarUrl'] ??
                item['avatar'] ??
                item['imageUrl'] ??
                item['image'] ??
                itemData['image'] ??
                itemData['avatar'] ??
                '')?.toString() ?? '';

            if (itemAvatar.isEmpty && item['product'] is Map) {
              final pImgs = item['product']['images'] ?? item['product']['image'];
              if (pImgs is List && pImgs.isNotEmpty) {
                itemAvatar = pImgs[0].toString();
              } else if (pImgs is String) {
                itemAvatar = pImgs;
              }
            }
            if (itemAvatar.isEmpty) {
              itemAvatar = "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200";
            }

            final time = item['createdAt'] ?? "";
            final isRead = item['isRead'] == true;

            parsedUpdates.add({
              "name": title.startsWith('@') ? title.substring(1) : title,
              "message": msg,
              "time": _formatTime(time),
              "hasNew": !isRead,
              "avatar": itemAvatar,
              "tags": [rawType],
              "type": rawType,
              "actionUrl": (item['actionUrl'] ?? itemData['actionUrl'] ?? item['checkoutUrl'] ?? itemData['checkoutUrl'] ?? '')?.toString(),
              "orderId": (item['orderId'] ?? itemData['orderId'] ?? '')?.toString(),
              "productTitle": prodTitle,
              "amount": amountStr,
              "rawItem": item,
            });
          }
          updateLogs.assignAll(parsedUpdates);
        } else {
          updateLogs.clear();
        }
      }
    } catch (e) {
      Get.log("Error loading notifications in MessagesController: $e");
    }
  }

  Future<String?> createChatRoom(String targetUserId) async {
    try {
      final response = await _apiClient.postData("${ApiUrl.chat}/$targetUserId", {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return body['data']?['_id'] ?? body['data']?['id'];
      }
    } catch (e) {
      Get.log("Error creating chat room: $e");
    }
    return null;
  }

  void changeFilter(int index) {
    selectedFilter.value = index;
  }

  // --- FILTERED GETTERS ---
  List<Map<String, dynamic>> get filteredUpdates {
    final idx = selectedFilter.value;
    if (idx == 0) return updateLogs;
    if (idx == 1) return updateLogs.where((u) => u['hasNew'] == true).toList();
    if (idx == 2) {
      // Orders
      return updateLogs.where((u) {
        final List tags = u['tags'] ?? [];
        final msg = (u['message'] ?? '').toString().toLowerCase();
        final name = (u['name'] ?? '').toString().toLowerCase();
        return tags.any((t) => t.toString().toLowerCase().contains('ord') || t.toString().toLowerCase().contains('ship')) ||
               msg.contains('order') || msg.contains('ship') || msg.contains('purchase') || msg.contains('buy') || msg.contains('sold') ||
               name.contains('order');
      }).toList();
    }
    if (idx == 3) {
      // Trades
      return updateLogs.where((u) {
        final List tags = u['tags'] ?? [];
        final msg = (u['message'] ?? '').toString().toLowerCase();
        return tags.any((t) => t.toString().toLowerCase().contains('trade') || t.toString().toLowerCase().contains('offer')) ||
               msg.contains('trade') || msg.contains('offer') || msg.contains('swap') || msg.contains('exchange');
      }).toList();
    }
    return updateLogs;
  }

  List<Map<String, dynamic>> get filteredChats {
    final idx = selectedFilter.value;
    if (idx == 0) return chatRooms;
    if (idx == 1) return chatRooms.where((c) => c['isSpecial'] == true).toList();
    if (idx == 2) {
      // Orders
      return chatRooms.where((c) {
        final msg = (c['message'] ?? '').toString().toLowerCase();
        final name = (c['name'] ?? '').toString().toLowerCase();
        return msg.contains('order') || msg.contains('ship') || msg.contains('purchase') || msg.contains('buy') || msg.contains('sold') || msg.contains('won') ||
               name.contains('order') || name.contains('store') || name.contains('shop') || c['isOrder'] == true;
      }).toList();
    }
    if (idx == 3) {
      // Trades
      return chatRooms.where((c) {
        final msg = (c['message'] ?? '').toString().toLowerCase();
        final name = (c['name'] ?? '').toString().toLowerCase();
        return msg.contains('trade') || msg.contains('offer') || msg.contains('swap') || msg.contains('exchange') || msg.contains('bid') || msg.contains('gavel') ||
               name.contains('trade') || name.contains('bid') || c['isTrade'] == true;
      }).toList();
    }
    return chatRooms;
  }
}
