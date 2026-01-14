// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newbie_android_app/config/config_store.dart';
import 'package:newbie_android_app/main.dart';

void main() {
  testWidgets('App renders main navigation and pages', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final configStore = ConfigStore();
    await configStore.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: configStore,
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('对话'), findsOneWidget);
    expect(find.text('生图'), findsOneWidget);
    expect(find.text('生视频'), findsOneWidget);
    expect(find.text('配置'), findsOneWidget);

    expect(find.text('EP 对话'), findsOneWidget);
  });
}
