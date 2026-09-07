import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:commicbook/core/models.dart';
import 'package:commicbook/features/auctions/auction_list_page.dart';
import 'package:commicbook/features/catalog/comic_detail_page.dart';
import 'package:commicbook/features/catalog/catalog_filters.dart';
import 'package:commicbook/service/database.dart';
import 'package:commicbook/ui/empty_state.dart';
import 'package:commicbook/ui/comic_cover_image.dart';
import 'package:commicbook/ui/manga_theme.dart';
import 'package:flutter/material.dart';

final _database = DatabaseService();

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.onAdd});

  final ValueChanged<ComicItem> onAdd;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String _mode = 'shop';
  String _genre = allGenresLabel;
  String _sort = 'Mới Nhất';

  List<ComicItem> _fromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs.indexed
          .where((entry) {
            final data = entry.$2.data();
            return (data['status'] as String? ?? 'active') == 'active' &&
                ((data['stock'] as num?)?.toInt() ?? 0) > 0;
          })
          .map((entry) {
            final index = entry.$1;
            final doc = entry.$2;
            final data = doc.data();
            const colors = [mangaRed, mangaNavy, mangaYellow, mangaGreen];
            return ComicItem(
              id: doc.id,
              title: data['title'] as String? ?? 'Chưa có tên',
              author: data['author'] as String? ?? 'Chưa rõ tác giả',
              price: data['price'] as num? ?? 0,
              originalPrice: data['originalPrice'] as num?,
              color: colors[index % colors.length],
              image: data['image'] as String? ?? '',
              genre: data['genre'] as String? ?? 'Chưa rõ',
              condition: data['condition'] as String? ?? 'Mới',
              rating: (data['rating'] as num?)?.toDouble() ?? 0,
              reviews: (data['reviews'] as num?)?.toInt() ?? 0,
              stock: (data['stock'] as num?)?.toInt() ?? 0,
              isNew: data['isNew'] as bool? ?? false,
              isSale: data['isSale'] as bool? ?? false,
              sellerUid: data['sellerUid'] as String? ?? '',
              previewImages:
                  (data['previewImages'] as List<dynamic>?)
                      ?.whereType<String>()
                      .toList() ??
                  const [],
            );
          })
          .toList();

  List<ComicItem> _filtered(List<ComicItem> source) {
    final selectedGenre = availableCatalogGenres(source).contains(_genre)
        ? _genre
        : allGenresLabel;
    final result = source
        .where((comic) => comicMatchesGenre(comic, selectedGenre))
        .toList();
    switch (_sort) {
      case 'Giá Thấp Nhất':
        result.sort((a, b) => a.price.compareTo(b.price));
      case 'Giá Cao Nhất':
        result.sort((a, b) => b.price.compareTo(a.price));
      case 'Đánh Giá Cao':
        result.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _database.comicsStream(),
        builder: (context, snapshot) {
          final allComics = snapshot.hasData
              ? _fromSnapshot(snapshot.data!)
              : <ComicItem>[];
          final genres = availableCatalogGenres(allComics);
          final comics = _filtered(allComics);

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _MangaHero()),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 36, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ModeSwitch(
                            value: _mode,
                            onChanged: (value) {
                              if (value == 'auction') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AuctionListPage(),
                                  ),
                                );
                                return;
                              }
                              setState(() => _mode = value);
                            },
                          ),
                          const SizedBox(height: 28),
                          if (_mode == 'shop')
                            _ShopFilters(
                              genre: _genre,
                              genres: genres,
                              sort: _sort,
                              onGenre: (value) =>
                                  setState(() => _genre = value),
                              onSort: (value) => setState(() => _sort = value),
                            )
                          else
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  color: mangaRed,
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        color: Colors.white,
                                        size: 9,
                                      ),
                                      SizedBox(width: 7),
                                      Text(
                                        'LIVE ĐẤU GIÁ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  '4 phiên đang diễn ra',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_mode == 'shop' &&
                  snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_mode == 'shop' && snapshot.hasError)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 280,
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'Không có dữ liệu',
                      message: 'Hiện chưa có dữ liệu để hiển thị.',
                    ),
                  ),
                )
              else if (_mode == 'shop' && comics.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 280,
                    child: EmptyState(
                      icon: allComics.isEmpty
                          ? Icons.library_books_outlined
                          : Icons.search_off_rounded,
                      title: allComics.isEmpty
                          ? 'Chưa có truyện để hiển thị'
                          : 'Không tìm thấy truyện phù hợp',
                      message: allComics.isEmpty
                          ? 'Danh mục sẽ được cập nhật khi có truyện đang bán.'
                          : 'Hãy thử chọn thể loại hoặc cách sắp xếp khác.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 64),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) => SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.crossAxisExtent >= 1100
                            ? 4
                            : constraints.crossAxisExtent >= 720
                            ? 3
                            : constraints.crossAxisExtent >= 450
                            ? 2
                            : 1,
                        mainAxisExtent: _mode == 'shop' ? 410 : 430,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ComicCard(
                          comic: comics[index],
                          onAdd: widget.onAdd,
                        ),
                        childCount: comics.length,
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: _MangaFooter()),
            ],
          );
        },
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
        final size = 120.0 + (index % 5) * 22;
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

