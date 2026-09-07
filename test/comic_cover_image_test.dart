import 'dart:convert';
import 'dart:io';

import 'package:commicbook/ui/comic_cover_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('thư viện create-comics chứa đủ 12 ảnh từ source', () {
    expect(ComicTemplateAssets.all, hasLength(12));
    for (final path in ComicTemplateAssets.all) {
      expect(File(path).existsSync(), isTrue, reason: 'Thiếu asset $path');
    }
  });

  test('manifest ghi nhận đầy đủ kết quả tải URL ảnh truyện', () {
    final manifest =
        jsonDecode(
              File(
                'assets/data/comzone_image_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(manifest['totalUrls'], 471);
    expect(manifest['downloaded'], 42);
    expect(manifest['failed'], 429);
    final downloaded = (manifest['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((item) => item['success'] == true);
    for (final item in downloaded) {
      expect(File(item['assetPath'] as String).existsSync(), isTrue);
    }
  });

  testWidgets('ComicCoverImage hiển thị được ảnh asset nội bộ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 140,
            height: 190,
            child: ComicCoverImage(
              source: ComicTemplateAssets.all.first,
              fallbackColor: Colors.purple,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
