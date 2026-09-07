import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/admin/admin_hub_page.dart' as admin;
import 'package:commicbook/auth/auth_validators.dart';
import 'package:commicbook/core/models.dart';
import 'package:commicbook/features/auctions/auction_history_page.dart';
import 'package:commicbook/features/auctions/auction_list_page.dart';
import 'package:commicbook/features/catalog/catalog_page.dart' as catalog_page;
import 'package:commicbook/features/catalog/saved_comics_page.dart';
import 'package:commicbook/features/chat/chat_list_page.dart';
import 'package:commicbook/features/checkout/checkout_page.dart'
    as checkout_page;
import 'package:commicbook/features/exchange/exchange_list_page.dart';
import 'package:commicbook/features/exchange/exchange_requests_page.dart';
import 'package:commicbook/features/notifications/notifications_page.dart';
import 'package:commicbook/features/notifications/announcement_assets.dart';
import 'package:commicbook/features/orders/orders_page.dart';
import 'package:commicbook/features/profile/profile_page.dart';
import 'package:commicbook/features/profile/seller_registration_page.dart';
import 'package:commicbook/features/wallet/transaction_history_page.dart';
import 'package:commicbook/features/wallet/wallet_page.dart';
import 'package:commicbook/forgot_password.dart';
import 'package:commicbook/seller/seller_main.dart';
import 'package:commicbook/service/auth.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

final _auth = AuthService();
final _database = DatabaseService();