class _MangaHero extends StatelessWidget {
  const _MangaHero();

  @override
  Widget build(BuildContext context) => Container(
    color: mangaNavy,
    constraints: const BoxConstraints(minHeight: 420),
    child: Stack(
      children: [
        const Positioned.fill(child: _ComicBackdrop()),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 46),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final text = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: mangaYellow,
                          border: Border.all(color: mangaInk, width: 2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'HOT DEAL HÔM NAY',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'THỊ TRƯỜNG\n'),
                            TextSpan(
                              text: 'TRUYỆN TRANH\n',
                              style: mangaDisplay(
                                size: wide ? 62 : 46,
                                color: mangaYellow,
                                spacing: 2.5,
                              ),
                            ),
                            const TextSpan(text: 'VIỆT NAM'),
                          ],
                        ),
                        style: mangaDisplay(
                          size: wide ? 62 : 46,
                          color: Colors.white,
                          spacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Mua, Bán & Đấu Giá truyện tranh chính hãng. Hơn 50,000 đầu sách từ Nhật Bản, Hàn Quốc và toàn thế giới.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MangaButton(
                            label: 'KHÁM PHÁ NGAY',
                            color: mangaRed,
                            foreground: Colors.white,
                            icon: Icons.explore_rounded,
                            onTap: () {},
                          ),
                          _MangaButton(
                            label: 'PHÒNG ĐẤU GIÁ',
                            icon: Icons.gavel_rounded,
                            color: mangaYellow,
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Wrap(
                        spacing: 34,
                        runSpacing: 12,
                        children: [
                          _HeroMetric(value: '50K+', label: 'ĐẦU SÁCH'),
                          _HeroMetric(value: '120K+', label: 'THÀNH VIÊN'),
                          _HeroMetric(value: '4.9★', label: 'ĐÁNH GIÁ'),
                        ],
                      ),
                    ],
                  );

