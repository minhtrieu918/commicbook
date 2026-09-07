class SellerPriority {
  const SellerPriority({
    required this.level,
    required this.label,
    required this.priority,
  });

  final String level;
  final String label;
  final int priority;

  factory SellerPriority.fromOrder({
    required String classification,
    required num totalPrice,
    required String status,
  }) {
    final normalized = classification.trim();
    if (normalized == 'Hiếm') {
      return const SellerPriority(
        level: 'urgent',
        label: 'Ưu tiên cao',
        priority: 1,
      );
    }

    if (normalized == 'Bán chạy' || totalPrice >= 100000) {
      return const SellerPriority(
        level: 'high',
        label: 'Nhiệt tình',
        priority: 2,
      );
    }

    if (status == 'Đang giao') {
      return const SellerPriority(
        level: 'medium',
        label: 'Cần xử lý',
        priority: 3,
      );
    }

    return const SellerPriority(
      level: 'normal',
      label: 'Bình thường',
      priority: 4,
    );
  }
}

class SellerSummary {
  const SellerSummary({
    required this.activeListings,
    required this.pendingOrders,
    required this.shippingOrders,
    required this.deliveredRevenue,
  });

  factory SellerSummary.fromData({
    required Iterable<Map<String, dynamic>> listings,
    required Iterable<Map<String, dynamic>> orders,
  }) {
    var activeListings = 0;
    var pendingOrders = 0;
    var shippingOrders = 0;
    num deliveredRevenue = 0;

    for (final listing in listings) {
      if (listing['status'] == 'active' &&
          (listing['stock'] as num? ?? 0) > 0) {
        activeListings++;
      }
    }
    for (final order in orders) {
      final status = order['status'] as String? ?? 'Chờ xác nhận';
      if (status == 'Chờ xác nhận' || status == 'Đang xử lý') pendingOrders++;
      if (status == 'Đang giao') shippingOrders++;
      if (status == 'Đã giao') {
        deliveredRevenue += order['price'] as num? ?? 0;
      }
    }

    return SellerSummary(
      activeListings: activeListings,
      pendingOrders: pendingOrders,
      shippingOrders: shippingOrders,
      deliveredRevenue: deliveredRevenue,
    );
  }

  final int activeListings;
  final int pendingOrders;
  final int shippingOrders;
  final num deliveredRevenue;
}
