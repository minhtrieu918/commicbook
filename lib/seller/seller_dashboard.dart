import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/seller/seller_models.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class SellerDashboardPage extends StatelessWidget {
  const SellerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Bạn cần đăng nhập để xem dashboard.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _database.sellerListingsStream(uid),
      builder: (context, listingsSnapshot) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _database.sellerOrdersStream(uid),
            builder: (context, ordersSnapshot) {
              if (listingsSnapshot.hasError || ordersSnapshot.hasError) {
                return const NoDataState();
              }
              if (!listingsSnapshot.hasData || !ordersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final orders = ordersSnapshot.data!.docs
                  .map((doc) => doc.data())
                  .toList();
              final summary = SellerSummary.fromData(
                listings: listingsSnapshot.data!.docs.map((doc) => doc.data()),
                orders: orders,
              );
              final priorities =
                  orders
                      .where(
                        (order) =>
                            order['status'] != 'Đã giao' &&
                            order['status'] != 'Đã hủy',
                      )
                      .map(
                        (order) => SellerPriority.fromOrder(
                          classification:
                              order['classification'] as String? ??
                              'Bình thường',
                          totalPrice: order['price'] as num? ?? 0,
                          status: order['status'] as String? ?? 'Chờ xác nhận',
                        ),
                      )
                      .toList()
                    ..sort((a, b) => a.priority.compareTo(b.priority));

              return ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  const _SellerTitle(
                    title: 'DASHBOARD NGƯỜI BÁN',
                    subtitle:
                        'Theo dõi truyện, đơn hàng và doanh thu trong thời gian thực.',
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _MetricCard(
                        label: 'TRUYỆN ĐANG BÁN',
                        value: '${summary.activeListings}',
                        color: mangaNavy,
                      ),
                      _MetricCard(
                        label: 'ĐƠN CẦN XỬ LÝ',
                        value: '${summary.pendingOrders}',
                        color: mangaYellow,
                      ),
                      _MetricCard(
                        label: 'ĐANG GIAO',
                        value: '${summary.shippingOrders}',
                        color: mangaRed,
                      ),
                      _MetricCard(
                        label: 'DOANH THU ĐÃ GIAO',
                        value: _money(summary.deliveredRevenue),
                        color: mangaGreen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  MangaPanel(
                    shadow: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MỨC ƯU TIÊN XỬ LÝ',
                          style: mangaDisplay(size: 22, color: mangaNavy),
                        ),
                        const SizedBox(height: 12),
                        if (priorities.isEmpty)
                          const EmptyState(
                            icon: Icons.task_alt_rounded,
                            title: 'Không có đơn cần xử lý',
                            message:
                                'Đơn hàng mới của người bán sẽ xuất hiện tại đây.',
                            compact: true,
                          )
                        else
                          ...priorities
                              .take(5)
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: item.level == 'urgent'
                                              ? mangaRed
                                              : item.level == 'high'
                                              ? mangaYellow
                                              : item.level == 'medium'
                                              ? mangaSky
                                              : mangaGreen,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${item.label} • ${item.priority == 1
                                              ? 'Xử lý ngay'
                                              : item.priority == 2
                                              ? 'Xử lý nhanh'
                                              : 'Theo lô'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: MangaPanel(
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            color: color,
            child: const Icon(Icons.bar_chart_rounded, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(value, style: mangaDisplay(size: 25, color: mangaInk)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

class _SellerTitle extends StatelessWidget {
  const _SellerTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: mangaDisplay(size: 28, color: mangaNavy)),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

String _money(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return '$bufferđ';
}
