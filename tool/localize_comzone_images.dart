import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Tải toàn bộ ảnh bìa và ảnh nội dung được tham chiếu trong seed ComZone.
///
/// Cách chạy:
/// `dart run tool/localize_comzone_images.dart seed.json asset-dir manifest.json`
Future<void> main(List<String> arguments) async {
  if (arguments.length != 3) {
    stderr.writeln(
      'Cách dùng: dart run tool/localize_comzone_images.dart '
      '<seed.json> <asset-dir> <manifest.json>',
    );
    exitCode = 64;
    return;
  }

  final seedFile = File(arguments[0]);
  final assetDirectory = Directory(arguments[1]);
  final manifestFile = File(arguments[2]);
  if (!seedFile.existsSync()) {
    stderr.writeln('Không tìm thấy seed: ${seedFile.path}');
    exitCode = 66;
    return;
  }
  assetDirectory.createSync(recursive: true);

  final seed = jsonDecode(seedFile.readAsStringSync()) as Map<String, dynamic>;
  final comics =
      (seed['collections'] as Map<String, dynamic>)['comics'] as List<dynamic>;
  final sourceUrls = <String>{};
  for (final value in comics) {
    final data =
        (value as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final cover = data['sourceImageUrl'] ?? data['image'];
    if (_isRemoteImageReference(cover)) sourceUrls.add('$cover');
    final previews = data['sourcePreviewImageUrls'] ?? data['previewImages'];
    if (previews is List) {
      sourceUrls.addAll(
        previews.where(_isRemoteImageReference).map((e) => '$e'),
      );
    }
  }

  final existing = _readExistingManifest(manifestFile);
  final results = <String, _DownloadResult>{};
  for (final entry in existing.entries) {
    if (File(entry.value.assetPath).existsSync()) {
      results[entry.key] = entry.value;
    }
  }
  final pending = sourceUrls.where((url) => !results.containsKey(url)).toList();
  stdout.writeln(
    'Tổng ${sourceUrls.length} URL ảnh; đã có ${results.length}; '
    'cần tải ${pending.length}.',
  );

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..idleTimeout = const Duration(seconds: 20)
    ..userAgent = 'ComZone-Firebase-Migration/1.0';
  var cursor = 0;
  var completed = 0;

  Future<void> worker() async {
    while (true) {
      final current = cursor++;
      if (current >= pending.length) return;
      final url = pending[current];
      results[url] = await _download(client, url, assetDirectory);
      completed++;
      if (completed % 25 == 0 || completed == pending.length) {
        stdout.writeln('Đã xử lý $completed/${pending.length} URL mới.');
      }
    }
  }

  await Future.wait(List.generate(8, (_) => worker()));
  client.close(force: true);

  var localizedCovers = 0;
  var localizedPreviews = 0;
  for (final value in comics) {
    final data =
        (value as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final cover = data['sourceImageUrl'] ?? data['image'];
    if (_isRemoteImageReference(cover)) {
      data['sourceImageUrl'] = '$cover';
      final result = results['$cover'];
      if (result?.success == true) {
        data['image'] = result!.assetPath;
        localizedCovers++;
      }
    }

    final sourcePreviews =
        data['sourcePreviewImageUrls'] ?? data['previewImages'];
    if (sourcePreviews is List) {
      final originals = sourcePreviews.map((item) => '$item').toList();
      data['sourcePreviewImageUrls'] = originals;
      data['previewImages'] = originals.map((url) {
        final result = results[url];
        if (result?.success == true) {
          localizedPreviews++;
          return result!.assetPath;
        }
        return url;
      }).toList();
    }
  }

  final localizedCoverByComicId = <String, String>{
    for (final value in comics)
      '${(value as Map<String, dynamic>)['id']}':
          '${(value['data'] as Map<String, dynamic>)['image'] ?? ''}',
  };
  final auctions =
      (seed['collections'] as Map<String, dynamic>)['auctions']
          as List<dynamic>? ??
      const <dynamic>[];
  for (final value in auctions) {
    final data =
        (value as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    data['coverImage'] = localizedCoverByComicId['${data['comicId']}'] ?? '';
  }

  seedFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(seed),
    flush: true,
  );
  final orderedResults = results.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  manifestFile.parent.createSync(recursive: true);
  manifestFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'source': seed['source'],
      'totalUrls': sourceUrls.length,
      'downloaded': results.values.where((item) => item.success).length,
      'failed': results.values.where((item) => !item.success).length,
      'items': [
        for (final entry in orderedResults) entry.value.toJson(entry.key),
      ],
    }),
    flush: true,
  );

  stdout.writeln('Đã nội bộ hóa $localizedCovers ảnh bìa.');
  stdout.writeln('Đã nội bộ hóa $localizedPreviews ảnh nội dung.');
  stdout.writeln('Manifest: ${manifestFile.path}');
}

