import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/app_route.dart';
import 'core/dependency.dart';
import 'data/helpers/shared_prefe.dart';
import 'global/widgets/floating_live_stream_overlay.dart';
import 'view/screens/live_stream/controller/agora_live_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables safely
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Environment file (.env) load error: $e");
  }

  // Initialize Stripe publishable key safely
  try {
    Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    Stripe.instance.applySettings();
  } catch (e) {
    debugPrint("Stripe init error: $e");
  }


  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  await SharePrefsHelper.init();
  DependencyInjection.init();

  final String accessToken = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);
  final bool hasSeenOnboarding = SharePrefsHelper.getBool("hasSeenOnboarding");

  String initialRoute;
  if (accessToken.isNotEmpty) {
    initialRoute = AppRoute.main;
  } else if (hasSeenOnboarding) {
    initialRoute = AppRoute.login;
  } else {
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
          title: 'Live Stream App',
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
                  if (ctrl.isLive.value) {
                    if (routing.current != AppRoute.hostLive && routing.current != AppRoute.viewerLive) {
                      ctrl.isMinimized.value = true;
                    } else {
                      ctrl.isMinimized.value = false;
                    }
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
