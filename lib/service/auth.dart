import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service xử lý các thao tác xác thực bằng Firebase Authentication.
///
/// Mật khẩu được Firebase Authentication lưu và bảo vệ; ứng dụng tuyệt đối
/// không ghi mật khẩu (kể cả mật khẩu đã băm) vào Cloud Firestore. Mỗi lần
/// đăng nhập, Firebase Authentication sẽ đối chiếu email/mật khẩu với dữ liệu
/// xác thực trên máy chủ trước khi trả về [UserCredential].
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Gửi OTP thật bằng Firebase Phone Authentication.
  ///
  /// Trên Web, Firebase tự hiển thị reCAPTCHA. Trên Android/iOS, callback
  /// [codeSent] được chuyển thành một [PhoneOtpSession] thống nhất để giao
  /// diện có thể xác nhận OTP theo cùng một cách.
  Future<PhoneOtpSession> sendPhoneOtp({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    if (kIsWeb) {
      final confirmation = await _auth.signInWithPhoneNumber(phoneNumber);
      return PhoneOtpSession.web(confirmation);
    }

    final completer = Completer<PhoneOtpSession>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 120),
      forceResendingToken: forceResendingToken,
      verificationCompleted: (credential) {
        if (!completer.isCompleted) {
          completer.complete(PhoneOtpSession.automatic(credential));
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneOtpSession.native(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  Future<UserCredential> confirmPhoneOtp({
    required PhoneOtpSession session,
    required String smsCode,
  }) {
    final automaticCredential = session.automaticCredential;
    if (automaticCredential != null) {
      return _auth.signInWithCredential(automaticCredential);
    }
    final webConfirmation = session.webConfirmation;
    if (webConfirmation != null) return webConfirmation.confirm(smsCode);

    final credential = PhoneAuthProvider.credential(
      verificationId: session.verificationId!,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> updateCurrentUserPassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Không tìm thấy tài khoản đã xác minh.',
      );
    }
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() => _auth.signOut();
}

class PhoneOtpSession {
  const PhoneOtpSession._({
    this.verificationId,
    this.resendToken,
    this.webConfirmation,
    this.automaticCredential,
  });

  factory PhoneOtpSession.native({
    required String verificationId,
    int? resendToken,
  }) => PhoneOtpSession._(
    verificationId: verificationId,
    resendToken: resendToken,
  );

  factory PhoneOtpSession.web(ConfirmationResult confirmation) =>
      PhoneOtpSession._(webConfirmation: confirmation);

  factory PhoneOtpSession.automatic(PhoneAuthCredential credential) =>
      PhoneOtpSession._(automaticCredential: credential);

  final String? verificationId;
  final int? resendToken;
  final ConfirmationResult? webConfirmation;
  final PhoneAuthCredential? automaticCredential;
}
