import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/monitoring_controller.dart';
import 'core/sound/yamnet_engine.dart';
import 'features/alerts/alert_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Install the real on-device sound detection engine
  final monitor = MonitoringController.instance;
  monitor.engine = YamnetSoundEngine();
  monitor.attachLifecycle();
  AlertCoordinator.instance.start();

  runApp(const HearAbleApp());
}