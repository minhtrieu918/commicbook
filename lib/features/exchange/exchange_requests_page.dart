import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class ExchangeRequestsPage extends StatelessWidget {
  const ExchangeRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'YÊU CẦU TRAO ĐỔI',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: uid == null
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Bạn chưa đăng nhập',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _database.exchangeRequestsStream(uid),
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
                    icon: Icons.swap_horiz_rounded,
                    title: 'Chưa có yêu cầu trao đổi',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final incoming = data['recipientUid'] == uid;
                    final pending = data['status'] == 'pending';
                    return MangaPanel(
                      shadow: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['offeredComic'] as String? ??
                                'Truyện trao đổi',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${incoming ? 'Yêu cầu nhận được' : 'Yêu cầu đã gửi'} • ${data['status'] ?? 'pending'}',
                          ),
                          if (incoming && pending) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: () =>
                                      _database.respondExchangeRequest(
                                        requestId: doc.id,
                                        accepted: true,
                                      ),
                                  child: const Text('CHẤP NHẬN'),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      _database.respondExchangeRequest(
                                        requestId: doc.id,
                                        accepted: false,
                                      ),
                                  child: const Text('TỪ CHỐI'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
