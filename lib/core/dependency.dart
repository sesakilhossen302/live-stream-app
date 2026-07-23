import 'package:get/get.dart';
import '../data/services/api_client.dart';
import '../data/services/socket_service.dart';
import '../view/screens/live_stream/controller/agora_live_controller.dart';

class DependencyInjection {
  static void init() {
    Get.lazyPut(() => ApiClient(), fenix: true);
    Get.lazyPut(() => SocketService(), fenix: true);
    Get.lazyPut(() => AgoraLiveController(), fenix: true);
  }
}
