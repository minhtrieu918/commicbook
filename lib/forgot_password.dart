import 'dart:async';

import 'package:commicbook/auth/auth_validators.dart';
import 'package:commicbook/service/auth.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _ResetStep { identifier, emailSent, phoneOtp, newPassword, success }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _otpDuration = 120;

  final _identifierForm = GlobalKey<FormState>();
  final _otpForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  _ResetStep _step = _ResetStep.identifier;
  PhoneOtpSession? _phoneSession;
  Timer? _timer;
  int _remainingSeconds = _otpDuration;
  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  AuthService get _auth => widget.authService;
  String get _identifierValue => _identifier.text.trim();
  bool get _canResend => _remainingSeconds == 0 && !_loading;

  @override
  void dispose() {
    _timer?.cancel();
    _identifier.dispose();
    _otp.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _remainingSeconds = _otpDuration);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _requestReset() async {
    if (!_identifierForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      if (AuthValidators.isEmail(_identifierValue)) {
        await _auth.sendPasswordResetEmail(email: _identifierValue);
        if (!mounted) return;
        setState(() => _step = _ResetStep.emailSent);
        _startCountdown();
      } else {
        await _sendPhoneOtp();
      }
    } on FirebaseAuthException catch (error) {
      _showError(_authError(error.code));
    } catch (_) {
      _showError('Không thể gửi yêu cầu. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPhoneOtp({bool resend = false}) async {
    final phone = AuthValidators.normalizeVietnamesePhone(_identifierValue);
    final session = await _auth.sendPhoneOtp(
      phoneNumber: phone,
      forceResendingToken: resend ? _phoneSession?.resendToken : null,
    );
    if (!mounted) return;

    _phoneSession = session;
    _otp.clear();
    _startCountdown();

    if (session.automaticCredential != null) {
      await _completePhoneVerification(session: session, smsCode: '');
    } else {
      setState(() => _step = _ResetStep.phoneOtp);
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() => _loading = true);
    try {
      if (_step == _ResetStep.emailSent) {
        await _auth.sendPasswordResetEmail(email: _identifierValue);
        _startCountdown();
        _showMessage('Đã gửi lại email khôi phục mật khẩu.');
      } else {
        await _sendPhoneOtp(resend: true);
        _showMessage('Đã gửi lại mã OTP.');
      }
    } on FirebaseAuthException catch (error) {
      _showError(_authError(error.code));
    } catch (_) {
      _showError('Không thể gửi lại mã. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_otpForm.currentState!.validate()) return;
    if (_remainingSeconds == 0) {
      _showError('Mã OTP đã hết hạn. Hãy nhấn gửi lại mã.');
      return;
    }
    final session = _phoneSession;
    if (session == null) {
      _showError('Phiên xác minh không hợp lệ. Hãy gửi lại mã.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await _completePhoneVerification(
        session: session,
        smsCode: _otp.text.trim(),
      );
    } on FirebaseAuthException catch (error) {
      _showError(_authError(error.code));
    } catch (_) {
      _showError('Không thể xác minh OTP. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completePhoneVerification({
    required PhoneOtpSession session,
    required String smsCode,
  }) async {
    final credential = await _auth.confirmPhoneOtp(
      session: session,
      smsCode: smsCode,
    );

    // Firebase có thể tự tạo một tài khoản Phone mới nếu số điện thoại chưa
    // từng được liên kết. Không cho phép dùng tài khoản mới đó để đổi mật khẩu.
    if (credential.additionalUserInfo?.isNewUser ?? false) {
      await credential.user?.delete();
      await _auth.signOut();
      throw FirebaseAuthException(code: 'phone-not-linked');
    }

    final hasPasswordProvider =
        credential.user?.providerData.any(
          (provider) => provider.providerId == 'password',
        ) ??
        false;
    if (!hasPasswordProvider) {
      await _auth.signOut();
      throw FirebaseAuthException(code: 'phone-not-linked');
    }

    _timer?.cancel();
    if (mounted) setState(() => _step = _ResetStep.newPassword);
  }

  Future<void> _updatePassword() async {
    if (!_passwordForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await _auth.updateCurrentUserPassword(_newPassword.text);
      await _auth.signOut();
      if (mounted) setState(() => _step = _ResetStep.success);
    } on FirebaseAuthException catch (error) {
      _showError(_authError(error.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToIdentifier() {
    _timer?.cancel();
    _otp.clear();
    _newPassword.clear();
    _confirmPassword.clear();
    setState(() {
      _step = _ResetStep.identifier;
      _remainingSeconds = _otpDuration;
      _phoneSession = null;
    });
  }

  void _showError(String message) => _showMessage(message, isError: true);

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? mangaRed : mangaGreen,
        ),
      );
  }

  String _authError(String code) => switch (code) {
    'invalid-email' => 'Email không hợp lệ.',
    'user-not-found' =>
      'Nếu tài khoản tồn tại, hướng dẫn khôi phục sẽ được gửi.',
    'invalid-phone-number' => 'Số điện thoại không hợp lệ.',
    'invalid-verification-code' => 'Mã OTP không đúng.',
    'session-expired' => 'Mã OTP đã hết hạn. Hãy gửi lại mã.',
    'phone-not-linked' =>
      'Số điện thoại này chưa được liên kết với tài khoản mật khẩu.',
    'operation-not-allowed' =>
      'Phương thức xác thực này chưa được bật trên Firebase.',
    'quota-exceeded' => 'Đã hết hạn mức gửi OTP. Vui lòng thử lại sau.',
    'too-many-requests' => 'Có quá nhiều yêu cầu. Vui lòng chờ rồi thử lại.',
    'network-request-failed' =>
      'Không có kết nối mạng. Vui lòng kiểm tra Internet.',
    'requires-recent-login' =>
      'Phiên xác minh đã hết hạn. Vui lòng thực hiện lại.',
    'weak-password' => 'Mật khẩu chưa đủ mạnh. Hãy kiểm tra lại các điều kiện.',
    _ => 'Thao tác chưa thành công. Vui lòng thử lại.',
  };

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: mangaCream,
      foregroundColor: mangaInk,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: _loading
            ? null
            : _step == _ResetStep.identifier
            ? () => Navigator.pop(context)
            : _backToIdentifier,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: Stack(
      children: [
        const Positioned.fill(child: _ResetBackdrop()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: MangaPanel(
                color: mangaCream,
                padding: const EdgeInsets.all(28),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (_step) {
                    _ResetStep.identifier => _buildIdentifierStep(),
                    _ResetStep.emailSent => _buildEmailSentStep(),
                    _ResetStep.phoneOtp => _buildOtpStep(),
                    _ResetStep.newPassword => _buildNewPasswordStep(),
                    _ResetStep.success => _buildSuccessStep(),
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildHeader({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
  }) => Column(
    key: key,
    children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: mangaYellow,
          shape: BoxShape.circle,
          border: Border.all(color: mangaInk, width: 3),
        ),
        child: Icon(icon, size: 36, color: mangaRed),
      ),
      const SizedBox(height: 18),
      Text(title, textAlign: TextAlign.center, style: mangaDisplay(size: 31)),
      const SizedBox(height: 8),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
      ),
      const SizedBox(height: 22),
      Container(height: 3, color: mangaInk),
      const SizedBox(height: 22),
    ],
  );

  Widget _buildIdentifierStep() => Form(
    key: _identifierForm,
    child: Column(
      key: const ValueKey('identifier-step'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(
          key: const ValueKey('identifier-header'),
          icon: Icons.lock_reset_rounded,
          title: 'QUÊN MẬT KHẨU?',
          subtitle:
              'Nhập email để nhận liên kết khôi phục, hoặc số điện thoại '
              'đã liên kết để nhận mã OTP.',
        ),
        TextFormField(
          key: const Key('forgot-identifier-field'),
          controller: _identifier,
          enabled: !_loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [
            AutofillHints.email,
            AutofillHints.telephoneNumber,
          ],
          decoration: const InputDecoration(
            labelText: 'Email hoặc số điện thoại',
            hintText: 'ban@example.com hoặc 0912345678',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
          validator: AuthValidators.emailOrPhone,
          onFieldSubmitted: (_) => _loading ? null : _requestReset(),
        ),
        const SizedBox(height: 12),
        const _SecurityNote(
          text:
              'Vì lý do bảo mật, chỉ số điện thoại đã xác minh và liên kết '
              'với tài khoản mới có thể dùng OTP để đổi mật khẩu.',
        ),
        const SizedBox(height: 20),
        _PrimaryAction(
          loading: _loading,
          label: 'GỬI YÊU CẦU',
          onPressed: _requestReset,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text(
            'Quay lại đăng nhập',
            style: TextStyle(color: mangaRed, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );

  Widget _buildEmailSentStep() => Column(
    key: const ValueKey('email-sent-step'),
    mainAxisSize: MainAxisSize.min,
    children: [
      _buildHeader(
        key: const ValueKey('email-sent-header'),
        icon: Icons.mark_email_read_outlined,
        title: 'KIỂM TRA EMAIL!',
        subtitle:
            'Firebase đã gửi liên kết đặt lại mật khẩu đến '
            '$_identifierValue. Mở liên kết trong email để tiếp tục.',
      ),
      _CountdownCard(time: _formattedTime),
      const SizedBox(height: 14),
      _ResendAction(
        canResend: _canResend,
        loading: _loading,
        onPressed: _resend,
        waitingLabel: 'Có thể gửi lại sau $_formattedTime',
        readyLabel: 'Gửi lại email',
      ),
      const SizedBox(height: 16),
      const _SecurityNote(
        text:
            'Không thấy email? Hãy kiểm tra thư rác hoặc nhập lại địa chỉ '
            'email. Liên kết do Firebase gửi thay cho OTP email.',
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: _loading ? null : _backToIdentifier,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('ĐỔI EMAIL / SỐ ĐIỆN THOẠI'),
      ),
    ],
  );

  Widget _buildOtpStep() => Form(
    key: _otpForm,
    child: Column(
      key: const ValueKey('otp-step'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(
          key: const ValueKey('otp-header'),
          icon: Icons.sms_outlined,
          title: 'NHẬP MÃ OTP',
          subtitle:
              'Mã gồm 6 chữ số đã được gửi đến '
              '${AuthValidators.normalizeVietnamesePhone(_identifierValue)}.',
        ),
        TextFormField(
          key: const Key('otp-field'),
          controller: _otp,
          enabled: !_loading && _remainingSeconds > 0,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: mangaMono(
            size: 25,
            weight: FontWeight.w900,
          ).copyWith(letterSpacing: 12),
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: 'Mã OTP',
            hintText: '000000',
            prefixIcon: Icon(Icons.password_rounded),
          ),
          validator: (value) {
            final code = value?.trim() ?? '';
            if (code.isEmpty) return 'Vui lòng nhập mã OTP';
            return code.length == 6 ? null : 'Mã OTP phải gồm 6 chữ số';
          },
          onFieldSubmitted: (_) => _loading ? null : _verifyOtp(),
        ),
        const SizedBox(height: 14),
        _CountdownCard(time: _formattedTime),
        const SizedBox(height: 8),
        _ResendAction(
          canResend: _canResend,
          loading: _loading,
          onPressed: _resend,
          waitingLabel: 'Mã còn hiệu lực trong $_formattedTime',
          readyLabel: 'Gửi lại mã OTP',
        ),
        const SizedBox(height: 18),
        _PrimaryAction(
          loading: _loading,
          label: 'XÁC NHẬN MÃ',
          onPressed: _verifyOtp,
        ),
      ],
    ),
  );

  Widget _buildNewPasswordStep() => Form(
    key: _passwordForm,
    child: Column(
      key: const ValueKey('new-password-step'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(
          key: const ValueKey('new-password-header'),
          icon: Icons.password_rounded,
          title: 'TẠO MẬT KHẨU MỚI',
          subtitle:
              'Số điện thoại đã được xác minh. Hãy đặt một mật khẩu mạnh '
              'cho tài khoản của bạn.',
        ),
        TextFormField(
          key: const Key('new-password-field'),
          controller: _newPassword,
          enabled: !_loading,
          obscureText: _hidePassword,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Mật khẩu mới',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _hidePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: AuthValidators.password,
        ),
        const SizedBox(height: 10),
        _PasswordRules(password: _newPassword.text),
        const SizedBox(height: 14),
        TextFormField(
          key: const Key('confirm-password-field'),
          controller: _confirmPassword,
          enabled: !_loading,
          obscureText: _hideConfirmPassword,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Nhập lại mật khẩu',
            prefixIcon: const Icon(Icons.lock_person_outlined),
            suffixIcon: IconButton(
              tooltip: _hideConfirmPassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              onPressed: () =>
                  setState(() => _hideConfirmPassword = !_hideConfirmPassword),
              icon: Icon(
                _hideConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) =>
              AuthValidators.confirmPassword(value, _newPassword.text),
          onFieldSubmitted: (_) => _loading ? null : _updatePassword(),
        ),
        const SizedBox(height: 20),
        _PrimaryAction(
          loading: _loading,
          label: 'ĐỔI MẬT KHẨU',
          onPressed: _updatePassword,
        ),
      ],
    ),
  );

  Widget _buildSuccessStep() => Column(
    key: const ValueKey('success-step'),
    mainAxisSize: MainAxisSize.min,
    children: [
      _buildHeader(
        key: const ValueKey('success-header'),
        icon: Icons.check_circle_outline_rounded,
        title: 'ĐỔI MẬT KHẨU THÀNH CÔNG!',
        subtitle:
            'Mật khẩu mới đã được cập nhật. Bạn có thể dùng mật khẩu này '
            'để đăng nhập ngay.',
      ),
      _PrimaryAction(
        loading: false,
        label: 'VỀ MÀN HÌNH ĐĂNG NHẬP',
        onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
      ),
    ],
  );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    ),
  );
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: mangaMuted,
      border: Border.all(color: mangaInk, width: 2),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer_outlined, color: mangaRed),
        const SizedBox(width: 8),
        Text(time, style: mangaMono(size: 20, weight: FontWeight.w900)),
      ],
    ),
  );
}

class _ResendAction extends StatelessWidget {
  const _ResendAction({
    required this.canResend,
    required this.loading,
    required this.onPressed,
    required this.waitingLabel,
    required this.readyLabel,
  });

  final bool canResend;
  final bool loading;
  final VoidCallback onPressed;
  final String waitingLabel;
  final String readyLabel;

  @override
  Widget build(BuildContext context) {
    if (!canResend) {
      return Text(
        waitingLabel,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800),
      );
    }

    return TextButton.icon(
      key: const Key('resend-otp-button'),
      onPressed: loading ? null : onPressed,
      icon: const Icon(Icons.refresh_rounded),
      label: Text(
        readyLabel,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _PasswordRules extends StatelessWidget {
  const _PasswordRules({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final rules = <(String, bool)>[
      ('Tối thiểu 8 ký tự', password.length >= 8),
      ('Có chữ hoa', RegExp(r'[A-Z]').hasMatch(password)),
      ('Có chữ thường', RegExp(r'[a-z]').hasMatch(password)),
      ('Có chữ số', RegExp(r'[0-9]').hasMatch(password)),
      ('Có ký tự đặc biệt', RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)),
    ];

    return Semantics(
      label: 'Các điều kiện mật khẩu',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final rule in rules)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: rule.$2
                    ? mangaGreen.withValues(alpha: .14)
                    : Colors.white,
                border: Border.all(
                  color: rule.$2 ? mangaGreen : mangaInk,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rule.$2
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 16,
                    color: rule.$2 ? mangaGreen : mangaInk,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    rule.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: rule.$2 ? mangaGreen : mangaInk,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: mangaSky.withValues(alpha: .35),
      border: const Border(left: BorderSide(color: mangaNavy, width: 4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, size: 20, color: mangaNavy),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ResetBackdrop extends StatelessWidget {
  const _ResetBackdrop();

  @override
  Widget build(BuildContext context) => Container(
    color: mangaNavy,
    child: Stack(
      children: List.generate(16, (index) {
        final size = 28.0 + (index % 4) * 12;
        return Positioned(
          left: (index * 113 % 1000).toDouble(),
          top: (index * 83 % 760).toDouble(),
          child: Transform.rotate(
            angle: index * .22,
            child: Icon(
              index.isEven ? Icons.lock_outline_rounded : Icons.bolt_rounded,
              size: size,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
        );
      }),
    ),
  );
}
