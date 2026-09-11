import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/helper/auth_guard.dart';
import '../model/trade_vote_model.dart';

class TradeVotingController extends GetxController {
  final ApiClient _apiClient = ApiClient();

  final RxList<TradeVoteModel> feedItems = <TradeVoteModel>[].obs;
  final RxBool isInitialLoading = true.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString errorMessage = ''.obs;

  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalVotesCount = 0.obs;
  final int limit = 10;

  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    fetchFeed();
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;

    if (currentScroll >= maxScroll - 200) {
      if (!isLoadingMore.value && currentPage.value < totalPages.value) {
        loadMore();
      }
    }
  }

  /// Fetches the initial feed or refreshes it
  Future<void> fetchFeed({bool isRefresh = false}) async {
    if (isRefresh) {
      isRefreshing.value = true;
      currentPage.value = 1;
    } else {
      isInitialLoading.value = true;
    }
    errorMessage.value = '';

    try {
      final endpoint = "${ApiUrl.tradeVotesFeed}?page=1&limit=$limit";
      final response = await _apiClient.getData(endpoint);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List rawList = data['data'];
          final List<TradeVoteModel> items = rawList
              .map((item) => TradeVoteModel.fromJson(item as Map<String, dynamic>))
              .toList();

          feedItems.assignAll(items);

          if (data['meta'] != null) {
            totalPages.value = (data['meta']['totalPage'] as num?)?.toInt() ?? 1;
            totalVotesCount.value = (data['meta']['total'] as num?)?.toInt() ?? items.length;
            currentPage.value = (data['meta']['page'] as num?)?.toInt() ?? 1;
          }
        } else {
          feedItems.clear();
        }
      } else {
        errorMessage.value = "Failed to load trade voting feed (${response.statusCode})";
      }
    } catch (e) {
      errorMessage.value = "An error occurred while loading votes: $e";
    } finally {
      isInitialLoading.value = false;
      isRefreshing.value = false;
    }
  }

  /// Loads the next page of results for infinite scroll
  Future<void> loadMore() async {
    if (isLoadingMore.value || currentPage.value >= totalPages.value) return;

    isLoadingMore.value = true;
    final nextPage = currentPage.value + 1;

    try {
      final endpoint = "${ApiUrl.tradeVotesFeed}?page=$nextPage&limit=$limit";
      final response = await _apiClient.getData(endpoint);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List rawList = data['data'];
          final List<TradeVoteModel> items = rawList
              .map((item) => TradeVoteModel.fromJson(item as Map<String, dynamic>))
              .toList();

          feedItems.addAll(items);
          currentPage.value = nextPage;
          if (data['meta'] != null) {
            totalPages.value = (data['meta']['totalPage'] as num?)?.toInt() ?? totalPages.value;
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading more trade votes: $e");
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Casts a vote on a trade item
  Future<void> castVote(TradeVoteModel trade, String option) async {
    // 1. Guest Check: Feed loads without token; vote tap triggers login prompt
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
      _showToast("Demo vote simulated locally", isError: false);
      return;
    }

    trade.isVoting.value = true;

    try {
      final endpoint = ApiUrl.castTradeVote(trade.id);
      final response = await _apiClient.postData(endpoint, {"option": option});

      switch (response.statusCode) {
        case 200:
          // Vote cast successfully -> Update card UI with returned data locally
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
          // Voting closed / invalid ID
          try {
            final body = jsonDecode(response.body);
            final msg = (body['message'] ?? body['error'] ?? "This vote is no longer active.").toString();
            _showToast(msg.isNotEmpty ? msg : "This vote is no longer active.");
          } catch (_) {
            _showToast("This vote is no longer active.");
          }
          break;

        case 401:
          // Guest — no token or session expired
          AuthGuard.showAuthPrompt(
            title: "Sign In Required",
            message: "Your session has expired. Sign in to vote on trades!",
          );
          break;

        case 403:
          // Trader voting on own trade
          _showToast("You can't vote on your own trade.");
          break;

        case 409:
          // Already voted
          _showToast("You've already voted on this trade!");
          trade.hasVoted.value = true;
          break;

        case 404:
          // Vote record not found -> Remove card from feed silently
          feedItems.removeWhere((item) => item.id == trade.id);
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
}
