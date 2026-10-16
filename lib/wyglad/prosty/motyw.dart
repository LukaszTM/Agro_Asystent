import 'package:flutter/material.dart';

import '../../rdzen/wspolne/mapa_dzialek.dart';

/// Kolory, odstępy i rozmiary wyglądu „Prosty" (użytkownicy 60+).
///
/// Wartości pochodzą z makiety opisanej w planie (pkt 5). Ekrany nie wpisują
/// kodów kolorów ani rozmiarów czcionek — biorą je stąd albo z `Theme.of`.
abstract final class MotywProsty {
  // Kolory z makiety.
  static const Color tlo = Color(0xFFF4F6F0);
  static const Color tekst = Color(0xFF10230F);
  static const Color zielenAkcji = Color(0xFF1E5B2E);
  static const Color powierzchnia = Color(0xFFFFFFFF);
  static const Color powierzchniaDruga = Color(0xFFE4EEDF);
  static const Color ostrzezenieTlo = Color(0xFFFFF1D6);
  static const Color ostrzezenieObramowanie = Color(0xFF8A4B00);

  /// Krój z makiety. Plik czcionki dojdzie przy pierwszym ekranie produkcyjnym
  /// (Atkinson Hyperlegible, licencja OFL); do tego czasu krój systemowy.
  static const String? krojPisma = null;

  /// Najmniejszy dopuszczalny rozmiar tekstu (plan, pkt 5).
  static const double minRozmiarTekstu = 18;

  /// Najmniejszy cel dotyku (plan, pkt 5).
  static const double minCelDotyku = 48;

  static const double zaokraglenieMale = 14;
  static const double zaokraglenieDuze = 18;
  static const double odstep = 16;

  /// Barwy mapy działek dla tego wyglądu — sama mapa leży w `rdzen/`.
  static const BarwyMapy barwyMapy = BarwyMapy(
    tlo: powierzchnia,
    obramowanie: powierzchniaDruga,
    dzialka: powierzchniaDruga,
    wyrozniona: Color(0x401E5B2E),
    kreska: zielenAkcji,
    tekst: tekst,
    zaokraglenie: zaokraglenieDuze,
  );

  static ThemeData zbuduj() {
    const schemat = ColorScheme.light(
      primary: zielenAkcji,
      onPrimary: powierzchnia,
      secondary: powierzchniaDruga,
      onSecondary: tekst,
      surface: powierzchnia,
      onSurface: tekst,
      error: ostrzezenieObramowanie,
      onError: powierzchnia,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: schemat,
      scaffoldBackgroundColor: tlo,
      fontFamily: krojPisma,
      // Żaden styl nie schodzi poniżej 18 px.
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: 40,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: 20,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: minRozmiarTekstu,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: tekst,
          fontFamily: krojPisma,
          fontSize: 20,
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
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: powierzchnia,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(zaokraglenieDuze),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: zielenAkcji,
          foregroundColor: powierzchnia,
          minimumSize: const Size(minCelDotyku * 2, minCelDotyku + 8),
          textStyle: const TextStyle(
            fontFamily: krojPisma,
            fontSize: 22,
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
