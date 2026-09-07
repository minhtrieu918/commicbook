import 'package:commicbook/auth/auth_validators.dart';
import 'package:flutter/material.dart';

Future<String?> showAdminPasswordDialog(
  BuildContext context, {
  required String accountName,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => AdminPasswordDialog(accountName: accountName),
);

/// Dialog tự quản lý controller để chúng chỉ bị hủy sau khi route đóng xong.
class AdminPasswordDialog extends StatefulWidget {
  const AdminPasswordDialog({super.key, required this.accountName});

  final String accountName;

  @override
  State<AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<AdminPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _password.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Đặt mật khẩu người dùng'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tài khoản: ${widget.accountName}'),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('admin-password-field'),
              controller: _password,
              autofocus: true,
              obscureText: _hidePassword,
              decoration: InputDecoration(
                labelText: 'Mật khẩu mới',
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: AuthValidators.password,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('admin-password-confirmation-field'),
              controller: _confirmation,
              obscureText: _hideConfirmation,
              decoration: InputDecoration(
                labelText: 'Nhập lại mật khẩu',
                suffixIcon: IconButton(
                  tooltip: _hideConfirmation ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: () =>
                      setState(() => _hideConfirmation = !_hideConfirmation),
                  icon: Icon(
                    _hideConfirmation
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  AuthValidators.confirmPassword(value, _password.text),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Mật khẩu không được lưu trong hồ sơ Firestore.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('HỦY'),
      ),
      FilledButton.icon(
        key: const Key('admin-password-submit'),
        onPressed: _submit,
        icon: const Icon(Icons.password_rounded),
        label: const Text('ĐẶT MẬT KHẨU'),
      ),
    ],
  );
}
