import 'package:flutter/material.dart';

import '../../funkcje/ustawienia/rozmiar_tekstu.dart';
import '../../rdzen/wspolne/mapa_dzialek.dart';

/// Kolory, odstępy i rozmiary programu na komputer.
///
/// Program na Windows ma **jeden wygląd dla wszystkich**, z ustawieniem
/// wielkości tekstu (plan, pkt 5). Barwy są te same co na telefonie — to ta
/// sama aplikacja i te same ostrzeżenia mają znaczyć to samo — ale układ
/// jest myszowy i gęstszy: stała nawigacja z boku, tabele zamiast kafelków,
/// szeroki obszar treści.
///
/// Ekrany nie wpisują kodów kolorów ani rozmiarów — biorą je stąd albo
/// z `Theme.of` (CLAUDE.md, reguły interfejsu).
abstract final class MotywKomputer {
  static const Color tlo = Color(0xFFF4F6F0);
  static const Color karta = Color(0xFFFFFFFF);
  static const Color powierzchniaDruga = Color(0xFFE4EEDF);
  static const Color tekst = Color(0xFF10230F);
  static const Color tekstPomocniczy = Color(0xFF4F5F51);
  static const Color zielen = Color(0xFF1E5B2E);
  static const Color obramowanie = Color(0xFFD7E0D3);

  /// Ostrzeżenia trzymają barwy wspólne dla całej aplikacji.
  static const Color ostrzezenieTlo = Color(0xFFFFF1D6);
  static const Color ostrzezenieObramowanie = Color(0xFF8A4B00);

  /// Krój dojdzie razem z czcionkami ekranowymi; do tego czasu systemowy.
  static const String? krojPisma = null;

  /// Szerokość stałej nawigacji po lewej.
  static const double szerokoscNawigacji = 232;

  /// Najmniejszy cel kliknięcia. Myszą trafia się precyzyjniej niż palcem,
  /// ale program ma też działać na laptopie z ekranem dotykowym.
  static const double minCelKlikniecia = 40;

  static const double zaokraglenieKarty = 14;
  static const double zaokraglenieMale = 10;
  static const double odstep = 16;

  /// Najmniejsza szerokość, przy której układ z nawigacją ma sens. Niżej
  /// nawigacja zwija się do ikon.
  static const double szerokoscPelnegoUkladu = 1000;

  static const BarwyMapy barwyMapy = BarwyMapy(
    tlo: karta,
    obramowanie: obramowanie,
    dzialka: powierzchniaDruga,
    wyrozniona: Color(0x551E5B2E),
    kreska: zielen,
    tekst: tekst,
    zaokraglenie: zaokraglenieKarty,
  );

  /// Barwy kawałków wykresu zasiewów.
  ///
  /// Zieleń gospodarstwa na początku, dalej barwy ziemi i zboża — mają się
  /// od siebie różnić także przy wydruku w szarości i przy najczęstszej
  /// wadzie wzroku (nierozróżnianie czerwieni i zieleni), dlatego idą
  /// naprzemiennie od ciemnych do jasnych.
  static const List<Color> barwyWykresu = [
    Color(0xFF1E5B2E),
    Color(0xFFC7922B),
    Color(0xFF4F8F4A),
    Color(0xFF8A4B00),
    Color(0xFF7FB069),
    Color(0xFF3D5A80),
    Color(0xFFB7C68B),
    Color(0xFF6B4E71),
  ];

  /// Barwa kawałka wykresu o numerze [numer] — z nawrotem, gdy upraw jest
  /// więcej niż barw.
  static Color barwaWykresu(int numer) =>
      barwyWykresu[numer % barwyWykresu.length];

  /// Kawałek „bez wpisanej uprawy" — szary, bo to brak danych, nie uprawa.
  static const Color barwaBezDanych = Color(0xFFB9C2B6);

  /// Barwy dni kalendarza biodynamicznego — po rodzaju pracy. Nazwy prac
  /// pochodzą ze słownika (`assets/dane/kalendarz_biodynamiczny.json`),
  /// nie z kodu.
  static const Map<String, Color> barwyPracy = {
    'korzeń': Color(0xFF8A5A2B),
    'liść': Color(0xFF3F7D3F),
    'kwiat': Color(0xFF6B4E71),
    'owoc': Color(0xFFC0532B),
  };

  static Color barwaPracy(String praca) => barwyPracy[praca] ?? tekstPomocniczy;

  /// Motyw programu w wybranej wielkości tekstu.
  static ThemeData zbuduj([RozmiarTekstu rozmiar = RozmiarTekstu.normalny]) {
    final skala = rozmiar.skala;
    const schemat = ColorScheme.light(
      primary: zielen,
      onPrimary: karta,
      secondary: powierzchniaDruga,
      onSecondary: tekst,
      surface: karta,
      onSurface: tekst,
      error: ostrzezenieObramowanie,
      onError: karta,
    );

    TextStyle styl({
      required double rozmiarPisma,
      FontWeight waga = FontWeight.w400,
      Color kolor = tekst,
      double wysokosc = 1.4,
    }) => TextStyle(
      color: kolor,
      fontFamily: krojPisma,
      fontSize: rozmiarPisma * skala,
      fontWeight: waga,
      height: wysokosc,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: schemat,
      scaffoldBackgroundColor: tlo,
      fontFamily: krojPisma,
      textTheme: TextTheme(
        displayLarge: styl(rozmiarPisma: 30, waga: FontWeight.w700),
        headlineMedium: styl(rozmiarPisma: 23, waga: FontWeight.w700),
        titleLarge: styl(rozmiarPisma: 18, waga: FontWeight.w600),
        bodyLarge: styl(rozmiarPisma: 15),
        bodyMedium: styl(rozmiarPisma: 13, kolor: tekstPomocniczy),
        labelLarge: styl(rozmiarPisma: 14, waga: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tlo,
        foregroundColor: tekst,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: styl(rozmiarPisma: 19, waga: FontWeight.w700),
      ),
      dividerTheme: const DividerThemeData(color: obramowanie, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: zielen,
          foregroundColor: karta,
          minimumSize: Size(0, minCelKlikniecia * skala),
          textStyle: styl(
            rozmiarPisma: 14,
            waga: FontWeight.w600,
            kolor: karta,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(zaokraglenieMale),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: zielen,
          minimumSize: Size(0, minCelKlikniecia * skala),
          side: const BorderSide(color: zielen),
          textStyle: styl(
            rozmiarPisma: 14,
            waga: FontWeight.w600,
            kolor: zielen,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(zaokraglenieMale),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: karta,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(zaokraglenieMale),
          borderSide: const BorderSide(color: obramowanie),
        ),
      ),
    );
  }
}
