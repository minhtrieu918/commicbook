import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Tải các ảnh bìa đã được đối chiếu bằng Google Images và cập nhật seed.
///
/// Cách chạy:
/// `dart run tool/import_google_comic_images.dart <seed.json> <mapping.json> `
/// `<asset-dir> <manifest.json>`
Future<void> main(List<String> arguments) async {
  if (arguments.length != 4) {
    stderr.writeln(
      'Cách dùng: dart run tool/import_google_comic_images.dart '
      '<seed.json> <mapping.json> <asset-dir> <manifest.json>',
    );
    exitCode = 64;
    return;
  }

  final seedFile = File(arguments[0]);
  final mappingFile = File(arguments[1]);
  final assetDirectory = Directory(arguments[2]);
  final manifestFile = File(arguments[3]);
  if (!seedFile.existsSync() || !mappingFile.existsSync()) {
    stderr.writeln('Không tìm thấy seed hoặc danh sách ảnh Google.');
    exitCode = 66;
    return;
  }

  assetDirectory.createSync(recursive: true);
  final seed = jsonDecode(seedFile.readAsStringSync()) as Map<String, dynamic>;
  final mappings = (jsonDecode(mappingFile.readAsStringSync()) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final comics =
      (seed['collections'] as Map<String, dynamic>)['comics'] as List<dynamic>;
  final comicById = <String, Map<String, dynamic>>{
    for (final value in comics)
      '${(value as Map<String, dynamic>)['id']}':
          value['data'] as Map<String, dynamic>,
  };

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..idleTimeout = const Duration(seconds: 20)
    ..userAgent = 'Mozilla/5.0 (compatible; ComZone image importer/1.0)';
  final results = List<_ImportResult?>.filled(mappings.length, null);
  var cursor = 0;
  var completed = 0;

  Future<void> worker() async {
    while (true) {
      final index = cursor++;
      if (index >= mappings.length) return;
      final mapping = mappings[index];
      results[index] = await _importOne(
        client: client,
        mapping: mapping,
        output: assetDirectory,
      );
      completed++;
      if (completed % 20 == 0 || completed == mappings.length) {
        stdout.writeln('Đã xử lý $completed/${mappings.length} ảnh.');
      }
    }
  }

  await Future.wait(List.generate(4, (_) => worker()));
  client.close(force: true);

  var updated = 0;
  for (var index = 0; index < mappings.length; index++) {
    final mapping = mappings[index];
    final result = results[index]!;
    final comic = comicById['${mapping['id']}'];
    if (comic == null || !result.success) continue;

    final currentImage = '${comic['image'] ?? ''}';
    if (_isRemoteUrl(currentImage)) {
      comic['sourceImageUrl'] = currentImage;
    }
    comic['image'] = result.assetPath;
    comic['googleImageSearchUrl'] = '${mapping['searchUrl'] ?? ''}';
    comic['googleImageResultTitle'] =
        '${(mapping['candidate'] as Map<String, dynamic>?)?['alt'] ?? ''}';
    comic['googleImageUrl'] = result.sourceUrl;
    updated++;
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
  manifestFile.parent.createSync(recursive: true);
  manifestFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'source': 'Google Images searches by comic title',
      'total': mappings.length,
      'downloaded': results.where((item) => item?.success == true).length,
      'failed': results.where((item) => item?.success != true).length,
      'items': [
        for (var index = 0; index < mappings.length; index++)
          results[index]!.toJson(mappings[index]),
      ],
    }),
    flush: true,
  );

  stdout.writeln('Đã cập nhật $updated/${mappings.length} ảnh bìa truyện.');
  stdout.writeln('Manifest: ${manifestFile.path}');
  if (updated != mappings.length) exitCode = 1;
}

Future<_ImportResult> _importOne({
  required HttpClient client,
  required Map<String, dynamic> mapping,
  required Directory output,
}) async {
  final id = '${mapping['id'] ?? ''}';
  final candidate = mapping['candidate'] as Map<String, dynamic>?;
  final sourceUrl = '${candidate?['src'] ?? ''}';
  if (id.isEmpty || !_isRemoteUrl(sourceUrl)) {
    return _ImportResult.failure(sourceUrl, 'Thiếu mã truyện hoặc URL ảnh.');
  }

  try {
    final request = await client.getUrl(Uri.parse(sourceUrl));
    request.headers.set(HttpHeaders.acceptHeader, 'image/*');
    request.followRedirects = true;
    request.maxRedirects = 5;
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return _ImportResult.failure(sourceUrl, 'HTTP ${response.statusCode}');
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
    if (bytes.length < 2048) {
      return _ImportResult.failure(sourceUrl, 'File ảnh quá nhỏ.');
    }
    final extension = _imageExtension(
      bytes,
      response.headers.contentType?.mimeType,
    );
    if (extension == null) {
      return _ImportResult.failure(sourceUrl, 'Phản hồi không phải file ảnh.');
    }

    final filename = 'google-$id.$extension';
    final file = File('${output.path}/$filename');
    file.writeAsBytesSync(bytes, flush: true);
    return _ImportResult.success(
      sourceUrl,
      '${output.path}/$filename',
      bytes.length,
    );
  } on Object catch (error) {
    return _ImportResult.failure(sourceUrl, '$error');
  }
}

bool _isRemoteUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
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

class _ImportResult {
  const _ImportResult.success(this.sourceUrl, this.assetPath, this.size)
    : success = true,
      error = null;

  const _ImportResult.failure(this.sourceUrl, this.error)
    : success = false,
      assetPath = '',
      size = 0;

  final bool success;
  final String sourceUrl;
  final String assetPath;
  final int size;
  final String? error;

  Map<String, dynamic> toJson(Map<String, dynamic> mapping) => {
    'comicId': '${mapping['id'] ?? ''}',
    'title': '${mapping['title'] ?? ''}',
    'previousImageUrl': '${mapping['image'] ?? ''}',
    'searchUrl': '${mapping['searchUrl'] ?? ''}',
    'resultTitle':
        '${(mapping['candidate'] as Map<String, dynamic>?)?['alt'] ?? ''}',
    'sourceUrl': sourceUrl,
    'success': success,
    'assetPath': assetPath,
    'size': size,
    if (error != null) 'error': error,
  };
}
