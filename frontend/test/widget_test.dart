import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhatro_frontend/main.dart';

void main() {
  testWidgets('NhaTroManagerApp SaaS Dashboard smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NhaTroManagerApp());
    await tester.pumpAndSettle();

    expect(find.text('NHÀ TRỌ MANAGER'), findsOneWidget);
    expect(find.text('Tổng quan'), findsWidgets);
    expect(find.text('Theo dõi tình hình hoạt động nhà trọ của bạn.'), findsOneWidget);
  });
}
