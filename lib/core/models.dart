import 'package:flutter/material.dart';

class ComicItem {
  const ComicItem({
    required this.id,
    required this.title,
    required this.price,
    required this.author,
    required this.color,
    this.image = '',
    this.genre = 'Chưa rõ',
    this.condition = 'Chưa rõ',
    this.rating = 0,
    this.reviews = 0,
    this.stock = 0,
    this.originalPrice,
    this.isNew = false,
    this.isSale = false,
    this.sellerUid = '',
    this.previewImages = const [],
  });

  final String id;
  final String title;
  final String author;
  final num price;
  final num? originalPrice;
  final Color color;
  final String image;
  final String genre;
  final String condition;
  final double rating;
  final int reviews;
  final int stock;
  final bool isNew;
  final bool isSale;
  final String sellerUid;
  final List<String> previewImages;
}

/// Dữ liệu một phiên đấu giá khi cần dựng card từ Firestore.
/// Không chứa dữ liệu mẫu; các giá trị phải đến từ snapshot thật.
class AuctionItem {
  const AuctionItem({
    required this.title,
    required this.currentBid,
    required this.startBid,
    required this.bids,
    required this.duration,
    required this.image,
    required this.condition,
    required this.seller,
  });

  final String title;
  final num currentBid;
  final num startBid;
  final int bids;
  final Duration duration;
  final String image;
  final String condition;
  final String seller;
}