                  if (!wide) return text;
                  return Row(
                    children: [
                      Expanded(child: text),
                      const SizedBox(width: 38),
                      const Expanded(child: _HeroCollage()),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _HeroCollage extends StatelessWidget {
  const _HeroCollage();

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      childAspectRatio: .82,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
    ),
    itemCount: 6,
    itemBuilder: (context, index) => Transform.translate(
      offset: Offset(
        0,
        index == 1
            ? -14
            : index == 3
            ? 14
            : 0,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: _ImageFallback(
          color: const [
            mangaRed,
            mangaNavy,
            mangaYellow,
            mangaGreen,
            mangaSakura,
            mangaSky,
          ][index],
        ),
      ),
    ),
  );
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: mangaDisplay(size: 25, color: mangaYellow)),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _MangaButton extends StatelessWidget {
  const _MangaButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.foreground = mangaInk,
    this.icon,
  });

  final String label;
  final Color color;
  final Color foreground;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.zero,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: mangaInk, width: 3)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeButton(
          active: value == 'shop',
          label: 'MUA BÁN',
          icon: Icons.library_books_rounded,
          onTap: () => onChanged('shop'),
        ),
        _ModeButton(
          active: value == 'auction',
          label: 'ĐẤU GIÁ',
          icon: Icons.gavel_rounded,
          onTap: () => onChanged('auction'),
        ),
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.active,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool active;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      color: active ? mangaInk : mangaCream,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: active ? mangaYellow : mangaInk, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: mangaDisplay(
              size: 18,
              color: active ? Colors.white : mangaInk,
              spacing: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ShopFilters extends StatelessWidget {
  const _ShopFilters({
    required this.genre,
    required this.genres,
    required this.sort,
    required this.onGenre,
    required this.onSort,
  });

  final String genre;
  final List<String> genres;
  final String sort;
  final ValueChanged<String> onGenre;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final genreItems = [allGenresLabel, ...genres];
    final selectedGenre = genreItems.contains(genre) ? genre : allGenresLabel;
    const sortItems = [
      'Mới Nhất',
      'Giá Thấp Nhất',
      'Giá Cao Nhất',
      'Đánh Giá Cao',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = [
          _FilterDropdown(
            label: 'THỂ LOẠI',
            value: selectedGenre,
            items: genreItems,
            onChanged: onGenre,
          ),
          _FilterDropdown(
            label: 'SẮP XẾP',
            value: sort,
            items: sortItems,
            onChanged: onSort,
          ),
        ];
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FilterLabel(),
              const SizedBox(height: 10),
              controls[0],
              const SizedBox(height: 10),
              controls[1],
            ],
          );
        }
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FilterLabel(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: controls[0]),
                  const SizedBox(width: 10),
                  Expanded(child: controls[1]),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            const _FilterLabel(),
            const SizedBox(width: 12),
            SizedBox(width: 260, child: controls[0]),
            const SizedBox(width: 12),
            SizedBox(width: 220, child: controls[1]),
          ],
        );
      },
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.filter_alt_rounded, size: 18),
      SizedBox(width: 5),
      Text('BỘ LỌC', style: TextStyle(fontWeight: FontWeight.w900)),
    ],
  );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 11),
    decoration: BoxDecoration(
      color: mangaCream,
      border: Border.all(color: mangaInk, width: 2),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        style: const TextStyle(
          color: mangaInk,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
        selectedItemBuilder: (context) => items
            .map(
              (item) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$label: ${item.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item.toUpperCase()),
              ),
            )
            .toList(),
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    ),
  );
}

class _ComicCard extends StatefulWidget {
  const _ComicCard({required this.comic, required this.onAdd});

  final ComicItem comic;
  final ValueChanged<ComicItem> onAdd;

  @override
  State<_ComicCard> createState() => _ComicCardState();
}

class _ComicCardState extends State<_ComicCard> {
  bool _favorite = false;

