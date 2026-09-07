import 'package:commicbook/core/models.dart';
import 'package:commicbook/features/catalog/catalog_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const comics = [
    ComicItem(
      id: '1',
      title: 'A',
      author: 'Tác giả',
      price: 10000,
      color: Colors.red,
      genre: 'Hành động, Shounen',
    ),
    ComicItem(
      id: '2',
      title: 'B',
      author: 'Tác giả',
      price: 20000,
      color: Colors.blue,
      genre: 'Lãng mạn',
    ),
  ];

  test('bộ lọc lấy thể loại thực tế và loại bỏ giá trị trùng', () {
    expect(availableCatalogGenres(comics), [
      'Hành động',
      'Lãng mạn',
      'Shounen',
    ]);
  });

  test('truyện nhiều thể loại khớp từng thể loại riêng biệt', () {
    expect(comicMatchesGenre(comics.first, 'Shounen'), isTrue);
    expect(comicMatchesGenre(comics.first, 'Hành động'), isTrue);
    expect(comicMatchesGenre(comics.first, 'Seinen'), isFalse);
    expect(comicMatchesGenre(comics.first, allGenresLabel), isTrue);
  });
}
