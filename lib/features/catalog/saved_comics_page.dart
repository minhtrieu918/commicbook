import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/core/models.dart';
import 'package:commicbook/features/catalog/comic_detail_page.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class SavedComicsPage extends StatelessWidget {
  const SavedComicsPage({super.key, required this.onAdd});

  final ValueChanged<ComicItem> onAdd;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'TRUYỆN ĐÃ LƯU',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: uid == null
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Bạn chưa đăng nhập',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _database.savedComicsStream(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const NoDataState();
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Chưa lưu truyện nào',
                    message: 'Truyện bạn đánh dấu sẽ xuất hiện tại đây.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final comic = ComicItem(
                      id: data['comicId'] as String? ?? '',
                      title: data['title'] as String? ?? 'Không có tên',
                      author: data['author'] as String? ?? 'Không rõ tác giả',
                      price: data['price'] as num? ?? 0,
                      color: mangaNavy,
                      genre: data['genre'] as String? ?? 'Chưa rõ',
                      condition: data['condition'] as String? ?? 'Chưa rõ',
                      stock: (data['stock'] as num? ?? 0).toInt(),
                      image: data['image'] as String? ?? '',
                      sellerUid: data['sellerUid'] as String? ?? '',
                      previewImages:
                          (data['previewImages'] as List<dynamic>?)
                              ?.whereType<String>()
                              .toList() ??
                          const [],
                    );
                    return MangaPanel(
                      shadow: false,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.bookmark_rounded,
                          color: mangaNavy,
                        ),
                        title: Text(
                          comic.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(comic.author),
                        trailing: Text(
                          '${comic.price.toStringAsFixed(0)}đ',
                          style: mangaMono(size: 11, color: mangaRed),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ComicDetailPage(comic: comic, onAdd: onAdd),
                          ),
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