  @override
  Widget build(BuildContext context) {
    final comic = widget.comic;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComicDetailPage(comic: comic, onAdd: widget.onAdd),
        ),
      ),
      child: MangaPanel(
        padding: EdgeInsets.zero,
        shadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NetworkComicImage(
                    url: comic.image,
                    fallbackColor: comic.color,
                  ),
                  if (comic.isNew)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        color: mangaNavy,
                        child: const Text(
                          'MỚI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  if (comic.isSale)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        color: mangaRed,
                        child: const Text(
                          'SALE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 10,
                    right: 9,
                    child: InkWell(
                      onTap: () => setState(() => _favorite = !_favorite),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        color: Colors.white,
                        child: Icon(
                          _favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color: _favorite ? mangaRed : mangaInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        color: mangaMuted,
                        child: Text(
                          comic.genre.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.star_rounded,
                        color: mangaYellow,
                        size: 15,
                      ),
                      Text(
                        ' ${comic.rating} (${comic.reviews})',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mangaDisplay(size: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comic.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B5C3E),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: mangaYellow,
                        size: 15,
                      ),
                      Text(
                        ' ${comic.rating}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'CÒN ${comic.stock}',
                        style: TextStyle(
                          color: comic.stock <= 3 ? mangaRed : mangaGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        _money(comic.price),
                        style: mangaMono(size: 14, color: mangaRed),
                      ),
                      if (comic.originalPrice != null) ...[
                        const SizedBox(width: 7),
                        Text(
                          _money(comic.originalPrice!),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black45,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: comic.stock > 0
                          ? () => widget.onAdd(comic)
                          : null,
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 17,
                      ),
                      label: const Text('THÊM VÀO GIỎ'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkComicImage extends StatelessWidget {
  const _NetworkComicImage({required this.url, required this.fallbackColor});

  final String url;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) =>
      ComicCoverImage(source: url, fallbackColor: fallbackColor);
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    color: color,
    alignment: Alignment.center,
    child: const Icon(
      Icons.auto_stories_rounded,
      color: Colors.white,
      size: 54,
    ),
  );
}

class _AuctionCard extends StatefulWidget {
  const _AuctionCard({required this.item});

  final AuctionItem item;

  @override
  State<_AuctionCard> createState() => _AuctionCardState();
}

class _AuctionCardState extends State<_AuctionCard> {
  late Duration _remaining = widget.item.duration;
  late num _bid = widget.item.currentBid;
  late int _bidCount = widget.item.bids;
  late final TextEditingController _bidController;
  bool _bidSuccess = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bidController = TextEditingController(
      text: (widget.item.currentBid + 50000).round().toString(),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _remaining.inSeconds <= 0) return;
      setState(() => _remaining -= const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bidController.dispose();
    super.dispose();
  }

  void _placeBid() {
    final nextBid = num.tryParse(
      _bidController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (nextBid == null || nextBid <= _bid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Giá mới phải lớn hơn ${_money(_bid)}.')),
      );
      return;
    }
    setState(() {
      _bid = nextBid;
      _bidCount++;
      _bidSuccess = true;
      _bidController.text = (_bid + 50000).round().toString();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đặt giá thành công!')));
  }

  @override
  Widget build(BuildContext context) => MangaPanel(
    padding: EdgeInsets.zero,
    shadow: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NetworkComicImage(
                url: widget.item.image,
                fallbackColor: mangaNavy,
              ),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  color: mangaRed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  child: const Text(
                    '● LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  color: mangaYellow,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Text(
                    widget.item.condition,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          color: mangaInk,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              const Icon(Icons.timer_rounded, color: mangaYellow, size: 17),
              const SizedBox(width: 7),
              Text(
                _duration(_remaining),
                style: mangaMono(size: 13, color: Colors.white),
              ),
              const Spacer(),
              Text(
                '$_bidCount LƯỢT',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Người bán: ${widget.item.seller}',
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
              const SizedBox(height: 10),
              const Text(
                'GIÁ HIỆN TẠI',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
              ),
              Text(_money(_bid), style: mangaMono(size: 17, color: mangaRed)),
              Text(
                'Giá khởi điểm: ${_money(widget.item.startBid)}',
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bidController,
                      keyboardType: TextInputType.number,
                      style: mangaMono(size: 12),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'GIÁ CỦA BẠN (VNĐ)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Đặt giá',
                    onPressed: _remaining.inSeconds > 0 ? _placeBid : null,
                    icon: const Icon(Icons.gavel_rounded),
                  ),
                ],
              ),
              if (_bidSuccess) ...[
                const SizedBox(height: 7),
                const Text(
                  '✓ BẠN ĐANG DẪN ĐẦU',
                  style: TextStyle(
                    color: mangaGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _MangaFooter extends StatelessWidget {
  const _MangaFooter();

  @override
  Widget build(BuildContext context) => Container(
    color: mangaInk,
    padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 60,
              runSpacing: 30,
              children: [
                SizedBox(
                  width: 270,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MANGA MART',
                        style: mangaDisplay(size: 28, color: mangaYellow),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nền tảng mua bán & đấu giá truyện tranh hàng đầu Việt Nam.',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const _FooterColumn(
                  title: 'DỊCH VỤ',
                  items: ['Mua Truyện', 'Đấu Giá', 'Trao Đổi'],
                ),
                const _FooterColumn(
                  title: 'HỖ TRỢ',
                  items: [
                    'Trung Tâm Hỗ Trợ',
                    'Bảo Hành',
                    'Hoàn Tiền',
                    'Liên Hệ',
                  ],
                ),
                const _FooterColumn(
                  title: 'CỘNG ĐỒNG',
                  items: ['Blog Manga', 'Forum', 'Discord', 'YouTube'],
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            const Row(
              children: [
                Text(
                  '© 2026 Manga Mart. All rights reserved.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                Spacer(),
                Text(
                  'Thiết kế tại Việt Nam 🇻🇳',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: mangaDisplay(size: 17, color: mangaYellow)),
        const SizedBox(height: 9),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              item,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ),
      ],
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
  return '$bufferđ';
}

String _duration(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
