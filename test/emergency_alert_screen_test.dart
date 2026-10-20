import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearable/core/sound/sound_categories.dart';
import 'package:hearable/features/alerts/emergency_alert_screen.dart';

/// Opens the screen and records what it returns.
Future<AlertDecision? Function()> openScreen(
  WidgetTester tester, {
  required SoundCategory category,
  int seconds = 30,
  bool allowIgnore = false,
  bool simulated = false,
}) async {
  // Tall, phone-like test screen so every button is visible
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  AlertDecision? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await Navigator.push<AlertDecision>(
            context,
            MaterialPageRoute(
              builder: (_) => EmergencyAlertScreen(
                detection: SoundDetection(
                  category: category,
                  score: 0.9,
                  detectedAt: DateTime(2026, 10, 18, 21, 30),
                  simulated: simulated,
                ),
                countdownSeconds: seconds,
                allowIgnore: allowIgnore,
              ),
            ),
          );
        },
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  // Don't use pumpAndSettle: the pulsing background never "settles"
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return () => result;
}
/// Scrolls to a button, then taps it.
Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}
void main() {
  testWidgets('smoke alarm shows 30 s countdown and no Ignore', (tester) async {
    await openScreen(tester, category: SoundCategory.smokeAlarm);
    expect(find.text('SMOKE OR FIRE ALARM DETECTED'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Ignore'), findsNothing);
  });

  testWidgets("I'm safe returns 'safe'", (tester) async {
    final result = await openScreen(tester, category: SoundCategory.smokeAlarm);
        await tapText(tester, "I'm safe");
    await tester.pump();
    expect(result()?.type, DecisionType.safe);
  });

  testWidgets("I need help returns 'needHelp'", (tester) async {
    final result =
        await openScreen(tester, category: SoundCategory.glassBreaking);
    await tester.tap(find.text('I need help'));
    await tester.pump();
    expect(result()?.type, DecisionType.needHelp);
  });

  testWidgets('no response escalates when the countdown ends', (tester) async {
    final result = await openScreen(tester,
        category: SoundCategory.smokeAlarm, seconds: 30);
    await tester.pump(const Duration(seconds: 15));
    expect(result(), isNull, reason: 'must not escalate early');
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(result()?.type, DecisionType.timeout);
  });

  testWidgets('loud bang offers Ignore with reason and mute', (tester) async {
    final result = await openScreen(tester,
        category: SoundCategory.loudBang, seconds: 60, allowIgnore: true);
    expect(find.text('LOUD BANG DETECTED'), findsOneWidget);

    await tester.tap(find.text('Ignore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Door slammed'));
    await tester.pump();
    await tester.tap(find.text('5 minutes'));
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(result()?.type, DecisionType.ignore);
    expect(result()?.ignoreReason, 'Door slammed');
    expect(result()?.muteMinutes, 5);
  });

  testWidgets('simulated alerts are clearly labelled', (tester) async {
    await openScreen(tester,
        category: SoundCategory.smokeAlarm, simulated: true);
    expect(find.textContaining('SIMULATED TEST'), findsOneWidget);
    expect(find.text('This is a test. Nobody will be contacted.'),
        findsOneWidget);
  });
}