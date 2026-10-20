import 'package:permission_handler/permission_handler.dart';

enum AppPermission { microphone, notifications, sms, battery }

class PermissionService {
  Permission _map(AppPermission p) => switch (p) {
        AppPermission.microphone => Permission.microphone,
        AppPermission.notifications => Permission.notification,
        AppPermission.sms => Permission.sms,
        AppPermission.battery => Permission.ignoreBatteryOptimizations,
      };

  Future<PermissionStatus> status(AppPermission p) => _map(p).status;

  Future<PermissionStatus> request(AppPermission p) => _map(p).request();

  Future<bool> openSettings() => openAppSettings();
}