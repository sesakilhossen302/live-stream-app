import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/app_route.dart';
import 'core/dependency.dart';
import 'data/helpers/shared_prefe.dart';
import 'data/services/push_notification_service.dart';
import 'global/widgets/floating_live_stream_overlay.dart';
import 'view/screens/live_stream/controller/agora_live_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch framework errors gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("🔴 Flutter Error: ${details.exceptionAsString()}");
  };

  // 1. Load environment variables safely
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Environment file (.env) load error: $e");
  }

  // 2. Initialize Stripe publishable key safely
  try {
    String? key;
    if (dotenv.isInitialized) {
      key = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
    }
    key ??= "pk_test_51NJLdJF5nDLFMGmox0iseTJZp42wfLi6Ub41OGs7hoMl0GSFe93a0My7PxdF2eKsxV1rvUf8vVw4p6jl9h9pCmEQ00WSln5w44";
    if (key.isNotEmpty) {
      Stripe.publishableKey = key;
      Stripe.instance.applySettings();
    }
  } catch (e) {
    debugPrint("⚠️ Stripe init error: $e");
  }

  // 3. System UI Overlay Style
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  } catch (_) {}

  // 4. SharedPreferences initialization
  try {
    await SharePrefsHelper.init();
  } catch (e) {
    debugPrint("⚠️ SharePrefsHelper init error: $e");
  }

  // 5. Dependency Injection
  try {
    DependencyInjection.init();
  } catch (e) {
    debugPrint("⚠️ DependencyInjection init error: $e");
  }

  // 6. Initialize Push Notification Service (FCM & Local Notifications)
  try {
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint("⚠️ PushNotificationService init error: $e");
  }

  String initialRoute = AppRoute.onboarding;
  try {
    final String accessToken = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);
    final bool isGuest = SharePrefsHelper.isGuest;
    final bool hasSeenOnboarding = SharePrefsHelper.getBool("hasSeenOnboarding");

    if (accessToken.isNotEmpty || isGuest) {
      initialRoute = AppRoute.main;
    } else if (hasSeenOnboarding) {
      initialRoute = AppRoute.login;
    } else {
      initialRoute = AppRoute.onboarding;
    }
  } catch (e) {
    debugPrint("⚠️ Route resolution error: $e");
    initialRoute = AppRoute.onboarding;
  }

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 950),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AREIS',
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            fontFamily: 'Inter',
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Color(0xFF8B9BFF),
              selectionColor: Color(0x668B9BFF),
              selectionHandleColor: Color(0xFF8B9BFF),
            ),
          ),
          initialRoute: initialRoute,
          getPages: AppRoute.routes,
          routingCallback: (routing) {
            if (routing != null) {
              AppRoute.routeStream.add(routing.current);
              try {
                if (Get.isRegistered<AgoraLiveController>()) {
                  final ctrl = Get.find<AgoraLiveController>();
                  if (ctrl.isLive.value && !ctrl.isEnding.value) {
                    if (routing.current == AppRoute.hostLive || routing.current == AppRoute.viewerLive) {
                      ctrl.isMinimized.value = false;
                    }
                  } else {
                    ctrl.isMinimized.value = false;
                  }
                }
              } catch (_) {}
            }
          },
          builder: (context, widget) {
            return Stack(
              children: [
                if (widget != null) widget,
                const FloatingLiveStreamOverlay(),
              ],
            );
          },
        );
      },
    );
  }
}
