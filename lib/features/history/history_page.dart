import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/service/auth.dart';
import 'package:commicbook/features/orders/order_detail_page.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:flutter/material.dart';

final _auth = AuthService();
final _database = DatabaseService();

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 1,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: mangaNavy,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LỊCH SỬ GIAO DỊCH',
                style: mangaDisplay(size: 36, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const TabBar(
                labelColor: mangaInk,
                unselectedLabelColor: Colors.white,
                indicator: BoxDecoration(color: mangaRed),
                tabs: [Tab(text: 'ĐƠN ĐÃ MUA')],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              _HistoryList(
                stream: _database.ordersOf(_auth.currentUser!.uid),
                isOrder: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.stream, required this.isOrder});

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool isOrder;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const NoDataState();
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final docs = snapshot.data!.docs.toList()
        ..sort((a, b) {
          final aDate = a.data()['createdAt'];
          final bDate = b.data()['createdAt'];
          final aMillis = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
          final bMillis = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
          return bMillis.compareTo(aMillis);
        });

      if (docs.isEmpty) {
        return EmptyState(
          icon: isOrder ? Icons.shopping_bag_outlined : Icons.sell_outlined,
          title: isOrder
              ? 'Bạn chưa mua truyện nào'
              : 'Bạn chưa gửi yêu cầu bán',
          message: isOrder
              ? 'Các đơn đã đặt sẽ xuất hiện tại đây.'
              : 'Yêu cầu đã gửi sẽ xuất hiện tại đây sau khi được tạo.',
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final data = docs[index].data();
          final status =
              data['status'] as String? ??
              (isOrder ? 'Chờ xác nhận' : 'Chờ duyệt');
          final statusColor = switch (status) {
            'Đã giao' || 'Đã duyệt' || 'Đã thanh toán' => mangaGreen,
            'Đã hủy' || 'Từ chối' => mangaRed,
            'Đang giao' => mangaNavy,
            'Đang xử lý' => const Color(0xFF8B5FBF),
            _ => Colors.orange.shade800,
          };

          return InkWell(
            onTap: isOrder
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailPage(orderId: docs[index].id),
                    ),
                  )
                : null,
            child: MangaPanel(
              shadow: false,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    color: isOrder ? mangaNavy : mangaYellow,
                    child: Icon(
                      isOrder ? Icons.shopping_bag_rounded : Icons.sell_rounded,
                      color: isOrder ? Colors.white : mangaInk,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (isOrder ? data['comicTitle'] : data['title'])
                                  as String? ??
                              'Không có tên',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${isOrder ? data['paymentMethod'] ?? '' : data['author'] ?? ''} • ${_date(data['createdAt'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(data['price'] as num? ?? 0),
                        style: mangaMono(size: 13, color: mangaRed),
                      ),
                      SizedBox(
                        width: 112,
                        child: Text(
                          status.toUpperCase(),
                          maxLines: 2,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

String _money(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '$bufferđ';
}

String _date(dynamic value) {
  if (value is! Timestamp) return 'Đang cập nhật';
  final date = value.toDate();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