class ComicBookApp extends StatelessWidget {
  const ComicBookApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Manga Mart',
    theme: buildMangaTheme(),
    home: StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingPage();
        }
        return snapshot.hasData ? const MainScreen() : const AuthScreen();
      },
    ),
  );
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: mangaNavy,
    body: Center(child: CircularProgressIndicator(color: mangaYellow)),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await _auth.signIn(email: _email.text.trim(), password: _password.text);
      } else {
        final credential = await _auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
        await _database.createUser(
          uid: credential.user!.uid,
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
        );
      }
    } on FirebaseAuthException catch (error) {
      _show(_authError(error.code));
    } on FirebaseException catch (error) {
      _show('Không thể lưu dữ liệu: ${error.message ?? 'Vui lòng thử lại.'}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _authError(String code) => switch (code) {
    'invalid-email' => 'Email không hợp lệ.',
    'user-not-found' => 'Không tìm thấy tài khoản với email này.',
    'wrong-password' ||
    'invalid-credential' => 'Email hoặc mật khẩu không đúng.',
    'email-already-in-use' => 'Email này đã được sử dụng.',
    'weak-password' =>
      'Mật khẩu cần ít nhất 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',
    'network-request-failed' =>
      'Không kết nối được Firebase. Hãy kiểm tra Internet và thử lại.',
    'invalid-api-key' => 'Cấu hình Firebase không hợp lệ.',
    'too-many-requests' =>
      'Có quá nhiều lần thử đăng nhập. Vui lòng thử lại sau.',
    _ => 'Thao tác chưa thành công. Vui lòng thử lại.',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: _ComicBackdrop()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: MangaPanel(
                color: mangaCream,
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.menu_book_rounded,
                            color: mangaRed,
                            size: 34,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'MANGA MART',
                            style: mangaDisplay(size: 36, color: mangaRed),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(height: 4, color: mangaInk),
                      const SizedBox(height: 22),
                      Text(
                        _isLogin ? 'CHÀO MỪNG TRỞ LẠI!' : 'GIA NHẬP CỘNG ĐỒNG!',
                        textAlign: TextAlign.center,
                        style: mangaDisplay(size: 30),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isLogin
                            ? 'Đăng nhập để tiếp tục săn manga hiếm.'
                            : 'Tạo tài khoản để mua, bán và đấu giá truyện.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 22),
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Vui lòng nhập họ tên'
                              : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: AuthValidators.email,
                      ),
                      if (!_isLogin) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: AuthValidators.phone,
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: AuthValidators.password,
                      ),
                      if (_isLogin) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ForgotPasswordScreen(authService: _auth),
                              ),
                            ),
                            icon: const Icon(Icons.lock_reset_rounded),
                            label: const Text('Quên mật khẩu?'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              _loading
                                  ? 'ĐANG XỬ LÝ...'
                                  : (_isLogin ? 'ĐĂNG NHẬP' : 'TẠO TÀI KHOẢN'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _loading
                            ? null
                            : () => setState(() => _isLogin = !_isLogin),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: Text(
                          _isLogin
                              ? 'Chưa có tài khoản? Đăng ký ngay'
                              : 'Đã có tài khoản? Đăng nhập',
                          style: const TextStyle(
                            color: mangaRed,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ComicBackdrop extends StatelessWidget {
  const _ComicBackdrop();

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [mangaNavy, mangaInk],
      ),
    ),
    child: Stack(
      children: List.generate(18, (index) {
        final size = 30.0 + (index % 4) * 14;
        return Positioned(
          left: (index * 97 % 1000).toDouble(),
          top: (index * 71 % 760).toDouble(),
          child: Transform.rotate(
            angle: index * .2,
            child: Icon(
              index.isEven
                  ? Icons.auto_stories_rounded
                  : Icons.menu_book_rounded,
              size: size,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
        );
      }),
    ),
  );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  String _role = 'customer';
  final List<ComicItem> _cart = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  bool get _isAdmin => _role == 'admin';
  bool get _isModerator => _role == 'moderator';
  bool get _isStaff => _isAdmin || _isModerator;
  bool get _isSeller => _role == 'seller' || _isAdmin;

  @override
  void initState() {
    super.initState();
    _watchUserRole();
  }

  void _watchUserRole() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _profileSubscription = _database.userProfileStream(uid).listen((profile) {
      if (!mounted) return;
      setState(() => _role = profile.data()?['role'] as String? ?? 'customer');
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  void _addToCart(ComicItem comic) {
    setState(() => _cart.add(comic));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${comic.title} vào giỏ hàng.'),
        action: SnackBarAction(
          label: 'XEM GIỎ',
          textColor: mangaYellow,
          onPressed: _showCart,
        ),
      ),
    );
  }

  void _showCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: mangaCream,
      builder: (context) => _CartSheet(
        items: _cart,
        onCheckout: () => setState(_cart.clear),
        onRemove: (comic) {
          setState(() => _cart.remove(comic));
          Navigator.pop(context);
          _showCart();
        },
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openAccountPage(String value) {
    switch (value) {
      case 'profile':
        _openPage(const ProfilePage());
      case 'orders':
        _openPage(const OrdersPage());
      case 'saved-comics':
        _openPage(SavedComicsPage(onAdd: _addToCart));
      case 'exchange-requests':
        _openPage(const ExchangeRequestsPage());
      case 'auction-history':
        _openPage(const AuctionHistoryPage());
      case 'wallet':
        _openPage(const WalletPage());
      case 'transactions':
        _openPage(const TransactionHistoryPage());
      case 'chat':
        _openPage(const ChatListPage());
      case 'seller-registration':
        _openPage(const SellerRegistrationPage());
      case 'logout':
        _auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      catalog_page.CatalogPage(onAdd: _addToCart),
      const ExchangeListPage(),
      if (_isSeller) const SellerMainPage(),
      if (_isStaff) admin.AdminHubPage(canConfigure: _isAdmin),
    ];
    if (_index >= pages.length) _index = 0;

    return Scaffold(
      appBar: _CustomerHeader(
        isAdmin: _isStaff,
        isSeller: _isSeller,
        cartCount: _cart.length,
        onHome: () => setState(() => _index = 0),
        onAuction: () => _openPage(const AuctionListPage()),
        onNotifications: () => _openPage(const NotificationsPage()),
        onAccountSelected: _openAccountPage,
        onAdmin: () => setState(() => _index = pages.length - 1),
        onCart: _showCart,
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: mangaCream,
        indicatorColor: mangaRed,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.library_books_rounded),
            selectedIcon: Icon(Icons.library_books_rounded),
            label: 'Mua & đấu giá',
          ),
          const NavigationDestination(
            icon: Icon(Icons.swap_horiz_rounded),
            selectedIcon: Icon(Icons.swap_horiz_rounded),
            label: 'Trao đổi',
          ),
          if (_isSeller)
            const NavigationDestination(
              icon: Icon(Icons.storefront_rounded),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: 'Seller',
            ),
          if (_isStaff)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_rounded),
              selectedIcon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Quản trị',
            ),
        ],
      ),
    );
  }
}

class _CartSheet extends StatelessWidget {
  const _CartSheet({
    required this.items,
    required this.onRemove,
    required this.onCheckout,
  });

