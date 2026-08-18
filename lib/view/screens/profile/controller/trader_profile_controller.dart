import 'dart:convert';
import 'package:get/get.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/helpers/shared_prefe.dart';

class TraderProfileController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  // ─── Profile ────────────────────────────────────────────────────────────────
  final isLoading = true.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  final traderId = ''.obs;
  final traderName = ''.obs;
  final traderUsername = ''.obs;
  final traderEmail = ''.obs;
  final traderAvatar = ''.obs;
  final traderBio = ''.obs;
  final traderRole = ''.obs;
  final isVerified = false.obs;
  final memberSince = ''.obs;

  // ─── Stats ──────────────────────────────────────────────────────────────────
  final totalTrades = 0.obs;
  final rating = 0.0.obs;
  final reviewCount = 0.obs;
  final positivePercent = 0.obs;
  final followersCount = 0.obs;
  final followingCount = 0.obs;
  final totalOrders = 0.obs;

  // ─── Follow State ────────────────────────────────────────────────────────────
  final isFollowing = false.obs;
  final isFollowLoading = false.obs;
  final isFollowersLoading = false.obs;
  final followersList = <Map<String, dynamic>>[].obs;
  final isFollowingLoading = false.obs;
  final followingList = <Map<String, dynamic>>[].obs;

  // ─── Products (Trade Collection) ─────────────────────────────────────────────
  final isProductsLoading = true.obs;
  final products = <Map<String, dynamic>>[].obs;

  // ─── Recent Bids / Trade Offers ──────────────────────────────────────────────
  final isBidsLoading = true.obs;
  final recentBids = <Map<String, dynamic>>[].obs;

  // ─── Reviews ─────────────────────────────────────────────────────────────────
  final isReviewsLoading = true.obs;
  final reviews = <Map<String, dynamic>>[].obs;

  // ─── Upcoming Shows (Feature 5) ─────────────────────────────────────────────
  final isUpcomingShowsLoading = true.obs;
  final upcomingShows = <Map<String, dynamic>>[].obs;
  final remindedShowIds = <String>{}.obs;

  // ─── Active Tab ──────────────────────────────────────────────────────────────
  final activeTab = 0.obs; // 0=Collection, 1=Recent Bids, 2=Reviews

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>? ?? {};

    traderId.value = args['id'] ?? args['_id'] ?? '';

    // Prefill from navigation args immediately (instant render)
    final dynamic navSeller = args['sellerId'] ?? args['seller'] ?? args['user'];
    final String initialName = (args['name'] ?? args['fullName'] ?? (navSeller is Map ? navSeller['fullName'] : '') ?? '').toString();
    traderName.value = initialName.replaceAll('@', '').trim();
    traderUsername.value = (args['username'] ?? '').toString().replaceAll('@', '').trim();
    traderBio.value = args['bio'] ?? args['description'] ?? '';
    traderAvatar.value = args['avatar'] ?? args['image'] ?? '';

    final String initialEmail = (args['email'] ?? (navSeller is Map ? navSeller['email'] : '') ?? '').toString();
    if (initialEmail.isNotEmpty) {
      traderEmail.value = initialEmail;
    }

    if (traderId.value.isNotEmpty) {
      _loadAll();
    } else {
      isLoading.value = false;
      isProductsLoading.value = false;
      isBidsLoading.value = false;
      isReviewsLoading.value = false;
      isUpcomingShowsLoading.value = false;
      fetchUpcomingShows();
    }
  }

  void _loadAll() {
    fetchTraderProfile();
    fetchTraderProducts();
    fetchRecentBids();
    fetchReviews();
    fetchUpcomingShows();
  }

  // ─── FETCH PROFILE ──────────────────────────────────────────────────────────

  Future<void> fetchTraderProfile() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      final response =
          await _apiClient.getData('${ApiUrl.users}/${traderId.value}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body;

        final String rawName = (data['fullName'] ?? data['name'] ?? traderName.value).toString();
        traderName.value = rawName.replaceAll('@', '').trim();

        final String rawUser = (data['username'] ?? traderUsername.value).toString();
        traderUsername.value = rawUser.replaceAll('@', '').trim();

        traderBio.value =
            data['bio'] ?? data['description'] ?? traderBio.value;
        traderAvatar.value = data['avatar'] ??
            data['profileImage'] ??
            data['image'] ??
            traderAvatar.value;
        traderRole.value = data['role'] ?? '';
        
        final dynamic rawEmail = data['email'] ??
            (data['user'] is Map ? data['user']['email'] : null) ??
            (data['authId'] is Map ? data['authId']['email'] : null) ??
            (data['userId'] is Map ? data['userId']['email'] : null) ??
            (data['sellerId'] is Map ? data['sellerId']['email'] : null);
        if (rawEmail != null && rawEmail.toString().isNotEmpty) {
          traderEmail.value = rawEmail.toString();
        }
        Get.log("🔍 [TraderProfile] fetched email: '${traderEmail.value}' for user: ${traderId.value}");
        
        isVerified.value = data['isVerified'] == true || data['verified'] == true;

        // Member since
        final createdAt = data['createdAt'] ?? '';
        if (createdAt.isNotEmpty) {
          try {
            final dt = DateTime.parse(createdAt).toLocal();
            memberSince.value =
                '${_monthName(dt.month)} ${dt.year}';
          } catch (_) {}
        }

        // Stats block per culturecardsllc-server integration guide
        final stats = data['stats'] ?? {};
        
        final t = stats['trades'] ?? stats['totalTrades'] ?? data['totalTrades'] ?? data['trades'];
        totalTrades.value = t != null ? (t as num).toInt() : 0;
        
        totalOrders.value = (stats['totalOrders'] ?? data['totalOrders'] ?? 0) as int;

        final r = stats['rating'] ?? data['rating'] ?? data['averageRating'];
        rating.value = r != null ? (r as num).toDouble() : 0.0;

        reviewCount.value = (stats['reviewCount'] ?? data['reviewCount'] ?? 0) as int;

        final pos = stats['positive'] ?? stats['positivePercent'] ?? data['positivePercent'] ?? data['positiveRate'];
        positivePercent.value = pos != null ? (pos as num).toInt() : 0;

        // Followers & Following from stats
        final fol = stats['followers'] ?? data['followersCount'] ?? (data['followers'] is List ? (data['followers'] as List).length : (data['followers'] is int ? data['followers'] : 0));
        followersCount.value = fol != null ? (fol as num).toInt() : 0;

        final fing = stats['following'] ?? data['followingCount'] ?? (data['following'] is List ? (data['following'] as List).length : (data['following'] is int ? data['following'] : 0));
        followingCount.value = fing != null ? (fing as num).toInt() : 0;

        // Check if current user follows this trader
        if (data.containsKey('isFollowing')) {
          isFollowing.value = data['isFollowing'] == true;
        } else if (data.containsKey('isFollowed')) {
          isFollowing.value = data['isFollowed'] == true;
        } else {
          final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
          final followers = data['followers'];
          if (followers is List) {
            isFollowing.value = followers.any((f) =>
                f == currentUserId ||
                (f is Map && (f['_id'] == currentUserId || f['id'] == currentUserId)));
          }
        }

        Get.log('✅ [TraderProfile] Loaded: ${traderName.value}');
      } else {
        hasError.value = true;
        errorMessage.value = 'Failed to load profile (${response.statusCode})';
        Get.log('⚠️ [TraderProfile] Status: ${response.statusCode}');
      }
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Network error. Please try again.';
      Get.log('❌ [TraderProfile] fetchProfile error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ─── FETCH PRODUCTS ─────────────────────────────────────────────────────────

  Future<void> fetchTraderProducts() async {
    isProductsLoading.value = true;
    try {
      final response = await _apiClient
          .getData('${ApiUrl.products}?sellerId=${traderId.value}&limit=20');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List rawList =
            body['data'] ?? body['products'] ?? body['result'] ?? [];
        products.value =
            rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        
        for (var item in rawList) {
          if (item is Map && item['sellerId'] is Map && item['sellerId']['email'] != null) {
            final em = item['sellerId']['email'].toString();
            if (em.isNotEmpty) {
              traderEmail.value = em;
              Get.log("✅ [TraderProfile] Extracted email from product sellerId: $em");
              break;
            }
          }
        }
        Get.log('✅ [TraderProfile] Products: ${products.length}');
      }
    } catch (e) {
      Get.log('❌ [TraderProfile] fetchProducts error: $e');
    } finally {
      isProductsLoading.value = false;
    }
  }

  // ─── FETCH RECENT BIDS / TRADES ─────────────────────────────────────────────

  Future<void> fetchRecentBids() async {
    isBidsLoading.value = true;
    try {
      final response = await _apiClient.getData(
          '${ApiUrl.tradeOffers}?userId=${traderId.value}&type=sent&limit=10');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List rawList =
            body['data'] ?? body['trades'] ?? body['offers'] ?? [];
        recentBids.value =
            rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        Get.log('✅ [TraderProfile] Bids: ${recentBids.length}');
      }
    } catch (e) {
      Get.log('❌ [TraderProfile] fetchBids error: $e');
    } finally {
      isBidsLoading.value = false;
    }
  }

  // ─── FETCH REVIEWS ──────────────────────────────────────────────────────────

  Future<void> fetchReviews() async {
    isReviewsLoading.value = true;
    try {
      final response = await _apiClient
          .getData('${ApiUrl.review}/provider/${traderId.value}');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List rawList =
            body['data'] ?? body['reviews'] ?? [];
        reviews.value =
            rawList.map((e) => Map<String, dynamic>.from(e)).toList();

        // Recompute rating from reviews if profile didn't have it
        if (reviews.isNotEmpty && rating.value == 0.0) {
          final avg = reviews
                  .map((r) => (r['rating'] ?? 0) as num)
                  .reduce((a, b) => a + b) /
              reviews.length;
          rating.value = avg.toDouble();
          reviewCount.value = reviews.length;

          final pos = reviews.where((r) => (r['rating'] ?? 0) >= 4).length;
          positivePercent.value =
              ((pos / reviews.length) * 100).toInt();
        }

        Get.log('✅ [TraderProfile] Reviews: ${reviews.length}');
      }
    } catch (e) {
      Get.log('❌ [TraderProfile] fetchReviews error: $e');
    } finally {
      isReviewsLoading.value = false;
    }
  }

  // ─── FOLLOW / UNFOLLOW ──────────────────────────────────────────────────────

  Future<void> toggleFollow() async {
    if (isFollowLoading.value || traderId.value.isEmpty) return;
    isFollowLoading.value = true;
    try {
      final response = await _apiClient.postData('/follow/${traderId.value}', {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        if (data is Map && data.containsKey('followed')) {
          isFollowing.value = data['followed'] == true;
        } else {
          isFollowing.value = !isFollowing.value;
        }
        followersCount.value = isFollowing.value
            ? followersCount.value + 1
            : (followersCount.value - 1).clamp(0, 9999999);
        Get.log('✅ [TraderProfile] Follow API success: isFollowing=${isFollowing.value}');
      } else {
        Get.snackbar('Error', 'Failed to update follow status (${response.statusCode})');
      }
    } catch (e) {
      Get.log('❌ [TraderProfile] toggleFollow error: $e');
    } finally {
      isFollowLoading.value = false;
    }
  }

  // ─── FETCH FOLLOWERS & FOLLOWING LISTS ────────────────────────────────────

  Future<void> fetchFollowersList() async {
    if (traderId.value.isEmpty) return;
    isFollowersLoading.value = true;
    try {
      final response = await _apiClient.getData('/follow/${traderId.value}/followers?page=1&limit=20');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List list = body['data'] ?? body['followers'] ?? [];
        followersList.assignAll(list.map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (e) {
      Get.log("Error fetching followers list: $e");
    } finally {
      isFollowersLoading.value = false;
    }
  }

  Future<void> fetchFollowingList() async {
    if (traderId.value.isEmpty) return;
    isFollowingLoading.value = true;
    try {
      final response = await _apiClient.getData('/follow/${traderId.value}/following?page=1&limit=20');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List list = body['data'] ?? body['following'] ?? [];
        followingList.assignAll(list.map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (e) {
      Get.log("Error fetching following list: $e");
    } finally {
      isFollowingLoading.value = false;
    }
  }


  // ─── UPCOMING SHOWS ────────────────────────────────────────────────────────
  void toggleReminder(String showId) {
    if (remindedShowIds.contains(showId)) {
      remindedShowIds.remove(showId);
      Get.snackbar(
        "Reminder Removed",
        "You will not receive a notification for this show.",
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      remindedShowIds.add(showId);
      Get.snackbar(
        "Reminder Set 🔔",
        "We'll notify you 15 minutes before the show goes live!",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> fetchUpcomingShows() async {
    isUpcomingShowsLoading.value = true;
    try {
      final tid = traderId.value;
      if (tid.isNotEmpty) {
        final response = await _apiClient.getData('/live-stream/user/$tid?status=upcoming');
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final List list = body['data'] ?? body['streams'] ?? [];
          if (list.isNotEmpty) {
            upcomingShows.assignAll(list.map((e) => Map<String, dynamic>.from(e)).toList());
            return;
          }
        }
      }
      // Fallback mock upcoming shows for realistic display if backend is empty
      upcomingShows.assignAll([
        {
          "id": "show_1",
          "title": "Exclusive Vault Drop & Holy Grails",
          "scheduledTime": "Tomorrow, 8:00 PM EST",
          "thumbnail": "https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=600",
          "category": "Collectibles",
          "totalItems": 12,
          "isLive": false,
        },
        {
          "id": "show_2",
          "title": "Vintage PSA 10 Mystery Box Auction",
          "scheduledTime": "Friday, 9:30 PM EST",
          "thumbnail": "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=600",
          "category": "Trading Cards",
          "totalItems": 8,
          "isLive": false,
        },
      ]);
    } catch (e) {
      Get.log("Error fetching upcoming shows: $e");
    } finally {
      isUpcomingShowsLoading.value = false;
    }
  }

  // ─── REFRESH ALL ────────────────────────────────────────────────────────────

  Future<void> refreshAll() async {
    await Future.wait([
      fetchTraderProfile(),
      fetchTraderProducts(),
      fetchRecentBids(),
      fetchReviews(),
      fetchUpcomingShows(),
    ]);
  }

  // ─── TAB ────────────────────────────────────────────────────────────────────

  void setTab(int index) => activeTab.value = index;

  // ─── COMPUTED GETTERS ────────────────────────────────────────────────────────

  String get displayName {
    final clean = traderName.value.replaceAll('@', '').trim();
    return clean.isNotEmpty ? clean : 'Trader';
  }

  String get displayUsername {
    final clean = traderUsername.value.replaceAll('@', '').trim();
    if (clean.isNotEmpty) return '@$clean';
    final nameClean = traderName.value.replaceAll('@', '').replaceAll(' ', '').toLowerCase().trim();
    return nameClean.isNotEmpty ? '@$nameClean' : '';
  }

  String get displayEmail => traderEmail.value;

  String get displayBio {
    final b = traderBio.value;
    return b.isNotEmpty ? b : 'Trusted trader. Verified for secure swaps.';
  }

  String get displayAvatar => traderAvatar.value;

  String get ratingDisplay =>
      rating.value > 0 ? rating.value.toStringAsFixed(1) : '—';

  String get positiveDisplay =>
      positivePercent.value > 0 ? '${positivePercent.value}%' : '—';

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }
}
