import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

/// Service thao tác với Cloud Firestore.
///
/// Collection sử dụng trong đồ án:
/// - users: thông tin hồ sơ người dùng
/// - comics: danh mục truyện do admin quản lý
/// - orders: đơn mua truyện
/// - sell_requests: yêu cầu đăng ký bán truyện (admin duyệt)
class DatabaseService {
  DatabaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Nhập dữ liệu nghiệp vụ thật đã chuyển đổi từ dump MySQL ComZone.
  ///
  /// Seed không chứa mật khẩu, token, OTP, email, số điện thoại, địa chỉ hay
  /// lịch sử tài chính. Document trùng ID được cập nhật theo kiểu merge để có
  /// thể chạy lại khi cần mà không tạo bản ghi trùng.
  Future<Map<String, int>> importComzonePublicSeed() async {
    final raw = await rootBundle.loadString(
      'assets/data/comzone_public_seed.json',
    );
    final seed = jsonDecode(raw) as Map<String, dynamic>;
    final collections = seed['collections'] as Map<String, dynamic>?;
    if (collections == null) {
      throw const FormatException('Seed ComZone không có collections.');
    }

    final counts = <String, int>{};
    var batch = _firestore.batch();
    var batchSize = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (batchSize == 0 || (!force && batchSize < 400)) return;
      await batch.commit();
      batch = _firestore.batch();
      batchSize = 0;
    }

