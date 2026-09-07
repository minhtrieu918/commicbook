import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:commicbook/features/auctions/auction_detail_page.dart';
import 'package:commicbook/features/auctions/auction_rules.dart';
import 'package:commicbook/seller/seller_create_auction.dart';
import 'package:commicbook/service/auction_service.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();
final _auctionService = AuctionService();

class SellerAuctionsPage extends StatelessWidget {
  const SellerAuctionsPage({super.key});

  Future<void> _cancel(BuildContext context, String auctionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dừng phiên đấu giá?'),
        content: const Text(
          'Tiền cọc đang giữ sẽ được hoàn lại. Người đã tham gia sẽ nhận thông báo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KHÔNG'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DỪNG PHIÊN'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await _auctionService.cancel(auctionId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã dừng phiên đấu giá.')));
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Không thể dừng phiên.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Bạn chưa đăng nhập',
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _database.sellerAuctionRequestsStream(uid),
      builder: (context, requestSnapshot) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _database.sellerAuctionsStream(uid),
            builder: (context, auctionSnapshot) {
              if (requestSnapshot.hasError || auctionSnapshot.hasError) {
                return const NoDataState();
              }
              if (!requestSnapshot.hasData || !auctionSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final requests = requestSnapshot.data!.docs;
              final auctions = auctionSnapshot.data!.docs;
              return ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ĐẤU GIÁ CỦA TÔI',
                          style: mangaDisplay(size: 28, color: mangaNavy),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SellerCreateAuctionPage(),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('TẠO YÊU CẦU'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('YÊU CẦU DUYỆT', style: mangaDisplay(size: 20)),
                  const SizedBox(height: 10),
                  if (requests.isEmpty)
                    const EmptyState(
                      compact: true,
                      icon: Icons.fact_check_outlined,
                      title: 'Không có dữ liệu',
                      message: 'Chưa có yêu cầu đấu giá.',
                    )
                  else
                    ...requests.map((doc) => _RequestCard(data: doc.data())),
                  const SizedBox(height: 22),
                  Text('PHIÊN ĐẤU GIÁ', style: mangaDisplay(size: 20)),
                  const SizedBox(height: 10),
                  if (auctions.isEmpty)
                    const EmptyState(
                      compact: true,
                      icon: Icons.gavel_outlined,
                      title: 'Không có dữ liệu',
                      message: 'Chưa có phiên đấu giá đã được duyệt.',
                    )
                  else
                    ...auctions.map((doc) {
                      final data = doc.data();
                      final status = data['status'] as String? ?? '';
                      final canStop =
                          status == AuctionStatus.upcoming ||
                          status == AuctionStatus.active;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: MangaPanel(
                          shadow: false,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.gavel_rounded,
                              color: mangaNavy,
                            ),
                            title: Text(
                              data['title'] as String? ?? 'Phiên đấu giá',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              '${AuctionStatus.label(status)} • ${data['bidCount'] ?? 0} lượt giá',
                            ),
                            trailing: canStop
                                ? IconButton(
                                    tooltip: 'Dừng đấu giá',
                                    onPressed: () => _cancel(context, doc.id),
                                    icon: const Icon(
                                      Icons.stop_circle_outlined,
                                    ),
                                  )
                                : null,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AuctionDetailPage(auctionId: doc.id),
                              ),
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
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? AuctionStatus.pending;
    final reason = data['rejectionReason'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MangaPanel(
        shadow: false,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.fact_check_outlined, color: mangaNavy),
          title: Text(
            data['title'] as String? ?? 'Yêu cầu đấu giá',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            [
              '${data['durationDays'] ?? 1} ngày',
              AuctionStatus.label(status),
              if (reason != null && reason.isNotEmpty) 'Lý do: $reason',
            ].join(' • '),
          ),
        ),
      ),
    );
  }
}
