import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetingmind/main.dart';

void main() {
  testWidgets('app boots and shows title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MeetingMindApp()));
    expect(find.text('MeetingMind'), findsOneWidget);
  });
}
