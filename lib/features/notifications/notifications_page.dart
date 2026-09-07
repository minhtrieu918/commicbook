import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/features/notifications/announcement_assets.dart';
import 'package:commicbook/features/notifications/announcement_card.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'THÔNG BÁO',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: uid == null
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Bạn chưa đăng nhập',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _database.notificationsStream(uid),
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
                    icon: Icons.notifications_none_rounded,
                    assetPath: AnnouncementAssets.noNotification,
                    title: 'Chưa có thông báo',
                    message: 'Thông báo mới sẽ xuất hiện tại đây.',
                  );
                }
                final unreadCount = docs
                    .where((doc) => doc.data()['isRead'] != true)
                    .length;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
                      itemCount: docs.length + 1,
                      separatorBuilder: (_, index) =>
                          SizedBox(height: index == 0 ? 16 : 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _NotificationSummary(
                            totalCount: docs.length,
                            unreadCount: unreadCount,
                          );
                        }
                        final doc = docs[index - 1];
                        final data = doc.data();
                        final isRead = data['isRead'] == true;
                        return AnnouncementCard(
                          data: data,
                          isRead: isRead,
                          onTap: isRead
                              ? null
                              : () => _database.markNotificationRead(doc.id),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _NotificationSummary extends StatelessWidget {
  const _NotificationSummary({
    required this.totalCount,
    required this.unreadCount,
  });

  final int totalCount;
  final int unreadCount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('THÔNG BÁO CỦA BẠN', style: mangaDisplay(size: 25)),
            Text(
              '$totalCount thông báo trong danh sách',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      if (unreadCount > 0)
        Container(
          color: mangaYellow,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '$unreadCount CHƯA ĐỌC',
            style: const TextStyle(
              color: mangaInk,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
    ],
  );
}
