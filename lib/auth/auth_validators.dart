/// Các quy tắc kiểm tra dữ liệu dùng chung cho đăng nhập, đăng ký và
/// khôi phục mật khẩu.
class AuthValidators {
  AuthValidators._();

  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9.!#$%&'
    '*+/=?^_`{|}~-]+@'
    r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  static final RegExp _phonePattern = RegExp(r'^(?:0[0-9]{9}|\+84[0-9]{9})$');

  static String compactPhone(String value) =>
      value.trim().replaceAll(RegExp(r'[\s.\-()]'), '');

  static String normalizeVietnamesePhone(String value) {
    final phone = compactPhone(value);
    return phone.startsWith('0') ? '+84${phone.substring(1)}' : phone;
  }

  static bool isEmail(String value) => _emailPattern.hasMatch(value.trim());

  static bool isPhone(String value) =>
      _phonePattern.hasMatch(compactPhone(value));

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email';
    return isEmail(email) ? null : 'Email chưa đúng định dạng';
  }

  static String? phone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại';
    return isPhone(phone) ? null : 'Số điện thoại chưa đúng định dạng';
  }

  static String? emailOrPhone(String? value) {
    final identifier = value?.trim() ?? '';
    if (identifier.isEmpty) return 'Vui lòng nhập email hoặc số điện thoại';
    if (isEmail(identifier) || isPhone(identifier)) return null;
    return 'Email hoặc số điện thoại chưa đúng định dạng';
  }

  static List<String> passwordRuleErrors(String password) {
    final errors = <String>[];
    if (password.length < 8) errors.add('ít nhất 8 ký tự');
    if (!RegExp(r'[A-Z]').hasMatch(password)) errors.add('1 chữ hoa');
    if (!RegExp(r'[a-z]').hasMatch(password)) errors.add('1 chữ thường');
    if (!RegExp(r'[0-9]').hasMatch(password)) errors.add('1 chữ số');
    if (!RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)) {
      errors.add('1 ký tự đặc biệt');
    }
    return errors;
  }

  static bool isStrongPassword(String password) =>
      passwordRuleErrors(password).isEmpty;

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Vui lòng nhập mật khẩu';
    final errors = passwordRuleErrors(password);
    return errors.isEmpty ? null : 'Mật khẩu cần có ${errors.join(', ')}';
  }

  static String? confirmPassword(String? value, String password) {
    final required = AuthValidators.password(value);
    if (required != null) return required;
    return value == password ? null : 'Mật khẩu xác nhận không khớp';
  }
}
