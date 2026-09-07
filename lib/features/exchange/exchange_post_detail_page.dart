import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class ExchangePostDetailPage extends StatefulWidget {
  const ExchangePostDetailPage({
    super.key,
    required this.postId,
    required this.data,
  });

  final String postId;
  final Map<String, dynamic> data;

  @override
  State<ExchangePostDetailPage> createState() => _ExchangePostDetailPageState();
}

class _ExchangePostDetailPageState extends State<ExchangePostDetailPage> {
  Future<void> _requestExchange() async {
    final offered = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi yêu cầu trao đổi'),
        content: TextField(
          controller: offered,
          decoration: const InputDecoration(
            labelText: 'Truyện bạn đề nghị trao đổi',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('HỦY'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, offered.text.trim()),
            child: const Text('GỬI'),
          ),
        ],
      ),
    );
    offered.dispose();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final recipientUid = widget.data['userId'] as String?;
    if (value == null || value.isEmpty || uid == null || recipientUid == null) {
      return;
    }
    await _database.createExchangeRequest(
      postId: widget.postId,
      requesterUid: uid,
      recipientUid: recipientUid,
      offeredComic: value,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu trao đổi.')));
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'CHI TIẾT TRAO ĐỔI',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              MangaPanel(
                shadow: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] as String? ?? 'Bài trao đổi',
                      style: mangaDisplay(size: 28, color: mangaNavy),
                    ),
                    const SizedBox(height: 14),
                    _row('Truyện đề nghị', data['offeredComic']),
                    _row('Tác giả', data['author']),
                    _row('Tình trạng', data['condition']),
                    _row('Liên hệ', data['contactDetails']),
                    const SizedBox(height: 14),
                    Text(data['content'] as String? ?? ''),
                    if (currentUid != data['userId']) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _requestExchange,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Padding(
                            padding: EdgeInsets.all(13),
                            child: Text('GỬI YÊU CẦU TRAO ĐỔI'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text('$label: ${value ?? 'Chưa có'}'),
  );
}
