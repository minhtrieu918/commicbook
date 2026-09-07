import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/core/models.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/features/profile/seller_profile_page.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:commicbook/ui/comic_cover_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class ComicDetailPage extends StatelessWidget {
  const ComicDetailPage({super.key, required this.comic, required this.onAdd});

  final ComicItem comic;
  final ValueChanged<ComicItem> onAdd;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: mangaInk,
      foregroundColor: Colors.white,
      title: Text(
        'CHI TIẾT TRUYỆN',
        style: mangaDisplay(size: 22, color: mangaYellow),
      ),
      actions: [_SavedComicButton(comic: comic)],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            MangaPanel(
              shadow: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 650;
                  final cover = _Cover(comic: comic);
                  final information = _Information(comic: comic, onAdd: onAdd);
                  return compact
                      ? Column(
                          children: [
                            cover,
                            const SizedBox(height: 20),
                            information,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 280, child: cover),
                            const SizedBox(width: 28),
                            Expanded(child: information),
                          ],
                        );
                },
              ),
            ),
            if (comic.previewImages.isNotEmpty) ...[
              const SizedBox(height: 18),
              _PreviewGallery(comic: comic),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PreviewGallery extends StatelessWidget {
  const _PreviewGallery({required this.comic});

  final ComicItem comic;

  @override
  Widget build(BuildContext context) => MangaPanel(
    shadow: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ẢNH NỘI DUNG', style: mangaDisplay(size: 24, color: mangaNavy)),
        const SizedBox(height: 4),
        Text(
          '${comic.previewImages.length} hình ảnh từ dữ liệu nguồn ComZone.',
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: comic.previewImages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => Container(
              width: 180,
              decoration: BoxDecoration(
                border: Border.all(color: mangaInk, width: 2),
              ),
              child: ComicCoverImage(
                source: comic.previewImages[index],
                fallbackColor: comic.color,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SavedComicButton extends StatelessWidget {
  const _SavedComicButton({required this.comic});

  final ComicItem comic;

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) return const SizedBox.shrink();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _database.savedComicStream(uid: uid, comicId: comic.id),
      builder: (context, snapshot) {
        final saved = snapshot.data?.exists == true;
        return IconButton(
          tooltip: saved ? 'Bỏ khỏi danh sách đã lưu' : 'Lưu truyện',
          onPressed: () => _database.setComicSaved(
            uid: uid,
            comicId: comic.id,
            saved: !saved,
            comicData: {
              'title': comic.title,
              'author': comic.author,
              'price': comic.price,
              'genre': comic.genre,
              'condition': comic.condition,
              'stock': comic.stock,
              'image': comic.image,
              'sellerUid': comic.sellerUid,
              'previewImages': comic.previewImages,
            },
          ),
          icon: Icon(
            saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          ),
        );
      },
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.comic});

  final ComicItem comic;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: .72,
    child: ComicCoverImage(
      source: comic.image,
      fallbackColor: comic.color,
      fallbackIconSize: 72,
    ),
  );
}

class _Information extends StatelessWidget {
  const _Information({required this.comic, required this.onAdd});

  final ComicItem comic;
  final ValueChanged<ComicItem> onAdd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(comic.title, style: mangaDisplay(size: 32, color: mangaNavy)),
      const SizedBox(height: 6),
      Text(
        comic.author,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Tag(text: comic.genre),
          _Tag(text: comic.condition),
          _Tag(text: 'Còn ${comic.stock}'),
        ],
      ),
      const SizedBox(height: 20),
      Text(_money(comic.price), style: mangaMono(size: 24, color: mangaRed)),
      const SizedBox(height: 18),
      Text(
        'Đánh giá ${comic.rating}/5 từ ${comic.reviews} lượt đánh giá.',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      if (comic.sellerUid.isNotEmpty) ...[
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SellerProfilePage(sellerUid: comic.sellerUid),
            ),
          ),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('XEM HỒ SƠ SELLER'),
        ),
      ],
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: comic.stock <= 0
              ? null
              : () {
                  onAdd(comic);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã thêm ${comic.title} vào giỏ.')),
                  );
                },
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(comic.stock > 0 ? 'THÊM VÀO GIỎ' : 'HẾT HÀNG'),
          ),
        ),
      ),
    ],
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    color: mangaMuted,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
    ),
  );
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
