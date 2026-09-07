import 'package:commicbook/admin/admin_order_rules.dart';
import 'package:commicbook/core/models.dart';
import 'package:commicbook/features/catalog/comic_detail_page.dart';
import 'package:commicbook/seller/seller_models.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EmptyState hiển thị icon và nội dung khi không có dữ liệu', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Không có dữ liệu',
            message: 'Dữ liệu mới sẽ xuất hiện tại đây.',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('KHÔNG CÓ DỮ LIỆU'), findsOneWidget);
    expect(find.text('Dữ liệu mới sẽ xuất hiện tại đây.'), findsOneWidget);
  });

  testWidgets('NoDataState không hiển thị lỗi kỹ thuật backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NoDataState())),
    );

    expect(find.text('KHÔNG CÓ DỮ LIỆU'), findsOneWidget);
    expect(find.text('Hiện chưa có dữ liệu để hiển thị.'), findsOneWidget);
    expect(find.textContaining('cloud_firestore'), findsNothing);
    expect(find.textContaining('console.firebase.google.com'), findsNothing);
  });

  test('ComicItem lưu đúng thông tin truyện', () {
    const comic = ComicItem(
      id: 'test-1',
      title: 'Truyện mẫu',
      author: 'Tác giả mẫu',
      price: 25000,
      color: Color(0xFF5B35A8),
    );

    expect(comic.title, 'Truyện mẫu');
    expect(comic.price, 25000);
  });

  testWidgets('Comic detail thêm truyện còn hàng vào giỏ', (tester) async {
    const comic = ComicItem(
      id: 'comic-detail-1',
      title: 'Truyện chi tiết',
      author: 'Tác giả',
      price: 50000,
      color: Color(0xFF5B35A8),
      stock: 2,
    );
    ComicItem? added;

    await tester.pumpWidget(
      MaterialApp(
        home: ComicDetailPage(comic: comic, onAdd: (value) => added = value),
      ),
    );
    await tester.tap(find.text('THÊM VÀO GIỎ'));
    await tester.pump();

    expect(added?.id, comic.id);
  });

  test('Phân loại đơn hàng theo genre, điều kiện và giá trị', () {
    expect(
      classifyOrder({
        'genre': 'Dark Fantasy',
        'condition': 'Hiếm',
        'price': 240000,
      }),
      'Hiếm',
    );

    expect(
      classifyOrder({'genre': 'Shounen', 'condition': 'Mới', 'price': 120000}),
      'Bán chạy',
    );

    expect(
      classifyOrder({
        'genre': 'Slice of Life',
        'condition': 'Khá',
        'price': 45000,
      }),
      'Bình thường',
    );
  });

  test('Nhóm đơn hàng theo quy tắc phân loại để xử lý đồng loạt', () {
    final grouped = groupOrdersByClassification([
      {
        'id': '1',
        'genre': 'Dark Fantasy',
        'condition': 'Hiếm',
        'price': 240000,
      },
      {'id': '2', 'genre': 'Shounen', 'condition': 'Mới', 'price': 120000},
      {'id': '3', 'genre': 'Slice of Life', 'condition': 'Khá', 'price': 45000},
    ]);

    expect(grouped['Hiếm']?.length, 1);
    expect(grouped['Bán chạy']?.length, 1);
    expect(grouped['Bình thường']?.length, 1);
  });

  test('Đơn hàng của người bán luôn có mức ưu tiên xử lý rõ ràng', () {
    final rare = SellerPriority.fromOrder(
      classification: 'Hiếm',
      totalPrice: 240000,
      status: 'Chờ xác nhận',
    );
    final hot = SellerPriority.fromOrder(
      classification: 'Bán chạy',
      totalPrice: 120000,
      status: 'Đang giao',
    );

    expect(rare.level, 'urgent');
    expect(hot.level, 'high');
  });

  test('Seller dashboard tổng hợp dữ liệu thật theo trạng thái', () {
    final summary = SellerSummary.fromData(
      listings: [
        {'status': 'active', 'stock': 3},
        {'status': 'active', 'stock': 0},
        {'status': 'paused', 'stock': 5},
      ],
      orders: [
        {'status': 'Chờ xác nhận', 'price': 50000},
        {'status': 'Đang xử lý', 'price': 60000},
        {'status': 'Đang giao', 'price': 70000},
        {'status': 'Đã giao', 'price': 120000},
        {'status': 'Đã hủy', 'price': 999999},
      ],
    );

    expect(summary.activeListings, 1);
    expect(summary.pendingOrders, 2);
    expect(summary.shippingOrders, 1);
    expect(summary.deliveredRevenue, 120000);
  });
}
