import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/socket_service.dart';
import '../../../../global/helper/auth_guard.dart';
import '../../trade_voting/model/trade_vote_model.dart';

class HomeController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  var selectedCategoryIndex = 0.obs;
  final RxString fullName = "User".obs;
  final RxBool isLoading = false.obs;

  final RxList<LiveItemModel> liveItems = <LiveItemModel>[].obs;

  // Dynamic Products List
  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;
  final RxBool isProductsLoading = false.obs;

  // Products Pagination State
  final RxInt currentProductPage = 1.obs;
  final RxBool hasMoreProducts = true.obs;
  final RxBool isMoreProductsLoading = false.obs;
  final int productLimit = 10;

  // Dynamic Category Items & Titles List
  final RxList<HomeCategoryItem> categoriesList = <HomeCategoryItem>[
    HomeCategoryItem(id: "", name: "All"),
  ].obs;

  final RxList<String> categories = <String>[
    "All",
    "Collectibles",
    "Streetwear",
    "Sneakers",
    "Watches",
    "Art",
  ].obs;

  // In-Memory Category Cache: cacheKey -> List of products
  final Map<String, List<Map<String, dynamic>>> _categoryProductsCache = {};

  String _getCacheKey(int index) {
    if (index >= 0 && index < categoriesList.length) {
      final cat = categoriesList[index];
      if (cat.id.isNotEmpty) return cat.id;
      if (cat.name.isNotEmpty) return cat.name;
    }
    return "All";
  }

  final RxInt unreadNotificationCount = 0.obs;

  // Search state for Discover-in-Home feature
  final TextEditingController searchController = TextEditingController();
  final RxString searchQuery = "".obs;
  bool get isSearching => searchQuery.value.trim().isNotEmpty;

  // Recent Trades (Who Won The Trade?) Voting Feature
  final RxInt currentTradeIndex = 0.obs;
  final RxBool isRecentTradesLoading = false.obs;
  final RxList<TradeVoteModel> recentTrades = <TradeVoteModel>[
    TradeVoteModel(
      id: "65f123abc456789012345678",
      tradeId: "65ee99887766554433221100",
      category: "Trading Cards",
      timeAgo: "Completed 2h ago",
      itemA: TradeVoteItemModel(
        name: "1986 Michael Jordan Fleer #57 PSA 8",
        value: "\$1,800",
        image: "https://images.unsplash.com/photo-1534447677768-be436bb09401?q=80&w=800",
        traderName: "CollectorKing",
      ),
      itemB: TradeVoteItemModel(
        name: "2003 LeBron James Topps Chrome PSA 9",
        value: "\$2,100",
        image: "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?q=80&w=800",
        traderName: "HoopsLegacy",
      ),
      initialVotesA: 14,
      initialVotesB: 36,
      initialTotalVotes: 50,
      initialPercentageA: 28,
      initialPercentageB: 72,
    ),
    TradeVoteModel(
      id: "trade_2",
      tradeId: "trade_id_2",
      category: "Sneakers",
      timeAgo: "Completed 5h ago",
      itemA: TradeVoteItemModel(
        name: "Nike Dunk Low 'Panda' (DS)",
        value: "\$180",
        image: "https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a?q=80&w=800",
        traderName: "KicksGuru",
      ),
      itemB: TradeVoteItemModel(
        name: "Air Jordan 1 High 'Shadow 2.0'",
        value: "\$210",
        image: "https://images.unsplash.com/photo-1584735935682-2f2b69dff9d2?q=80&w=800",
        traderName: "SneakerVault",
      ),
      initialVotesA: 42,
      initialVotesB: 58,
      initialTotalVotes: 100,
      initialPercentageA: 42,
      initialPercentageB: 58,
    ),
  ].obs;

  Future<void> fetchRecentTrades() async {
    isRecentTradesLoading.value = true;
    try {
      final endpoint = "${ApiUrl.tradeVotesFeed}?page=1&limit=5";
      final response = await _apiClient.getData(endpoint);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List rawList = data['data'];
          if (rawList.isNotEmpty) {
            final List<TradeVoteModel> items = rawList
                .map((item) => TradeVoteModel.fromJson(item as Map<String, dynamic>))
                .toList();
            recentTrades.assignAll(items);
            currentTradeIndex.value = 0;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching recent trade votes on Home: $e");
    } finally {
      isRecentTradesLoading.value = false;
    }
  }

  Future<void> voteOnTrade(TradeVoteModel trade, String option) async {
    final isGuest = SharePrefsHelper.isGuest ||
        SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey).isEmpty;
    if (isGuest) {
      AuthGuard.showAuthPrompt(
        title: "Sign In Required",
        message: "Sign in or create an account to participate in community trade voting!",
      );
      return;
    }

    if (trade.hasVoted.value || trade.isVoting.value) return;

    // If this is a demo placeholder card (because live database has 0 trades right now),
    // simulate the vote locally so developers can test the full UI without a 400 server error!
    final isRealMongoId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(trade.id);
    if (!isRealMongoId || trade.id == "65f123abc456789012345678" || trade.id.startsWith("trade_")) {
      trade.hasVoted.value = true;
      trade.votedOption.value = option;
      if (option == "A") {
        trade.votesA.value += 1;
      } else {
        trade.votesB.value += 1;
      }
      final sum = trade.votesA.value + trade.votesB.value;
      trade.totalVotes.value = sum;
      if (sum > 0) {
        trade.percentageA.value = ((trade.votesA.value / sum) * 100).round();
        trade.percentageB.value = 100 - trade.percentageA.value;
      }
      _showToast("Demo vote simulated locally (Backend has 0 active trades yet)", isError: false);
      return;
    }

    trade.isVoting.value = true;

    try {
      final endpoint = ApiUrl.castTradeVote(trade.id);
      final response = await _apiClient.postData(endpoint, {"option": option});

      switch (response.statusCode) {
        case 200:
          final resData = jsonDecode(response.body);
          if (resData['data'] != null && resData['data'] is Map<String, dynamic>) {
            trade.updateWithVoteResult(resData['data']);
          } else {
            trade.hasVoted.value = true;
            trade.votedOption.value = option;
            if (option == "A") {
              trade.votesA.value += 1;
            } else {
              trade.votesB.value += 1;
            }
            final sum = trade.votesA.value + trade.votesB.value;
            trade.totalVotes.value = sum;
            if (sum > 0) {
              trade.percentageA.value = ((trade.votesA.value / sum) * 100).round();
              trade.percentageB.value = 100 - trade.percentageA.value;
            }
          }
          _showToast("Vote cast successfully!", isError: false);
          break;

        case 400:
          try {
            final body = jsonDecode(response.body);
            final msg = (body['message'] ?? body['error'] ?? "This vote is no longer active.").toString();
            // If it is a demo placeholder card (since live backend currently has 0 trades),
            // allow local simulation so user can test the interactive UI flow
            if (trade.id == "65f123abc456789012345678" || trade.id.startsWith("trade_")) {
              trade.hasVoted.value = true;
              trade.votedOption.value = option;
              if (option == "A") {
                trade.votesA.value += 1;
              } else {
                trade.votesB.value += 1;
              }
              final sum = trade.votesA.value + trade.votesB.value;
              trade.totalVotes.value = sum;
              if (sum > 0) {
                trade.percentageA.value = ((trade.votesA.value / sum) * 100).round();
                trade.percentageB.value = 100 - trade.percentageA.value;
              }
              _showToast("Demo vote simulated locally (Backend has 0 active trades yet)", isError: false);
              break;
            }
            _showToast(msg.isNotEmpty ? msg : "This vote is no longer active.");
          } catch (_) {
            _showToast("This vote is no longer active.");
          }
          break;

        case 401:
          AuthGuard.showAuthPrompt(
            title: "Sign In Required",
            message: "Your session has expired. Sign in to vote on trades!",
          );
          break;

        case 403:
          _showToast("You can't vote on your own trade.");
          break;

        case 409:
          _showToast("You've already voted on this trade!");
          trade.hasVoted.value = true;
          break;

        case 404:
          recentTrades.removeWhere((item) => item.id == trade.id);
          if (currentTradeIndex.value >= recentTrades.length && recentTrades.isNotEmpty) {
            currentTradeIndex.value = recentTrades.length - 1;
          }
          break;

        default:
          final body = jsonDecode(response.body);
          final msg = (body['message'] ?? body['error'] ?? "Failed to cast vote").toString();
          _showToast(msg);
          break;
      }
    } catch (e) {
      _showToast("Unable to submit vote. Please try again.");
    } finally {
      trade.isVoting.value = false;
    }
  }

  void _showToast(String message, {bool isError = true}) {
    Get.snackbar(
      isError ? "Notice" : "Success",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF22C55E),
      colorText: Colors.white,
      margin: EdgeInsets.all(16.w),
      borderRadius: 12.r,
      duration: const Duration(seconds: 3),
    );
  }

  void nextTrade() {
    if (recentTrades.isEmpty) return;
    currentTradeIndex.value = (currentTradeIndex.value + 1) % recentTrades.length;
  }

  void prevTrade() {
    if (recentTrades.isEmpty) return;
    currentTradeIndex.value = (currentTradeIndex.value - 1 + recentTrades.length) % recentTrades.length;
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = "";
  }

  @override
  void onInit() {
    super.onInit();
    final cachedName = SharePrefsHelper.getString('userName');
    if (cachedName.isNotEmpty) {
      fullName.value = cachedName.split(" ").first;
    }

    // Instant load from cache if available
    if (_categoryProductsCache.containsKey("All") && _categoryProductsCache["All"]!.isNotEmpty) {
      products.assignAll(_categoryProductsCache["All"]!);
    }

    // High-speed parallel fetching for all Home components
    Future.wait([
      fetchProfileData(),
      fetchLiveStreams(),
      fetchScheduledShows(),
      fetchCategories(),
      fetchProducts(showLoading: products.isEmpty),
      fetchUnreadNotificationCount(),
      fetchRecentTrades(),
    ]);
  }

  Future<void> fetchUnreadNotificationCount() async {
    try {
      final response = await _apiClient.getData(ApiUrl.myNotifications);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final list = body['data'] ?? body['notifications'] ?? body['result'] ?? (body is List ? body : []);
        if (list is List) {
          int count = 0;
          for (var item in list) {
            if (item is Map && (item['isRead'] == false || item['read'] == false)) {
              count++;
            }
          }
          unreadNotificationCount.value = count;
        }
      }
    } catch (_) {}
  }

  Future<void> fetchCategories() async {
    try {
      Get.log("🔄 [Home] Fetching categories from API: ${ApiUrl.category}");
      var response = await _apiClient.getData(ApiUrl.category);

      if (response.statusCode != 200) {
        Get.log("🔄 [Home] Primary category endpoint failed (${response.statusCode}), trying fallback: ${ApiUrl.popularCategories}");
        response = await _apiClient.getData(ApiUrl.popularCategories);
      }

      if (response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        List data = [];
        if (resBody['data'] is List) {
          data = resBody['data'];
        } else if (resBody['categories'] is List) {
          data = resBody['categories'];
        }

        if (data.isNotEmpty) {
          final List<HomeCategoryItem> fetched = [
            HomeCategoryItem(id: "", name: "All"),
          ];

          for (var item in data) {
            if (item is Map) {
              final String id = (item['_id'] ?? item['id'] ?? '').toString();
              final String name = (item['name'] ?? item['title'] ?? '').toString();
              final String image = (item['image'] ?? '').toString();
              final String icon = (item['icon'] ?? '').toString();

              if (name.isNotEmpty) {
                fetched.add(HomeCategoryItem(
                  id: id,
                  name: name,
                  image: image,
                  icon: icon,
                ));
              }
            }
          }

          categoriesList.assignAll(fetched);
          categories.assignAll(fetched.map((c) => c.name).toList());
          Get.log("✅ [Home] Successfully loaded ${categoriesList.length} categories from API");
        }
      } else {
        Get.log("⚠️ [Home] Category fetch status: ${response.statusCode}");
      }
    } catch (e) {
      Get.log("❌ [Home] Error fetching categories: $e");
    }
  }

  Future<void> fetchProfileData() async {
    isLoading.value = true;
    try {
      final response = await _apiClient.getData(ApiUrl.profile);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final String full = data['fullName'] ?? "User";
        // Extract only the first name
        fullName.value = full.split(" ").first;

        // Save User ID to SharedPreferences
        final String userId = data['id'] ?? data['_id'] ?? "";
        if (userId.isNotEmpty) {
          await SharePrefsHelper.setString(SharePrefsHelper.userIdKey, userId);
          // Initialize Socket.io connection since we have userId now
          try {
            Get.find<SocketService>().initSocket();
          } catch (e) {
            Get.log("Socket connection failed to initialize: $e");
          }
        }
      }
    } catch (e) {
      Get.log("Error fetching profile on Home: $e");
    }
  }

  Future<void> fetchLiveStreams() async {
    try {
      var response = await _apiClient.getData("${ApiUrl.liveStreams}?status=live");
      if (response.statusCode != 200) {
        response = await _apiClient.getData(ApiUrl.liveStreams);
      }

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List data = body['data'] is List 
            ? body['data'] 
            : (body['streams'] is List ? body['streams'] : (body['result'] is List ? body['result'] : []));

        final parsedShows = data.where((item) {
          if (item is! Map) return false;
          final status = (item['status'] ?? item['state'] ?? 'live').toString().toLowerCase();
          return status == 'live' || status == 'active' || item['isLive'] == true;
        }).map((item) {
          final title = (item['title'] ?? "Live Show").toString();
          final hostName = (item['curator'] ?? item['sellerId']?['fullName'] ?? item['seller']?['fullName'] ?? "Curator").toString();
          
          String imageUrl = "";
          String imagePath = (item['image'] ?? item['coverImage'] ?? "").toString();
          if (imagePath.isEmpty && item['productId'] is Map) {
            final prod = item['productId'];
            final List prodImages = prod['images'] ?? [];
            if (prodImages.isNotEmpty) {
              imagePath = prodImages[0].toString();
            } else {
              imagePath = (prod['image'] ?? prod['coverImage'] ?? "").toString();
            }
          }

          if (imagePath.isNotEmpty) {
            imageUrl = imagePath.startsWith('http')
                ? imagePath
                : "${ApiUrl.imageBaseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}";
          }

          final seller = item['sellerId'] is Map ? item['sellerId'] : item['seller'];
          String avatarUrl = "";
          if (seller is Map) {
            final avatarPath = (seller['profile'] ?? seller['profileImage'] ?? seller['image'] ?? seller['profileImageUrl'] ?? seller['avatar'] ?? "").toString();
            if (avatarPath.isNotEmpty) {
              avatarUrl = avatarPath.startsWith('http')
                  ? avatarPath
                  : "${ApiUrl.imageBaseUrl}${avatarPath.startsWith('/') ? avatarPath : '/$avatarPath'}";
            }
          }

          return LiveItemModel(
            title: title,
            curator: hostName,
            viewers: "${item['viewersCount'] ?? item['viewers'] ?? '0'}",
            image: imageUrl,
            curatorAvatar: avatarUrl,
            raw: item,
          );
        }).toList();
        
        liveItems.assignAll(parsedShows);
        Get.log("📺 [Home] Loaded ${liveItems.length} active live streams");
      }
    } catch (e) {
      Get.log("Error fetching live streams on Home: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch Products based on selected category & active status with pagination
  Future<void> fetchProducts({bool showLoading = true, bool isLoadMore = false}) async {
    final int currentIdx = selectedCategoryIndex.value;
    final String currentCacheKey = _getCacheKey(currentIdx);

    if (isLoadMore) {
      if (isMoreProductsLoading.value || !hasMoreProducts.value) return;
      isMoreProductsLoading.value = true;
    } else {
      currentProductPage.value = 1;
      hasMoreProducts.value = true;

      // Instant 0ms cache rendering for initial load
      if (_categoryProductsCache.containsKey(currentCacheKey) &&
          _categoryProductsCache[currentCacheKey]!.isNotEmpty) {
        if (selectedCategoryIndex.value == currentIdx) {
          products.assignAll(_categoryProductsCache[currentCacheKey]!);
        }
        showLoading = false;
      }

      if (showLoading && products.isEmpty) {
        isProductsLoading.value = true;
      }
    }

    final int targetPage = isLoadMore ? (currentProductPage.value + 1) : 1;

    try {
      final selectedCat = (currentIdx >= 0 && currentIdx < categoriesList.length)
          ? categoriesList[currentIdx]
          : HomeCategoryItem(id: "", name: "All");

      String url;
      final String queryParams = "status=active&page=$targetPage&limit=$productLimit";

      if (selectedCat.id.isNotEmpty) {
        url = "${ApiUrl.products}?category=${selectedCat.id}&$queryParams";
      } else if (selectedCat.name.isNotEmpty && selectedCat.name != "All") {
        url = "${ApiUrl.products}?category=${Uri.encodeComponent(selectedCat.name)}&$queryParams";
      } else {
        url = "${ApiUrl.products}?$queryParams";
      }

      Get.log("🔄 [Home] Fetching products (page $targetPage): $url");
      var response = await _apiClient.getData(url);

      if (response.statusCode != 200) {
        String fallbackUrl = selectedCat.id.isNotEmpty
            ? "${ApiUrl.products}?category=${selectedCat.id}&page=$targetPage&limit=$productLimit"
            : (selectedCat.name != "All"
                ? "${ApiUrl.products}?category=${Uri.encodeComponent(selectedCat.name)}&page=$targetPage&limit=$productLimit"
                : "${ApiUrl.products}?page=$targetPage&limit=$productLimit");
        Get.log("🔄 [Home] Primary query failed (${response.statusCode}), trying fallback: $fallbackUrl");
        response = await _apiClient.getData(fallbackUrl);
      }

      if (response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        List rawList = [];

        if (resBody['data'] is List) {
          rawList = resBody['data'];
        } else if (resBody['data'] is Map) {
          final dataMap = resBody['data'];
          if (dataMap['doc'] is List) {
            rawList = dataMap['doc'];
          } else if (dataMap['products'] is List) {
            rawList = dataMap['products'];
          } else if (dataMap['result'] is List) {
            rawList = dataMap['result'];
          }
        } else if (resBody['products'] is List) {
          rawList = resBody['products'];
        }

        final List<Map<String, dynamic>> parsedList = rawList.map((e) => Map<String, dynamic>.from(e)).toList();

        // Check if more items exist
        if (parsedList.length < productLimit) {
          hasMoreProducts.value = false;
        } else {
          hasMoreProducts.value = true;
        }

        final meta = resBody['meta'] ?? (resBody['data'] is Map ? resBody['data']['meta'] : null);
        if (meta is Map && meta['totalPage'] != null) {
          final int totalPage = (meta['totalPage'] as num).toInt();
          if (targetPage >= totalPage) {
            hasMoreProducts.value = false;
          }
        }

        if (selectedCategoryIndex.value == currentIdx) {
          if (isLoadMore) {
            final existingIds = products.map((p) => (p['_id'] ?? p['id'] ?? '').toString()).toSet();
            final uniqueNew = parsedList.where((p) {
              final id = (p['_id'] ?? p['id'] ?? '').toString();
              return id.isEmpty || !existingIds.contains(id);
            }).toList();
            products.addAll(uniqueNew);
            currentProductPage.value = targetPage;
            Get.log("✅ [Home] Appended ${uniqueNew.length} more products. Total: ${products.length}");
          } else {
            products.assignAll(parsedList);
            currentProductPage.value = 1;
            _categoryProductsCache[currentCacheKey] = parsedList;
            if (currentIdx == 0) {
              _categoryProductsCache["All"] = parsedList;
            }
            Get.log("✅ [Home] Loaded & cached ${products.length} products for category: ${selectedCat.name}");
          }
        }
      } else {
        Get.log("⚠️ [Home] Failed to fetch products. Status: ${response.statusCode}");
        if (isLoadMore) {
          hasMoreProducts.value = false;
        } else if (selectedCategoryIndex.value == currentIdx && !_categoryProductsCache.containsKey(currentCacheKey)) {
          products.clear();
        }
      }
    } catch (e) {
      Get.log("❌ [Home] Error fetching products: $e");
      if (isLoadMore) {
        hasMoreProducts.value = false;
      } else if (selectedCategoryIndex.value == currentIdx && !_categoryProductsCache.containsKey(currentCacheKey)) {
        products.clear();
      }
    } finally {
      if (selectedCategoryIndex.value == currentIdx) {
        isProductsLoading.value = false;
        isMoreProductsLoading.value = false;
      }
    }
  }

  Future<void> loadMoreProducts() async {
    if (!hasMoreProducts.value || isMoreProductsLoading.value || isProductsLoading.value) return;
    await fetchProducts(showLoading: false, isLoadMore: true);
  }

  void onCategorySelected(int index) {
    if (selectedCategoryIndex.value == index && products.isNotEmpty) return;
    selectedCategoryIndex.value = index;
    currentProductPage.value = 1;
    hasMoreProducts.value = true;

    final String cacheKey = _getCacheKey(index);

    // 1. If this category is already cached, display INSTANTLY with ZERO loading delay!
    if (_categoryProductsCache.containsKey(cacheKey) && _categoryProductsCache[cacheKey]!.isNotEmpty) {
      products.assignAll(_categoryProductsCache[cacheKey]!);
      isProductsLoading.value = false;
      // Silently revalidate in background without showing annoying shimmer
      fetchProducts(showLoading: false);
      return;
    }

    // 2. If "All" is cached, pre-filter items for instant responsive feedback
    if (index > 0 && _categoryProductsCache.containsKey("All") && _categoryProductsCache["All"]!.isNotEmpty) {
      final selectedCat = (index < categoriesList.length) ? categoriesList[index] : null;
      if (selectedCat != null) {
        final filteredFromAll = _categoryProductsCache["All"]!.where((p) {
          final pCat = p['category'];
          if (pCat is Map) {
            final pCatId = (pCat['_id'] ?? pCat['id'] ?? '').toString();
            final pCatName = (pCat['name'] ?? pCat['title'] ?? '').toString().toLowerCase();
            return (selectedCat.id.isNotEmpty && pCatId == selectedCat.id) ||
                   (pCatName == selectedCat.name.toLowerCase());
          } else if (pCat is String) {
            return (selectedCat.id.isNotEmpty && pCat == selectedCat.id) ||
                   (pCat.toLowerCase() == selectedCat.name.toLowerCase());
          }
          return false;
        }).toList();

        if (filteredFromAll.isNotEmpty) {
          products.assignAll(filteredFromAll);
          isProductsLoading.value = false;
          // Silent background fetch to get full server results
          fetchProducts(showLoading: false);
          return;
        }
      }
    }

    // 3. First time loading this category - show loading indicator
    fetchProducts(showLoading: true);
  }

  // ─── UPCOMING / SCHEDULED SHOWS (Feature 3 & 4) ───
  final RxList<Map<String, dynamic>> scheduledShows = <Map<String, dynamic>>[].obs;
  final RxBool isScheduledShowsLoading = false.obs;

  Future<void> fetchScheduledShows() async {
    isScheduledShowsLoading.value = true;
    try {
      final res = await _apiClient.getData("${ApiUrl.liveStreams}?status=scheduled");
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final raw = body['data'] is List 
            ? body['data'] 
            : (body['streams'] is List ? body['streams'] : (body['result'] is List ? body['result'] : []));
        if (raw is List) {
          scheduledShows.assignAll(raw.where((e) => e is Map).map((e) => Map<String, dynamic>.from(e as Map)).toList());
          Get.log("📅 [HomeController] Loaded ${scheduledShows.length} scheduled shows");
          for (var s in scheduledShows) {
            Get.log("📸 [Scheduled Show] '${s['title']}' coverImage: '${s['coverImage']}' | image: '${s['image']}'");
          }
        }
      }
    } catch (e) {
      Get.log("❌ [HomeController] fetchScheduledShows error: $e");
    } finally {
      isScheduledShowsLoading.value = false;
    }
  }

  bool isMyShow(Map<String, dynamic> show) {
    final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    if (currentUserId.isEmpty) return false;
    final seller = show['sellerId'] ?? show['seller'];
    if (seller is Map) {
      return (seller['_id'] ?? seller['id']) == currentUserId;
    }
    return seller?.toString() == currentUserId;
  }

  // ─── SAVED SHOWS & BOOKMARKS (Feature 4) ───
  final RxList<Map<String, dynamic>> savedShows = <Map<String, dynamic>>[].obs;
  final RxBool isSavedShowsLoading = false.obs;

  Future<void> fetchSavedShows() async {
    final token = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);
    if (token.isEmpty) return; // Guest user
    isSavedShowsLoading.value = true;
    try {
      final res = await _apiClient.getData(ApiUrl.savedShows);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final raw = body['data'];
        if (raw is List) {
          savedShows.assignAll(raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
        }
      }
    } catch (e) {
      Get.log("❌ [HomeController] fetchSavedShows error: $e");
    } finally {
      isSavedShowsLoading.value = false;
    }
  }

  Future<bool> toggleBookmarkShow(String streamId) async {
    if (streamId.isEmpty) return false;
    try {
      final res = await _apiClient.postData(ApiUrl.bookmarkStream(streamId), {});
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final isBookmarked = body['data']?['isBookmarked'] ?? true;
        fetchSavedShows();
        Get.snackbar(
          isBookmarked ? "Show Saved! 🔔" : "Show Removed",
          isBookmarked ? "You will receive a notification 15 mins before showtime." : "Bookmark removed.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF161622),
          colorText: Colors.white,
        );
        return true;
      }
    } catch (e) {
      Get.log("❌ [HomeController] toggleBookmarkShow error: $e");
    }
    return false;
  }

  Future<void> refreshHome() async {
    _categoryProductsCache.clear();
    currentProductPage.value = 1;
    hasMoreProducts.value = true;
    await Future.wait([
      fetchProfileData(),
      fetchLiveStreams(),
      fetchScheduledShows(),
      fetchCategories(),
      fetchSavedShows(),
    ]);
    await fetchProducts(showLoading: true);
  }
}

class HomeCategoryItem {
  final String id;
  final String name;
  final String image;
  final String icon;

  HomeCategoryItem({
    required this.id,
    required this.name,
    this.image = "",
    this.icon = "",
  });
}

class LiveItemModel {
  final String title;
  final String curator;
  final String viewers;
  final String image;
  final String curatorAvatar;
  final Map<String, dynamic>? raw;

  LiveItemModel({
    required this.title,
    required this.curator,
    required this.viewers,
    required this.image,
    this.curatorAvatar = "",
    this.raw,
  });
}

typedef RecentTradeVoteModel = TradeVoteModel;

