import 'dart:convert';
import 'package:get/get.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/socket_service.dart';

class HomeController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  var selectedCategoryIndex = 0.obs;
  final RxString fullName = "User".obs;
  final RxBool isLoading = false.obs;

  final RxList<LiveItemModel> liveItems = <LiveItemModel>[].obs;

  // Dynamic Products List
  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;
  final RxBool isProductsLoading = false.obs;

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
      fetchCategories(),
      fetchProducts(showLoading: products.isEmpty),
      fetchUnreadNotificationCount(),
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

  // Fetch Products based on selected category & active status
  Future<void> fetchProducts({bool showLoading = true}) async {
    final int currentIdx = selectedCategoryIndex.value;
    final String currentCacheKey = _getCacheKey(currentIdx);

    // Instant 0ms cache rendering
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

    try {
      final selectedCat = (currentIdx >= 0 && currentIdx < categoriesList.length)
          ? categoriesList[currentIdx]
          : HomeCategoryItem(id: "", name: "All");

      String url;
      const String statusQuery = "status=active";

      if (selectedCat.id.isNotEmpty) {
        url = "${ApiUrl.products}?category=${selectedCat.id}&$statusQuery";
      } else if (selectedCat.name.isNotEmpty && selectedCat.name != "All") {
        url = "${ApiUrl.products}?category=${Uri.encodeComponent(selectedCat.name)}&$statusQuery";
      } else {
        url = "${ApiUrl.products}?$statusQuery";
      }

      Get.log("🔄 [Home] Fetching products from: $url");
      var response = await _apiClient.getData(url);

      if (response.statusCode != 200) {
        String fallbackUrl = selectedCat.id.isNotEmpty
            ? "${ApiUrl.products}?category=${selectedCat.id}"
            : (selectedCat.name != "All" ? "${ApiUrl.products}?category=${Uri.encodeComponent(selectedCat.name)}" : ApiUrl.products);
        Get.log("🔄 [Home] Primary query failed (${response.statusCode}), trying standard endpoint: $fallbackUrl");
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

        // Cache the category products for instant future loads
        _categoryProductsCache[currentCacheKey] = parsedList;
        if (currentIdx == 0) {
          _categoryProductsCache["All"] = parsedList;
        }

        // Only update UI if the user is still on this category
        if (selectedCategoryIndex.value == currentIdx) {
          products.assignAll(parsedList);
          Get.log("✅ [Home] Loaded & cached ${products.length} products for category: ${selectedCat.name}");
        }
      } else {
        Get.log("⚠️ [Home] Failed to fetch products. Status: ${response.statusCode}");
        if (selectedCategoryIndex.value == currentIdx && !_categoryProductsCache.containsKey(currentCacheKey)) {
          products.clear();
        }
      }
    } catch (e) {
      Get.log("❌ [Home] Error fetching products: $e");
      if (selectedCategoryIndex.value == currentIdx && !_categoryProductsCache.containsKey(currentCacheKey)) {
        products.clear();
      }
    } finally {
      if (selectedCategoryIndex.value == currentIdx) {
        isProductsLoading.value = false;
      }
    }
  }

  void onCategorySelected(int index) {
    if (selectedCategoryIndex.value == index && products.isNotEmpty) return;
    selectedCategoryIndex.value = index;

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

  Future<void> refreshHome() async {
    _categoryProductsCache.clear();
    await Future.wait([
      fetchProfileData(),
      fetchLiveStreams(),
      fetchCategories(),
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
