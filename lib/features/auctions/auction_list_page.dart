import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/features/auctions/auction_detail_page.dart';
import 'package:commicbook/features/auctions/auction_rules.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/comic_cover_image.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class AuctionListPage extends StatefulWidget {
  const AuctionListPage({super.key});

  @override
  State<AuctionListPage> createState() => _AuctionListPageState();
}

class _AuctionListPageState extends State<AuctionListPage> {
  Timer? _timer;
  String _filter = 'current';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: mangaInk,
      foregroundColor: Colors.white,
      title: Text(
        'PHIÊN ĐẤU GIÁ',
        style: mangaDisplay(size: 22, color: mangaYellow),
      ),
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _database.auctionsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const NoDataState();
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((doc) {
          final status = effectiveAuctionStatus(doc.data());
          return switch (_filter) {
            'current' => status == AuctionStatus.active,
            'upcoming' => status == AuctionStatus.upcoming,
            _ =>
              status == AuctionStatus.successful ||
                  status == AuctionStatus.completed ||
                  status == AuctionStatus.failed ||
                  status == AuctionStatus.cancelled ||
                  status == AuctionStatus.stopped,
          };
        }).toList();
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'current', label: Text('ĐANG DIỄN RA')),
                  ButtonSegment(value: 'upcoming', label: Text('SẮP DIỄN RA')),
                  ButtonSegment(value: 'ended', label: Text('ĐÃ KẾT THÚC')),
                ],
                selected: {_filter},
                onSelectionChanged: (value) {
                  setState(() => _filter = value.first);
                },
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? const EmptyState(
                      icon: Icons.gavel_outlined,
                      title: 'Không có dữ liệu',
                      message: 'Không có phiên đấu giá phù hợp với bộ lọc.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final status = effectiveAuctionStatus(data);
                        final target = status == AuctionStatus.upcoming
                            ? auctionDate(data['startAt'])
                            : auctionDate(data['endAt']);
                        return MangaPanel(
                          shadow: false,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: SizedBox(
                              width: 54,
                              height: 72,
                              child: ComicCoverImage(
                                source: data['coverImage'] as String? ?? '',
                                fallbackColor: mangaNavy,
                                fallbackIconSize: 26,
                              ),
                            ),
                            title: Text(
                              data['title'] as String? ?? 'Phiên đấu giá',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              [
                                AuctionStatus.label(status),
                                if (target != null &&
                                    (status == AuctionStatus.active ||
                                        status == AuctionStatus.upcoming))
                                  _remaining(target),
                                '${data['bidCount'] ?? 0} lượt',
                              ].join(' • '),
                            ),
                            trailing: Text(
                              _money(data['currentBid'] as num? ?? 0),
                              style: mangaMono(size: 12, color: mangaRed),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AuctionDetailPage(auctionId: doc.id),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}

String _remaining(DateTime target) {
  final duration = target.difference(DateTime.now());
  if (duration.isNegative) return '00:00:00';
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24).toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return days > 0
      ? '$days ngày $hours:$minutes:$seconds'
      : '$hours:$minutes:$seconds';
}

String _money(num value) {
  final digits = value.round().toString();
  return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
}