    for (final collectionEntry in collections.entries) {
      final documents = collectionEntry.value as List<dynamic>;
      counts[collectionEntry.key] = documents.length;
      for (final value in documents) {
        final document = value as Map<String, dynamic>;
        final id = document['id'] as String;
        final data = _firestoreData(document['data'] as Map<String, dynamic>);
        data['importSource'] = seed['sourceType'] ?? 'comzone_mysql';
        data['importedAt'] = FieldValue.serverTimestamp();
        batch.set(
          _firestore.collection(collectionEntry.key).doc(id),
          data,
          SetOptions(merge: true),
        );
        batchSize++;
        await commitIfNeeded();
      }
    }
    await commitIfNeeded(force: true);
    return counts;
  }

  Map<String, dynamic> _firestoreData(Map<String, dynamic> source) => {
    for (final entry in source.entries)
      entry.key: _firestoreValue(entry.key, entry.value),
  };

  dynamic _firestoreValue(String key, dynamic value) {
    if (value is Map<String, dynamic>) return _firestoreData(value);
    if (value is List) {
      return value.map((item) => _firestoreValue('', item)).toList();
    }
    if (value is String &&
        (key.endsWith('At') ||
            key == 'startAt' ||
            key == 'endAt' ||
            key == 'paymentDeadline')) {
      final date = DateTime.tryParse(value);
      if (date != null) return Timestamp.fromDate(date);
    }
    return value;
  }

  /// Chỉ lưu hồ sơ công khai của người dùng.
  ///
  /// Mật khẩu đã được Firebase Authentication quản lý trong lúc đăng ký nên
  /// không được truyền vào hoặc lưu trong document `users`.
  Future<void> createUser({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
  }) async {
    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(uid), {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': 'customer',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('wallets').doc(uid), {
      'userId': uid,
      'balance': 0,
      'withdrawableBalance': 0,
      'heldBalance': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> comicsStream() {
    return _firestore.collection('comics').orderBy('title').snapshots();
  }

  Future<void> createOrder({
    required String uid,
    required String comicId,
    required String comicTitle,
    required String sellerUid,
    required num price,
    required String paymentMethod,
    String? buyerEmail,
    String? genre,
    String? condition,
    String? classification,
  }) async {
    final orderRef = _firestore.collection('orders').doc();
    final comicRef = _firestore.collection('comics').doc(comicId);

    await _firestore.runTransaction((transaction) async {
      final comic = await transaction.get(comicRef);
      var resolvedTitle = comicTitle;
      var resolvedSellerUid = sellerUid;
      var resolvedPrice = price;
      var resolvedGenre = genre ?? 'Chưa rõ';
      var resolvedCondition = condition ?? 'Chưa rõ';

      if (comic.exists) {
        final data = comic.data() ?? {};
        final stock = (data['stock'] as num?)?.toInt() ?? 0;
        if (data['status'] != 'active' || stock <= 0) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message: 'Truyện đã hết hàng hoặc đang tạm ngừng bán.',
          );
        }
        resolvedTitle = data['title'] as String? ?? comicTitle;
        resolvedSellerUid = data['sellerUid'] as String? ?? '';
        resolvedPrice = data['price'] as num? ?? price;
        resolvedGenre = data['genre'] as String? ?? resolvedGenre;
        resolvedCondition = data['condition'] as String? ?? resolvedCondition;
        transaction.update(comicRef, {
          'stock': stock - 1,
          'lastOrderId': orderRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(orderRef, {
        'userId': uid,
        'buyerEmail': buyerEmail ?? '',
        'comicId': comicId,
        'comicTitle': resolvedTitle,
        'sellerUid': resolvedSellerUid,
        'price': resolvedPrice,
        'paymentMethod': paymentMethod,
        'genre': resolvedGenre,
        'condition': resolvedCondition,
        'classification': classification ?? 'Bình thường',
        'status': 'Chờ xác nhận',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> bulkUpdateOrderStatus({
    required List<String> orderIds,
    required String status,
  }) async {
    if (orderIds.isEmpty) return;

    final batch = _firestore.batch();
    for (final orderId in orderIds) {
      final ref = _firestore.collection('orders').doc(orderId);
      batch.update(ref, {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> ordersStream() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) {
    return _firestore.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createSellRequest({
    required String uid,
    required String title,
    required String author,
    required num price,
    required String description,
    String genre = 'Chưa rõ',
    String condition = 'Chưa rõ',
    int stock = 1,
    Map<String, dynamic> metadata = const {},
  }) {
    return _firestore.collection('sell_requests').add({
      'userId': uid,
      'title': title,
      'author': author,
      'price': price,
      'description': description,
      'genre': genre,
      'condition': condition,
      'stock': stock,
      ...metadata,
      'status': 'Chờ duyệt',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    required String phone,
  }) {
    return _firestore.collection('users').doc(uid).update({
      'fullName': fullName,
      'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> registerAsSeller({
    required String uid,
    required String fullName,
    required String phone,
    required String address,
    required String bankAccount,
    required String verificationDocument,
    String businessName = '',
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final requestRef = _firestore
        .collection('seller_registration_requests')
        .doc(uid);
    await _firestore.runTransaction((transaction) async {
      final user = await transaction.get(userRef);
      if (!user.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Không tìm thấy tài khoản.',
        );
      }
      final role = user.data()?['role'] as String? ?? 'customer';
      if (role == 'seller' || role == 'admin') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'already-exists',
          message: 'Tài khoản đã có quyền người bán.',
        );
      }

      final existingRequest = await transaction.get(requestRef);
      final existingStatus = existingRequest.data()?['status'] as String?;
      if (existingStatus == 'pending') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'already-exists',
          message: 'Yêu cầu đăng ký Seller đang chờ Admin duyệt.',
        );
      }
      if (existingStatus == 'approved') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'already-exists',
          message: 'Yêu cầu đăng ký Seller đã được duyệt.',
        );
      }

      transaction.set(requestRef, {
        'userId': uid,
        'fullName': fullName,
        'businessName': businessName,
        'phone': phone,
        'address': address,
        'bankAccount': bankAccount,
        'verificationDocument': verificationDocument,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>
  sellerRegistrationRequestStream(String uid) {
    return _firestore
        .collection('seller_registration_requests')
        .doc(uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
  sellerRegistrationRequestsStream() {
    return _firestore
        .collection('seller_registration_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> reviewSellerRegistration({
    required String uid,
    required String reviewerUid,
    required bool approved,
    String rejectionReason = '',
  }) async {
    final requestRef = _firestore
        .collection('seller_registration_requests')
        .doc(uid);
    final userRef = _firestore.collection('users').doc(uid);
    final sellerRef = _firestore.collection('seller_profiles').doc(uid);
    final notificationRef = _firestore.collection('notifications').doc();

    await _firestore.runTransaction((transaction) async {
      final request = await transaction.get(requestRef);
      final user = await transaction.get(userRef);
      if (!request.exists || !user.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Không tìm thấy yêu cầu hoặc tài khoản đăng ký.',
        );
      }
      final data = request.data() ?? {};
      if (data['status'] != 'pending') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Yêu cầu này đã được xử lý.',
        );
      }

      if (!approved) {
        transaction.update(requestRef, {
          'status': 'rejected',
          'rejectionReason': rejectionReason,
          'reviewedBy': reviewerUid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(notificationRef, {
          'userId': uid,
          'type': 'SELLER_REGISTRATION_REJECTED',
          'title': 'Yêu cầu Seller bị từ chối',
          'content': rejectionReason.isEmpty
              ? 'Admin đã từ chối yêu cầu đăng ký Seller.'
              : rejectionReason,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      transaction.update(requestRef, {
        'status': 'approved',
        'reviewedBy': reviewerUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, {
        'role': 'seller',
        'fullName': data['fullName'] ?? '',
        'phone': data['phone'] ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(sellerRef, {
        'userId': uid,
        'fullName': data['fullName'] ?? '',
        'businessName': data['businessName'] ?? '',
        'phone': data['phone'] ?? '',
        'address': data['address'] ?? '',
        'approvalStatus': 'approved',
        'registrationRequestId': requestRef.id,
        'rating': 0,
        'feedbackCount': 0,
        'approvedBy': reviewerUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationRef, {
        'userId': uid,
        'type': 'SELLER_REGISTRATION_APPROVED',
        'title': 'Đăng ký Seller đã được duyệt',
        'content': 'Bạn đã có thể tạo truyện và quản lý kho Seller.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> sellerProfileStream(
    String uid,
  ) {
    return _firestore.collection('seller_profiles').doc(uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sellerProfilesStream() {
    return _firestore.collection('seller_profiles').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> savedComicsStream(String uid) {
    return _firestore
        .collection('saved_comics')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> savedComicStream({
    required String uid,
    required String comicId,
  }) {
    return _firestore
        .collection('saved_comics')
        .doc('${uid}_$comicId')
        .snapshots();
  }

  Future<void> setComicSaved({
    required String uid,
    required String comicId,
    required bool saved,
    Map<String, dynamic>? comicData,
  }) async {
    final ref = _firestore.collection('saved_comics').doc('${uid}_$comicId');
    if (!saved) {
      await ref.delete();
      return;
    }
    await ref.set({
      'userId': uid,
      'comicId': comicId,
      ...?comicData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sellerFeedbackStream(
    String sellerUid,
  ) {
    return _firestore
        .collection('seller_feedback')
        .where('sellerUid', isEqualTo: sellerUid)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> submitSellerFeedback({
    required String sellerUid,
    required String userId,
    required String content,
    required int rating,
    bool isReport = false,
  }) {
    return _firestore.collection('seller_feedback').add({
      'sellerUid': sellerUid,
      'userId': userId,
      'content': content,
      'rating': rating,
      'type': isReport ? 'report' : 'feedback',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> feedbackModerationStream() {
    return _firestore
        .collection('seller_feedback')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> reviewSellerFeedback({
    required String feedbackId,
    required bool approved,
  }) async {
    final feedbackRef = _firestore
        .collection('seller_feedback')
        .doc(feedbackId);
    final snapshot = await feedbackRef.get();
    if (!snapshot.exists) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'Phản hồi không còn tồn tại.',
      );
    }
    final data = snapshot.data() ?? {};
    final sellerUid = data['sellerUid'] as String? ?? '';
    await feedbackRef.update({
      'status': approved ? 'approved' : 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    if (sellerUid.isEmpty) return;

    final approvedFeedback = await _firestore
        .collection('seller_feedback')
        .where('sellerUid', isEqualTo: sellerUid)
        .where('status', isEqualTo: 'approved')
        .get();
    final ratings = approvedFeedback.docs
        .where((doc) => doc.data()['type'] == 'feedback')
        .map((doc) => doc.data()['rating'] as num? ?? 0)
        .where((rating) => rating > 0)
        .toList();
    final average = ratings.isEmpty
        ? 0
        : ratings.reduce((total, rating) => total + rating) / ratings.length;
    await _firestore.collection('seller_profiles').doc(sellerUid).update({
      'rating': average,
      'feedbackCount': ratings.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> followStream({
    required String uid,
    required String sellerUid,
  }) {
    return _firestore
        .collection('follows')
        .doc('${uid}_$sellerUid')
        .snapshots();
  }

  Future<void> setSellerFollowed({
    required String uid,
    required String sellerUid,
    required bool followed,
  }) async {
    final ref = _firestore.collection('follows').doc('${uid}_$sellerUid');
    if (!followed) {
      await ref.delete();
      return;
    }
    await ref.set({
      'userId': uid,
      'sellerUid': sellerUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveSellRequest({
    required String requestId,
    required String title,
    required String author,
    required num price,
    required String description,
    required String sellerUid,
    String genre = 'Chưa rõ',
    String condition = 'Chưa rõ',
    int stock = 1,
    Map<String, dynamic> metadata = const {},
  }) async {
    final requestRef = _firestore.collection('sell_requests').doc(requestId);
    final comicRef = _firestore.collection('comics').doc(requestId);
    final sellerRef = _firestore.collection('users').doc(sellerUid);
    final sellerProfileRef = _firestore
        .collection('seller_profiles')
        .doc(sellerUid);

    await _firestore.runTransaction((transaction) async {
      final request = await transaction.get(requestRef);
      final seller = await transaction.get(sellerRef);
      final sellerProfile = await transaction.get(sellerProfileRef);
      if (!request.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Yêu cầu đăng bán không còn tồn tại.',
        );
      }
      if (request.data()?['status'] != 'Chờ duyệt') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Yêu cầu này đã được kiểm duyệt.',
        );
      }
      if (sellerUid.isEmpty || request.data()?['userId'] != sellerUid) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Yêu cầu không có thông tin Seller hợp lệ.',
        );
      }
      final approvalStatus = sellerProfile.data()?['approvalStatus'] as String?;
      if (!seller.exists ||
          seller.data()?['role'] != 'seller' ||
          !sellerProfile.exists ||
          (approvalStatus != null && approvalStatus != 'approved')) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Tài khoản chưa được Admin duyệt quyền Seller.',
        );
      }

      transaction.update(requestRef, {
        'status': 'Đã duyệt',
        'reviewedAt': FieldValue.serverTimestamp(),
        'comicId': comicRef.id,
      });
      transaction.set(comicRef, {
        'title': title,
        'author': author,
        'price': price,
        'description': description,
        'genre': genre,
        'condition': condition,
        'stock': stock,
        ...metadata,
        'sellerUid': sellerUid,
        'sourceRequestId': requestId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectSellRequest({required String requestId}) {
    return _firestore.collection('sell_requests').doc(requestId).update({
      'status': 'Từ chối',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingSellRequestsStream() {
    return _firestore
        .collection('sell_requests')
        .where('status', isEqualTo: 'Chờ duyệt')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sellRequestsStream() {
    return _firestore
        .collection('sell_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> ordersOf(String uid) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> orderStream(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sellRequestsOf(String uid) {
    return _firestore
        .collection('sell_requests')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sellerListingsStream(String uid) {
    return _firestore
        .collection('comics')
        .where('sellerUid', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sellerOrdersStream(String uid) {
    return _firestore
        .collection('orders')
        .where('sellerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateSellerOrderStatus({
    required String orderId,
    required String status,
  }) {
    return _firestore.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSellerListingStatus({
    required String listingId,
    required String status,
  }) {
    return _firestore.collection('comics').doc(listingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSellerListing({
    required String listingId,
    required num price,
    required int stock,
    required String status,
  }) {
    return _firestore.collection('comics').doc(listingId).update({
      'price': price,
      'stock': stock,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> makeSellerListingUnavailable(String listingId) {
    return _firestore.collection('comics').doc(listingId).update({
      'status': 'unavailable',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserRole({required String uid, required String role}) {
    if (role == 'seller') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message: 'Quyền Seller chỉ được cấp từ màn hình duyệt đăng ký Seller.',
      );
    }
    return _firestore.collection('users').doc(uid).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> catalogOptionsStream(
    String collection,
  ) {
    return _firestore.collection(collection).orderBy('name').snapshots();
  }

  Future<void> createCatalogOption({
    required String collection,
    required String name,
    String description = '',
  }) {
    return _firestore.collection(collection).add({
      'name': name,
      'description': description,
      'isDeleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCatalogOption({
    required String collection,
    required String id,
    required String name,
    required String description,
  }) {
    return _firestore.collection(collection).doc(id).update({
      'name': name,
      'description': description,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setCatalogOptionDeleted({
    required String collection,
    required String id,
    required bool deleted,
  }) {
    return _firestore.collection(collection).doc(id).update({
      'isDeleted': deleted,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> auctionsStream() {
    return _firestore.collection('auctions').orderBy('endAt').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> auctionConfigsStream() {
    return _firestore
        .collection('auction_configs')
        .where('isDeleted', isEqualTo: false)
        .limit(1)
        .snapshots();
  }

  Future<void> updateAuctionConfig({
    required String configId,
    required num bidIncrementPercent,
    required num depositPercent,
    required num buyNowMultiplier,
    required int paymentDays,
  }) {
    return _firestore.collection('auction_configs').doc(configId).set({
      'bidIncrementConfig': bidIncrementPercent,
      'depositAmountConfig': depositPercent,
      'maxPriceConfig': buyNowMultiplier,
      'paymentDays': paymentDays,
      'isDeleted': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> auctionRequestsStream() {
    return _firestore
        .collection('auction_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sellerAuctionRequestsStream(
    String uid,
  ) {
    return _firestore
        .collection('auction_requests')
        .where('sellerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sellerAuctionsStream(String uid) {
    return _firestore
        .collection('auctions')
        .where('sellerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> bidsOfAuction(String auctionId) {
    return _firestore
        .collection('auction_bids')
        .where('auctionId', isEqualTo: auctionId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> auctionStream(
    String auctionId,
  ) {
    return _firestore.collection('auctions').doc(auctionId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> auctionBidsOf(String uid) {
    return _firestore
        .collection('auction_bids')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> auctionDepositsOf(String uid) {
    return _firestore
        .collection('auction_deposits')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> auctionDepositStream({
    required String auctionId,
    required String uid,
  }) {
    return _firestore
        .collection('auction_deposits')
        .doc('${auctionId}_$uid')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> exchangePostsStream() {
    return _firestore
        .collection('exchange_posts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> createExchangePost({
    required String uid,
    required String title,
    required String content,
    required String offeredComic,
    required String condition,
    required String author,
    required String contactDetails,
  }) {
    return _firestore.collection('exchange_posts').add({
      'userId': uid,
      'title': title,
      'content': content,
      'offeredComic': offeredComic,
      'condition': condition,
      'author': author,
      'contactDetails': contactDetails,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createExchangeRequest({
    required String postId,
    required String requesterUid,
    required String recipientUid,
    required String offeredComic,
  }) {
    return _firestore.collection('exchange_requests').add({
      'postId': postId,
      'requesterUid': requesterUid,
      'recipientUid': recipientUid,
      'participantIds': [requesterUid, recipientUid],
      'offeredComic': offeredComic,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> exchangeRequestsStream(
    String uid,
  ) {
    return _firestore
        .collection('exchange_requests')
        .where('participantIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> respondExchangeRequest({
    required String requestId,
    required bool accepted,
  }) {
    return _firestore.collection('exchange_requests').doc(requestId).update({
      'status': accepted ? 'accepted' : 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream(String uid) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markNotificationRead(String notificationId) {
    return _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> walletStream(String uid) {
    return _firestore.collection('wallets').doc(uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> walletTransactionsStream(
    String uid,
  ) {
    return _firestore
        .collection('wallet_transactions')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> walletRequestsStream(String uid) {
    return _firestore
        .collection('wallet_requests')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> walletModerationStream() {
    return _firestore
        .collection('wallet_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> reviewWalletRequest({
    required String requestId,
    required bool approved,
  }) async {
    final requestRef = _firestore.collection('wallet_requests').doc(requestId);
    final transactionRef = _firestore.collection('wallet_transactions').doc();
    await _firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists ||
          requestSnapshot.data()?['status'] != 'pending') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Yêu cầu đã được xử lý hoặc không còn tồn tại.',
        );
      }
      final requestData = requestSnapshot.data() ?? {};
      final uid = requestData['userId'] as String? ?? '';
      final type = requestData['type'] as String? ?? '';
      final amount = requestData['amount'] as num? ?? 0;
      final walletRef = _firestore.collection('wallets').doc(uid);
      final walletSnapshot = await transaction.get(walletRef);
      final wallet = walletSnapshot.data() ?? {};
      final balance = wallet['balance'] as num? ?? 0;
      final withdrawable = wallet['withdrawableBalance'] as num? ?? 0;
      final held = wallet['heldBalance'] as num? ?? 0;

      if (approved && type == 'deposit') {
        transaction.set(walletRef, {
          'userId': uid,
          'balance': balance + amount,
          'withdrawableBalance': withdrawable,
          'heldBalance': held,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!walletSnapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (approved && type == 'withdraw') {
        if (balance < amount) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message: 'Tổng số dư ví không đủ để hoàn tất rút tiền.',
          );
        }
        transaction.update(walletRef, {
          'balance': balance - amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (!approved && type == 'withdraw') {
        transaction.update(walletRef, {
          'withdrawableBalance': withdrawable + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.update(requestRef, {
        'status': approved ? 'successful' : 'failed',
        'reviewedAt': FieldValue.serverTimestamp(),
        'transactionId': approved ? transactionRef.id : null,
      });
      if (approved) {
        transaction.set(transactionRef, {
          'userId': uid,
          'requestId': requestId,
          'code': transactionRef.id,
          'amount': amount,
          'type': type == 'deposit' ? 'ADD' : 'SUBTRACT',
          'status': 'SUCCESSFUL',
          'note': type == 'deposit'
              ? 'Nạp tiền vào ví'
              : 'Rút tiền về ngân hàng',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> createWalletRequest({
    required String uid,
    required String type,
    required num amount,
    required String paymentMethod,
  }) async {
    final requestRef = _firestore.collection('wallet_requests').doc();
    final walletRef = _firestore.collection('wallets').doc(uid);
    await _firestore.runTransaction((transaction) async {
      if (type == 'withdraw') {
        final wallet = await transaction.get(walletRef);
        if (!wallet.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'Không tìm thấy ví.',
          );
        }
        final withdrawable = wallet.data()?['withdrawableBalance'] as num? ?? 0;
        if (amount > withdrawable) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'failed-precondition',
            message: 'Số dư có thể rút không đủ.',
          );
        }
        transaction.update(walletRef, {
          'withdrawableBalance': withdrawable - amount,
          'lastRequestId': requestRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(requestRef, {
        'userId': uid,
        'type': type,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> chatsStream(String uid) {
    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Future<String> createChatRoom({
    required String creatorUid,
    required String participantUid,
    required String title,
  }) async {
    final ref = _firestore.collection('chats').doc();
    await ref.set({
      'title': title,
      'participantIds': [creatorUid, participantUid],
      'roomType': 'private',
      'createdBy': creatorUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
    });
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderUid,
    required String content,
  }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final batch = _firestore.batch();
    batch.set(messageRef, {
      'senderUid': senderUid,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(chatRef, {
      'lastMessage': content,
      'lastSenderUid': senderUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