bool _isRemoteImageReference(Object? value) {
  if (value is! String) return false;
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
}

Map<String, _DownloadResult> _readExistingManifest(File file) {
  if (!file.existsSync()) return {};
  try {
    final manifest =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final items = manifest['items'] as List<dynamic>? ?? const [];
    return {
      for (final value in items)
        if ((value as Map<String, dynamic>)['success'] == true)
          value['sourceUrl'] as String: _DownloadResult.fromJson(value),
    };
  } on Object {
    return {};
  }
}

Future<_DownloadResult> _download(
  HttpClient client,
  String sourceUrl,
  Directory output,
) async {
  try {
    final uri = Uri.parse(sourceUrl);
    if (_isPrivateHost(uri.host)) {
      return const _DownloadResult.failure('Địa chỉ nội bộ không được phép.');
    }
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'image/*');
    request.followRedirects = true;
    request.maxRedirects = 5;
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return _DownloadResult.failure('HTTP ${response.statusCode}');
    }

    final builder = BytesBuilder(copy: false);
    var size = 0;
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      size += chunk.length;
      if (size > 12 * 1024 * 1024) {
        throw const HttpException('File ảnh vượt quá 12 MB.');
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    final extension = _imageExtension(
      bytes,
      response.headers.contentType?.mimeType,
    );
    if (extension == null) {
      return const _DownloadResult.failure('Phản hồi không phải file ảnh.');
    }
    final filename = '${_fnv1a64(sourceUrl)}.$extension';
    final file = File('${output.path}/$filename');
    file.writeAsBytesSync(bytes, flush: true);
    return _DownloadResult.success(file.path, bytes.length);
  } on Object catch (error) {
    return _DownloadResult.failure('$error');
  }
}

bool _isPrivateHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1' ||
      normalized.endsWith('.local');
}

String? _imageExtension(Uint8List bytes, String? mimeType) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'jpg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'png';
  }
  if (bytes.length >= 6 && ascii.decode(bytes.sublist(0, 3)) == 'GIF') {
    return 'gif';
  }
  if (bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4)) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12)) == 'WEBP') {
    return 'webp';
  }
  return switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    _ => null,
  };
}

String _fnv1a64(String value) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  for (final byte in utf8.encode(value)) {
    hash ^= BigInt.from(byte);
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

class _DownloadResult {
  const _DownloadResult.success(this.assetPath, this.size)
    : success = true,
      error = null;

  const _DownloadResult.failure(this.error)
    : success = false,
      assetPath = '',
      size = 0;

  factory _DownloadResult.fromJson(Map<String, dynamic> json) =>
      _DownloadResult.success(
        json['assetPath'] as String,
        (json['size'] as num?)?.toInt() ?? 0,
      );

  final bool success;
  final String assetPath;
  final int size;
  final String? error;

  Map<String, Object?> toJson(String sourceUrl) => {
    'sourceUrl': sourceUrl,
    'success': success,
    if (success) 'assetPath': assetPath,
    if (success) 'size': size,
    if (!success) 'error': error,
  };
}
