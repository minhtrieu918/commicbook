import 'package:flutter/material.dart';

abstract final class ComicTemplateAssets {
  static const root = 'assets/create-comics';

  static const all = <String>[
    '$root/81a9xLAmIxL.jpg',
    '$root/c2b9e59a-453c-4736-8945-99350c18d435.jpg',
    '$root/kny4365413424.jpg',
    '$root/naruto-tap-63-02_8b0691abe8ea45ae9823898669da8435_ba120370bb67482d947650c643631b96.jpg',
    '$root/q9h6hen6hhj71.jpg',
    '$root/tumblr_99c5c0ccafe338e03aadc8d18bc3c4fc_5db995e4_540.jpg',
    '$root/naruto2.jpg',
    '$root/jjks1.jpg',
    '$root/sdo1.jpg',
    '$root/op2.jpg',
    '$root/kny2.jpg',
    '$root/dragonball.jpeg',
  ];
}

/// Hiển thị thống nhất ảnh truyện từ URL hoặc asset nội bộ.
class ComicCoverImage extends StatelessWidget {
  const ComicCoverImage({
    super.key,
    required this.source,
    required this.fallbackColor,
    this.fit = BoxFit.cover,
    this.fallbackIconSize = 54,
  });

  final String source;
  final Color fallbackColor;
  final BoxFit fit;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final value = source.trim();
    if (value.isEmpty) return _fallback();
    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: fit,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return Image.network(
      value,
      fit: fit,
      errorBuilder: (_, _, _) => _fallback(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback(loading: true),
    );
  }

  Widget _fallback({bool loading = false}) => Container(
    color: fallbackColor,
    alignment: Alignment.center,
    child: loading
        ? const CircularProgressIndicator(color: Colors.white)
        : Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: fallbackIconSize,
          ),
  );
}
