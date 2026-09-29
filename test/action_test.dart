import 'package:flutter_test/flutter_test.dart';
import 'package:stream_deck/models/deck_action.dart';
import 'package:stream_deck/server/windows_action_executor.dart';

void main() {
  test('WindowsActionExecutor test launch app', () async {
    final calc = await WindowsActionExecutor.execute(DeckAction.launchApp('calc'));
    print('calc: $calc');
    expect(calc, isTrue);
  });
}
