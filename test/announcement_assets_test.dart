import 'package:commicbook/features/notifications/announcement_assets.dart';
import 'package:commicbook/features/notifications/announcement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapping icon thông báo giữ đúng quy tắc từ ComZone Client', () {
    expect(AnnouncementAssets.forType('ORDER_NEW'), AnnouncementAssets.order);
    expect(
      AnnouncementAssets.forType('EXCHANGE_APPROVED'),
      AnnouncementAssets.approve,
    );
    expect(
      AnnouncementAssets.forType('DELIVERY_FAILED_SEND'),
      AnnouncementAssets.reject,
    );
    expect(
      AnnouncementAssets.forType('TRANSACTION_ADD'),
      AnnouncementAssets.walletAdd,
    );
    expect(
      AnnouncementAssets.forType('khong-xac-dinh'),
      AnnouncementAssets.notification,
    );
  });

  testWidgets('thẻ thông báo không tràn trên màn hình mobile', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(12),
            child: AnnouncementCard(
              isRead: false,
              data: {
                'type': 'ORDER_DELIVERY',
                'title': 'Đơn hàng đang được giao đến người nhận',
                'content': 'Đơn hàng đã được bàn giao cho đơn vị vận chuyển.',
                'createdAt': '2026-08-09T10:30:00Z',
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MỚI'), findsOneWidget);
    expect(find.textContaining('10:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
