import 'package:commicbook/admin/admin_order_rules.dart';
import 'package:commicbook/core/models.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:commicbook/ui/comic_cover_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class CheckoutPage extends StatefulWidget {
  CheckoutPage({super.key, required ComicItem comic, this.onSuccess})
    : items = [comic];

  CheckoutPage.cart({super.key, required List<ComicItem> items, this.onSuccess})
    : items = List<ComicItem>.unmodifiable(items);

  final List<ComicItem> items;
  final VoidCallback? onSuccess;
  ComicItem get comic => items.first;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String _method = 'Thanh toán khi nhận hàng';
  bool _loading = false;

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      for (final comic in widget.items) {
        final classification = classifyOrder({
          'genre': comic.genre,
          'condition': comic.condition,
          'price': comic.price,
        });
        await _database.createOrder(
          uid: user.uid,
          comicId: comic.id,
          comicTitle: comic.title,
          sellerUid: comic.sellerUid,
          price: comic.price,
          paymentMethod: _method,
          buyerEmail: user.email,
          genre: comic.genre,
          condition: comic.condition,
          classification: classification,
        );
      }
      if (!mounted) return;
      widget.onSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đặt mua thành công! Đơn hàng đã được lưu.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể tạo đơn: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.fold<num>(
      0,
      (amount, comic) => amount + comic.price,
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'THANH TOÁN',
          style: mangaDisplay(size: 24, color: mangaYellow),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              MangaPanel(
                child: Column(
                  children: widget.items.indexed.map((entry) {
                    final index = entry.$1;
                    final comic = entry.$2;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == widget.items.length - 1 ? 0 : 12,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 90,
                            height: 110,
                            child: _NetworkComicImage(
                              url: comic.image,
                              fallbackColor: comic.color,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comic.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                Text(comic.author),
                                const SizedBox(height: 10),
                                Text(
                                  _money(comic.price),
                                  style: mangaMono(size: 17, color: mangaRed),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),
              Text('PHƯƠNG THỨC THANH TOÁN', style: mangaDisplay(size: 23)),
              const SizedBox(height: 10),
              RadioGroup<String>(
                groupValue: _method,
                onChanged: (value) {
                  if (value != null) setState(() => _method = value);
                },
                child: const MangaPanel(
                  shadow: false,
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'Thanh toán khi nhận hàng',
                        title: Text('Thanh toán khi nhận hàng'),
                      ),
                      RadioListTile<String>(
                        value: 'Chuyển khoản ngân hàng',
                        title: Text('Chuyển khoản ngân hàng'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _loading ? null : _pay,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Text(
                    _loading ? 'ĐANG XỬ LÝ...' : 'XÁC NHẬN ${_money(total)}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkComicImage extends StatelessWidget {
  const _NetworkComicImage({required this.url, required this.fallbackColor});

  final String url;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) =>
      ComicCoverImage(source: url, fallbackColor: fallbackColor);
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
