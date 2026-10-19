import 'package:flutter/material.dart';

import '../../rdzen/wspolne/kalendarz_biodynamiczny.dart';
import '../../rdzen/wspolne/mapa_dzialek.dart';

/// Kolory, odstępy i rozmiary wyglądu „Nowoczesny" (osoby obyte ze
/// smartfonem).
///
/// Wartości pochodzą z planu (pkt 5): tło #F6F7F4, karty białe
/// z zaokrągleniem 18–20 px, tekst #0F1F12, tekst pomocniczy #4F5F51,
/// zieleń #1E5B2E, dolny pasek #0F1F12 z przyciskiem #B9E26A, tekst
/// 13–16 px.
///
/// Ekrany nie wpisują kodów kolorów ani rozmiarów — biorą je stąd albo
/// z `Theme.of` (CLAUDE.md, reguły interfejsu).
abstract final class MotywNowoczesny {
  static const Color tlo = Color(0xFFF6F7F4);
  static const Color karta = Color(0xFFFFFFFF);
  static const Color tekst = Color(0xFF0F1F12);
  static const Color tekstPomocniczy = Color(0xFF4F5F51);
  static const Color zielen = Color(0xFF1E5B2E);
  static const Color pasekNawigacji = Color(0xFF0F1F12);
  static const Color przyciskDodaj = Color(0xFFB9E26A);

  /// Ostrzeżenia trzymają te same barwy co w wyglądzie prostym —
  /// ostrzeżenie ma znaczyć to samo w obu wyglądach.
  static const Color ostrzezenieTlo = Color(0xFFFFF1D6);
  static const Color ostrzezenieObramowanie = Color(0xFF8A4B00);

  /// Krój z planu to Manrope. Plik czcionki dojdzie razem z czcionkami
  /// ekranowymi; do tego czasu krój systemowy — dokładnie tak samo jak
  /// w wyglądzie prostym.
  static const String? krojPisma = null;

  /// Najmniejszy tekst w tym wyglądzie (plan: 13–16 px).
  static const double minRozmiarTekstu = 13;

  /// Cel dotyku. Mniejszy niż w wyglądzie prostym, ale nie mniejszy niż
  /// zalecane 44 px — palcem trafia się także na nowoczesnym ekranie.
  static const double minCelDotyku = 44;

  static const double zaokraglenieKarty = 20;
  static const double zaokraglenieMale = 12;
  static const double odstep = 14;

  /// Wysokość dolnego paska nawigacji.
  static const double wysokoscPaska = 64;

  /// Barwy dni kalendarza biodynamicznego po rodzaju pracy. Nazwy prac
  /// pochodzą ze słownika (`assets/dane/kalendarz_biodynamiczny.json`).
  static const Map<String, Color> barwyPracy = {
    'korzeń': Color(0xFF8A5A2B),
    'liść': Color(0xFF3F7D3F),
    'kwiat': Color(0xFF6B4E71),
    'owoc': Color(0xFFC0532B),
  };

  /// Styl kalendarza biodynamicznego — kalendarz leży w `rdzen/wspolne/`.
  static const StylKalendarza stylKalendarza = StylKalendarza(
    tekst: tekst,
    tekstPomocniczy: tekstPomocniczy,
    tlo: karta,
    akcent: zielen,
    ostrzezenie: ostrzezenieObramowanie,
    barwyPracy: barwyPracy,
    zaokraglenie: zaokraglenieMale,
    odstep: odstep,
  );

  /// Barwy mapy działek. Mapa jest wspólna dla obu wyglądów
  /// (`rdzen/wspolne/`), więc kolory podaje wygląd.
  static const BarwyMapy barwyMapy = BarwyMapy(
    tlo: karta,
    obramowanie: Color(0xFFE2E7DF),
    dzialka: Color(0xFFE7EFE4),
    wyrozniona: Color(0x551E5B2E),
    kreska: zielen,
    tekst: tekst,
    zaokraglenie: zaokraglenieKarty,
  );

  static ThemeData zbuduj() {
    const schemat = ColorScheme.light(
      primary: zielen,
      onPrimary: karta,
      secondary: przyciskDodaj,
      onSecondary: tekst,
      surface: karta,
      onSurface: tekst,
      error: ostrzezenieObramowanie,
      onError: karta,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: schemat,
      scaffoldBackgroundColor: tlo,
      fontFamily: krojPisma,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: tekstPomocniczy,
          fontFamily: krojPisma,
          fontSize: minRozmiarTekstu,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: tlo,
        foregroundColor: tekst,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: karta,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(zaokraglenieKarty),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: zielen,
          foregroundColor: karta,
          minimumSize: const Size(0, minCelDotyku),
          textStyle: const TextStyle(
            fontFamily: krojPisma,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(zaokraglenieMale),
          ),
        ),
      ),
    );
  }
}
