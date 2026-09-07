import 'package:cloud_functions/cloud_functions.dart';

/// Cổng gọi backend cho mọi thao tác có ảnh hưởng tới tiền và kết quả đấu giá.
class AuctionService {
  AuctionService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<void> createRequest({
    required String comicId,
    required int durationDays,
    num? buyNowPrice,
  }) => _call('createAuctionRequest', {
    'comicId': comicId,
    'durationDays': durationDays,
    'buyNowPrice': ?buyNowPrice,
  });

  Future<void> reviewRequest({
    required String requestId,
    required bool approved,
    DateTime? startAt,
    String? rejectionReason,
  }) => _call('reviewAuctionRequest', {
    'requestId': requestId,
    'approved': approved,
    if (startAt != null) 'startAt': startAt.toUtc().toIso8601String(),
    if (rejectionReason != null) 'rejectionReason': rejectionReason.trim(),
  });

  Future<void> deposit(String auctionId) =>
      _call('placeAuctionDeposit', {'auctionId': auctionId});

  Future<void> bid({required String auctionId, required num amount}) =>
      _call('placeAuctionBid', {'auctionId': auctionId, 'amount': amount});

  Future<void> buyNow(String auctionId) =>
      _call('buyNowAuction', {'auctionId': auctionId});

  Future<void> pay(String auctionId) =>
      _call('payAuction', {'auctionId': auctionId});

  Future<void> cancel(String auctionId) =>
      _call('cancelAuction', {'auctionId': auctionId});

  Future<void> sync(String auctionId) =>
      _call('syncAuction', {'auctionId': auctionId});

  Future<void> _call(String name, Map<String, Object> data) async {
    await _functions.httpsCallable(name).call<void>(data);
  }
}
