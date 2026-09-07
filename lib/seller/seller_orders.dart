import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/seller/seller_models.dart';
import 'package:commicbook/seller/seller_order_detail.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> {
  static const _statuses = [
    'Chờ xác nhận',
    'Đang xử lý',
    'Đang giao',
    'Đã giao',
    'Đã hủy',
  ];

  String _filter = 'Tất cả';
  String? _updatingId;

  Future<void> _changeStatus(String orderId, String status) async {
    setState(() => _updatingId = orderId);
    try {
      await _database.updateSellerOrderStatus(orderId: orderId, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã cập nhật đơn hàng: $status.')));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không cập nhật được: ${error.message ?? error.code}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Bạn cần đăng nhập để xem đơn hàng.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _database.sellerOrdersStream(uid),
      builder: (context, snapshot) {
        final orders = (snapshot.data?.docs ?? []).where((doc) {
          final status = doc.data()['status'] as String? ?? 'Chờ xác nhận';
          return _filter == 'Tất cả' || status == _filter;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const _SellerTitle(
              title: 'QUẢN LÝ ĐƠN HÀNG',
              subtitle:
                  'Xác nhận, đóng gói, giao và cập nhật trạng thái cho từng đơn.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['Tất cả', ..._statuses]
                  .map(
                    (label) => ChoiceChip(
                      label: Text(label),
                      selected: _filter == label,
                      onSelected: (_) => setState(() => _filter = label),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              const NoDataState(compact: true)
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (orders.isEmpty)
              const MangaPanel(
                shadow: false,
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Không có đơn hàng',
                  message: 'Chưa có đơn hàng phù hợp với bộ lọc đã chọn.',
                  compact: true,
                ),
              )
            else
              ...orders.map((doc) {
                final data = doc.data();
                final status = data['status'] as String? ?? 'Chờ xác nhận';
                final classification =
                    data['classification'] as String? ?? 'Bình thường';
                final price = data['price'] as num? ?? 0;
                final priority = SellerPriority.fromOrder(
                  classification: classification,
                  totalPrice: price,
                  status: status,
                );
                final order = <String, dynamic>{
                  ...data,
                  'id': doc.id,
                  'comic': data['comicTitle'] ?? 'Không có tên truyện',
                  'customer': data['buyerEmail'] ?? 'Không rõ khách hàng',
                };

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MangaPanel(
                    shadow: false,
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SellerOrderDetailPage(order: order),
                            ),
                          ),
                          child: Container(
                            width: 52,
                            height: 58,
                            color: mangaSky,
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: mangaNavy,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 310,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order['comic'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                order['customer'] as String,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                '#${doc.id.substring(0, doc.id.length.clamp(0, 8))}',
                                style: mangaMono(size: 10),
                              ),
                            ],
                          ),
                        ),
                        _StatusPill(
                          text: classification.toUpperCase(),
                          color: priority.level == 'urgent'
                              ? mangaRed
                              : priority.level == 'high'
                              ? mangaYellow
                              : mangaSky,
                        ),
                        Text(
                          _money(price),
                          style: mangaMono(size: 13, color: mangaRed),
                        ),
                        DropdownButton<String>(
                          value: status,
                          items: <String>{status, ..._statuses}
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: _updatingId == doc.id
                              ? null
                              : (value) {
                                  if (value != null && value != status) {
                                    _changeStatus(doc.id, value);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
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

String _money(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return '$bufferđ';
}
