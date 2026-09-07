import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/auth/auth_validators.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _initialized = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save(String uid) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _database.updateUserProfile(
        uid: uid,
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Không cập nhật được hồ sơ.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mangaInk,
        foregroundColor: Colors.white,
        title: Text(
          'HỒ SƠ CÁ NHÂN',
          style: mangaDisplay(size: 22, color: mangaYellow),
        ),
      ),
      body: user == null
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Bạn chưa đăng nhập',
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _database.userProfileStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const NoDataState();
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.data!.exists) {
                  return const EmptyState(
                    icon: Icons.person_off_outlined,
                    title: 'Không có dữ liệu hồ sơ',
                  );
                }
                final data = snapshot.data!.data() ?? {};
                if (!_initialized) {
                  _name.text = data['fullName'] as String? ?? '';
                  _phone.text = data['phone'] as String? ?? '';
                  _initialized = true;
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView(
                      padding: const EdgeInsets.all(22),
                      children: [
                        MangaPanel(
                          shadow: false,
                          child: Form(
                            key: _form,
                            child: Column(
                              children: [
                                const CircleAvatar(
                                  radius: 38,
                                  backgroundColor: mangaSky,
                                  foregroundColor: mangaNavy,
                                  child: Icon(Icons.person_rounded, size: 42),
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _name,
                                  decoration: const InputDecoration(
                                    labelText: 'Họ và tên',
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Vui lòng nhập họ tên'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  initialValue: user.email ?? '',
                                  enabled: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Số điện thoại',
                                  ),
                                  validator: AuthValidators.phone,
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _loading
                                        ? null
                                        : () => _save(user.uid),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Text(
                                        _loading ? 'ĐANG LƯU...' : 'LƯU HỒ SƠ',
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
              },
            ),
    );
  }
}
