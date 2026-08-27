import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';

class DiscoverController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final RxBool isLoading = false.obs;

  var selectedFilter = 0.obs;
  final filters = ["All", "Live Shows", "Trade Market"];

  // Search parameters
  final searchQuery = "".obs;
  final searchController = TextEditingController();

  // Lists for dynamic API integration
  final liveShows = <Map<String, dynamic>>[].obs;
  final featuredLiveItems = <Map<String, dynamic>>[].obs;
  final featuredTrades = <Map<String, dynamic>>[].obs;
  final tradeMarketItems = <Map<String, dynamic>>[].obs;
  final topSellers = <Map<String, dynamic>>[].obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = "".obs;

  final trendingTags = ["#jordan1", "#charizard-psa10", "#rolex-daytona", "#grail-sneakers", "#luxury-trading"].obs;

  @override
  void onInit() {
    super.onInit();
    fetchDiscoverData();
  }

  Future<void> fetchDiscoverData() async {
    isLoading.value = true;
    try {
      await Future.wait([
        fetchLiveShows(),
        fetchTradeMarketItems(),
      ]);
    } catch (e) {
      Get.log("Error loading discover data: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchLiveShows() async {
    try {
      final response = await _apiClient.getData("${ApiUrl.liveStreams}?status=live");
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body)['data'] ?? [];
        final parsedShows = data.where((item) => item['status'] == 'live').map((item) {
          final hostName = item['curator'] ?? item['sellerId']?['fullName'] ?? "Curator";
          
          // Get product info from productId directly or nested auctionItems
          Map<String, dynamic>? prod;
          if (item['productId'] is Map) {
            prod = Map<String, dynamic>.from(item['productId']);
          }

          final auctionItems = item['auctionItems'];
          if (auctionItems is List && auctionItems.isNotEmpty) {
            final firstAuctionItem = auctionItems[0];
            if (firstAuctionItem is Map) {
              final prodData = firstAuctionItem['productId'];
              if (prod == null && prodData is Map) {
                prod = Map<String, dynamic>.from(prodData);
              }
            }
          }

          final title = item['title'] ?? (prod != null ? (prod['title'] ?? prod['name']) : null) ?? "Live Show";
          
          String imageUrl = "";
          String imagePath = item['image'] ?? "";
          if (imagePath.isEmpty && prod != null) {
            final List prodImages = prod['images'] ?? [];
            if (prodImages.isNotEmpty) {
              imagePath = prodImages[0].toString();
            } else {
              imagePath = prod['image'] ?? prod['coverImage'] ?? "";
            }
          }

          if (imagePath.isNotEmpty) {
            imageUrl = (imagePath.startsWith('http') || imagePath.startsWith('data:image/'))
                ? imagePath
                : "${ApiUrl.imageBaseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}";
          } else {
            imageUrl = "";
          }

          final seller = item['sellerId'];
          String hostAvatarUrl = "";
          if (seller is Map) {
            final avatarPath = seller['profile'] ?? seller['profileImage'] ?? seller['image'] ?? seller['profileImageUrl'] ?? seller['avatar'] ?? "";
            if (avatarPath.isNotEmpty) {
              hostAvatarUrl = avatarPath.startsWith('http')
                  ? avatarPath
                  : "${ApiUrl.imageBaseUrl}${avatarPath.startsWith('/') ? avatarPath : '/$avatarPath'}";
            }
          }

          return <String, dynamic>{
            "title": title,
            "host": "Hosted by $hostName",
            "viewers": "${item['viewers'] ?? '0'}",
            "image": imageUrl,
            "hostAvatar": hostAvatarUrl,
            "raw": item,
          };
        }).toList();
        liveShows.assignAll(parsedShows);

        final List<Map<String, dynamic>> parsedFeatured = [];
        for (var item in data.take(2)) {
          String prodId = "";
          if (item['productId'] is Map) {
            prodId = (item['productId']['_id'] ?? item['productId']['id'] ?? "").toString();
          } else if (item['productId'] != null) {
            prodId = item['productId'].toString();
          }

          final auctionItems = item['auctionItems'];
          if (auctionItems is List && auctionItems.isNotEmpty) {
            final firstAuctionItem = auctionItems[0];
            if (firstAuctionItem is Map) {
              final prodData = firstAuctionItem['productId'];
              if (prodData is Map) {
                if (prodId.isEmpty) {
                  prodId = (prodData['_id'] ?? prodData['id'] ?? "").toString();
                }
              } else if (prodData != null && prodId.isEmpty) {
                prodId = prodData.toString();
              }
            }
          }

          Map<String, dynamic>? prod;
          if (prodId.isNotEmpty) {
            try {
              final pRes = await _apiClient.getData("/products/$prodId");
              if (pRes.statusCode == 200) {
                final body = jsonDecode(pRes.body);
                final pData = body['data'] ?? body['product'] ?? body;
                if (pData is Map) {
                  prod = Map<String, dynamic>.from(pData);
                }
              }
            } catch (e) {
              debugPrint("Error fetching product details for discover: $e");
            }
          }

          if (prod == null && item['productId'] is Map) {
            prod = Map<String, dynamic>.from(item['productId']);
          }

          final title = item['title'] ?? (prod != null ? (prod['title'] ?? prod['name']) : null) ?? "Live Item";
          double priceVal = 0.0;
          if (prod != null) {
            priceVal = double.tryParse(prod['buyNowPrice']?.toString() ?? prod['estValue']?.toString() ?? prod['price']?.toString() ?? prod['startingBid']?.toString() ?? '0') ?? 0.0;
          }

          String imageUrl = "";
          String imagePath = item['image'] ?? "";
          if (imagePath.isEmpty && prod != null) {
            final List prodImages = prod['images'] ?? [];
            if (prodImages.isNotEmpty) {
              imagePath = prodImages[0].toString();
            } else {
              imagePath = prod['image'] ?? prod['coverImage'] ?? "";
            }
          }

          if (imagePath.isNotEmpty) {
            imageUrl = (imagePath.startsWith('http') || imagePath.startsWith('data:image/'))
                ? imagePath
                : "${ApiUrl.imageBaseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}";
          } else {
            imageUrl = "";
          }

          if (prod == null) {
            final seller = item['sellerId'];
            prod = {
              "id": item['id'] ?? item['_id'] ?? "dummy_id_${title}",
              "_id": item['_id'] ?? item['id'] ?? "dummy_id_${title}",
              "title": title,
              "description": item['description'] ?? "No description provided.",
              "category": "PRODUCT",
              "condition": "BRAND NEW",
              "estValue": "0",
              "price": "0",
              "buyNowPrice": "0",
              "images": imageUrl.isNotEmpty ? [imageUrl] : [],
              "sellerId": seller,
              "allowTrade": true,
            };
          }

          parsedFeatured.add(<String, dynamic>{
            "category": "PRODUCT",
            "title": title,
            "price": "\$${priceVal.toStringAsFixed(0)}",
            "image": imageUrl,
            "badge": "BUY NOW",
            "raw": item,
            "productRaw": prod,
          });
        }
        featuredLiveItems.assignAll(parsedFeatured);
      }
    } catch (e) {
      Get.log("Error loading live shows: $e");
    }
  }

  Future<void> fetchTradeMarketItems() async {
    try {
      final response = await _apiClient.getData(ApiUrl.products);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body)['data'] ?? [];
        
        final parsedMarket = data.map((item) {
          final title = item['title'] ?? "Unknown Item";
          final priceVal = item['estValue'] ?? 0;
          final condition = item['condition'] ?? "GOOD";
          
          String imageUrl = "";
          final imagesList = item['images'];
          if (imagesList != null && imagesList is List && imagesList.isNotEmpty) {
            final imagePath = imagesList[0].toString();
            imageUrl = (imagePath.startsWith('http') || imagePath.startsWith('data:image/'))
                ? imagePath
                : "${ApiUrl.imageBaseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}";
          }
          if (imageUrl.isEmpty) {
            imageUrl = "";
          }
          
          return <String, dynamic>{
            "title": title,
            "value": "\$${priceVal.toString()}",
            "lookingFor": (item['description'] ?? "Trade for equal value").toString(),
            "tag": condition.toString().toUpperCase(),
            "image": imageUrl,
            "raw": item,
          };
        }).toList();
        tradeMarketItems.assignAll(parsedMarket);

        final parsedFeatured = data.take(3).map((item) {
          final title = item['title'] ?? "Unknown Item";
          final priceVal = item['estValue'] ?? 0;
          
          String imageUrl = "";
          final imagesList = item['images'];
          if (imagesList != null && imagesList is List && imagesList.isNotEmpty) {
            final imagePath = imagesList[0].toString();
            imageUrl = (imagePath.startsWith('http') || imagePath.startsWith('data:image/'))
                ? imagePath
                : "${ApiUrl.imageBaseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}";
          }
          if (imageUrl.isEmpty) {
            imageUrl = "";
          }
          
          return <String, dynamic>{
            "title": title,
            "price": "Starting Est. \$${priceVal.toString()}",
            "image": imageUrl,
            "raw": item,
          };
        }).toList();
        featuredTrades.assignAll(parsedFeatured);
      }
    } catch (e) {
      Get.log("Error loading trade market items: $e");
    }
  }

  bool get isSearching => searchQuery.value.trim().isNotEmpty;

  int get totalSearchResultsCount => filteredLiveShows.length + filteredTradeMarketItems.length;

  List<Map<String, dynamic>> get filteredLiveShows {
    final query = searchQuery.value.toLowerCase().trim();
    if (query.isEmpty) return liveShows;
    return liveShows.where((show) {
      final title = (show['title'] ?? '').toString().toLowerCase();
      final host = (show['host'] ?? '').toString().toLowerCase();
      final raw = show['raw'];
      final prodTitle = (raw is Map && raw['productId'] is Map)
          ? (raw['productId']['title'] ?? raw['productId']['name'] ?? '').toString().toLowerCase()
          : '';
      return title.contains(query) || host.contains(query) || prodTitle.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get filteredTradeMarketItems {
    final query = searchQuery.value.toLowerCase().trim();
    if (query.isEmpty) return tradeMarketItems;
    return tradeMarketItems.where((item) {
      final title = item['title']?.toString().toLowerCase() ?? "";
      final tag = item['tag']?.toString().toLowerCase() ?? "";
      final lookingFor = item['lookingFor']?.toString().toLowerCase() ?? "";
      final raw = item['raw'];
      final desc = (raw is Map ? (raw['description'] ?? '') : '').toString().toLowerCase();
      final category = (raw is Map && raw['category'] is Map)
          ? (raw['category']['name'] ?? raw['category']['title'] ?? '').toString().toLowerCase()
          : '';
      return title.contains(query) ||
          tag.contains(query) ||
          lookingFor.contains(query) ||
          desc.contains(query) ||
          category.contains(query);
    }).toList();
  }

  void onTagSelected(String tag) {
    final clean = tag.replaceAll('#', '').trim();
    searchController.text = clean;
    searchQuery.value = clean;
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = "";
  }

  Future<void> performServerSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    isLoading.value = true;
    try {
      final response = await _apiClient.getData("${ApiUrl.products}?searchTerm=${Uri.encodeComponent(q)}");
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List data = [];
        if (body['data'] is List) {
          data = body['data'];
        } else if (body['data'] is Map && body['data']['doc'] is List) {
          data = body['data']['doc'];
        } else if (body['data'] is Map && body['data']['products'] is List) {
          data = body['data']['products'];
        } else if (body['products'] is List) {
          data = body['products'];
        }
        if (data.isNotEmpty) {
          final parsed = data.map((item) {
            final title = item['title'] ?? "Unknown Item";
            final priceVal = item['estValue'] ?? 0;
            final condition = item['condition'] ?? "GOOD";
            String imageUrl = "";
            final imagesList = item['images'];
            if (imagesList != null && imagesList is List && imagesList.isNotEmpty) {
              final imagePath = imagesList[0].toString();
              imageUrl = (imagePath.startsWith('http') || imagePath.startsWith('data:image/'))
                  ? imagePath
                  : "${ApiUrl.imageBaseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}";
            }
            return <String, dynamic>{
              "title": title,
              "value": "\$${priceVal.toString()}",
              "lookingFor": (item['description'] ?? "Trade for equal value").toString(),
              "tag": condition.toString().toUpperCase(),
              "image": imageUrl,
              "raw": item,
            };
          }).toList();
          tradeMarketItems.assignAll(parsed);
        }
      }
    } catch (e) {
      Get.log("Server search error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void changeFilter(int index) {
    selectedFilter.value = index;
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
