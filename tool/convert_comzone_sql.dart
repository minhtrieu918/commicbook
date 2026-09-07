import 'dart:convert';
import 'dart:io';

/// Chuyển dump MySQL của ComZone thành seed JSON an toàn cho ứng dụng.
///
/// Cách chạy:
/// `dart run tool/convert_comzone_sql.dart dump.sql seed.json`
///
/// Công cụ chỉ xuất dữ liệu nghiệp vụ/công khai. Email, số điện thoại, mật
/// khẩu, token, OTP, địa chỉ, tài khoản ngân hàng và lịch sử tài chính không
/// được đưa vào asset của ứng dụng.
void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Cách dùng: dart run tool/convert_comzone_sql.dart '
      '<dump.sql> <seed.json>',
    );
    exitCode = 64;
    return;
  }

  final input = File(arguments[0]);
  if (!input.existsSync()) {
    stderr.writeln('Không tìm thấy dump: ${input.path}');
    exitCode = 66;
    return;
  }

  final tables = _SqlDumpParser(input.readAsStringSync()).parse();
  final seed = _buildSeed(tables);
  final output = File(arguments[1]);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(seed),
    flush: true,
  );

  final collections = seed['collections']! as Map<String, Object?>;
  stdout.writeln('Đã tạo ${output.path}');
  for (final entry in collections.entries) {
    stdout.writeln('- ${entry.key}: ${(entry.value! as List).length}');
  }
}

