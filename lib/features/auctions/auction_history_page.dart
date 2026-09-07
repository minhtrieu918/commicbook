import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/features/auctions/auction_detail_page.dart';
import 'package:commicbook/features/auctions/auction_rules.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class AuctionHistoryPage extends StatelessWidget {
  const AuctionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'LỊCH SỬ ĐẤU GIÁ',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: uid == null
          ? const EmptyState(
              icon: Icons.lock_outline,
              title: 'Bạn chưa đăng nhập',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _database.auctionDepositsOf(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const NoDataState();
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final deposits = snapshot.data!.docs;
                if (deposits.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Không có dữ liệu',
                    message: 'Bạn chưa tham gia phiên đấu giá nào.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: deposits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final deposit = deposits[index].data();
                    final auctionId = deposit['auctionId'] as String? ?? '';
                    return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: _database.auctionStream(auctionId),
                      builder: (context, auctionSnapshot) {
                        if (!auctionSnapshot.hasData) {
                          return const MangaPanel(
                            shadow: false,
                            child: LinearProgressIndicator(),
                          );
                        }
                        final auction = auctionSnapshot.data?.data() ?? {};
                        final status = effectiveAuctionStatus(auction);
                        final winner = auction['winnerUid'] == uid;
                        return MangaPanel(
                          shadow: false,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              winner
                                  ? Icons.emoji_events_rounded
                                  : Icons.gavel_rounded,
                              color: winner ? mangaYellow : mangaNavy,
                            ),
                            title: Text(
                              auction['title'] as String? ?? 'Phiên đấu giá',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              [
                                winner
                                    ? 'Bạn là người thắng'
                                    : AuctionStatus.label(status),
                                'Cọc: ${_depositLabel(deposit['status'] as String? ?? '')}',
                                'Mức hiện tại: ${_money(auction['currentBid'] as num? ?? 0)}',
                              ].join(' • '),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: auctionId.isEmpty
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AuctionDetailPage(
                                        auctionId: auctionId,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

String _depositLabel(String status) => switch (status) {
  AuctionDepositStatus.holding || 'completed' => 'Đang giữ',
  AuctionDepositStatus.refunded => 'Đã hoàn',
  AuctionDepositStatus.used => 'Đã dùng thanh toán',
  AuctionDepositStatus.seized => 'Bị thu giữ',
  _ => 'Đang cập nhật',
};

String _money(num value) {
  final digits = value.round().toString();
  return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
}
