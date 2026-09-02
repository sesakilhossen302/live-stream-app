import 'dart:async';
import 'package:get/get.dart';
import '../view/screens/onboarding/screen/onboarding_screen.dart';
import '../view/screens/auth/screen/login_screen.dart';
import '../view/screens/auth/screen/forgot_password_screen.dart';
import '../view/screens/auth/screen/sign_up_screen.dart';
import '../view/screens/auth/screen/otp_screen.dart';
import '../view/screens/auth/screen/reset_password_screen.dart';
import '../view/screens/category/screen/category_screen.dart';
import '../view/screens/main/screen/main_screen.dart';
import '../view/screens/live_stream/screen/live_stream_screen.dart';
import '../view/screens/live_stream/screen/go_live_setup_screen.dart';
import '../view/screens/live_stream/screen/host_live_screen.dart';
import '../view/screens/live_stream/screen/viewer_live_screen.dart';
import '../view/screens/messages/screen/message_details_screen.dart';
import '../view/screens/messages/controller/message_details_controller.dart';
import '../view/screens/purchases/screen/track_order/screen/track_order_screen.dart';
import '../view/screens/trade_details/screen/trade_details_screen.dart';
import '../view/screens/profile/screen/account_settings_screen.dart';
import '../view/screens/profile/screen/profile_information_screen.dart';
import '../view/screens/profile/screen/change_password_screen.dart';
import '../view/screens/profile/screen/user_preferences_screen.dart';
import '../view/screens/profile/screen/terms_conditions_screen.dart';
import '../view/screens/notifications/screen/notifications_screen.dart';
import '../view/screens/notifications/screen/trade_offer_screen.dart';
import '../view/screens/trade_market/screen/create_trade_screen.dart';
import '../view/screens/profile/screen/trader_profile_screen.dart';
import '../view/screens/purchases/screen/purchases_screen.dart';
import '../view/screens/my_trades/screen/my_trades_screen.dart';
import '../view/screens/trade_details/screen/make_offer_screen.dart';
import '../view/screens/discover/screen/all_live_shows_screen.dart';
import '../view/screens/purchases/screen/shipping_label_viewer_screen.dart';
import '../view/screens/sold_items/screen/sold_items_screen.dart';
import '../view/screens/spin_wheel/screen/spin_wheel_screen.dart';
import '../view/screens/checkout/screen/order_checkout_screen.dart';

import '../view/screens/profile/screen/blocked_users_screen.dart';

class AppRoute {
  static final routeStream = StreamController<String>.broadcast();
  static const String checkout = "/checkout";
  static const String forgotPassword = "/forgotPassword";
  static const String onboarding = "/onboarding";
  static const String login = "/login";
  static const String signUp = "/signUp";
  static const String otp = "/otp";
  static const String resetPassword = "/resetPassword";
  static const String category = "/category";
  static const String main = "/main";
  static const String trackOrder = "/trackOrder";
  static const String tradeDetails = "/trade_details";
  static const String messageDetails = "/message_details";
  static const String liveStream = "/live_stream";
  static const String goLiveSetup = "/go_live_setup";
  static const String hostLive = "/host_live";
  static const String viewerLive = "/viewer_live";
  static const String createTrade = "/create_trade";
  static const String traderProfile = "/trader_profile";
  static const String purchases = "/purchases";
  static const String myTrades = "/my_trades";
  static const String makeOffer = "/make_offer";
  static const String accountSettings = "/account_settings";
  static const String profileInformation = "/profile_information";
  static const String changePassword = "/change_password";
  static const String userPreferences = "/user_preferences";
  static const String blockedUsers = "/blocked_users";
  static const String terms = "/terms";
  static const String notifications = "/notifications";
  static const String newOffer = "/new_offer";
  static const String allLiveShows = "/all_live_shows";
  static const String soldItems = "/sold_items";
  static const String shippingLabel = "/shipping_label";
  static const String spinWheel = "/spin_wheel";

  static List<GetPage> routes = [
    GetPage(name: forgotPassword, page: () => const ForgotPasswordScreen()),
    GetPage(name: onboarding, page: () => const OnboardingScreen()),
    GetPage(name: login, page: () => const LoginScreen()),
    GetPage(name: signUp, page: () => const SignUpScreen()),
    GetPage(name: otp, page: () => const OtpScreen()),
    GetPage(name: resetPassword, page: () => const ResetPasswordScreen()),
    GetPage(name: category, page: () => const CategoryScreen()),
    GetPage(name: main, page: () => const MainScreen()),
    GetPage(name: trackOrder, page: () => const TrackOrderScreen()),
    GetPage(name: tradeDetails, page: () => const TradeDetailsScreen()),
    GetPage(
      name: messageDetails,
      page: () => const MessageDetailsScreen(),
      binding: BindingsBuilder(() {
        Get.put<MessageDetailsController>(MessageDetailsController());
      }),
    ),
    GetPage(name: liveStream, page: () => const LiveStreamScreen()),
    GetPage(name: goLiveSetup, page: () => const GoLiveSetupScreen()),
    GetPage(name: hostLive, page: () => const HostLiveScreen()),
    GetPage(name: viewerLive, page: () => ViewerLiveScreen(streamData: Get.arguments ?? {})),
    GetPage(name: createTrade, page: () => const CreateTradeScreen()),
    GetPage(name: traderProfile, page: () => const TraderProfileScreen()),
    GetPage(name: purchases, page: () => const PurchasesScreen()),
    GetPage(name: myTrades, page: () => const MyTradesScreen()),
    GetPage(name: makeOffer, page: () => const MakeOfferScreen()),
    GetPage(name: accountSettings, page: () => const AccountSettingsScreen()),
    GetPage(
      name: profileInformation,
      page: () => const ProfileInformationScreen(),
    ),
    GetPage(name: changePassword, page: () => const ChangePasswordScreen()),
    GetPage(name: userPreferences, page: () => const UserPreferencesScreen()),
    GetPage(name: blockedUsers, page: () => const BlockedUsersScreen()),
    GetPage(name: terms, page: () => const TermsConditionsScreen()),
    GetPage(name: notifications, page: () => const NotificationsScreen()),
    GetPage(name: newOffer, page: () => const TradeOfferScreen()),
    GetPage(name: allLiveShows, page: () => const AllLiveShowsScreen()),
    GetPage(name: soldItems, page: () => const SoldItemsScreen()),
    GetPage(name: shippingLabel, page: () => const ShippingLabelViewerScreen()),
    GetPage(name: spinWheel, page: () => const SpinWheelScreen()),
    GetPage(name: checkout, page: () => const OrderCheckoutScreen()),
  ];
}
