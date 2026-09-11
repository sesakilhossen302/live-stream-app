import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiUrl {
  static String get baseUrl {
    if (dotenv.isInitialized) {
      return dotenv.env['BASE_URL'] ?? "https://mohosin5001.binarybards.online/api/v1";
    }
    return "https://mohosin5001.binarybards.online/api/v1";
  }

  static String get imageBaseUrl {
    if (dotenv.isInitialized) {
      return dotenv.env['IMAGE_BASE_URL'] ?? "https://mohosin5001.binarybards.online";
    }
    return "https://mohosin5001.binarybards.online";
  }


  // Auth
  static const String login = "/auth/login";
  static const String signUp = "/auth/signup";
  static const String verifyAccount = "/auth/verify-account";
  static const String forgotPassword = "/auth/forget-password";
  static const String resetPassword = "/auth/reset-password";
  static const String updateProfile = "/users/profile";
  static const String resendOtp = "/auth/resend-otp";
  static const String deleteAccount = "/auth/delete-account";

  // User
  static const String profile = "/users/profile";
  static const String users = "/users";
  static const String switchRole = "/users/switch-role";
  static String blockUser(String userId) => "/users/block/$userId";
  static String unblockUser(String userId) => "/users/unblock/$userId";
  static const String blockedList = "/users/blocked-list";

  // Support / Report
  static const String support = "/support";

  // Products
  static const String products = "/products";
  static const String product = "/products";

  // Notifications
  static const String myNotifications = "/notifications/my";

  // Orders
  static const String userOrders = "/orders/user";
  static const String orders = "/orders";
  static const String orderJourney = "/orders/journey";

  // Trades
  static const String tradeOffers = "/trades/offers";
  static const String acceptTrade = "/trades/accept";
  static const String declineTrade = "/trades/decline";
  static const String tradeVotesFeed = "/trades/votes/feed";
  static String castTradeVote(String id) => "/trades/votes/$id/cast";

  // Category
  static const String category = "/category";
  static const String popularCategories = "/category/popular-categories";

  // Safety & Compliance Disclaimer
  static const String safetyDisclaimer = "/public/safety-disclaimer";

  // Giveaway / Spin Wheel
  static const String drawGiveawayWinner = "/giveaway/draw-winner";

  // Auctions / Live Streams
  static const String liveStreams = "/auctions/streams";
  static const String startStream = "/auctions/stream";
  static String startScheduledStream(String streamId) => "/auctions/stream/start-scheduled/$streamId";
  static String bookmarkStream(String streamId) => "/auctions/stream/$streamId/bookmark";
  static const String savedShows = "/auctions/saved-shows";
  static String streamInventory(String streamId) => "/auctions/stream/$streamId/inventory";
  static const String quickStartAuction = "/auctions/item/quick-start";
  static const String addAuctionItem = "/auctions/item";
  static const String placeBid = "/auctions/bid";
  static const String agoraToken = "/auctions/token";

  // Chats & Messages
  static const String chat = "/chat";
  static const String message = "/message";

  // Reviews
  static const String review = "/review";

  // Favourites
  static const String favourite = "/favourite";

  // Payments & Checkout
  static const String createPaymentIntent = "/payment/create-payment-intent";
  static const String createCheckoutSession = "/payment/create-checkout-session";
  static const String paymentCheckoutSession = "/payment/create-checkout-session";
  static const String subscriptionCheckoutSession = "/subscription/checkout-session";

  // Legal & Compliance
  static const String termsAndConditionsUrl = "https://api.areisco.com/terms-and-conditions";
  static const String privacyPolicyUrl = "https://api.areisco.com/privacy-policy";
}
