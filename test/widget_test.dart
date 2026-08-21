// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:musify/localization/app_localizations.dart';
import 'package:musify/models/element_config.dart';
import 'package:musify/models/layout_slot.dart';
import 'package:musify/screens/layout_editor_screen.dart';

void main() {
  testWidgets('Selecting an element shows resize handles in the layout editor', (
    WidgetTester tester,
  ) async {
    const element = ElementConfig(
      id: 'demo_title',
      x: 40,
      y: 60,
      width: 140,
      height: 36,
      actionId: 'SONG_TITLE',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LayoutEditorScreen(
          slot: LayoutSlot(
            slotId: 1,
            slotName: 'Demo',
            elements: [element],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('layout-element-demo_title')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('layout-element-demo_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('layout-resize-handle-demo_title-nw')), findsOneWidget);
    expect(find.byKey(const ValueKey('layout-resize-handle-demo_title-se')), findsOneWidget);
  });
}
