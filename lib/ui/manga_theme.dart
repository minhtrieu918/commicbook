import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Bảng màu lấy cảm hứng từ Nhật Bản hiện đại: hoa anh đào, torii đỏ,
// indigo và nắng vàng. Các tên token cũ được giữ để toàn bộ app đồng bộ.
const mangaInk = Color.fromARGB(255, 67, 24, 97);
const mangaCream = Color(0xFFFFF7FA);
const mangaNavy = Color(0xFF3D64A8);
const mangaRed = Color.fromARGB(255, 6, 145, 48);
const mangaYellow = Color(0xFFFFD166);
const mangaMuted = Color(0xFFFFE5EC);
const mangaGreen = Color(0xFF2FA66A);
const mangaSakura = Color(0xFFFFB7C5);
const mangaSky = Color(0xFFBDE7F6);

TextStyle mangaDisplay({
  double size = 24,
  Color color = const Color.fromARGB(255, 125, 99, 144),
  double spacing = 1.4,
}) => GoogleFonts.bangers(
  fontSize: size,
  color: color,
  letterSpacing: spacing,
  height: .98,
);

TextStyle mangaMono({
  double size = 13,
  Color color = mangaInk,
  FontWeight weight = FontWeight.w700,
}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);

ThemeData buildMangaTheme() {
  final base = ThemeData.light(useMaterial3: true);
  final textTheme = GoogleFonts.nunitoTextTheme(
    base.textTheme,
  ).apply(bodyColor: mangaInk, displayColor: mangaInk);

  return base.copyWith(
    scaffoldBackgroundColor: mangaCream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: mangaRed,
      brightness: Brightness.light,
      primary: mangaRed,
      secondary: mangaNavy,
      tertiary: mangaYellow,
      surface: mangaCream,
      onSurface: mangaInk,
    ),
    textTheme: textTheme,
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: mangaInk, width: 3),
        borderRadius: BorderRadius.zero,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: mangaInk, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: mangaInk, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: mangaRed, width: 3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: mangaRed, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(fontWeight: FontWeight.w800),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: mangaRed,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: mangaInk, width: 2),
        ),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: mangaInk,
        side: const BorderSide(color: mangaInk, width: 2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w900),
      ),
    ),
    dividerColor: mangaInk,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: mangaInk,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}

class MangaPanel extends StatelessWidget {
  const MangaPanel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
    this.borderWidth = 3,
    this.shadow = true,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double borderWidth;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: mangaInk, width: borderWidth),
      boxShadow: shadow
          ? const [BoxShadow(color: mangaInk, offset: Offset(5, 5))]
          : null,
    ),
    child: child,
  );
}
