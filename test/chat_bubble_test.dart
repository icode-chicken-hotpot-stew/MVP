import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_app/ui_widgets.dart';

void main() {
  testWidgets('auto calls onNext 8 seconds after line is fully shown', (
    WidgetTester tester,
  ) async {
    int nextCalls = 0;
    const String text = '最后一句会自动消失';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            text: text,
            onNext: () {
              nextCalls += 1;
            },
            onSkip: () {},
          ),
        ),
      ),
    );

    for (int i = 0; i < 50 && find.text(text).evaluate().isEmpty; i += 1) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(find.text(text), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    expect(nextCalls, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(nextCalls, 1);
  });

  testWidgets('does not auto call onNext before text is fully shown', (
    WidgetTester tester,
  ) async {
    int nextCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            text: '这一句不是最后一句',
            onNext: () {
              nextCalls += 1;
            },
            onSkip: () {},
          ),
        ),
      ),
    );

    // 5秒时文字尚未完全展示，不应触发自动 next。
    await tester.pump(const Duration(seconds: 5));

    expect(nextCalls, 0);
  });

  testWidgets('starts auto-next timer after tap-to-complete', (
    WidgetTester tester,
  ) async {
    int nextCalls = 0;
    const String text = '点击后立刻展示完整句子';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            text: text,
            onNext: () {
              nextCalls += 1;
            },
            onSkip: () {},
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
    expect(nextCalls, 0);

    await tester.pump(const Duration(seconds: 1));

    expect(nextCalls, 1);
  });

  testWidgets(
    'resets old timer when dialogue text is interrupted by next line',
    (WidgetTester tester) async {
      int nextCalls = 0;
      String currentText = '第一句';

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return MaterialApp(
              home: Scaffold(
                body: ChatBubble(
                  text: currentText,
                  onNext: () {
                    nextCalls += 1;
                    if (currentText == '第一句') {
                      setState(() {
                        currentText = '第二句被打断后重新计时';
                      });
                    }
                  },
                  onSkip: () {},
                ),
              ),
            );
          },
        ),
      );

      for (int i = 0; i < 50 && find.text('第一句').evaluate().isEmpty; i += 1) {
        await tester.pump(const Duration(milliseconds: 80));
      }

      await tester.pump(const Duration(seconds: 8));
      expect(nextCalls, 1);
      expect(find.text('第二句被打断后重新计时'), findsNothing);

      for (
        int i = 0;
        i < 60 && find.text('第二句被打断后重新计时').evaluate().isEmpty;
        i += 1
      ) {
        await tester.pump(const Duration(milliseconds: 80));
      }

      await tester.pump(const Duration(seconds: 7));
      expect(nextCalls, 1);

      await tester.pump(const Duration(seconds: 1));
      expect(nextCalls, 2);
    },
  );
}
