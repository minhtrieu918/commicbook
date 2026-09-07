import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'LỊCH SỬ GIAO DỊCH',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: uid == null
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Bạn chưa đăng nhập',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _database.walletTransactionsStream(uid),
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
                    icon: Icons.receipt_long_outlined,
                    title: 'Chưa có giao dịch',
                    message: 'Biến động ví sẽ xuất hiện tại đây.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final amount = data['amount'] as num? ?? 0;
                    return MangaPanel(
                      shadow: false,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          amount >= 0
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          color: amount >= 0 ? mangaGreen : mangaRed,
                        ),
                        title: Text(
                          data['description'] as String? ?? 'Giao dịch ví',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(_date(data['createdAt'])),
                        trailing: Text(
                          _money(amount),
                          style: mangaMono(
                            size: 12,
                            color: amount >= 0 ? mangaGreen : mangaRed,
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

String _date(dynamic value) {
  if (value is! Timestamp) return 'Đang cập nhật';
  final date = value.toDate();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _money(num value) {
  final sign = value > 0 ? '+' : '';
  final digits = value.abs().round().toString();
  final result = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) result.write('.');
    result.write(digits[index]);
  }
  return '$sign$resultđ';
}
