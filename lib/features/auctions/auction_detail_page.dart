import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:commicbook/features/auctions/auction_rules.dart';
import 'package:commicbook/service/auction_service.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/comic_cover_image.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();
final _auctionService = AuctionService();

class AuctionDetailPage extends StatefulWidget {
  const AuctionDetailPage({super.key, required this.auctionId});

  final String auctionId;

  @override
  State<AuctionDetailPage> createState() => _AuctionDetailPageState();
}

class _AuctionDetailPageState extends State<AuctionDetailPage> {
  final _amount = TextEditingController();
  Timer? _timer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_auctionService.sync(widget.auctionId).catchError((_) {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _loading = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Không thể thực hiện.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _bid(num minimum) async {
    final amount = num.tryParse(_amount.text.replaceAll('.', '').trim());
    if (amount == null || amount < minimum) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Giá tối thiểu là ${_money(minimum)}.')),
      );
      return;
    }
    await _run(
      () => _auctionService.bid(auctionId: widget.auctionId, amount: amount),
      'Đặt giá thành công.',
    );
    _amount.clear();
  }

  Future<void> _buyNow(num price) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận mua ngay'),
        content: Text(
          'Bạn sẽ thắng phiên với giá ${_money(price)} và phải thanh toán trước hạn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('HỦY'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('MUA NGAY'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await _run(
      () => _auctionService.buyNow(widget.auctionId),
      'Bạn đã mua ngay thành công. Vui lòng thanh toán trước hạn.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: mangaInk,
      foregroundColor: Colors.white,
      title: Text(
        'CHI TIẾT ĐẤU GIÁ',
        style: mangaDisplay(size: 22, color: mangaYellow),
      ),
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _database.auctionStream(widget.auctionId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const NoDataState();
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.data!.exists) {
          return const EmptyState(
            icon: Icons.gavel_outlined,
            title: 'Phiên đấu giá không tồn tại',
          );
        }
        final data = snapshot.data!.data() ?? {};
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          return const EmptyState(
            icon: Icons.lock_outline,
            title: 'Bạn chưa đăng nhập',
          );
        }
        final status = effectiveAuctionStatus(data);
        final currentBid = data['currentBid'] as num? ?? 0;
        final minimum = minimumNextBid(data);
        final endAt = auctionDate(data['endAt']);
        final startAt = auctionDate(data['startAt']);
        final active =
            status == AuctionStatus.active &&
            startAt != null &&
            !startAt.isAfter(DateTime.now()) &&
            endAt != null &&
            endAt.isAfter(DateTime.now());
        final seller = data['sellerUid'] == uid;
        final winner = data['winnerUid'] == uid;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _database.auctionDepositStream(
            auctionId: widget.auctionId,
            uid: uid,
          ),
          builder: (context, depositSnapshot) {
            final depositStatus =
                depositSnapshot.data?.data()?['status'] as String?;
            final deposited =
                depositStatus == AuctionDepositStatus.holding ||
                depositStatus == 'completed';
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    MangaPanel(
                      shadow: false,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cover = SizedBox(
                            width: 130,
                            height: 180,
                            child: ComicCoverImage(
                              source: data['coverImage'] as String? ?? '',
                              fallbackColor: mangaNavy,
                            ),
                          );
                          final information = _AuctionInformation(
                            data: data,
                            status: status,
                            currentBid: currentBid,
                            startAt: startAt,
                            endAt: endAt,
                          );
                          if (constraints.maxWidth < 560) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                cover,
                                const SizedBox(height: 16),
                                information,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cover,
                              const SizedBox(width: 18),
                              Expanded(child: information),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (winner && status == AuctionStatus.successful)
                      _WinnerPayment(
                        deadline: auctionDate(data['paymentDeadline']),
                        loading: _loading,
                        onPay: () => _run(
                          () => _auctionService.pay(widget.auctionId),
                          'Thanh toán thành công. Đơn hàng đã được tạo.',
                        ),
                      )
                    else if (active && !seller)
                      MangaPanel(
                        shadow: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THAM GIA ĐẤU GIÁ',
                              style: mangaDisplay(size: 22),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              deposited
                                  ? 'Tiền cọc đang được giữ trong ví.'
                                  : 'Tiền cọc: ${_money(data['depositAmount'] as num? ?? 0)}',
                              style: TextStyle(
                                color: deposited ? mangaGreen : mangaRed,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (!deposited)
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : () => _run(
                                          () => _auctionService.deposit(
                                            widget.auctionId,
                                          ),
                                          'Đặt cọc thành công. Bạn có thể ra giá.',
                                        ),
                                  icon: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                  label: const Padding(
                                    padding: EdgeInsets.all(13),
                                    child: Text('ĐẶT CỌC BẰNG VÍ'),
                                  ),
                                ),
                              )
                            else ...[
                              TextField(
                                controller: _amount,
                                enabled: !_loading,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Giá tối thiểu ${_money(minimum)}',
                                  prefixIcon: const Icon(
                                    Icons.payments_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : () => _bid(minimum),
                                  icon: const Icon(Icons.gavel_rounded),
                                  label: const Padding(
                                    padding: EdgeInsets.all(13),
                                    child: Text('XÁC NHẬN ĐẶT GIÁ'),
                                  ),
                                ),
                              ),
                              if (data['buyNowPrice'] is num) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _loading
                                        ? null
                                        : () => _buyNow(
                                            data['buyNowPrice'] as num,
                                          ),
                                    icon: const Icon(Icons.bolt_rounded),
                                    label: Padding(
                                      padding: const EdgeInsets.all(13),
                                      child: Text(
                                        'MUA NGAY ${_money(data['buyNowPrice'] as num)}',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    _BidHistory(auctionId: widget.auctionId),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _AuctionInformation extends StatelessWidget {
  const _AuctionInformation({
    required this.data,
    required this.status,
    required this.currentBid,
    required this.startAt,
    required this.endAt,
  });

  final Map<String, dynamic> data;
  final String status;
  final num currentBid;
  final DateTime? startAt;
  final DateTime? endAt;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        data['title'] as String? ?? 'Phiên đấu giá',
        style: mangaDisplay(size: 28, color: mangaNavy),
      ),
      const SizedBox(height: 8),
      Text(
        AuctionStatus.label(status).toUpperCase(),
        style: TextStyle(
          color: status == AuctionStatus.active ? mangaGreen : mangaRed,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 14),
      const Text('GIÁ HIỆN TẠI'),
      Text(_money(currentBid), style: mangaMono(size: 23, color: mangaRed)),
      Text('${data['bidCount'] ?? 0} lượt đặt giá'),
      if (status == AuctionStatus.upcoming && startAt != null)
        Text('Bắt đầu sau: ${_remaining(startAt!)}')
      else if (status == AuctionStatus.active && endAt != null)
        Text('Còn lại: ${_remaining(endAt!)}')
      else if (endAt != null)
        Text('Kết thúc: ${_date(endAt!)}'),
      if (data['winnerUid'] is String)
        Text(
          'Người thắng: ${_maskedUid(data['winnerUid'] as String)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
    ],
  );
}

class _WinnerPayment extends StatelessWidget {
  const _WinnerPayment({
    required this.deadline,
    required this.loading,
    required this.onPay,
  });

  final DateTime? deadline;
  final bool loading;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) => MangaPanel(
    color: mangaYellow,
    shadow: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BẠN ĐÃ THẮNG', style: mangaDisplay(size: 24)),
        const SizedBox(height: 6),
        Text(
          deadline == null
              ? 'Vui lòng thanh toán trước hạn.'
              : 'Hạn thanh toán: ${_date(deadline!)}. Quá hạn sẽ mất tiền cọc.',
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: loading ? null : onPay,
            icon: const Icon(Icons.account_balance_wallet_rounded),
            label: const Padding(
              padding: EdgeInsets.all(13),
              child: Text('THANH TOÁN BẰNG VÍ'),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BidHistory extends StatelessWidget {
  const _BidHistory({required this.auctionId});
  final String auctionId;

  @override
  Widget build(BuildContext context) => MangaPanel(
    shadow: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LỊCH SỬ RA GIÁ', style: mangaDisplay(size: 22)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _database.bidsOfAuction(auctionId),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const NoDataState(compact: true);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final bids = snapshot.data!.docs;
            if (bids.isEmpty) {
              return const EmptyState(
                compact: true,
                icon: Icons.history_rounded,
                title: 'Không có dữ liệu',
                message: 'Chưa có lượt ra giá.',
              );
            }
            return Column(
              children: bids.map((doc) {
                final data = doc.data();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(_maskedUid(data['userId'] as String? ?? '')),
                  subtitle: Text(_date(auctionDate(data['createdAt']))),
                  trailing: Text(
                    _money(data['amount'] as num? ?? 0),
                    style: mangaMono(size: 12, color: mangaRed),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ),
  );
}

String _maskedUid(String uid) {
  if (uid.length <= 6) return 'Người tham gia';
  return '${uid.substring(0, 3)}***${uid.substring(uid.length - 3)}';
}

String _money(num value) {
  final digits = value.round().toString();
  return '${digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
}

String _date(DateTime? value) {
  if (value == null) return 'Đang cập nhật';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
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
