import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_app/ui_widgets.dart';

void main() {
  testWidgets('auto dismisses 8 seconds after final line is fully shown', (
    WidgetTester tester,
  ) async {
    int autoDismissCalls = 0;
    const String text = '最后一句会自动消失';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            text: text,
            isLastLine: true,
            onNext: () {},
            onSkip: () {},
            onAutoDismiss: () {
              autoDismissCalls += 1;
            },
          ),
        ),
      ),
    );

    for (int i = 0; i < 50 && find.text(text).evaluate().isEmpty; i += 1) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text(text), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    expect(autoDismissCalls, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(autoDismissCalls, 1);
  });

  testWidgets('does not auto dismiss when not on final line', (
    WidgetTester tester,
  ) async {
    int autoDismissCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            text: '这一句不是最后一句',
            isLastLine: false,
            onNext: () {},
            onSkip: () {},
            onAutoDismiss: () {
              autoDismissCalls += 1;
            },
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 12));

    expect(autoDismissCalls, 0);
  });

  testWidgets('starts auto-dismiss timer after tap-to-complete on final line', (
    WidgetTester tester,
  ) async {
    int autoDismissCalls = 0;
    const String text = '点击后立刻展示完整句子';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            text: text,
            isLastLine: true,
            onNext: () {},
            onSkip: () {},
            onAutoDismiss: () {
              autoDismissCalls += 1;
            },
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text(text), findsNothing);

    final Finder bubbleTapFinder = find.byWidgetPredicate(
      (Widget widget) =>
          widget is GestureDetector &&
          widget.behavior == HitTestBehavior.opaque &&
          widget.onTap != null,
      description: 'chat bubble tap detector',
    );
    final GestureDetector bubbleTapDetector = tester.widget<GestureDetector>(
      bubbleTapFinder,
    );
    bubbleTapDetector.onTap!.call();

    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    expect(autoDismissCalls, 0);

    await tester.pump(const Duration(seconds: 1));

    expect(autoDismissCalls, 1);
  });
}
