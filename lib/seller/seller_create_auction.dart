import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:commicbook/features/auctions/auction_rules.dart';
import 'package:commicbook/service/auction_service.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();
final _auctions = AuctionService();

class SellerCreateAuctionPage extends StatefulWidget {
  const SellerCreateAuctionPage({super.key});

  @override
  State<SellerCreateAuctionPage> createState() =>
      _SellerCreateAuctionPageState();
}

class _SellerCreateAuctionPageState extends State<SellerCreateAuctionPage> {
  final _form = GlobalKey<FormState>();
  final _buyNow = TextEditingController();
  String? _comicId;
  Map<String, dynamic>? _comic;
  int _durationDays = 1;
  bool _loading = false;

  @override
  void dispose() {
    _buyNow.dispose();
    super.dispose();
  }

  Future<void> _submit(AuctionConfig config) async {
    if (!_form.currentState!.validate() || _comicId == null || _comic == null) {
      return;
    }
    final buyNow = num.tryParse(_buyNow.text.trim());
    setState(() => _loading = true);
    try {
      await _auctions.createRequest(
        comicId: _comicId!,
        durationDays: _durationDays,
        buyNowPrice: buyNow,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu đấu giá để duyệt.')),
      );
      Navigator.pop(context);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Không tạo được yêu cầu.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'YÊU CẦU ĐẤU GIÁ',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: uid == null
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Bạn chưa đăng nhập',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _database.auctionConfigsStream(),
              builder: (context, configSnapshot) {
                final config = AuctionConfig.fromMap(
                  configSnapshot.data?.docs.firstOrNull?.data(),
                );
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _database.sellerListingsStream(uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError || configSnapshot.hasError) {
                      return const NoDataState();
                    }
                    if (!snapshot.hasData || !configSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data();
                      return data['status'] == 'active' &&
                          (data['stock'] as num? ?? 0) > 0;
                    }).toList();
                    if (docs.isEmpty) {
                      return const EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'Không có truyện khả dụng',
                        message:
                            'Truyện phải đang hoạt động và còn hàng để gửi yêu cầu đấu giá.',
                      );
                    }
                    final startBid = _comic?['price'] as num? ?? 0;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: ListView(
                          padding: const EdgeInsets.all(22),
                          children: [
                            MangaPanel(
                              shadow: false,
                              child: Form(
                                key: _form,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      initialValue: _comicId,
                                      decoration: const InputDecoration(
                                        labelText: 'Truyện đấu giá',
                                      ),
                                      items: docs
                                          .map(
                                            (doc) => DropdownMenuItem(
                                              value: doc.id,
                                              child: Text(
                                                doc.data()['title']
                                                        as String? ??
                                                    'Không có tên',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        final selected = docs
                                            .where((doc) => doc.id == value)
                                            .firstOrNull;
                                        setState(() {
                                          _comicId = value;
                                          _comic = selected?.data();
                                        });
                                      },
                                      validator: (value) => value == null
                                          ? 'Vui lòng chọn truyện'
                                          : null,
                                    ),
                                    if (_comic != null) ...[
                                      const SizedBox(height: 14),
                                      _RuleRow(
                                        label: 'Giá khởi điểm',
                                        value: _money(startBid),
                                      ),
                                      _RuleRow(
                                        label:
                                            'Bước giá (${config.bidIncrementPercent}%)',
                                        value: _money(
                                          config.bidIncrementFor(startBid),
                                        ),
                                      ),
                                      _RuleRow(
                                        label:
                                            'Tiền cọc (${config.depositPercent}%)',
                                        value: _money(
                                          config.depositFor(startBid),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    DropdownButtonFormField<int>(
                                      initialValue: _durationDays,
                                      decoration: const InputDecoration(
                                        labelText: 'Thời lượng đấu giá',
                                      ),
                                      items: List.generate(
                                        7,
                                        (index) => DropdownMenuItem(
                                          value: index + 1,
                                          child: Text('${index + 1} ngày'),
                                        ),
                                      ),
                                      onChanged: (value) => setState(
                                        () => _durationDays = value ?? 1,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _buyNow,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Giá mua ngay (không bắt buộc)',
                                        helperText: startBid > 0
                                            ? 'Tối đa ${_money(config.maxBuyNowFor(startBid))}'
                                            : null,
                                      ),
                                      validator: (value) {
                                        if ((value ?? '').trim().isEmpty) {
                                          return null;
                                        }
                                        final amount = num.tryParse(
                                          value!.trim(),
                                        );
                                        if (amount == null ||
                                            amount <= startBid) {
                                          return 'Giá mua ngay phải lớn hơn giá khởi điểm';
                                        }
                                        if (amount >
                                            config.maxBuyNowFor(startBid)) {
                                          return 'Giá mua ngay vượt giới hạn cấu hình';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Moderator sẽ chọn thời gian bắt đầu khi duyệt. Thời gian kết thúc được tính tự động theo thời lượng đã chọn.',
                                      style: TextStyle(color: mangaMuted),
                                    ),
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _loading
                                            ? null
                                            : () => _submit(config),
                                        icon: const Icon(Icons.gavel_rounded),
                                        label: const Padding(
                                          padding: EdgeInsets.all(14),
                                          child: Text('GỬI DUYỆT ĐẤU GIÁ'),
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
                    );
                  },
                );
              },
            ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
  );
}

String _money(num value) {
  final digits = value.round().toString();
  return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
}
