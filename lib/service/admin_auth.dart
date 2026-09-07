import 'package:cloud_functions/cloud_functions.dart';

/// Các thao tác Firebase Authentication đặc quyền chỉ chạy qua backend.
class AdminAuthService {
  AdminAuthService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<void> setUserPassword({
    required String targetUid,
    required String newPassword,
  }) async {
    await _functions.httpsCallable('setUserPassword').call<void>({
      'targetUid': targetUid,
      'newPassword': newPassword,
    });
  }
}
