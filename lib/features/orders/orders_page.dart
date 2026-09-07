import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/features/orders/order_detail_page.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Bạn chưa đăng nhập',
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'ĐƠN HÀNG',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _database.ordersOf(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const NoDataState();
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.toList()
            ..sort(
              (a, b) => _millis(
                b.data()['createdAt'],
              ).compareTo(_millis(a.data()['createdAt'])),
            );
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Chưa có đơn hàng',
              message: 'Các đơn đã đặt sẽ xuất hiện tại đây.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return MangaPanel(
                shadow: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: mangaSky,
                    foregroundColor: mangaNavy,
                    child: Icon(Icons.shopping_bag_outlined),
                  ),
                  title: Text(
                    data['comicTitle'] as String? ?? 'Không có tên truyện',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${data['status'] ?? 'Chờ xác nhận'} • ${_date(data['createdAt'])}',
                  ),
                  trailing: Text(
                    _money(data['price'] as num? ?? 0),
                    style: mangaMono(size: 12, color: mangaRed),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailPage(orderId: doc.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

int _millis(dynamic value) =>
    value is Timestamp ? value.millisecondsSinceEpoch : 0;

String _date(dynamic value) {
  if (value is! Timestamp) return 'Đang cập nhật';
  final date = value.toDate();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _money(num value) {
  final digits = value.round().toString();
  final result = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) result.write('.');
    result.write(digits[index]);
  }
  return '$resultđ';
}
