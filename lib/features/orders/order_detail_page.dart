import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  static const _steps = ['Chờ xác nhận', 'Đang xử lý', 'Đang giao', 'Đã giao'];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: mangaInk,
      foregroundColor: Colors.white,
      title: Text(
        'CHI TIẾT ĐƠN HÀNG',
        style: mangaDisplay(size: 22, color: mangaYellow),
      ),
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _database.orderStream(orderId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const NoDataState();
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.data!.exists) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Đơn hàng không tồn tại',
            message: 'Đơn hàng có thể đã bị xóa hoặc không còn khả dụng.',
          );
        }

        final data = snapshot.data!.data() ?? {};
        final status = data['status'] as String? ?? 'Chờ xác nhận';
        final stepIndex = _steps.indexOf(status);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                MangaPanel(
                  shadow: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['comicTitle'] as String? ?? 'Không có tên truyện',
                        style: mangaDisplay(size: 26, color: mangaNavy),
                      ),
                      const SizedBox(height: 8),
                      Text('Mã đơn: $orderId', style: mangaMono(size: 11)),
                      const SizedBox(height: 8),
                      Text('Ngày đặt: ${_date(data['createdAt'])}'),
                      Text('Thanh toán: ${data['paymentMethod'] ?? 'Chưa rõ'}'),
                      const SizedBox(height: 14),
                      Text(
                        _money(data['price'] as num? ?? 0),
                        style: mangaMono(size: 20, color: mangaRed),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                MangaPanel(
                  shadow: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRẠNG THÁI ĐƠN HÀNG',
                        style: mangaDisplay(size: 21, color: mangaNavy),
                      ),
                      const SizedBox(height: 16),
                      if (status == 'Đã hủy')
                        const _CancelledState()
                      else
                        ..._steps.indexed.map((entry) {
                          final completed = entry.$1 <= stepIndex;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  completed
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: completed
                                      ? mangaGreen
                                      : Colors.black26,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  entry.$2,
                                  style: TextStyle(
                                    fontWeight: completed
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _CancelledState extends StatelessWidget {
  const _CancelledState();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.cancel_rounded, color: mangaRed),
      SizedBox(width: 10),
      Text('Đơn hàng đã hủy', style: TextStyle(fontWeight: FontWeight.w900)),
    ],
  );
}

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
