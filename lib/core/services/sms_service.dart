import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsStatusUpdate {
  const SmsStatusUpdate(this.id, this.status, [this.error]);
  final String id;

  /// submitted, sent, delivered, not_delivered, failed
  final String status;
  final String? error;

  bool get isFinal =>
      status == 'delivered' || status == 'failed' || status == 'not_delivered';
}

/// Sends SMS from the phone's own SIM.
/// Android: automatic, with real network status.
/// iPhone: Apple does not allow automatic SMS, so we open Messages
/// with the text already written and the user taps Send.
class SmsService {
  SmsService._() {
    _channel.setMethodCallHandler(_onNativeCall);
  }
  static final instance = SmsService._();

  static const _channel = MethodChannel('hearable/sms');
  final _updates = StreamController<SmsStatusUpdate>.broadcast();

  bool get canSendAutomatically => Platform.isAndroid;

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method != 'onStatus') return;
    final m = Map<String, dynamic>.from(call.arguments as Map);
    _updates.add(SmsStatusUpdate(
      m['id'] as String,
      m['status'] as String,
      m['error'] as String?,
    ));
  }

  Future<bool> hasPermission() async =>
      Platform.isAndroid && await Permission.sms.isGranted;

  Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return false;
    var status = await Permission.sms.status;
    if (!status.isGranted) status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Sends one SMS and reports every status change until it is
  /// delivered, failed, or [timeout] passes. Some networks never send
  /// delivery reports — then the last status stays "sent", and the app
  /// says "delivery not confirmed".
  Stream<SmsStatusUpdate> sendTracked({
    required String id,
    required String phone,
    required String message,
    Duration timeout = const Duration(minutes: 2),
  }) {
    final controller = StreamController<SmsStatusUpdate>();
    StreamSubscription<SmsStatusUpdate>? sub;
    Timer? timer;

    void emit(SmsStatusUpdate u) {
      if (!controller.isClosed) controller.add(u);
    }

    void close() {
      timer?.cancel();
      sub?.cancel();
      if (!controller.isClosed) controller.close();
    }

    // Listen BEFORE sending so no status update is missed
    sub = _updates.stream.where((u) => u.id == id).listen((u) {
      emit(u);
      if (u.isFinal) close();
    });
    timer = Timer(timeout, close);

    _channel
        .invokeMethod('send', {'id': id, 'phone': phone, 'message': message})
        .then((_) => emit(SmsStatusUpdate(id, 'submitted')))
        .catchError((Object e) {
      emit(SmsStatusUpdate(id, 'failed',
          e is PlatformException ? e.message : e.toString()));
      close();
    });

    return controller.stream;
  }

  /// iPhone / fallback: opens Messages with the text pre-filled.
  Future<bool> openComposer({
    required String phone,
    required String message,
  }) async {
    final uri =
        Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------
  // Message templates
  // ---------------------------------------------------------------
  static String testMessage(String userName) =>
      'HearAble test: $userName has added you as an emergency contact. '
      'This is only a test. No action is needed.';

  static String emergencyMessage({
    required String userName,
    required String category,
    required String time,
    required bool userAskedForHelp,
  }) =>
      'HEARABLE EMERGENCY ALERT: A possible $category emergency was '
      'detected by $userName at $time. '
      '${userAskedForHelp ? 'The user asked for help.' : 'The user did not confirm that they were safe.'} '
      'Please contact them and check whether assistance is required.';
      static String allClearMessage(String userName) =>
      'HearAble update: $userName has confirmed they are safe. '
      'The earlier emergency alert can be ignored.';
}