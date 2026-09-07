import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/comic_cover_image.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class SellerCreateListingPage extends StatefulWidget {
  const SellerCreateListingPage({super.key});

  @override
  State<SellerCreateListingPage> createState() =>
      _SellerCreateListingPageState();
}

class _SellerCreateListingPageState extends State<SellerCreateListingPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _genre = TextEditingController(text: 'Shounen');
  final _condition = TextEditingController(text: 'Tốt');
  final _stock = TextEditingController(text: '1');
  final _image = TextEditingController();
  final _publisher = TextEditingController();
  final _publicationYear = TextEditingController();
  final _originCountry = TextEditingController();
  final _pageCount = TextEditingController();
  final _edition = TextEditingController();
  String _cover = 'SOFT';
  String _colorType = 'GRAYSCALE';
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _price.dispose();
    _description.dispose();
    _genre.dispose();
    _condition.dispose();
    _stock.dispose();
    _image.dispose();
    _publisher.dispose();
    _publicationYear.dispose();
    _originCountry.dispose();
    _pageCount.dispose();
    _edition.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để gửi truyện bán.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _database.createSellRequest(
        uid: user.uid,
        title: _title.text.trim(),
        author: _author.text.trim(),
        price: num.parse(_price.text.trim()),
        description: _description.text.trim(),
        genre: _genre.text.trim(),
        condition: _condition.text.trim(),
        stock: int.parse(_stock.text.trim()),
        metadata: {
          'image': _image.text.trim(),
          'publisher': _publisher.text.trim(),
          'publicationYear': int.tryParse(_publicationYear.text.trim()),
          'originCountry': _originCountry.text.trim(),
          'pageCount': int.tryParse(_pageCount.text.trim()),
          'cover': _cover,
          'colorType': _colorType,
          'edition': _edition.text.trim(),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi truyện cho admin duyệt.')),
      );
      _form.currentState!.reset();
      _title.clear();
      _author.clear();
      _price.clear();
      _description.clear();
      _genre.text = 'Shounen';
      _condition.text = 'Tốt';
      _stock.text = '1';
      _image.clear();
      _publisher.clear();
      _publicationYear.clear();
      _originCountry.clear();
      _pageCount.clear();
      _edition.clear();
      Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không gửi được yêu cầu: ${error.message ?? error.code}',
          ),
        ),
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
        'TẠO TRUYỆN BÁN',
        style: mangaDisplay(size: 22, color: mangaYellow),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            MangaPanel(
              shadow: false,
              child: Form(
                key: _form,
                child: Column(
                  children: [
                    const _SectionHeader(
                      icon: Icons.menu_book_rounded,
                      title: 'Thông tin truyện',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Tên truyện',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Vui lòng nhập tên truyện'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _author,
                      decoration: const InputDecoration(
                        labelText: 'Tác giả',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Vui lòng nhập tác giả'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _genre,
                            decoration: const InputDecoration(
                              labelText: 'Thể loại',
                              prefixIcon: Icon(Icons.category_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _condition,
                            decoration: const InputDecoration(
                              labelText: 'Tình trạng',
                              prefixIcon: Icon(Icons.verified_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Giá bán (VNĐ)',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                            validator: (value) {
                              final parsed = num.tryParse((value ?? '').trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Giá phải lớn hơn 0';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stock,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Số lượng',
                              prefixIcon: Icon(Icons.inventory_2_rounded),
                            ),
                            validator: (value) {
                              final parsed = int.tryParse((value ?? '').trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Số lượng phải > 0';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả truyện',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Vui lòng nhập mô tả'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _image,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Ảnh bìa (URL hoặc ảnh gợi ý)',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ComicImagePicker(
                      selected: _image.text.trim(),
                      onSelected: (path) => setState(() => _image.text = path),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _publisher,
                            decoration: const InputDecoration(
                              labelText: 'Nhà xuất bản',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _publicationYear,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Năm xuất bản',
                            ),
                            validator: _optionalPositiveInteger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _originCountry,
                            decoration: const InputDecoration(
                              labelText: 'Quốc gia xuất xứ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _pageCount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Số trang',
                            ),
                            validator: _optionalPositiveInteger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _edition,
                      decoration: const InputDecoration(labelText: 'Ấn bản'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _cover,
                            decoration: const InputDecoration(
                              labelText: 'Loại bìa',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'SOFT',
                                child: Text('Bìa mềm'),
                              ),
                              DropdownMenuItem(
                                value: 'HARD',
                                child: Text('Bìa cứng'),
                              ),
                              DropdownMenuItem(
                                value: 'DETACHED',
                                child: Text('Bìa rời'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _cover = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _colorType,
                            decoration: const InputDecoration(
                              labelText: 'Màu in',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'GRAYSCALE',
                                child: Text('Đen trắng'),
                              ),
                              DropdownMenuItem(
                                value: 'COLORED',
                                child: Text('Màu'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _colorType = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: mangaYellow.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: mangaNavy),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sau khi gửi, truyện sẽ ở trạng thái “Chờ duyệt” để admin kiểm tra.',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(_loading ? 'ĐANG GỬI...' : 'GỬI DUYỆT'),
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
}

String? _optionalPositiveInteger(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final parsed = int.tryParse(text);
  return parsed == null || parsed <= 0 ? 'Giá trị phải lớn hơn 0' : null;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        color: mangaRed,
        child: Icon(icon, color: Colors.white),
      ),
      const SizedBox(width: 10),
      Text(title, style: mangaDisplay(size: 22, color: mangaNavy)),
    ],
  );
}

class _ComicImagePicker extends StatelessWidget {
  const _ComicImagePicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (selected.isNotEmpty) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 140,
            height: 190,
            decoration: BoxDecoration(
              border: Border.all(color: mangaInk, width: 2),
            ),
            child: ComicCoverImage(source: selected, fallbackColor: mangaNavy),
          ),
        ),
        const SizedBox(height: 14),
      ],
      const Text(
        'ẢNH GỢI Ý TỪ SOURCE COMZONE',
        style: TextStyle(fontWeight: FontWeight.w900, color: mangaNavy),
      ),
      const SizedBox(height: 4),
      const Text(
        'Chọn một ảnh có sẵn hoặc tiếp tục sử dụng URL ở trên.',
        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 600
              ? 6
              : constraints.maxWidth >= 420
              ? 4
              : 3;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ComicTemplateAssets.all.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: .68,
            ),
            itemBuilder: (context, index) {
              final path = ComicTemplateAssets.all[index];
              final active = selected == path;
              return Semantics(
                button: true,
                selected: active,
                label: 'Ảnh truyện gợi ý ${index + 1}',
                child: InkWell(
                  onTap: () => onSelected(path),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: active ? mangaRed : mangaInk,
                        width: active ? 4 : 1.5,
                      ),
                    ),
                    child: ComicCoverImage(
                      source: path,
                      fallbackColor: mangaNavy,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ],
  );
}
