import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/auth/auth_validators.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class SellerRegistrationPage extends StatefulWidget {
  const SellerRegistrationPage({super.key});

  @override
  State<SellerRegistrationPage> createState() => _SellerRegistrationPageState();
}

class _SellerRegistrationPageState extends State<SellerRegistrationPage> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _businessName = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _bankAccount = TextEditingController();
  final _document = TextEditingController();
  bool _acceptedTerms = false;
  bool _loading = false;
  bool _requestInitialized = false;

  @override
  void dispose() {
    _fullName.dispose();
    _businessName.dispose();
    _phone.dispose();
    _address.dispose();
    _bankAccount.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đồng ý điều khoản người bán.')),
      );
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      await _database.registerAsSeller(
        uid: uid,
        fullName: _fullName.text.trim(),
        businessName: _businessName.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        bankAccount: _bankAccount.text.trim(),
        verificationDocument: _document.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi yêu cầu đăng ký Seller cho Admin duyệt.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Không thể đăng ký Seller.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Bạn chưa đăng nhập',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'ĐĂNG KÝ SELLER',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _database.sellerRegistrationRequestStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const NoDataState();
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data();
          final status = data?['status'] as String?;
          if (status == 'pending') {
            return const _SellerRequestState(
              icon: Icons.hourglass_top_rounded,
              title: 'Đang chờ Admin duyệt',
              message:
                  'Hồ sơ đã được gửi. Quyền Seller và kho truyện chỉ xuất hiện sau khi Admin duyệt.',
            );
          }
          if (status == 'approved') {
            return const _SellerRequestState(
              icon: Icons.verified_rounded,
              title: 'Đã được duyệt Seller',
              message:
                  'Bạn đã có quyền tạo truyện và quản lý kho trong Seller Hub.',
            );
          }
          if (status == 'rejected' && data != null && !_requestInitialized) {
            _fullName.text = data['fullName'] as String? ?? '';
            _businessName.text = data['businessName'] as String? ?? '';
            _phone.text = data['phone'] as String? ?? '';
            _address.text = data['address'] as String? ?? '';
            _bankAccount.text = data['bankAccount'] as String? ?? '';
            _document.text = data['verificationDocument'] as String? ?? '';
            _requestInitialized = true;
          }
          return _registrationForm(
            rejectionReason: status == 'rejected'
                ? (data?['rejectionReason'] as String? ?? '')
                : '',
          );
        },
      ),
    );
  }

  Widget _registrationForm({required String rejectionReason}) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          if (rejectionReason.isNotEmpty) ...[
            MangaPanel(
              shadow: false,
              color: const Color(0xFFFFE8E8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: mangaRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Admin từ chối: $rejectionReason',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          MangaPanel(
            shadow: false,
            child: Form(
              key: _form,
              child: Column(
                children: [
                  _field(_fullName, 'Họ và tên'),
                  _field(
                    _businessName,
                    'Tên cửa hàng/doanh nghiệp (không bắt buộc)',
                    optional: true,
                  ),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                    ),
                    validator: AuthValidators.phone,
                  ),
                  const SizedBox(height: 12),
                  _field(_address, 'Địa chỉ hoạt động'),
                  _field(_bankAccount, 'Tài khoản ngân hàng nhận tiền'),
                  _field(_document, 'Tài liệu xác minh (mã hoặc đường dẫn)'),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _acceptedTerms,
                    onChanged: (value) =>
                        setState(() => _acceptedTerms = value == true),
                    title: const Text(
                      'Tôi đồng ý với điều khoản dành cho người bán.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: const Icon(Icons.storefront_rounded),
                      label: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          _loading
                              ? 'ĐANG GỬI...'
                              : rejectionReason.isEmpty
                              ? 'GỬI ADMIN DUYỆT'
                              : 'GỬI LẠI YÊU CẦU',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: optional
          ? null
          : (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập $label'
                : null,
    ),
  );
}

class _SellerRequestState extends StatelessWidget {
  const _SellerRequestState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: MangaPanel(
          shadow: false,
          child: EmptyState(icon: icon, title: title, message: message),
        ),
      ),
    ),
  );
}
