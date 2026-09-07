import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:commicbook/admin/admin_order_rules.dart';
import 'package:commicbook/admin/admin_password_dialog.dart';
import 'package:commicbook/features/auctions/auction_detail_page.dart';
import 'package:commicbook/features/auctions/auction_rules.dart';
import 'package:commicbook/service/admin_auth.dart';
import 'package:commicbook/service/auction_service.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Toàn bộ giao diện và nghiệp vụ dành riêng cho quản trị viên.
class AdminHubPage extends StatefulWidget {
  const AdminHubPage({super.key, this.canConfigure = true});

  final bool canConfigure;

  @override
  State<AdminHubPage> createState() => _AdminHubPageState();
}

class _AdminHubPageState extends State<AdminHubPage> {
  int _section = 0;

  static const _allItems = <(String, IconData, int)>[
    ('Tổng quan', Icons.dashboard_outlined, 0),
    ('Đơn hàng', Icons.local_shipping_outlined, 1),
    ('Tin đăng', Icons.fact_check_outlined, 2),
    ('Đấu giá', Icons.gavel_outlined, 3),
    ('Phản hồi', Icons.reviews_outlined, 4),
    ('Ví', Icons.account_balance_wallet_outlined, 5),
    ('Duyệt Seller', Icons.how_to_reg_outlined, 6),
    ('Người dùng', Icons.people_outline, 7),
    ('Danh mục', Icons.category_outlined, 8),
    ('Cài đặt', Icons.settings_outlined, 9),
  ];

  List<(String, IconData, int)> get _items => widget.canConfigure
      ? _allItems
      : _allItems
            .where((item) => item.$3 <= 5 || item.$3 == 7)
            .toList(growable: false);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final page = switch (_section) {
        0 => const _AdminDashboard(),
        1 => const _AdminOrdersPage(),
        2 => const _AdminListingsPage(),
        3 => const _AdminAuctionsPage(),
        4 => const _AdminFeedbackPage(),
        5 => const _AdminWalletRequestsPage(),
        6 => const _AdminSellerRegistrationsPage(),
        7 => _AdminUsersPage(canChangeRole: widget.canConfigure),
        8 => const _AdminCatalogOptionsPage(),
        _ => const _AdminSettingsPage(),
      };
      if (constraints.maxWidth < 880) {
        return Column(
          children: [
            Container(
              height: 62,
              color: mangaNavy,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _items.length,
                itemBuilder: (context, index) => TextButton.icon(
                  onPressed: () => setState(() => _section = _items[index].$3),
                  icon: Icon(
                    _items[index].$2,
                    color: _section == _items[index].$3
                        ? mangaYellow
                        : Colors.white70,
                  ),
                  label: Text(
                    _items[index].$1.toUpperCase(),
                    style: TextStyle(
                      color: _section == _items[index].$3
                          ? mangaYellow
                          : Colors.white70,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: page),
          ],
        );
      }
      return Row(
        children: [
          _AdminSidebar(
            items: _items,
            selected: _section,
            onSelected: (value) => setState(() => _section = value),
          ),
          Expanded(child: page),
        ],
      );
    },
  );
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<(String, IconData, int)> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: 250,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [mangaNavy, Color(0xFF684B9B)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MANGA MART',
                style: mangaDisplay(size: 25, color: mangaYellow),
              ),
              const Text(
                'TRANG QUẢN TRỊ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: mangaYellow,
            foregroundColor: mangaInk,
            child: Icon(Icons.admin_panel_settings),
          ),
          title: const Text(
            'Quản trị viên',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            FirebaseAuth.instance.currentUser?.email ?? 'Admin',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          final active = selected == item.$3;
          return InkWell(
            onTap: () => onSelected(item.$3),
            child: Container(
              color: active ? Colors.white.withValues(alpha: .16) : null,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    item.$2,
                    size: 20,
                    color: active ? mangaYellow : Colors.white70,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.$1.toUpperCase(),
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const Spacer(),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            '管理 • MANGA MART ADMIN',
            style: TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ),
      ],
    ),
  );
}

