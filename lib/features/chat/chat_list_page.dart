import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/features/chat/chat_detail_page.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  Future<void> _createChat(BuildContext context, String uid) async {
    final sellers = await _database.sellerProfilesStream().first;
    if (!context.mounted) return;
    String? selectedUid;
    final selected = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tạo hội thoại với Seller'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedUid,
            decoration: const InputDecoration(labelText: 'Chọn Seller'),
            items: sellers.docs
                .where((doc) => doc.id != uid)
                .map(
                  (doc) => DropdownMenuItem(
                    value: doc.id,
                    child: Text(
                      doc.data()['businessName'] as String? ??
                          doc.data()['fullName'] as String? ??
                          'Seller',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setDialogState(() => selectedUid = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('HỦY'),
            ),
            FilledButton(
              onPressed: selectedUid == null
                  ? null
                  : () {
                      final seller = sellers.docs
                          .where((doc) => doc.id == selectedUid)
                          .first;
                      Navigator.pop(dialogContext, {
                        'uid': seller.id,
                        'title':
                            seller.data()['businessName'] as String? ??
                            seller.data()['fullName'] as String? ??
                            'Seller',
                      });
                    },
              child: const Text('TẠO'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    final chatId = await _database.createChatRoom(
      creatorUid: uid,
      participantUid: selected['uid']!,
      title: selected['title']!,
    );
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatDetailPage(chatId: chatId, title: selected['title']!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'TIN NHẮN',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
        actions: [
          if (uid != null)
            IconButton(
              tooltip: 'Tạo hội thoại',
              onPressed: () => _createChat(context, uid),
              icon: const Icon(Icons.add_comment_outlined),
            ),
        ],
      ),
      body: uid == null
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Bạn chưa đăng nhập',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _database.chatsStream(uid),
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
                    icon: Icons.forum_outlined,
                    title: 'Chưa có hội thoại',
                    message: 'Các cuộc trò chuyện sẽ xuất hiện tại đây.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final title = data['title'] as String? ?? 'Hội thoại';
                    return MangaPanel(
                      shadow: false,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: mangaSky,
                          foregroundColor: mangaNavy,
                          child: Icon(Icons.person_outline_rounded),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          data['lastMessage'] as String? ?? 'Chưa có tin nhắn',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ChatDetailPage(chatId: doc.id, title: title),
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
