import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class CreateExchangePostPage extends StatefulWidget {
  const CreateExchangePostPage({super.key});

  @override
  State<CreateExchangePostPage> createState() => _CreateExchangePostPageState();
}

class _CreateExchangePostPageState extends State<CreateExchangePostPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _offeredComic = TextEditingController();
  final _condition = TextEditingController();
  final _author = TextEditingController();
  final _contact = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _offeredComic.dispose();
    _condition.dispose();
    _author.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      await _database.createExchangePost(
        uid: uid,
        title: _title.text.trim(),
        content: _content.text.trim(),
        offeredComic: _offeredComic.text.trim(),
        condition: _condition.text.trim(),
        author: _author.text.trim(),
        contactDetails: _contact.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Không thể tạo bài viết.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: mangaInk,
      foregroundColor: Colors.white,
      title: Text(
        'TẠO BÀI TRAO ĐỔI',
        style: mangaDisplay(size: 22, color: mangaYellow),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            MangaPanel(
              shadow: false,
              child: Form(
                key: _form,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Tiêu đề'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập tiêu đề'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _requiredField(_offeredComic, 'Truyện dùng để trao đổi'),
                    _requiredField(_condition, 'Tình trạng truyện'),
                    _requiredField(_author, 'Tác giả'),
                    _requiredField(_contact, 'Thông tin liên hệ'),
                    TextFormField(
                      controller: _content,
                      minLines: 5,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung trao đổi',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập nội dung'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: const Icon(Icons.publish_rounded),
                        label: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(_loading ? 'ĐANG ĐĂNG...' : 'ĐĂNG BÀI'),
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
    ),
  );

  Widget _requiredField(TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Vui lòng nhập $label'
              : null,
        ),
      );
}
