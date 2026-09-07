import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/features/chat/chat_detail_page.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class SellerProfilePage extends StatelessWidget {
  const SellerProfilePage({super.key, required this.sellerUid});

  final String sellerUid;

  Future<void> _startChat(
    BuildContext context,
    String title,
    String currentUid,
  ) async {
    final chatId = await _database.createChatRoom(
      creatorUid: currentUid,
      participantUid: sellerUid,
      title: title,
    );
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(chatId: chatId, title: title),
      ),
    );
  }

  Future<void> _feedback(BuildContext context, String currentUid) async {
    final content = TextEditingController();
    var rating = 5;
    var report = false;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Phản hồi về Seller'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: content,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Nội dung'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: rating,
                decoration: const InputDecoration(labelText: 'Đánh giá'),
                items: [1, 2, 3, 4, 5]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value sao'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => rating = value);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: report,
                title: const Text('Đây là báo cáo vi phạm'),
                onChanged: (value) =>
                    setDialogState(() => report = value == true),
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
              child: const Text('GỬI'),
            ),
          ],
        ),
      ),
    );
    final text = content.text.trim();
    content.dispose();
    if (submitted != true || text.isEmpty) return;
    await _database.submitSellerFeedback(
      sellerUid: sellerUid,
      userId: currentUid,
      content: text,
      rating: rating,
      isReport: report,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phản hồi đã được gửi để kiểm duyệt.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'HỒ SƠ SELLER',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _database.sellerProfileStream(sellerUid),
        builder: (context, profileSnapshot) {
          if (!profileSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!profileSnapshot.data!.exists) {
            return const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Không có hồ sơ Seller',
            );
          }
          final profile = profileSnapshot.data!.data() ?? {};
          final name = profile['businessName'] as String? ?? '';
          final title = name.isNotEmpty
              ? name
              : profile['fullName'] as String? ?? 'Seller';
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _database.sellerListingsStream(sellerUid),
            builder: (context, comicsSnapshot) =>
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _database.sellerFeedbackStream(sellerUid),
                  builder: (context, feedbackSnapshot) {
                    final comics = comicsSnapshot.data?.docs ?? [];
                    final feedback = feedbackSnapshot.data?.docs ?? [];
                    return ListView(
                      padding: const EdgeInsets.all(22),
                      children: [
                        MangaPanel(
                          shadow: false,
                          child: Column(
                            children: [
                              const CircleAvatar(
                                radius: 36,
                                backgroundColor: mangaSky,
                                foregroundColor: mangaNavy,
                                child: Icon(Icons.storefront_rounded, size: 38),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                title,
                                style: mangaDisplay(size: 28, color: mangaNavy),
                              ),
                              Text(
                                '${profile['rating'] ?? 0}/5 • ${profile['feedbackCount'] ?? 0} phản hồi',
                              ),
                              if (currentUid != null && currentUid != sellerUid)
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    StreamBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>
                                    >(
                                      stream: _database.followStream(
                                        uid: currentUid,
                                        sellerUid: sellerUid,
                                      ),
                                      builder: (context, snapshot) {
                                        final followed =
                                            snapshot.data?.exists == true;
                                        return OutlinedButton.icon(
                                          onPressed: () =>
                                              _database.setSellerFollowed(
                                                uid: currentUid,
                                                sellerUid: sellerUid,
                                                followed: !followed,
                                              ),
                                          icon: Icon(
                                            followed
                                                ? Icons.person_remove_outlined
                                                : Icons.person_add_outlined,
                                          ),
                                          label: Text(
                                            followed
                                                ? 'BỎ THEO DÕI'
                                                : 'THEO DÕI',
                                          ),
                                        );
                                      },
                                    ),
                                    FilledButton.icon(
                                      onPressed: () => _startChat(
                                        context,
                                        title,
                                        currentUid,
                                      ),
                                      icon: const Icon(Icons.chat_outlined),
                                      label: const Text('CHAT'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _feedback(context, currentUid),
                                      icon: const Icon(
                                        Icons.rate_review_outlined,
                                      ),
                                      label: const Text('PHẢN HỒI'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'TRUYỆN ĐANG BÁN (${comics.length})',
                          style: mangaDisplay(size: 22, color: mangaNavy),
                        ),
                        const SizedBox(height: 10),
                        if (comics.isEmpty)
                          const EmptyState(
                            icon: Icons.menu_book_outlined,
                            title: 'Seller chưa có truyện đang bán',
                            compact: true,
                          )
                        else
                          ...comics
                              .take(5)
                              .map(
                                (doc) => ListTile(
                                  leading: const Icon(Icons.menu_book_outlined),
                                  title: Text(
                                    doc.data()['title'] as String? ??
                                        'Không có tên',
                                  ),
                                  trailing: Text(
                                    '${(doc.data()['price'] as num? ?? 0).toStringAsFixed(0)}đ',
                                  ),
                                ),
                              ),
                        const SizedBox(height: 20),
                        Text(
                          'PHẢN HỒI',
                          style: mangaDisplay(size: 22, color: mangaNavy),
                        ),
                        if (feedback.isEmpty)
                          const EmptyState(
                            icon: Icons.reviews_outlined,
                            title: 'Chưa có phản hồi',
                            compact: true,
                          )
                        else
                          ...feedback.map(
                            (doc) => ListTile(
                              leading: const Icon(Icons.star_rounded),
                              title: Text(
                                doc.data()['content'] as String? ?? '',
                              ),
                              trailing: Text('${doc.data()['rating'] ?? 0}/5'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
          );
        },
      ),
    );
  }
}
