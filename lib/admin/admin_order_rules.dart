String classifyOrder(Map<String, dynamic> data) {
  final genre = (data['genre'] as String? ?? '').trim();
  final condition = (data['condition'] as String? ?? '').trim();
  final price = (data['price'] as num?) ?? 0;

  final normalizedGenre = genre.toLowerCase();
  final normalizedCondition = condition.toLowerCase();

  if (normalizedCondition.contains('hiếm') ||
      normalizedCondition.contains('cực hiếm')) {
    return 'Hiếm';
  }

  if (price >= 200000 ||
      normalizedGenre.contains('dark fantasy') ||
      normalizedGenre.contains('fantasy') ||
      normalizedGenre.contains('shounen') ||
      normalizedGenre.contains('action')) {
    return 'Bán chạy';
  }

  if (normalizedGenre.contains('slice of life') ||
      normalizedCondition.contains('khá')) {
    return 'Bình thường';
  }

  return 'Bình thường';
}

Map<String, List<Map<String, dynamic>>> groupOrdersByClassification(
  List<Map<String, dynamic>> orders,
) {
  final groups = <String, List<Map<String, dynamic>>>{};

  for (final order in orders) {
    final key = classifyOrder(order);
    groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(order);
  }

  return groups;
}