Map<String, Object?> _buildSeed(
  Map<String, List<Map<String, Object?>>> tables,
) {
  final genres = _byId(tables['genres']);
  final editions = _byId(tables['editions']);
  final merchandise = _byId(tables['merchandise']);
  final users = _byId(tables['users']);
  final comics = _byId(tables['comics']);
  final conditions = <String, Map<String, Object?>>{
    for (final row in tables['conditions'] ?? const []) '${row['value']}': row,
  };

  final genreIdsByComic = _groupJoin(
    tables['comic_genre'],
    ownerKey: 'comic_id',
    valueKey: 'genre_id',
  );
  final merchandiseIdsByComic = _groupJoin(
    tables['comic_merchandise'],
    ownerKey: 'comic_id',
    valueKey: 'merchandise_id',
  );

  final sellerDetails = <String, Map<String, Object?>>{
    for (final row in tables['seller_details'] ?? const [])
      if (row['userId'] != null) '${row['userId']}': row,
  };

  final collections = <String, Object?>{
    'comic_genres': (tables['genres'] ?? const []).map((row) {
      return _document('${row['id']}', {
        'name': row['name'],
        'description': row['description'] ?? '',
        ..._auditFields(row),
      });
    }).toList(),
    'comic_conditions': (tables['conditions'] ?? const []).map((row) {
      return _document('${row['value']}', {
        'name': row['name'],
        'description': row['description'] ?? '',
        'usageLevel': row['usageLevel'] ?? '',
        'value': row['value'],
        'isRemarkable': _bool(row['isRemarkable']),
        ..._auditFields(row),
      });
    }).toList(),
    'comic_editions': (tables['editions'] ?? const []).map((row) {
      return _document('${row['id']}', {
        'name': row['name'],
        'description': row['description'] ?? '',
        'auctionDisabled': _bool(row['auctionDisabled']),
        'isSpecial': _bool(row['isSpecial']),
        ..._auditFields(row),
      });
    }).toList(),
    'comic_merchandises': (tables['merchandise'] ?? const []).map((row) {
      return _document('${row['id']}', {
        'name': row['name'],
        'subName': row['sub_name'] ?? '',
        'description': row['description'] ?? '',
        'caution': row['caution'] ?? '',
        ..._auditFields(row),
      });
    }).toList(),
    'seller_profiles': sellerDetails.entries.map((entry) {
      final sourceUser = users[entry.key] ?? const <String, Object?>{};
      final detail = entry.value;
      final name = '${sourceUser['name'] ?? ''}'.trim();
      return _document(entry.key, {
        'userId': entry.key,
        'fullName': name,
        'businessName': name,
        'avatar': sourceUser['avatar'] ?? '',
        'bio': sourceUser['bio'] ?? '',
        'soldCount': detail['sold_count'] ?? 0,
        'followerCount': detail['follower_count'] ?? 0,
        'rating': 0,
        'feedbackCount': 0,
        'status': _lower(detail['status']),
        'legacySource': 'comzone_mysql',
        ..._auditFields(detail),
      });
    }).toList(),
    'comics': (tables['comics'] ?? const []).map((row) {
      final id = '${row['id']}';
      final genreIds = genreIdsByComic[id] ?? const <String>[];
      final genreNames = genreIds
          .map((genreId) => genres[genreId]?['name'])
          .whereType<String>()
          .toList();
      final merchandiseIds = merchandiseIdsByComic[id] ?? const <String>[];
      final merchandiseNames = merchandiseIds
          .map((itemId) => merchandise[itemId]?['name'])
          .whereType<String>()
          .toList();
      final conditionId = row['conditionValue']?.toString();
      final editionId = row['editionId']?.toString();
      final type = _lower(row['type']);
      final sourceStatus = '${row['status'] ?? ''}';
      final canAppearInShop = type == 'sell' && sourceStatus == 'AVAILABLE';
      return _document(id, {
        'title': row['title'],
        'author': row['author'],
        'description': row['description'] ?? '',
        'pageCount': row['page'],
        'price': row['price'] ?? 0,
        'status': canAppearInShop ? 'active' : _comicStatus(sourceStatus),
        'stock': row['quantity'] ?? 0,
        'previewImages': _jsonList(row['previewChapter']),
        'sellerUid': row['sellerIdId'] ?? '',
        'image': row['coverImage'] ?? '',
        'episodesList': _jsonList(row['episodes-list']),
        'type': type,
        'cover': _lower(row['cover']),
        'colorType': _lower(row['color']),
        'length': row['length'],
        'width': row['width'],
        'thickness': row['thickness'],
        'publisher': row['publisher'],
        'publicationYear': row['publication_year'],
        'originCountry': row['origin_country'],
        'releaseYear': row['release_year'],
        'willNotAuction': _bool(row['will_not_auction']),
        'genre': genreNames.join(', '),
        'genreIds': genreIds,
        'genres': genreNames,
        'conditionId': conditionId,
        'condition': conditionId == null
            ? 'Chưa rõ'
            : conditions[conditionId]?['name'] ?? 'Chưa rõ',
        'editionId': editionId,
        'edition': editionId == null ? '' : editions[editionId]?['name'] ?? '',
        'editionEvidence': _jsonList(row['edition_evidence']),
        'merchandiseIds': merchandiseIds,
        'merchandises': merchandiseNames,
        'legacySource': 'comzone_mysql',
        ..._auditFields(row),
      });
    }).toList(),
    'auction_configs': (tables['auction-config'] ?? const []).map((row) {
      return _document('${row['id']}', {
        'maxPriceConfig': row['maxPriceConfig'],
        'bidIncrementConfig': row['priceStepConfig'],
        'depositAmountConfig': row['depositAmountConfig'],
        ..._auditFields(row),
      });
    }).toList(),
    'auction_criteria': (tables['auction-criteria'] ?? const []).map((row) {
      return _document('${row['id']}', {
        'conditionLevelValue': row['conditionLevelValue'],
        'requiresFullInformation': _bool(row['is_full_info_filled']),
        'editionRestricted': _bool(row['edition_restricted']),
        ..._auditFields(row),
      });
    }).toList(),
    'auctions': (tables['auction'] ?? const []).map((row) {
      final comic = comics['${row['comicsId']}'];
      return _document('${row['id']}', {
        'comicId': row['comicsId'] ?? '',
        'title': comic?['title'] ?? '',
        'coverImage': comic?['coverImage'] ?? '',
        'sellerUid': comic?['sellerIdId'] ?? '',
        'startingBid': row['reservePrice'] ?? 0,
        'currentBid': row['current_price'] ?? row['reservePrice'] ?? 0,
        'buyNowPrice': row['maxPrice'],
        'bidIncrement': row['priceStep'] ?? 0,
        'depositAmount': row['deposit_amount'] ?? 0,
        'startAt': row['start_time'],
        'endAt': row['end_time'],
        'paymentDeadline': row['paymentDeadline'],
        'currentCondition': row['currentCondition'],
        'winnerUid': row['winner_id'],
        'isPaid': _bool(row['isPaid']),
        'status': _auctionStatus(row['status']),
        'bidCount': 0,
        'legacySource': 'comzone_mysql',
        ..._auditFields(row),
      });
    }).toList(),
    'auction_bids': (tables['bid'] ?? const []).map((row) {
      return _document('${row['id']}', {
        'auctionId': row['auctionId'] ?? '',
        'userId': row['userId'] ?? '',
        'amount': row['price'] ?? 0,
        'legacySource': 'comzone_mysql',
        ..._auditFields(row),
      });
    }).toList(),
    // Dữ liệu trao đổi cũ không được nhập lại; người dùng tạo dữ liệu mới từ UI.
    'exchange_posts': const <Map<String, dynamic>>[],
    'seller_feedback': (tables['seller-feedback'] ?? const []).map((row) {
      return _document('${row['id']}', {
        'userId': row['userId'] ?? '',
        'sellerUid': row['sellerId'] ?? '',
        'rating': row['rating'] ?? 0,
        'comment': row['comment'] ?? '',
        'images': _jsonList(row['attached_images']),
        'status': _bool(row['isApprove']) ? 'approved' : 'pending',
        'legacySource': 'comzone_mysql',
        ..._auditFields(row),
      });
    }).toList(),
    'seller_subscription_plans':
        (tables['seller-subscription-plan'] ?? const []).map((row) {
          return _document('${row['id']}', {
            'price': row['price'] ?? 0,
            'duration': row['duration'] ?? 0,
            'sellLimit': row['sell_time'] ?? 0,
            'auctionLimit': row['auction_time'] ?? 0,
            ..._auditFields(row),
          });
        }).toList(),
  };

  return {
    'schemaVersion': 1,
    'source': 'Dump20250111_version_2.sql',
    'sourceType': 'comzone_mysql',
    'security': {
      'containsCredentials': false,
      'containsPrivateUserData': false,
      'excludedTables': [
        'addresses',
        'delivery-information',
        'otp',
        'source-of-fund',
        'transactions',
        'users',
        'wallet-deposit',
        'withdrawal',
      ],
    },
    'collections': collections,
  };
}

