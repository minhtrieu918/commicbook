import 'package:commicbook/auth/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthValidators.email', () {
    test('chấp nhận email hợp lệ', () {
      expect(AuthValidators.email('reader@example.com'), isNull);
      expect(AuthValidators.email('reader+vip@sub.example.vn'), isNull);
    });

    test('từ chối email sai định dạng', () {
      expect(AuthValidators.email('reader@'), isNotNull);
      expect(AuthValidators.email('reader example.com'), isNotNull);
      expect(AuthValidators.email(''), isNotNull);
    });
  });

  group('AuthValidators.password', () {
    test('chấp nhận mật khẩu có đủ mọi điều kiện', () {
      expect(AuthValidators.password('Manga@123'), isNull);
    });

    test('yêu cầu tối thiểu 8 ký tự', () {
      expect(
        AuthValidators.passwordRuleErrors('Ma@1'),
        contains('ít nhất 8 ký tự'),
      );
    });

    test('yêu cầu chữ hoa, chữ thường, số và ký tự đặc biệt', () {
      expect(
        AuthValidators.passwordRuleErrors('manga@123'),
        contains('1 chữ hoa'),
      );
      expect(
        AuthValidators.passwordRuleErrors('MANGA@123'),
        contains('1 chữ thường'),
      );
      expect(
        AuthValidators.passwordRuleErrors('Manga@Test'),
        contains('1 chữ số'),
      );
      expect(
        AuthValidators.passwordRuleErrors('Manga1234'),
        contains('1 ký tự đặc biệt'),
      );
    });

    test('mật khẩu xác nhận phải trùng khớp', () {
      expect(
        AuthValidators.confirmPassword('Manga@124', 'Manga@123'),
        'Mật khẩu xác nhận không khớp',
      );
    });
  });

  group('AuthValidators.emailOrPhone', () {
    test('chấp nhận email hoặc số điện thoại Việt Nam', () {
      expect(AuthValidators.emailOrPhone('reader@example.com'), isNull);
      expect(AuthValidators.emailOrPhone('0912 345 678'), isNull);
      expect(AuthValidators.emailOrPhone('+84 912 345 678'), isNull);
    });

    test('chuẩn hóa số điện thoại sang E.164', () {
      expect(
        AuthValidators.normalizeVietnamesePhone('0912 345 678'),
        '+84912345678',
      );
      expect(
        AuthValidators.normalizeVietnamesePhone('+84 912 345 678'),
        '+84912345678',
      );
    });

    test('từ chối định danh sai định dạng', () {
      expect(AuthValidators.emailOrPhone('abc123'), isNotNull);
    });
  });
}
