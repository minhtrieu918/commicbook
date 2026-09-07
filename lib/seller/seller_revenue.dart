import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();
const _commissionRate = 0.15;

class SellerRevenuePage extends StatelessWidget {
  const SellerRevenuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Bạn cần đăng nhập để xem doanh thu.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _database.sellerOrdersStream(uid),
      builder: (context, snapshot) {
        final delivered = (snapshot.data?.docs ?? []).where((doc) {
          return doc.data()['status'] == 'Đã giao';
        }).toList();
        final now = DateTime.now();
        final monthly = delivered.where((doc) {
          final recognizedAt = _toDate(
            doc.data()['updatedAt'] ?? doc.data()['createdAt'],
          );
          return recognizedAt != null &&
              recognizedAt.year == now.year &&
              recognizedAt.month == now.month;
        }).toList();
        final gross = monthly.fold<num>(
          0,
          (total, doc) => total + (doc.data()['price'] as num? ?? 0),
        );
        final commission = gross * _commissionRate;
        final net = gross - commission;

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const _SellerTitle(
              title: 'DOANH THU',
              subtitle:
                  'Số liệu được tính từ các đơn đã giao trên Cloud Firestore.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _MetricCard(
                  label: 'DOANH THU THÁNG',
                  value: _money(gross),
                  color: mangaGreen,
                ),
                _MetricCard(
                  label: 'PHÍ SÀN (15%)',
                  value: _money(commission),
                  color: mangaRed,
                ),
                _MetricCard(
                  label: 'THỰC NHẬN DỰ KIẾN',
                  value: _money(net),
                  color: mangaNavy,
                ),
                _MetricCard(
                  label: 'ĐƠN ĐÃ GIAO',
                  value: '${monthly.length}',
                  color: mangaYellow,
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
                    'ĐỐI SOÁT ĐƠN ĐÃ GIAO',
                    style: mangaDisplay(size: 22, color: mangaNavy),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.hasError)
                    const NoDataState(compact: true)
                  else if (!snapshot.hasData)
                    const Center(child: CircularProgressIndicator())
                  else if (delivered.isEmpty)
                    const EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Chưa có doanh thu',
                      message:
                          'Doanh thu sẽ được ghi nhận khi đơn hàng chuyển sang Đã giao.',
                      compact: true,
                    )
                  else
                    ...delivered.map((doc) {
                      final data = doc.data();
                      final amount = data['price'] as num? ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['comicTitle'] as String? ??
                                        'Không có tên truyện',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '#${doc.id.substring(0, doc.id.length.clamp(0, 8))} • ${_date(data['updatedAt'] ?? data['createdAt'])}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _money(amount),
                                style: mangaMono(size: 12, color: mangaRed),
                              ),
                            ),
                            _StatusPill(label: 'ĐÃ GIAO', color: mangaGreen),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        );
      },
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
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(value, style: mangaDisplay(size: 23, color: mangaInk)),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w900,
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

DateTime? _toDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _date(dynamic value) {
  final date = _toDate(value);
  if (date == null) return 'Đang cập nhật';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
