import 'package:commicbook/features/auctions/auction_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuctionConfig', () {
    test('tính bước giá, tiền cọc và giới hạn mua ngay từ cấu hình', () {
      const config = AuctionConfig(
        bidIncrementPercent: 5,
        depositPercent: 120,
        buyNowMultiplier: 20,
      );

      expect(config.bidIncrementFor(56000), 3000);
      expect(config.depositFor(56000), 67000);
      expect(config.maxBuyNowFor(56000), 1120000);
    });
  });

  group('effectiveAuctionStatus', () {
    final now = DateTime(2026, 8, 9, 12);

    test('upcoming chuyển thành active khi đến giờ', () {
      expect(
        effectiveAuctionStatus({
          'status': AuctionStatus.upcoming,
          'startAt': now.subtract(const Duration(minutes: 1)),
          'endAt': now.add(const Duration(hours: 1)),
          'bidCount': 0,
        }, now: now),
        AuctionStatus.active,
      );
    });

    test('phiên hết giờ có giá trở thành successful', () {
      expect(
        effectiveAuctionStatus({
          'status': AuctionStatus.active,
          'endAt': now.subtract(const Duration(seconds: 1)),
          'bidCount': 2,
        }, now: now),
        AuctionStatus.successful,
      );
    });

    test('phiên hết giờ không có giá trở thành cancelled', () {
      expect(
        effectiveAuctionStatus({
          'status': AuctionStatus.active,
          'endAt': now.subtract(const Duration(seconds: 1)),
          'bidCount': 0,
        }, now: now),
        AuctionStatus.cancelled,
      );
    });
  });

  test('minimumNextBid cộng đúng bước giá', () {
    expect(
      minimumNextBid({'currentBid': 100000, 'bidIncrement': 5000}),
      105000,
    );
  });
}
