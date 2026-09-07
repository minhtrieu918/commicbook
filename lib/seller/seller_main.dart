import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/seller/seller_create_listing.dart';
import 'package:commicbook/seller/seller_auctions.dart';
import 'package:commicbook/seller/seller_dashboard.dart';
import 'package:commicbook/seller/seller_orders.dart';
import 'package:commicbook/seller/seller_revenue.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class SellerMainPage extends StatefulWidget {
  const SellerMainPage({super.key});

  @override
  State<SellerMainPage> createState() => _SellerMainPageState();
}

class _SellerMainPageState extends State<SellerMainPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const SellerDashboardPage(),
      const SellerOrdersPage(),
      const _SellerInventoryPage(),
      const SellerAuctionsPage(),
      const SellerRevenuePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'SELLER HUB',
          style: mangaDisplay(size: 24, color: mangaYellow),
        ),
      ),
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: _tab == 2
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SellerCreateListingPage(),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('THÊM TRUYỆN'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Kho truyện',
          ),
          NavigationDestination(
            icon: Icon(Icons.gavel_rounded),
            label: 'Đấu giá',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Payout',
          ),
        ],
      ),
    );
  }
}

class _SellerInventoryPage extends StatefulWidget {
  const _SellerInventoryPage();

  @override
  State<_SellerInventoryPage> createState() => _SellerInventoryPageState();
}

class _SellerInventoryPageState extends State<_SellerInventoryPage> {
  Future<void> _makeUnavailable(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ngừng bán truyện?'),
        content: Text(
          'Bạn có chắc muốn ngừng bán “${doc.data()?['title'] ?? 'truyện này'}”?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('NGỪNG BÁN'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _database.makeSellerListingUnavailable(doc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã chuyển truyện sang không khả dụng.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Không thể ngừng bán truyện.')),
      );
    }
  }

  Future<void> _editListing(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final price = TextEditingController(
      text: (data['price'] as num? ?? 0).toString(),
    );
    final stock = TextEditingController(
      text: (data['stock'] as num? ?? 0).toInt().toString(),
    );
    var status = data['status'] as String? ?? 'active';
    if (!const {'active', 'paused', 'unavailable'}.contains(status)) {
      status = 'active';
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Sửa ${data['title'] ?? 'truyện'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá bán'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tồn kho'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Đang bán')),
                  DropdownMenuItem(value: 'paused', child: Text('Tạm ẩn')),
                  DropdownMenuItem(
                    value: 'unavailable',
                    child: Text('Không khả dụng'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => status = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('HỦY'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('LƯU'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) {
      price.dispose();
      stock.dispose();
      return;
    }
    final parsedPrice = num.tryParse(price.text.trim());
    final parsedStock = int.tryParse(stock.text.trim());
    price.dispose();
    stock.dispose();
    if (parsedPrice == null ||
        parsedPrice <= 0 ||
        parsedStock == null ||
        parsedStock < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giá hoặc tồn kho không hợp lệ.')),
      );
      return;
    }

    try {
      await _database.updateSellerListing(
        listingId: doc.id,
        price: parsedPrice,
        stock: parsedStock,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật truyện.')));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không cập nhật được: ${error.message ?? error.code}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Bạn cần đăng nhập để xem kho truyện.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _database.sellerListingsStream(uid),
      builder: (context, snapshot) {
        final docs = [...?snapshot.data?.docs];
        docs.sort((left, right) {
          final leftAt = left.data()['createdAt'] as Timestamp?;
          final rightAt = right.data()['createdAt'] as Timestamp?;
          return (rightAt?.millisecondsSinceEpoch ?? 0).compareTo(
            leftAt?.millisecondsSinceEpoch ?? 0,
          );
        });

        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const _SellerTitle(
              title: 'KHO TRUYỆN',
              subtitle:
                  'Quản lý giá, tồn kho và trạng thái truyện đã được duyệt.',
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              const MangaPanel(shadow: false, child: NoDataState(compact: true))
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (docs.isEmpty)
              const MangaPanel(
                shadow: false,
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Kho truyện đang trống',
                  message: 'Truyện đã được admin duyệt sẽ xuất hiện tại đây.',
                  compact: true,
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final title = (data['title'] as String?) ?? 'Tên truyện';
                final status = (data['status'] as String?) ?? 'Chưa rõ';
                final condition = (data['condition'] as String?) ?? 'Chưa rõ';
                final price = (data['price'] as num?) ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MangaPanel(
                    shadow: false,
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 68,
                          color: mangaSky,
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: mangaNavy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$condition • ${price.toStringAsFixed(0)}đ',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            FilledButton.tonal(
                              onPressed: () => _editListing(doc),
                              child: const Text('SỬA'),
                            ),
                            IconButton(
                              tooltip: 'Ngừng bán',
                              onPressed: status == 'unavailable'
                                  ? null
                                  : () => _makeUnavailable(doc),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
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
