import 'package:commicbook/seller/seller_models.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class SellerOrderDetailPage extends StatefulWidget {
  const SellerOrderDetailPage({super.key, required this.order});

  final Map<String, dynamic> order;

  @override
  State<SellerOrderDetailPage> createState() => _SellerOrderDetailPageState();
}

class _SellerOrderDetailPageState extends State<SellerOrderDetailPage> {
  late String _status = widget.order['status'] as String? ?? 'Chờ xác nhận';
  bool _loading = false;

  Future<void> _updateStatus(String status) async {
    final orderId = widget.order['id'] as String?;
    if (orderId == null || orderId.isEmpty || _loading) return;

    setState(() => _loading = true);
    try {
      await _database.updateSellerOrderStatus(orderId: orderId, status: status);
      if (!mounted) return;
      setState(() => _status = status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật trạng thái: $status')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật đơn hàng: $error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final classification = order['classification'] as String? ?? 'Bình thường';
    final priority = SellerPriority.fromOrder(
      classification: classification,
      totalPrice: (order['price'] as num?) ?? 0,
      status: _status,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'CHI TIẾT ĐƠN HÀNG',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          MangaPanel(
            shadow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order['comic'] as String? ?? 'Tên truyện',
                        style: mangaDisplay(size: 24, color: mangaNavy),
                      ),
                    ),
                    _StatusPill(
                      text: _status.toUpperCase(),
                      color: _status == 'Đã giao'
                          ? mangaGreen
                          : _status == 'Đang giao'
                          ? mangaNavy
                          : _status == 'Đã hủy'
                          ? mangaRed
                          : mangaYellow,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Khách hàng: ${order['customer'] ?? 'Không rõ'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mã đơn: ${order['id'] ?? ''}',
                  style: mangaMono(size: 11),
                ),
                const SizedBox(height: 8),
                Text(
                  'Phân loại: $classification • Mức ưu tiên: ${priority.label}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
                  'THÔNG TIN THANH TOÁN',
                  style: mangaDisplay(size: 20, color: mangaNavy),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tổng tiền: ${(order['price'] as num? ?? 0).toString()}đ',
                  style: mangaMono(size: 14, color: mangaRed),
                ),
                const SizedBox(height: 6),
                Text(
                  'Phương thức: ${order['paymentMethod'] ?? 'Chưa rõ'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Vận chuyển: Giao tiêu chuẩn',
                  style: TextStyle(fontWeight: FontWeight.w700),
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
                  'CẬP NHẬT TRẠNG THÁI',
                  style: mangaDisplay(size: 20, color: mangaNavy),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickStatusChip(
                      label: 'Xác nhận',
                      color: mangaGreen,
                      onTap: _loading
                          ? null
                          : () => _updateStatus('Đang xử lý'),
                    ),
                    _QuickStatusChip(
                      label: 'Giao hàng',
                      color: mangaNavy,
                      onTap: _loading ? null : () => _updateStatus('Đang giao'),
                    ),
                    _QuickStatusChip(
                      label: 'Hoàn tất',
                      color: mangaRed,
                      onTap: _loading ? null : () => _updateStatus('Đã giao'),
                    ),
                    _QuickStatusChip(
                      label: 'Hủy đơn',
                      color: Colors.black54,
                      onTap: _loading ? null : () => _updateStatus('Đã hủy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatusChip extends StatelessWidget {
  const _QuickStatusChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
