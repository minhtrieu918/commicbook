import 'package:flutter/material.dart';

/// Asset và quy tắc chọn icon được chuyển nguyên từ source ComZone Client.
abstract final class AnnouncementAssets {
  static const _root = 'assets/announcement-icons';

  static const approve = '$_root/approve-icon.png';
  static const auction = '$_root/auction-icon.png';
  static const deal = '$_root/deal-icon.png';
  static const deliveryReturn = '$_root/delivery-return-icon.png';
  static const exchange = '$_root/exchange-icon.png';
  static const noNotification = '$_root/no-notification.jpg';
  static const notification = '$_root/notification-icon-462x512-tqwyit2p.png';
  static const order = '$_root/orderIcon.png';
  static const package = '$_root/package-icon.png';
  static const pay = '$_root/pay-icon.png';
  static const reject = '$_root/reject-icon.png';
  static const truck = '$_root/truck-icon.png';
  static const walletAdd = '$_root/wallet-add-icon.png';
  static const wallet = '$_root/wallet-icon.png';

  static String forType(Object? value) {
    final type = value?.toString().trim().toUpperCase() ?? '';
    return switch (type) {
      'ORDER_NEW' || 'ORDER' || 'PURCHASE' => order,
      'AUCTION' || 'AUCTION_REQUEST' || 'AUCTION_REQUEST_FAIL' => auction,
      'EXCHANGE_NEW_REQUEST' || 'EXCHANGE' => exchange,
      'ORDER_CONFIRMED' ||
      'EXCHANGE_APPROVED' ||
      'EXCHANGE_SUCCESSFUL' ||
      'DELIVERY_FINISHED_SEND' ||
      'DELIVERY_FINISHED_RECEIVE' ||
      'REFUND_APPROVE' ||
      'APPROVED' ||
      'SUCCESSFUL' => approve,
      'ORDER_FAILED' ||
      'EXCHANGE_REJECTED' ||
      'EXCHANGE_FAILED' ||
      'DELIVERY_FAILED_RECEIVE' ||
      'DELIVERY_FAILED_SEND' ||
      'REFUND_REJECT' ||
      'REJECTED' ||
      'FAILED' => reject,
      'EXCHANGE_NEW_DEAL' || 'DEAL' => deal,
      'EXCHANGE_PAY_AVAILABLE' || 'WALLET' => wallet,
      'DELIVERY_PICKING' || 'PACKAGE' => package,
      'ORDER_DELIVERY' ||
      'EXCHANGE_DELIVERY' ||
      'DELIVERY_ONGOING' ||
      'DELIVERY' ||
      'SHIPPING' => truck,
      'DELIVERY_RETURN' || 'RETURN' => deliveryReturn,
      'TRANSACTION_ADD' || 'DEPOSIT' || 'ADD' => walletAdd,
      'TRANSACTION_SUBTRACT' || 'WITHDRAW' || 'SUBTRACT' || 'PAY' => pay,
      _ => notification,
    };
  }
}

class AnnouncementIcon extends StatelessWidget {
  const AnnouncementIcon({
    super.key,
    required this.type,
    this.size = 48,
    this.color,
  });

  final Object? type;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Image.asset(
    AnnouncementAssets.forType(type),
    width: size,
    height: size,
    fit: BoxFit.contain,
    color: color,
    colorBlendMode: color == null ? null : BlendMode.srcIn,
    errorBuilder: (_, _, _) => Image.asset(
      AnnouncementAssets.notification,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
    ),
  );
}