Map<String, Map<String, Object?>> _byId(List<Map<String, Object?>>? rows) => {
  for (final row in rows ?? const <Map<String, Object?>>[])
    if (row['id'] != null) '${row['id']}': row,
};

Map<String, List<String>> _groupJoin(
  List<Map<String, Object?>>? rows, {
  required String ownerKey,
  required String valueKey,
}) {
  final result = <String, List<String>>{};
  for (final row in rows ?? const <Map<String, Object?>>[]) {
    final owner = row[ownerKey]?.toString();
    final value = row[valueKey]?.toString();
    if (owner != null && value != null) {
      result.putIfAbsent(owner, () => []).add(value);
    }
  }
  return result;
}

Map<String, Object?> _document(String id, Map<String, Object?> data) => {
  'id': id,
  'data': {
    for (final entry in data.entries)
      if (entry.value != null) entry.key: entry.value,
  },
};

Map<String, Object?> _auditFields(Map<String, Object?> row) => {
  if (row['createdAt'] != null) 'createdAt': _isoDate(row['createdAt']),
  if (row['updatedAt'] != null) 'updatedAt': _isoDate(row['updatedAt']),
  if (row['deletedAt'] != null) 'deletedAt': _isoDate(row['deletedAt']),
  'isDeleted': row['deletedAt'] != null,
};

String _isoDate(Object? value) {
  final text = '$value';
  return text.contains(' ') ? '${text.replaceFirst(' ', 'T')}Z' : text;
}

bool _bool(Object? value) => value == true || value == 1 || value == '1';

String _lower(Object? value) => value?.toString().toLowerCase() ?? '';

String _comicStatus(String status) => switch (status) {
  'PRE_ORDER' => 'preorder',
  'SOLD' => 'sold',
  _ => 'unavailable',
};

