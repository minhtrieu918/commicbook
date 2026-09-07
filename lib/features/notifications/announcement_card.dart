import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/features/notifications/announcement_assets.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:flutter/material.dart';

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.data,
    required this.isRead,
    this.onTap,
  });

  final Map<String, dynamic> data;
  final bool isRead;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] as String? ?? '').trim();
    final content =
        (data['content'] as String? ?? data['message'] as String? ?? '').trim();
    return MangaPanel(
      padding: EdgeInsets.zero,
      borderWidth: 2,
      shadow: !isRead,
      color: isRead ? Colors.white : const Color(0xFFFFFBEC),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 56,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isRead
                        ? mangaMuted
                        : mangaYellow.withValues(alpha: .35),
                    border: Border.all(color: mangaInk, width: 1.5),
                  ),
                  child: AnnouncementIcon(type: data['type'], size: 42),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title.isEmpty ? 'THÔNG BÁO' : title.toUpperCase(),
                              style: const TextStyle(
                                color: mangaInk,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            Container(
                              color: mangaRed,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              child: const Text(
                                'MỚI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          content,
                          style: const TextStyle(
                            color: Colors.black87,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _date(data['createdAt']),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _date(dynamic value) {
  final date = switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    String text => DateTime.tryParse(text),
    _ => null,
  };
  if (date == null) return 'Thời gian đang cập nhật';
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(date.hour)}:${twoDigits(date.minute)} • '
      '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
}