  final List<ComicItem> items;
  final ValueChanged<ComicItem> onRemove;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<num>(0, (amount, comic) => amount + comic.price);
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .78,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('GIỎ HÀNG', style: mangaDisplay(size: 30)),
                  const Spacer(),
                  Container(
                    color: mangaYellow,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      '${items.length} SẢN PHẨM',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(thickness: 3),
              if (items.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.remove_shopping_cart_rounded,
                          size: 52,
                          color: mangaNavy,
                        ),
                        const SizedBox(height: 10),
                        Text('GIỎ HÀNG ĐANG TRỐNG', style: mangaDisplay()),
                      ],
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final comic = items[index];
                      return MangaPanel(
                        padding: const EdgeInsets.all(10),
                        shadow: false,
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 70,
                              decoration: BoxDecoration(
                                color: comic.color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.auto_stories_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comic.title,
                                    style: mangaDisplay(size: 18),
                                  ),
                                  Text(
                                    comic.author,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    _money(comic.price),
                                    style: mangaMono(size: 12, color: mangaRed),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Xóa khỏi giỏ',
                              onPressed: () => onRemove(comic),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: mangaRed,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'TỔNG CỘNG',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Text(
                      _money(total),
                      style: mangaDisplay(size: 28, color: mangaRed),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => checkout_page.CheckoutPage.cart(
                            items: List<ComicItem>.from(items),
                            onSuccess: onCheckout,
                          ),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('TIẾN HÀNH THANH TOÁN'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget implements PreferredSizeWidget {
  const _CustomerHeader({
    required this.isAdmin,
    required this.isSeller,
    required this.cartCount,
    required this.onHome,
    required this.onAuction,
    required this.onNotifications,
    required this.onAccountSelected,
    required this.onAdmin,
    required this.onCart,
  });

  final bool isAdmin;
  final bool isSeller;
  final int cartCount;
  final VoidCallback onHome;
  final VoidCallback onAuction;
  final VoidCallback onNotifications;
  final ValueChanged<String> onAccountSelected;
  final VoidCallback onAdmin;
  final VoidCallback onCart;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) => Material(
    color: mangaInk,
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 850;
                  return Row(
                    children: [
                      InkWell(
                        onTap: onHome,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              color: mangaYellow,
                              size: 30,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'MANGA MART',
                              style: mangaDisplay(
                                size: wide ? 27 : 22,
                                color: mangaYellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (wide) ...[
                        const SizedBox(width: 34),
                        _HeaderLink(label: 'TRANG CHỦ', onTap: onHome),
                        _HeaderLink(label: 'TRUYỆN TRANH', onTap: onHome),
                        _HeaderLink(
                          label: 'ĐẤU GIÁ',
                          icon: Icons.gavel_rounded,
                          onTap: onAuction,
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 220,
                          height: 38,
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Tìm truyện tranh...',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: .55),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Colors.white60,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: .08),
                              contentPadding: EdgeInsets.zero,
                              enabledBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: Colors.white38,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'Thông báo',
                        onPressed: onNotifications,
                        icon: const AnnouncementIcon(
                          type: null,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: onCart,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                color: Colors.white,
                              ),
                            ),
                            if (cartCount > 0)
                              Positioned(
                                right: -5,
                                top: -6,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: mangaRed,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    '$cartCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        tooltip: 'Tài khoản',
                        color: mangaCream,
                        icon: const Icon(
                          Icons.account_circle_rounded,
                          color: mangaYellow,
                        ),
                        onSelected: onAccountSelected,
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Text(
                              _auth.currentUser?.email ?? 'Tài khoản',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'profile',
                            child: Text('Hồ sơ cá nhân'),
                          ),
                          const PopupMenuItem(
                            value: 'orders',
                            child: Text('Đơn hàng'),
                          ),
                          const PopupMenuItem(
                            value: 'saved-comics',
                            child: Text('Truyện đã lưu'),
                          ),
                          const PopupMenuItem(
                            value: 'exchange-requests',
                            child: Text('Yêu cầu trao đổi'),
                          ),
                          const PopupMenuItem(
                            value: 'auction-history',
                            child: Text('Lịch sử đấu giá'),
                          ),
                          const PopupMenuItem(
                            value: 'wallet',
                            child: Text('Ví của tôi'),
                          ),
                          const PopupMenuItem(
                            value: 'transactions',
                            child: Text('Lịch sử giao dịch'),
                          ),
                          const PopupMenuItem(
                            value: 'chat',
                            child: Text('Tin nhắn'),
                          ),
                          if (!isSeller)
                            const PopupMenuItem(
                              value: 'seller-registration',
                              child: Text('Đăng ký Seller'),
                            ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Đăng xuất'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isAdmin && wide) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: onAdmin,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: mangaYellow,
                            side: const BorderSide(color: mangaYellow),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('ADMIN ›'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          Container(height: 4, color: mangaRed),
        ],
      ),
    ),
  );
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 18),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: mangaYellow, size: 15),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

String _money(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '$buffer đ';
}
