import 'package:commicbook/core/models.dart';

const allGenresLabel = 'Tất Cả';

List<String> comicGenres(ComicItem comic) => comic.genre
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty && item.toLowerCase() != 'chưa rõ')
    .toList();

List<String> availableCatalogGenres(Iterable<ComicItem> comics) {
  final genres = <String>{
    for (final comic in comics) ...comicGenres(comic),
  }.toList();
  genres.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return genres;
}

bool comicMatchesGenre(ComicItem comic, String selectedGenre) {
  if (selectedGenre == allGenresLabel) return true;
  final expected = selectedGenre.toLowerCase();
  return comicGenres(comic).any((genre) => genre.toLowerCase() == expected);
}
