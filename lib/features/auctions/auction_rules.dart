import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class AuctionStatus {
  static const pending = 'pending';
  static const rejected = 'rejected';
  static const upcoming = 'upcoming';
  static const active = 'active';
  static const successful = 'successful';
  static const completed = 'completed';
  static const failed = 'failed';
  static const cancelled = 'cancelled';
  static const stopped = 'stopped';

  static String label(String value) => switch (value) {
    pending => 'Chờ duyệt',
    rejected => 'Bị từ chối',
    upcoming => 'Sắp diễn ra',
    active => 'Đang diễn ra',
    successful => 'Chờ người thắng thanh toán',
    completed => 'Đã hoàn tất',
    failed => 'Không thành công',
    cancelled => 'Đã hủy',
    stopped => 'Đã dừng',
    _ => 'Không xác định',
  };

  static bool isTerminal(String value) =>
      const {completed, failed, cancelled, stopped, rejected}.contains(value);
}

abstract final class AuctionDepositStatus {
  static const holding = 'holding';
  static const refunded = 'refunded';
  static const used = 'used';
  static const seized = 'seized';
}

class AuctionConfig {
  const AuctionConfig({
    this.bidIncrementPercent = 5,
    this.depositPercent = 120,
    this.buyNowMultiplier = 20,
    this.paymentDays = 7,
  });

  final num bidIncrementPercent;
  final num depositPercent;
  final num buyNowMultiplier;
  final int paymentDays;

  num bidIncrementFor(num startingBid) =>
      _roundToNearestThousand(startingBid * bidIncrementPercent / 100);

  num depositFor(num startingBid) =>
      _roundToNearestThousand(startingBid * depositPercent / 100);

  num maxBuyNowFor(num startingBid) => startingBid * buyNowMultiplier;

  factory AuctionConfig.fromMap(Map<String, dynamic>? data) => AuctionConfig(
    bidIncrementPercent:
        data?['bidIncrementConfig'] as num? ??
        data?['bidIncrementPercent'] as num? ??
        5,
    depositPercent:
        data?['depositAmountConfig'] as num? ??
        data?['depositPercent'] as num? ??
        120,
    buyNowMultiplier:
        data?['maxPriceConfig'] as num? ??
        data?['buyNowMultiplier'] as num? ??
        20,
    paymentDays: (data?['paymentDays'] as num? ?? 7).toInt(),
  );
}

num _roundToNearestThousand(num value) => (value / 1000).round() * 1000;

DateTime? auctionDate(dynamic value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime date => date,
  String text => DateTime.tryParse(text),
  _ => null,
};

String effectiveAuctionStatus(Map<String, dynamic> data, {DateTime? now}) {
  final status = data['status'] as String? ?? AuctionStatus.pending;
  final current = now ?? DateTime.now();
  final start = auctionDate(data['startAt']);
  final end = auctionDate(data['endAt']);
  if (status == AuctionStatus.upcoming &&
      start != null &&
      !start.isAfter(current)) {
    return end != null && !end.isAfter(current)
        ? _endedStatus(data)
        : AuctionStatus.active;
  }
  if (status == AuctionStatus.active && end != null && !end.isAfter(current)) {
    return _endedStatus(data);
  }
  return status;
}

String _endedStatus(Map<String, dynamic> data) =>
    (data['bidCount'] as num? ?? 0) > 0
    ? AuctionStatus.successful
    : AuctionStatus.cancelled;

num minimumNextBid(Map<String, dynamic> data) =>
    (data['currentBid'] as num? ?? data['startingBid'] as num? ?? 0) +
    (data['bidIncrement'] as num? ?? 0);
