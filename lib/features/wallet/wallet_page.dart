import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/features/wallet/transaction_history_page.dart';
import 'package:commicbook/features/wallet/wallet_request_page.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'VÍ CỦA TÔI',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: uid == null
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Bạn chưa đăng nhập',
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _database.walletStream(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const NoDataState();
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.data!.exists) {
                  return const EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Chưa có dữ liệu ví',
                    message: 'Ví sẽ hiển thị khi tài khoản được cấp dữ liệu.',
                  );
                }
                final data = snapshot.data!.data() ?? {};
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView(
                      padding: const EdgeInsets.all(22),
                      children: [
                        MangaPanel(
                          color: mangaNavy,
                          shadow: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: mangaYellow,
                                size: 42,
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'SỐ DƯ HIỆN TẠI',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                _money(data['balance'] as num? ?? 0),
                                style: mangaDisplay(
                                  size: 34,
                                  color: mangaYellow,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Có thể rút: ${_money(data['withdrawableBalance'] as num? ?? 0)}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'Đang tạm giữ: ${_money(data['nonWithdrawableBalance'] as num? ?? 0)}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WalletRequestPage(
                                      type: 'deposit',
                                      availableAmount:
                                          data['balance'] as num? ?? 0,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.add_card_rounded),
                                label: const Text('NẠP TIỀN'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WalletRequestPage(
                                      type: 'withdraw',
                                      availableAmount:
                                          data['withdrawableBalance'] as num? ??
                                          0,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.outbox_rounded),
                                label: const Text('RÚT TIỀN'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransactionHistoryPage(),
                            ),
                          ),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Padding(
                            padding: EdgeInsets.all(13),
                            child: Text('XEM LỊCH SỬ GIAO DỊCH'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

String _money(num value) {
  final digits = value.round().toString();
  final result = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) result.write('.');
    result.write(digits[index]);
  }
  return '$resultđ';
}
