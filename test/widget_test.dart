import 'package:audiobook_listener/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('style preview renders and toggles play/pause', (tester) async {
    await tester.pumpWidget(const AudiobookApp());

    expect(find.text('Muestra de estilo'), findsOneWidget);

    final play = find.byIcon(Icons.play_arrow_rounded);
    await tester.scrollUntilVisible(play, 200);
    await tester.tap(play);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });
}