String _auctionStatus(Object? status) => switch ('$status') {
  'ONGOING' => 'active',
  'UPCOMING' => 'pending',
  'SUCCESSFUL' => 'successful',
  'COMPLETED' => 'completed',
  'FAILED' => 'failed',
  'CANCELED' || 'CANCELLED' => 'cancelled',
  'STOPPED' => 'stopped',
  _ => _lower(status),
};

List<Object?> _jsonList(Object? value) {
  if (value == null || '$value'.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode('$value');
    return decoded is List ? decoded : const [];
  } on FormatException {
    return const [];
  }
}

class _SqlDumpParser {
  _SqlDumpParser(this.source);

  final String source;

  Map<String, List<Map<String, Object?>>> parse() {
    final columns = <String, List<String>>{};
    final createPattern = RegExp(
      r'CREATE TABLE `([^`]+)` \((.*?)\) ENGINE=',
      dotAll: true,
    );
    final columnPattern = RegExp(r'^  `([^`]+)`', multiLine: true);
    for (final match in createPattern.allMatches(source)) {
      columns[match.group(1)!] = columnPattern
          .allMatches(match.group(2)!)
          .map((column) => column.group(1)!)
          .toList();
    }

    final tables = <String, List<Map<String, Object?>>>{};
    final insertPattern = RegExp(
      r'^INSERT INTO `([^`]+)` VALUES (.*);$',
      multiLine: true,
    );
    for (final match in insertPattern.allMatches(source)) {
      final table = match.group(1)!;
      final tableColumns = columns[table];
      if (tableColumns == null) continue;
      for (final values in _parseTuples(match.group(2)!)) {
        if (values.length != tableColumns.length) {
          throw FormatException(
            '$table: ${values.length} giá trị cho '
            '${tableColumns.length} cột',
          );
        }
        tables.putIfAbsent(table, () => []).add({
          for (var index = 0; index < tableColumns.length; index++)
            tableColumns[index]: values[index],
        });
      }
    }
    return tables;
  }

  List<List<Object?>> _parseTuples(String text) {
    final tuples = <List<Object?>>[];
    var index = 0;
    while (index < text.length) {
      while (index < text.length && text[index] != '(') {
        index++;
      }
      if (index >= text.length) break;
      index++;
      final tuple = <Object?>[];
      while (index < text.length) {
        while (index < text.length && text[index].trim().isEmpty) {
          index++;
        }
        final result = _parseValue(text, index);
        tuple.add(result.value);
        index = result.nextIndex;
        while (index < text.length && text[index].trim().isEmpty) {
          index++;
        }
        if (index >= text.length) {
          throw const FormatException('Tuple SQL chưa đóng.');
        }
        if (text[index] == ',') {
          index++;
          continue;
        }
        if (text[index] == ')') {
          index++;
          tuples.add(tuple);
          break;
        }
        throw FormatException('Ký tự SQL không hợp lệ tại vị trí $index.');
      }
    }
    return tuples;
  }

  _ParsedValue _parseValue(String text, int start) {
    if (text[start] == "'") {
      final buffer = StringBuffer();
      var index = start + 1;
      while (index < text.length) {
        final char = text[index];
        if (char == "'") {
          return _ParsedValue(buffer.toString(), index + 1);
        }
        if (char == r'\' && index + 1 < text.length) {
          index++;
          final escaped = text[index];
          buffer.write(switch (escaped) {
            'n' => '\n',
            'r' => '\r',
            't' => '\t',
            '0' => '\u0000',
            _ => escaped,
          });
          index++;
          continue;
        }
        buffer.write(char);
        index++;
      }
      throw const FormatException('Chuỗi SQL chưa đóng.');
    }

    var end = start;
    while (end < text.length && text[end] != ',' && text[end] != ')') {
      end++;
    }
    final token = text.substring(start, end).trim();
    if (token == 'NULL') return _ParsedValue(null, end);
    final number = num.tryParse(token);
    return _ParsedValue(number ?? token, end);
  }
}

class _ParsedValue {
  const _ParsedValue(this.value, this.nextIndex);

  final Object? value;
  final int nextIndex;
}