class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const _AdminTitle(
        title: 'TỔNG QUAN',
        subtitle: 'Theo dõi hoạt động cửa hàng theo thời gian thực.',
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _StreamKpi(
            label: 'ĐƠN ĐẶT MUA',
            icon: Icons.shopping_bag_outlined,
            color: mangaRed,
            stream: _database.ordersStream(),
          ),
          _StreamKpi(
            label: 'TIN ĐĂNG',
            icon: Icons.menu_book_outlined,
            color: mangaNavy,
            stream: _database.sellRequestsStream(),
          ),
          _StreamKpi(
            label: 'THÀNH VIÊN',
            icon: Icons.people_outline,
            color: mangaGreen,
            stream: _database.usersStream(),
          ),
        ],
      ),
      const SizedBox(height: 22),
      MangaPanel(
        color: const Color(0xFFFFF0F4),
        shadow: false,
        child: Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, color: mangaRed, size: 42),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('XIN CHÀO ADMIN', style: mangaDisplay(size: 23)),
                  const Text(
                    'Đơn hàng mới và yêu cầu đăng bán sẽ tự động cập nhật từ Firebase.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _StreamKpi extends StatelessWidget {
  const _StreamKpi({
    required this.label,
    required this.icon,
    required this.color,
    required this.stream,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 225,
    child: MangaPanel(
      shadow: false,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) => Row(
          children: [
            Container(
              width: 48,
              height: 48,
              color: color,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${snapshot.data?.docs.length ?? 0}',
                  style: mangaDisplay(size: 27),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AdminOrdersPage extends StatefulWidget {
  const _AdminOrdersPage();

  @override
  State<_AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<_AdminOrdersPage> {
  final _search = TextEditingController();
  String _filter = 'Tất cả';
  String _bulkStatus = 'Đang xử lý';
  final Set<String> _selectedOrderIds = <String>{};

  static const _statuses = [
    'Chờ xác nhận',
    'Đang xử lý',
    'Đang giao',
    'Đã giao',
    'Đã hủy',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _changeStatus(String id, String status) async {
    try {
      await _database.updateOrderStatus(orderId: id, status: status);
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
    }
  }

  Future<void> _bulkUpdateStatus(String status) async {
    final ids = _selectedOrderIds.toList();
    if (ids.isEmpty) return;

    try {
      await _database.bulkUpdateOrderStatus(orderIds: ids, status: status);
      if (!mounted) return;
      _selectedOrderIds.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật $ids đơn hàng: $status.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không cập nhật hàng loạt: ${error.message ?? error.code}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _database.ordersStream(),
    builder: (context, snapshot) {
      final query = _search.text.trim().toLowerCase();
      final orders = (snapshot.data?.docs ?? []).where((doc) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'Chờ xác nhận';
        final haystack =
            '${data['comicTitle'] ?? ''} ${data['buyerEmail'] ?? ''} ${doc.id}'
                .toLowerCase();
        return (_filter == 'Tất cả' || status == _filter) &&
            (query.isEmpty || haystack.contains(query));
      }).toList();
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const _AdminTitle(
            title: 'QUẢN LÝ ĐƠN HÀNG',
            subtitle: 'Xác nhận, xử lý và theo dõi các đơn truyện đã đặt mua.',
          ),
          const SizedBox(height: 18),
          const _OrderProcessingDiagram(),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Tìm tên truyện, email hoặc mã đơn...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _filter,
                items: ['Tất cả', ..._statuses]
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _filter = value);
                },
              ),
              _StatusPill(text: '${orders.length} ĐƠN', color: mangaSakura),
            ],
          ),
          if (_selectedOrderIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            MangaPanel(
              shadow: false,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusPill(
                    text: '${_selectedOrderIds.length} ĐÃ CHỌN',
                    color: mangaYellow,
                  ),
                  DropdownButton<String>(
                    value: _bulkStatus,
                    items: _statuses
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _bulkStatus = value);
                    },
                  ),
                  FilledButton.icon(
                    onPressed: () => _bulkUpdateStatus(_bulkStatus),
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('CẬP NHẬT HÀNG LOẠT'),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedOrderIds.clear()),
                    icon: const Icon(Icons.clear_all_rounded),
                    label: const Text('BỎ CHỌN'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (snapshot.hasError)
            const NoDataState(compact: true)
          else if (!snapshot.hasData)
            const Center(child: CircularProgressIndicator())
          else if (orders.isEmpty)
            const _EmptyPanel(
              icon: Icons.inbox_outlined,
              text: 'KHÔNG CÓ ĐƠN HÀNG',
            )
          else
            ...orders.map((doc) {
              final data = doc.data();
              final status = data['status'] as String? ?? 'Chờ xác nhận';
              final classify =
                  (data['classification'] as String? ??
                          classifyOrder({
                            'genre': data['genre'] ?? '',
                            'condition': data['condition'] ?? '',
                            'price': data['price'] ?? 0,
                          }))
                      .toString();
              final options = <String>{status, ..._statuses}.toList();
              final selected = _selectedOrderIds.contains(doc.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MangaPanel(
                  shadow: false,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Checkbox(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedOrderIds.add(doc.id);
                            } else {
                              _selectedOrderIds.remove(doc.id);
                            }
                          });
                        },
                      ),
                      Container(
                        width: 52,
                        height: 58,
                        color: mangaSky,
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: mangaNavy,
                        ),
                      ),
                      SizedBox(
                        width: 300,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['comicTitle'] as String? ??
                                  'Không có tên truyện',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              data['buyerEmail'] as String? ?? 'Khách hàng cũ',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              '#${doc.id.substring(0, doc.id.length.clamp(0, 8))} • ${_date(data['createdAt'])}',
                              style: mangaMono(size: 9),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 155,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _money(data['price'] as num? ?? 0),
                              style: mangaMono(color: mangaRed),
                            ),
                            Text(
                              data['paymentMethod'] as String? ??
                                  'Chưa rõ phương thức',
                              style: const TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(
                        text: status.toUpperCase(),
                        color: _statusColor(status),
                      ),
                      _StatusPill(
                        text: classify.toUpperCase(),
                        color: switch (classify) {
                          'Hiếm' => mangaRed,
                          'Bán chạy' => mangaGreen,
                          _ => mangaSky,
                        },
                      ),
                      DropdownButton<String>(
                        value: status,
                        items: options
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
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

class _OrderProcessingDiagram extends StatelessWidget {
  const _OrderProcessingDiagram();

  static const _steps = [
    ('ĐƠN MỚI', Icons.receipt_long_outlined, mangaSky),
    ('PHÂN LOẠI', Icons.category_outlined, mangaYellow),
    ('GOM NHÓM', Icons.groups_2_outlined, mangaRed),
    ('XỬ LÝ', Icons.done_all_rounded, mangaGreen),
  ];

  @override
  Widget build(BuildContext context) => MangaPanel(
    shadow: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SƠ ĐỒ QUY TRÌNH XỬ LÝ ĐƠN HÀNG',
          style: mangaDisplay(size: 19, color: mangaNavy),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var index = 0; index < _steps.length; index++) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _steps[index].$3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_steps[index].$2, color: mangaInk),
                    const SizedBox(width: 8),
                    Text(
                      _steps[index].$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: mangaInk,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < _steps.length - 1)
                const Icon(Icons.arrow_forward_rounded, color: mangaNavy),
            ],
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Rule: Hiếm ưu tiên xử lý trước • Bán chạy gom nhóm nhanh • Bình thường xử lý theo lô.',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
      ],
    ),
  );
}

class _AdminListingsPage extends StatefulWidget {
  const _AdminListingsPage();

  @override
  State<_AdminListingsPage> createState() => _AdminListingsPageState();
}

class _AdminListingsPageState extends State<_AdminListingsPage> {
  String _filter = 'Tất cả';

  Future<void> _review(
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool approve,
  ) async {
    final data = doc.data() ?? {};
    try {
      if (approve) {
        await _database.approveSellRequest(
          requestId: doc.id,
          title: data['title'] as String? ?? 'Không có tên',
          author: data['author'] as String? ?? 'Không rõ tác giả',
          price: data['price'] as num? ?? 0,
          description: data['description'] as String? ?? '',
          sellerUid: data['userId'] as String? ?? '',
          genre: data['genre'] as String? ?? 'Chưa rõ',
          condition: data['condition'] as String? ?? 'Chưa rõ',
          stock: (data['stock'] as num?)?.toInt() ?? 1,
          metadata: {
            'image': data['image'] ?? '',
            'publisher': data['publisher'] ?? '',
            'publicationYear': data['publicationYear'],
            'originCountry': data['originCountry'] ?? '',
            'pageCount': data['pageCount'],
            'cover': data['cover'] ?? '',
            'colorType': data['colorType'] ?? '',
            'edition': data['edition'] ?? '',
          },
        );
      } else {
        await _database.rejectSellRequest(requestId: doc.id);
      }
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể kiểm duyệt: ${error.message ?? error.code}'),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _database.sellRequestsStream(),
    builder: (context, snapshot) {
      final docs = (snapshot.data?.docs ?? []).where((doc) {
        final status = doc.data()['status'] as String? ?? 'Chờ duyệt';
        return _filter == 'Tất cả' || status == _filter;
      }).toList();
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const _AdminTitle(
            title: 'QUẢN LÝ TIN ĐĂNG',
            subtitle: 'Kiểm duyệt truyện do thành viên gửi bán.',
          ),
          const SizedBox(height: 16),
          DropdownButton<String>(
            value: _filter,
            items: const ['Tất cả', 'Chờ duyệt', 'Đã duyệt', 'Từ chối']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _filter = value);
            },
          ),
          const SizedBox(height: 14),
          if (snapshot.hasError)
            const NoDataState(compact: true)
          else if (!snapshot.hasData)
            const Center(child: CircularProgressIndicator())
          else if (docs.isEmpty)
            const _EmptyPanel(
              icon: Icons.fact_check_outlined,
              text: 'KHÔNG CÓ TIN ĐĂNG',
            )
          else
            ...docs.map((doc) {
              final data = doc.data();
              final status = data['status'] as String? ?? 'Chờ duyệt';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MangaPanel(
                  shadow: false,
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 380,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'] as String? ?? 'Không có tên',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${data['author'] ?? 'Không rõ tác giả'} • ${_money(data['price'] as num? ?? 0)}',
                            ),
                            Text(
                              data['description'] as String? ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(
                        text: status.toUpperCase(),
                        color: _statusColor(status),
                      ),
                      if (status == 'Chờ duyệt') ...[
                        FilledButton.icon(
                          onPressed: () => _review(doc, true),
                          icon: const Icon(Icons.check),
                          label: const Text('DUYỆT'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _review(doc, false),
                          icon: const Icon(Icons.close),
                          label: const Text('TỪ CHỐI'),
                        ),
                      ],
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

class _AdminSellerRegistrationsPage extends StatefulWidget {
  const _AdminSellerRegistrationsPage();

  @override
  State<_AdminSellerRegistrationsPage> createState() =>
      _AdminSellerRegistrationsPageState();
}

class _AdminSellerRegistrationsPageState
    extends State<_AdminSellerRegistrationsPage> {
  String _filter = 'pending';
  String? _reviewingUid;

  Future<String?> _rejectionReason(String name) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Từ chối yêu cầu của $name'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Lý do từ chối',
            hintText: 'Nêu rõ thông tin cần bổ sung hoặc chỉnh sửa',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('HỦY'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('TỪ CHỐI'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _review(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool approved,
  }) async {
    final reviewerUid = FirebaseAuth.instance.currentUser?.uid;
    if (reviewerUid == null) return;
    final data = doc.data() ?? {};
    final name = data['fullName'] as String? ?? 'người dùng';
    final reason = approved ? '' : await _rejectionReason(name);
    if (!approved && reason == null) return;

    setState(() => _reviewingUid = doc.id);
    try {
      await _database.reviewSellerRegistration(
        uid: doc.id,
        reviewerUid: reviewerUid,
        approved: approved,
        rejectionReason: reason ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Đã duyệt quyền Seller cho $name.'
                : 'Đã từ chối yêu cầu của $name.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể duyệt Seller: ${error.message ?? error.code}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _reviewingUid = null);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _database.sellerRegistrationRequestsStream(),
    builder: (context, snapshot) {
      final docs = (snapshot.data?.docs ?? []).where((doc) {
        final status = doc.data()['status'] as String? ?? 'pending';
        return _filter == 'all' || status == _filter;
      }).toList();
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const _AdminTitle(
            title: 'DUYỆT ĐĂNG KÝ SELLER',
            subtitle:
                'Kiểm tra hồ sơ trước khi cấp quyền tạo truyện và quản lý kho.',
          ),
          const SizedBox(height: 16),
          DropdownButton<String>(
            value: _filter,
            items: const [
              DropdownMenuItem(value: 'pending', child: Text('CHỜ DUYỆT')),
              DropdownMenuItem(value: 'approved', child: Text('ĐÃ DUYỆT')),
              DropdownMenuItem(value: 'rejected', child: Text('TỪ CHỐI')),
              DropdownMenuItem(value: 'all', child: Text('TẤT CẢ')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _filter = value);
            },
          ),
          const SizedBox(height: 14),
          if (snapshot.hasError)
            const NoDataState(compact: true)
          else if (!snapshot.hasData)
            const Center(child: CircularProgressIndicator())
          else if (docs.isEmpty)
            const _EmptyPanel(
              icon: Icons.how_to_reg_outlined,
              text: 'KHÔNG CÓ YÊU CẦU SELLER',
            )
          else
            ...docs.map((doc) {
              final data = doc.data();
              final status = data['status'] as String? ?? 'pending';
              final isReviewing = _reviewingUid == doc.id;
              final statusText = switch (status) {
                'approved' => 'ĐÃ DUYỆT',
                'rejected' => 'TỪ CHỐI',
                _ => 'CHỜ DUYỆT',
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MangaPanel(
                  shadow: false,
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 430,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['fullName'] as String? ?? 'Người dùng',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${data['businessName'] ?? 'Cá nhân'} • ${data['phone'] ?? ''}',
                            ),
                            Text(
                              '${data['address'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              'Tài khoản nhận tiền: ${data['bankAccount'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              'Xác minh: ${data['verificationDocument'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            if (status == 'rejected' &&
                                '${data['rejectionReason'] ?? ''}'.isNotEmpty)
                              Text(
                                'Lý do: ${data['rejectionReason']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: mangaRed,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _StatusPill(
                        text: statusText,
                        color: status == 'approved'
                            ? mangaGreen
                            : status == 'rejected'
                            ? mangaRed
                            : mangaYellow,
                      ),
                      if (status == 'pending') ...[
                        FilledButton.icon(
                          onPressed: isReviewing
                              ? null
                              : () => _review(doc, approved: true),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('DUYỆT SELLER'),
                        ),
                        OutlinedButton.icon(
                          onPressed: isReviewing
                              ? null
                              : () => _review(doc, approved: false),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('TỪ CHỐI'),
                        ),
                      ],
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

class _AdminUsersPage extends StatefulWidget {
  const _AdminUsersPage({required this.canChangeRole});

  final bool canChangeRole;

  @override
  State<_AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<_AdminUsersPage> {
  String? _updatingUid;
  String? _settingPasswordUid;

  Future<void> _changeRole(String uid, String role) async {
    setState(() => _updatingUid = uid);
    try {
      await _database.updateUserRole(uid: uid, role: role);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã cập nhật vai trò: $role.')));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không cập nhật được: ${error.message ?? error.code}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingUid = null);
    }
  }

  Future<void> _setPassword(String uid, String name) async {
    final newPassword = await showAdminPasswordDialog(
      context,
      accountName: name,
    );
    if (newPassword == null || !mounted) return;

    setState(() => _settingPasswordUid = uid);
    try {
      await _adminAuth.setUserPassword(
        targetUid: uid,
        newPassword: newPassword,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã đặt mật khẩu mới cho $name.')));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'permission-denied' =>
          'Chỉ quản trị viên mới được đặt mật khẩu người dùng.',
        'not-found' => 'Không tìm thấy tài khoản xác thực của người dùng.',
        'invalid-argument' => 'Mật khẩu chưa đáp ứng điều kiện bảo mật.',
        'unauthenticated' => 'Phiên đăng nhập đã hết hạn.',
        _ => 'Không thể đặt mật khẩu lúc này.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _settingPasswordUid = null);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _database.usersStream(),
    builder: (context, snapshot) => ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const _AdminTitle(
          title: 'NGƯỜI DÙNG',
          subtitle:
              'Hồ sơ công khai; mật khẩu được Firebase Authentication bảo vệ.',
        ),
        const SizedBox(height: 18),
        if (snapshot.hasError)
          const NoDataState(compact: true)
        else if (!snapshot.hasData)
          const Center(child: CircularProgressIndicator())
        else if (snapshot.data!.docs.isEmpty)
          const _EmptyPanel(
            icon: Icons.people_outline,
            text: 'CHƯA CÓ NGƯỜI DÙNG',
          )
        else
          ...snapshot.data!.docs.indexed.map((entry) {
            final data = entry.$2.data();
            final name = data['fullName'] as String? ?? 'Người dùng';
            final storedRole = data['role'] as String? ?? 'customer';
            final role =
                const {
                  'customer',
                  'seller',
                  'moderator',
                  'admin',
                }.contains(storedRole)
                ? storedRole
                : 'customer';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MangaPanel(
                shadow: false,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: entry.$1.isEven ? mangaSakura : mangaSky,
                      foregroundColor: mangaInk,
                      child: Text(name.isEmpty ? 'U' : name[0].toUpperCase()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            data['email'] as String? ?? '',
                            style: mangaMono(size: 10),
                          ),
                          Text(
                            '${data['phone'] ?? 'Chưa có SĐT'} • ${_date(data['createdAt'])}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.canChangeRole)
                      IconButton(
                        tooltip: 'Đặt mật khẩu',
                        onPressed: _settingPasswordUid == entry.$2.id
                            ? null
                            : () => _setPassword(entry.$2.id, name),
                        icon: _settingPasswordUid == entry.$2.id
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.password_rounded),
                      ),
                    DropdownButton<String>(
                      value: role,
                      items: [
                        const DropdownMenuItem(
                          value: 'customer',
                          child: Text('CUSTOMER'),
                        ),
                        DropdownMenuItem(
                          value: 'seller',
                          enabled: role == 'seller',
                          child: const Text('SELLER'),
                        ),
                        const DropdownMenuItem(
                          value: 'moderator',
                          child: Text('MODERATOR'),
                        ),
                        const DropdownMenuItem(
                          value: 'admin',
                          child: Text('ADMIN'),
                        ),
                      ],
                      onChanged:
                          !widget.canChangeRole ||
                              _updatingUid == entry.$2.id ||
                              entry.$2.id ==
                                  FirebaseAuth.instance.currentUser?.uid
                          ? null
                          : (value) {
                              if (value != null && value != role) {
                                _changeRole(entry.$2.id, value);
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    ),
  );
}

class _AdminAuctionsPage extends StatefulWidget {
  const _AdminAuctionsPage();

  @override
  State<_AdminAuctionsPage> createState() => _AdminAuctionsPageState();
}

class _AdminAuctionsPageState extends State<_AdminAuctionsPage> {
  final _auctionService = AuctionService();
  String? _processingId;
  String _search = '';
  String _statusFilter = 'all';

  Future<void> _approve(String requestId) async {
    final now = DateTime.now().add(const Duration(minutes: 10));
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    final startAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await _review(requestId, true, startAt: startAt);
  }

  Future<void> _reject(String requestId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lý do từ chối'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Nhập lý do để Seller có thể kiểm tra lại',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('HỦY'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('XÁC NHẬN'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    await _review(requestId, false, reason: reason);
  }

  Future<void> _review(
    String requestId,
    bool approved, {
    DateTime? startAt,
    String? reason,
  }) async {
    setState(() => _processingId = requestId);
    try {
      await _auctionService.reviewRequest(
        requestId: requestId,
        approved: approved,
        startAt: startAt,
        rejectionReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Đã duyệt yêu cầu.' : 'Đã từ chối yêu cầu.'),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Không thể xử lý yêu cầu.')),
      );
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _stopAuction(String auctionId) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dừng phiên đấu giá?'),
        content: const Text(
          'Backend sẽ hoàn các khoản cọc đang giữ và thông báo cho người tham gia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DỪNG PHIÊN'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await _auctionService.cancel(auctionId);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Không thể dừng phiên.')),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _database.auctionRequestsStream(),
    builder: (context, requestSnapshot) =>
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _database.auctionsStream(),
          builder: (context, auctionSnapshot) {
            if (requestSnapshot.hasError || auctionSnapshot.hasError) {
              return const NoDataState();
            }
            if (!requestSnapshot.hasData || !auctionSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            bool matches(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
              final data = doc.data();
              final title = (data['title'] as String? ?? '').toLowerCase();
              final status = data['status'] as String? ?? '';
              return title.contains(_search.toLowerCase()) &&
                  (_statusFilter == 'all' || status == _statusFilter);
            }

            final requests = requestSnapshot.data!.docs.where(matches).toList();
            final auctions = auctionSnapshot.data!.docs.where(matches).toList();
            return ListView(
              padding: const EdgeInsets.all(22),
              children: [
                const _AdminTitle(
                  title: 'QUẢN LÝ ĐẤU GIÁ',
                  subtitle:
                      'Duyệt yêu cầu và theo dõi toàn bộ vòng đời phiên đấu giá.',
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 360,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Tìm theo tên truyện',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) =>
                            setState(() => _search = value.trim()),
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Chờ duyệt'),
                          ),
                          DropdownMenuItem(
                            value: 'upcoming',
                            child: Text('Sắp diễn ra'),
                          ),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Đang diễn ra'),
                          ),
                          DropdownMenuItem(
                            value: 'successful',
                            child: Text('Chờ thanh toán'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Đã hoàn tất'),
                          ),
                          DropdownMenuItem(
                            value: 'failed',
                            child: Text('Thất bại'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Đã hủy'),
                          ),
                          DropdownMenuItem(
                            value: 'rejected',
                            child: Text('Bị từ chối'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _statusFilter = value ?? 'all'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('YÊU CẦU ĐẤU GIÁ', style: mangaDisplay(size: 20)),
                const SizedBox(height: 10),
                if (requests.isEmpty)
                  const _EmptyPanel(
                    icon: Icons.fact_check_outlined,
                    text: 'KHÔNG CÓ DỮ LIỆU',
                  )
                else
                  ...requests.map((doc) {
                    final data = doc.data();
                    final status =
                        data['status'] as String? ?? AuctionStatus.pending;
                    final pending = status == AuctionStatus.pending;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MangaPanel(
                        shadow: false,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 380,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] as String? ??
                                        'Yêu cầu đấu giá',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '${data['durationDays'] ?? 1} ngày • Khởi điểm ${_money(data['startingBid'] as num? ?? 0)}',
                                  ),
                                  if ((data['rejectionReason'] as String? ?? '')
                                      .isNotEmpty)
                                    Text('Lý do: ${data['rejectionReason']}'),
                                ],
                              ),
                            ),
                            _StatusPill(
                              text: AuctionStatus.label(status).toUpperCase(),
                              color: _statusColor(status),
                            ),
                            if (pending) ...[
                              FilledButton.icon(
                                onPressed: _processingId == doc.id
                                    ? null
                                    : () => _approve(doc.id),
                                icon: const Icon(Icons.schedule_rounded),
                                label: const Text('CHỌN GIỜ & DUYỆT'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _processingId == doc.id
                                    ? null
                                    : () => _reject(doc.id),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('TỪ CHỐI'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 22),
                Text('PHIÊN ĐẤU GIÁ', style: mangaDisplay(size: 20)),
                const SizedBox(height: 10),
                if (auctions.isEmpty)
                  const _EmptyPanel(
                    icon: Icons.gavel_outlined,
                    text: 'KHÔNG CÓ DỮ LIỆU',
                  )
                else
                  ...auctions.map((doc) {
                    final data = doc.data();
                    final status = data['status'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MangaPanel(
                        shadow: false,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.gavel_rounded),
                          title: Text(
                            data['title'] as String? ?? 'Phiên đấu giá',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            'Hiện tại: ${_money(data['currentBid'] as num? ?? 0)} • ${data['bidCount'] ?? 0} lượt',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StatusPill(
                                text: AuctionStatus.label(status).toUpperCase(),
                                color: _statusColor(status),
                              ),
                              if (status == AuctionStatus.upcoming ||
                                  status == AuctionStatus.active)
                                IconButton(
                                  tooltip: 'Dừng phiên',
                                  onPressed: () => _stopAuction(doc.id),
                                  icon: const Icon(Icons.stop_circle_outlined),
                                ),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AuctionDetailPage(auctionId: doc.id),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
  );
}

class _AdminFeedbackPage extends StatelessWidget {
  const _AdminFeedbackPage();

  Future<void> _review(
    BuildContext context,
    String feedbackId,
    bool approved,
  ) async {
    try {
      await _database.reviewSellerFeedback(
        feedbackId: feedbackId,
        approved: approved,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? 'Đã duyệt phản hồi.' : 'Đã từ chối phản hồi.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? error.code)));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _database.feedbackModerationStream(),
    builder: (context, snapshot) {
      final docs = snapshot.data?.docs ?? [];
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const _AdminTitle(
            title: 'KIỂM DUYỆT PHẢN HỒI',
            subtitle: 'Duyệt đánh giá Seller và xử lý báo cáo vi phạm.',
          ),
          const SizedBox(height: 18),
          if (snapshot.hasError)
            const NoDataState(compact: true)
          else if (!snapshot.hasData)
            const Center(child: CircularProgressIndicator())
          else if (docs.isEmpty)
            const _EmptyPanel(
              icon: Icons.reviews_outlined,
              text: 'CHƯA CÓ PHẢN HỒI',
            )
          else
            ...docs.map((doc) {
              final data = doc.data();
              final status = data['status'] as String? ?? 'pending';
              final report = data['type'] == 'report';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MangaPanel(
                  shadow: false,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 430,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report
                                  ? 'BÁO CÁO VI PHẠM'
                                  : '${data['rating'] ?? 0}/5 SAO',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(data['content'] as String? ?? ''),
                            Text(
                              'Seller: ${data['sellerUid'] ?? ''} • ${_date(data['createdAt'])}',
                              style: mangaMono(size: 9),
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(
                        text: status.toUpperCase(),
                        color: report ? mangaRed : _statusColor(status),
                      ),
                      if (status == 'pending') ...[
                        FilledButton.icon(
                          onPressed: () => _review(context, doc.id, true),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('DUYỆT'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _review(context, doc.id, false),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('TỪ CHỐI'),
                        ),
                      ],
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

class _AdminCatalogOptionsPage extends StatefulWidget {
  const _AdminCatalogOptionsPage();

  @override
  State<_AdminCatalogOptionsPage> createState() =>
      _AdminCatalogOptionsPageState();
}

class _AdminWalletRequestsPage extends StatelessWidget {
  const _AdminWalletRequestsPage();

  Future<void> _review(
    BuildContext context,
    String requestId,
    bool approved,
  ) async {
    try {
      await _database.reviewWalletRequest(
        requestId: requestId,
        approved: approved,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? 'Đã hoàn tất giao dịch ví.' : 'Đã từ chối yêu cầu ví.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? error.code)));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _database.walletModerationStream(),
    builder: (context, snapshot) {
      final docs = snapshot.data?.docs ?? [];
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const _AdminTitle(
            title: 'YÊU CẦU VÍ',
            subtitle: 'Đối soát yêu cầu nạp và rút tiền của thành viên.',
          ),
          const SizedBox(height: 18),
          if (snapshot.hasError)
            const NoDataState(compact: true)
          else if (!snapshot.hasData)
            const Center(child: CircularProgressIndicator())
          else if (docs.isEmpty)
            const _EmptyPanel(
              icon: Icons.account_balance_wallet_outlined,
              text: 'CHƯA CÓ YÊU CẦU VÍ',
            )
          else
            ...docs.map((doc) {
              final data = doc.data();
              final type = data['type'] as String? ?? 'deposit';
              final status = data['status'] as String? ?? 'pending';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MangaPanel(
                  shadow: false,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        type == 'deposit'
                            ? Icons.add_card_rounded
                            : Icons.payments_outlined,
                        color: type == 'deposit' ? mangaGreen : mangaRed,
                        size: 34,
                      ),
                      SizedBox(
                        width: 360,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type == 'deposit' ? 'NẠP TIỀN' : 'RÚT TIỀN',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${_money(data['amount'] as num? ?? 0)} • ${data['paymentMethod'] ?? ''}',
                            ),
                            Text(
                              'UID: ${data['userId'] ?? ''} • ${_date(data['createdAt'])}',
                              style: mangaMono(size: 9),
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(
                        text: status.toUpperCase(),
                        color: _statusColor(status),
                      ),
                      if (status == 'pending') ...[
                        FilledButton.icon(
                          onPressed: () => _review(context, doc.id, true),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('DUYỆT'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _review(context, doc.id, false),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('TỪ CHỐI'),
                        ),
                      ],
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

class _AdminCatalogOptionsPageState extends State<_AdminCatalogOptionsPage> {
  static const _collections = <(String, String, IconData)>[
    ('comic_genres', 'Thể loại', Icons.category_outlined),
    ('comic_conditions', 'Tình trạng', Icons.verified_outlined),
    ('comic_editions', 'Ấn bản', Icons.collections_bookmark_outlined),
    ('comic_merchandises', 'Quà kèm', Icons.card_giftcard_outlined),
  ];
  int _selected = 0;

  Future<void> _showForm([
    QueryDocumentSnapshot<Map<String, dynamic>>? document,
  ]) async {
    final data = document?.data() ?? {};
    final name = TextEditingController(text: data['name'] as String? ?? '');
    final description = TextEditingController(
      text: data['description'] as String? ?? '',
    );
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(document == null ? 'Thêm dữ liệu' : 'Sửa dữ liệu'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Tên'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
            ],
          ),
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
    );
    final value = name.text.trim();
    final detail = description.text.trim();
    name.dispose();
    description.dispose();
    if (submitted != true || value.isEmpty) return;
    final collection = _collections[_selected].$1;
    if (document == null) {
      await _database.createCatalogOption(
        collection: collection,
        name: value,
        description: detail,
      );
    } else {
      await _database.updateCatalogOption(
        collection: collection,
        id: document.id,
        name: value,
        description: detail,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _collections[_selected];
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _database.catalogOptionsStream(selected.$1),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const _AdminTitle(
              title: 'DANH MỤC TRUYỆN',
              subtitle:
                  'Quản lý thể loại, tình trạng, ấn bản và quà kèm theo source ComZone.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _collections.indexed
                  .map(
                    (entry) => ChoiceChip(
                      selected: entry.$1 == _selected,
                      avatar: Icon(entry.$2.$3, size: 18),
                      label: Text(entry.$2.$2.toUpperCase()),
                      onSelected: (_) => setState(() => _selected = entry.$1),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _showForm,
                icon: const Icon(Icons.add_rounded),
                label: Text('THÊM ${selected.$2.toUpperCase()}'),
              ),
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              const NoDataState(compact: true)
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (docs.isEmpty)
              _EmptyPanel(
                icon: selected.$3,
                text: 'CHƯA CÓ ${selected.$2.toUpperCase()}',
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final deleted = data['isDeleted'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MangaPanel(
                    shadow: false,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        selected.$3,
                        color: deleted ? Colors.black38 : mangaNavy,
                      ),
                      title: Text(
                        data['name'] as String? ?? 'Không có tên',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          decoration: deleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      subtitle: Text(data['description'] as String? ?? ''),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Sửa',
                            onPressed: deleted ? null : () => _showForm(doc),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: deleted ? 'Khôi phục' : 'Ẩn',
                            onPressed: () => _database.setCatalogOptionDeleted(
                              collection: selected.$1,
                              id: doc.id,
                              deleted: !deleted,
                            ),
                            icon: Icon(
                              deleted
                                  ? Icons.restore_rounded
                                  : Icons.delete_outline_rounded,
                            ),
                          ),
                        ],
                      ),
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

class _AdminSettingsPage extends StatefulWidget {
  const _AdminSettingsPage();

  @override
  State<_AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<_AdminSettingsPage> {
  bool _importing = false;

  Future<void> _importComzone() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập dữ liệu ComZone?'),
        content: const Text(
          'Dữ liệu thật từ dump sẽ được ghi vào Firebase theo ID gốc. '
          'Bản ghi đã tồn tại sẽ được cập nhật, không tạo bản sao. '
          'Mật khẩu, token, OTP và dữ liệu riêng tư không được nhập.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('NHẬP DỮ LIỆU'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    setState(() => _importing = true);
    try {
      final counts = await _database.importComzonePublicSeed();
      final total = counts.values.fold<int>(
        0,
        (currentTotal, itemCount) => currentTotal + itemCount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã nhập $total bản ghi thật từ ComZone.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể nhập dữ liệu: $error')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const _AdminTitle(
        title: 'CÀI ĐẶT',
        subtitle: 'Cấu hình vận hành Manga Mart.',
      ),
      const SizedBox(height: 18),
      const _AuctionConfigPanel(),
      const SizedBox(height: 18),
      MangaPanel(
        color: mangaMuted,
        shadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security_outlined, color: mangaNavy, size: 38),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'QUYỀN QUẢN TRỊ ĐƯỢC KIỂM TRA BẰNG FIRESTORE RULES',
                    style: mangaDisplay(size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text('DỮ LIỆU NGUỒN COMZONE', style: mangaDisplay(size: 20)),
            const SizedBox(height: 6),
            const Text(
              'Nguồn: Dump20250111_version_2.sql. Bao gồm danh mục, truyện, '
              'hồ sơ người bán đã ẩn thông tin riêng tư, đấu giá, bài trao đổi '
              'và gói người bán.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _importing ? null : _importComzone,
              icon: _importing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_importing ? 'ĐANG NHẬP...' : 'NHẬP DỮ LIỆU COMZONE'),
            ),
          ],
        ),
      ),
    ],
  );
}

class _AuctionConfigPanel extends StatelessWidget {
  const _AuctionConfigPanel();

  Future<void> _edit(
    BuildContext context,
    String configId,
    AuctionConfig config,
  ) async {
    final bid = TextEditingController(text: '${config.bidIncrementPercent}');
    final deposit = TextEditingController(text: '${config.depositPercent}');
    final multiplier = TextEditingController(
      text: '${config.buyNowMultiplier}',
    );
    final days = TextEditingController(text: '${config.paymentDays}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cấu hình đấu giá'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bid,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Bước giá (%)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deposit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tiền cọc (%)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: multiplier,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Giới hạn mua ngay (lần giá khởi điểm)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Hạn thanh toán (ngày)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LƯU'),
          ),
        ],
      ),
    );
    if (saved != true || !context.mounted) {
      bid.dispose();
      deposit.dispose();
      multiplier.dispose();
      days.dispose();
      return;
    }
    final bidValue = num.tryParse(bid.text);
    final depositValue = num.tryParse(deposit.text);
    final multiplierValue = num.tryParse(multiplier.text);
    final daysValue = int.tryParse(days.text);
    bid.dispose();
    deposit.dispose();
    multiplier.dispose();
    days.dispose();
    if (bidValue == null ||
        bidValue <= 0 ||
        depositValue == null ||
        depositValue < 100 ||
        multiplierValue == null ||
        multiplierValue <= 1 ||
        daysValue == null ||
        daysValue < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giá trị cấu hình không hợp lệ.')),
      );
      return;
    }
    await _database.updateAuctionConfig(
      configId: configId,
      bidIncrementPercent: bidValue,
      depositPercent: depositValue,
      buyNowMultiplier: multiplierValue,
      paymentDays: daysValue,
    );
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _database.auctionConfigsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const NoDataState(compact: true);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final document = snapshot.data!.docs.firstOrNull;
          final config = AuctionConfig.fromMap(document?.data());
          return MangaPanel(
            shadow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel_rounded, color: mangaNavy, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'CẤU HÌNH ĐẤU GIÁ',
                        style: mangaDisplay(size: 20),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sửa cấu hình',
                      onPressed: () =>
                          _edit(context, document?.id ?? 'default', config),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Bước giá ${config.bidIncrementPercent}% • '
                  'Cọc ${config.depositPercent}% • '
                  'Mua ngay tối đa ${config.buyNowMultiplier} lần • '
                  'Thanh toán trong ${config.paymentDays} ngày',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          );
        },
      );
}

class _AdminTitle extends StatelessWidget {
  const _AdminTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: mangaDisplay(size: 36, color: mangaNavy)),
      Text(
        subtitle,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    color: color,
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    child: Text(
      text,
      style: TextStyle(
        color: color == mangaRed || color == mangaGreen
            ? Colors.white
            : mangaInk,
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => MangaPanel(
    color: Colors.white,
    shadow: false,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: mangaNavy),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: mangaDisplay(size: 22),
          ),
        ],
      ),
    ),
  );
}

final _database = DatabaseService();
final _adminAuth = AdminAuthService();

Color _statusColor(String status) => switch (status) {
  'Đã giao' ||
  'Đã duyệt' ||
  'successful' ||
  'approved' ||
  'active' => mangaGreen,
  'Đã hủy' || 'Từ chối' || 'failed' || 'rejected' || 'cancelled' => mangaRed,
  'Đang giao' => mangaSky,
  'Đang xử lý' => mangaSakura,
  _ => mangaYellow,
};

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
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
