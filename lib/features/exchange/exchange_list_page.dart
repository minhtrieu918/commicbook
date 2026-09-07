import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/features/exchange/create_exchange_post_page.dart';
import 'package:commicbook/features/exchange/exchange_post_detail_page.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class ExchangeListPage extends StatelessWidget {
  const ExchangeListPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _database.exchangePostsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const NoDataState();
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs
            .where((doc) => doc.data()['status'] == 'active')
            .toList();
        return ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRAO ĐỔI',
                        style: mangaDisplay(size: 30, color: mangaNavy),
                      ),
                      const Text(
                        'Danh sách bài đăng trao đổi trong cộng đồng.',
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateExchangePostPage(),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('TẠO BÀI'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (docs.isEmpty)
              const EmptyState(
                icon: Icons.swap_horiz_rounded,
                title: 'Chưa có bài trao đổi',
                message: 'Bài đăng mới sẽ xuất hiện tại đây.',
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ExchangePostDetailPage(postId: doc.id, data: data),
                      ),
                    ),
                    child: MangaPanel(
                      shadow: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] as String? ?? 'Không có tiêu đề',
                            style: mangaDisplay(size: 21, color: mangaNavy),
                          ),
                          const SizedBox(height: 8),
                          Text(data['content'] as String? ?? ''),
                          const SizedBox(height: 10),
                          Text(
                            _date(data['createdAt']),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
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
    ),
  );
}

String _date(dynamic value) {
  if (value is! Timestamp) return 'Đang cập nhật';
  final date = value.toDate();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
