import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiUrl {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? "http://10.10.26.208:5007/api/v1";
  static String get imageBaseUrl => dotenv.env['IMAGE_BASE_URL'] ?? "http://10.10.26.208:5007";


  // Auth
  static const String login = "/auth/login";
  static const String signUp = "/auth/signup";
  static const String verifyAccount = "/auth/verify-account";
  static const String forgotPassword = "/auth/forget-password";
  static const String resetPassword = "/auth/reset-password";
  static const String updateProfile = "/users/profile";
  static const String resendOtp = "/auth/resend-otp";

  // User
  static const String profile = "/users/profile";
  static const String users = "/users";
  static const String switchRole = "/users/switch-role";

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

  // Category
  static const String category = "/category";
  static const String popularCategories = "/category/popular-categories";

  // Auctions / Live Streams
  static const String liveStreams = "/auctions/streams";
  static const String startStream = "/auctions/stream";
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
}
