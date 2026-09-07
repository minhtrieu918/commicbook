import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> seed;

  setUpAll(() {
    seed =
        jsonDecode(
              File('assets/data/comzone_public_seed.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  test('seed ComZone chứa đúng dữ liệu nguồn đã chuyển đổi', () {
    final collections = seed['collections'] as Map<String, dynamic>;
    expect(collections['comics'], hasLength(116));
    expect(collections['comic_genres'], hasLength(20));
    expect(collections['auctions'], hasLength(20));
    expect(collections['exchange_posts'], isEmpty);
  });

  test('seed ComZone không chứa trường xác thực hoặc dữ liệu riêng tư', () {
    const forbiddenKeys = {
      'email',
      'password',
      'phone',
      'refresh_token',
      'device_id',
      'otp',
      'address',
      'bankAccount',
    };
    final found = <String>{};

    void visit(dynamic value) {
      if (value is Map) {
        for (final entry in value.entries) {
          if (forbiddenKeys.contains(entry.key)) found.add('${entry.key}');
          visit(entry.value);
        }
      } else if (value is List) {
        for (final item in value) {
          visit(item);
        }
      }
    }

    visit(seed['collections']);
    expect(found, isEmpty);
  });

  test('toàn bộ truyện dùng ảnh bìa nội bộ tồn tại trong assets', () {
    final collections = seed['collections'] as Map<String, dynamic>;
    final comics = collections['comics'] as List<dynamic>;

    for (final value in comics) {
      final comic = value as Map<String, dynamic>;
      final data = comic['data'] as Map<String, dynamic>;
      final image = '${data['image'] ?? ''}';
      expect(
        image,
        startsWith('assets/'),
        reason: 'Ảnh của truyện ${data['title']} chưa được nội bộ hóa.',
      );
      expect(
        File(image).existsSync(),
        isTrue,
        reason: 'Không tìm thấy ảnh của truyện ${data['title']}: $image',
      );
    }
  });

  test('manifest ảnh Google ghi nhận đủ các truyện được bổ sung', () {
    final manifest =
        jsonDecode(
              File(
                'assets/data/google_image_supplement_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    expect(manifest['total'], 99);
    expect(manifest['downloaded'], 99);
    expect(manifest['failed'], 0);
    expect(manifest['items'], hasLength(99));
  });
}
