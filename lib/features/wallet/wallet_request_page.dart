import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class WalletRequestPage extends StatefulWidget {
  const WalletRequestPage({
    super.key,
    required this.type,
    required this.availableAmount,
  });

  final String type;
  final num availableAmount;

  @override
  State<WalletRequestPage> createState() => _WalletRequestPageState();
}

class _WalletRequestPageState extends State<WalletRequestPage> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String _method = 'VNPay';
  bool _loading = false;

  bool get _deposit => widget.type == 'deposit';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      await _database.createWalletRequest(
        uid: uid,
        type: widget.type,
        amount: num.parse(_amount.text.trim()),
        paymentMethod: _deposit ? _method : 'Bank transfer',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _deposit
                ? 'Đã tạo yêu cầu nạp tiền, đang chờ cổng thanh toán xử lý.'
                : 'Đã tạo yêu cầu rút tiền, trạng thái đang xử lý.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể tạo yêu cầu: $error')));
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
        _deposit ? 'NẠP TIỀN' : 'RÚT TIỀN',
        style: mangaDisplay(size: 22, color: mangaYellow),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            MangaPanel(
              shadow: false,
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _deposit
                          ? 'SỐ DƯ HIỆN TẠI: ${_money(widget.availableAmount)}'
                          : 'CÓ THỂ RÚT: ${_money(widget.availableAmount)}',
                      style: mangaDisplay(size: 20, color: mangaNavy),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số tiền',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (value) {
                        final amount = num.tryParse((value ?? '').trim());
                        if (amount == null || amount <= 0) {
                          return 'Số tiền không hợp lệ';
                        }
                        if (!_deposit && amount > widget.availableAmount) {
                          return 'Số tiền vượt quá số dư có thể rút';
                        }
                        return null;
                      },
                    ),
                    if (_deposit) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _method,
                        decoration: const InputDecoration(
                          labelText: 'Phương thức thanh toán',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'VNPay',
                            child: Text('VNPay'),
                          ),
                          DropdownMenuItem(
                            value: 'ZaloPay',
                            child: Text('ZaloPay'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _method = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _loading ? 'ĐANG XỬ LÝ...' : 'TẠO YÊU CẦU',
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
    ),
  );
}

String _money(num value) => '${value.toStringAsFixed(0)}đ';
