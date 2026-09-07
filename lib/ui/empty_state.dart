import 'package:commicbook/ui/manga_theme.dart';
import 'package:flutter/material.dart';

/// Trạng thái rỗng dùng thống nhất cho các màn không có dữ liệu để hiển thị.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.compact = false,
    this.assetPath,
  });

  final IconData icon;
  final String title;
  final String? message;
  final bool compact;
  final String? assetPath;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: compact ? 12 : 36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assetPath == null)
              Container(
                width: compact ? 58 : 76,
                height: compact ? 58 : 76,
                decoration: BoxDecoration(
                  color: mangaSky.withValues(alpha: .35),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: compact ? 30 : 40, color: mangaNavy),
              )
            else
              Image.asset(
                assetPath!,
                key: const Key('empty-state-asset'),
                width: compact ? 90 : 250,
                height: compact ? 72 : 180,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    Icon(icon, size: compact ? 30 : 40, color: mangaNavy),
              ),
            SizedBox(height: compact ? 10 : 16),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: mangaDisplay(size: compact ? 19 : 24, color: mangaNavy),
            ),
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Trạng thái dùng khi truy vấn không trả về dữ liệu khả dụng.
/// Không hiển thị mã lỗi hoặc chi tiết kỹ thuật từ backend.
class NoDataState extends StatelessWidget {
  const NoDataState({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.inbox_outlined,
    title: 'Không có dữ liệu',
    message: 'Hiện chưa có dữ liệu để hiển thị.',
    compact: compact,
  );
}
