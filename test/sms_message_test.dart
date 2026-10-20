import 'package:flutter_test/flutter_test.dart';
import 'package:hearable/core/services/sms_service.dart';

void main() {
  test('timeout message says the user did not confirm they were safe', () {
    final msg = SmsService.emergencyMessage(
      userName: 'Aina',
      category: 'smoke or fire alarm',
      time: '21:30 on 18/10/2026',
      userAskedForHelp: false,
    );
    expect(msg, startsWith('HEARABLE EMERGENCY ALERT'));
    expect(msg, contains('Aina'));
    expect(msg, contains('smoke or fire alarm'));
    expect(msg, contains('21:30 on 18/10/2026'));
    expect(msg, contains('did not confirm that they were safe'));
  });

  test('help message says the user asked for help', () {
    final msg = SmsService.emergencyMessage(
      userName: 'Aina',
      category: 'loud bang',
      time: '10:00 on 18/10/2026',
      userAskedForHelp: true,
    );
    expect(msg, contains('asked for help'));
    expect(msg, isNot(contains('did not confirm')));
  });

  test('all-clear and test messages include the user name', () {
    expect(SmsService.allClearMessage('Aina'), contains('Aina'));
    expect(SmsService.testMessage('Aina'), contains('only a test'));
  });
}