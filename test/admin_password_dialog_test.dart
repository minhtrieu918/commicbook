import 'package:commicbook/admin/admin_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dialog Admin đóng an toàn và trả về mật khẩu hợp lệ', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showAdminPasswordDialog(
                  context,
                  accountName: 'Nguyễn Văn A',
                );
              },
              child: const Text('MỞ'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('MỞ'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin-password-field')),
      'Admin@123',
    );
    await tester.enterText(
      find.byKey(const Key('admin-password-confirmation-field')),
      'Admin@123',
    );
    await tester.tap(find.byKey(const Key('admin-password-submit')));
    await tester.pumpAndSettle();

    expect(result, 'Admin@123');
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialog Admin không trả mật khẩu khi hủy', (tester) async {
    String? result = 'unchanged';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showAdminPasswordDialog(
                  context,
                  accountName: 'Nguyễn Văn A',
                );
              },
              child: const Text('MỞ'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('MỞ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HỦY'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
