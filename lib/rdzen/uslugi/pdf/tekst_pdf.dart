import 'dart:math' as math;
import 'dart:typed_data';

import 'dokument_pdf.dart';
import 'skladnia_pdf.dart';

/// Słowo odczytane ze strony: tekst i jego położenie na stronie.
///
/// `gora` liczymy od górnej krawędzi strony, tak jak robi to większość
/// narzędzi do PDF — wiersze tabeli rozpoznajemy właśnie po tej wartości.
class SlowoPdf {
  const SlowoPdf({
    required this.tekst,
    required this.x0,
    required this.x1,
    required this.gora,
  });

  final String tekst;
  final double x0;
  final double x1;
  final double gora;

  double get srodek => (x0 + x1) / 2;

  @override
  String toString() =>
      '„$tekst" (${x0.toStringAsFixed(1)}, ${gora.toStringAsFixed(1)})';
}

/// Strona z odczytanym tekstem.
class StronaTekstuPdf {
  const StronaTekstuPdf({
    required this.szerokosc,
    required this.wysokosc,
    required this.slowa,
  });

  final double szerokosc;
  final double wysokosc;
  final List<SlowoPdf> slowa;

  /// Słowa pogrupowane w wiersze po wysokości i uporządkowane od lewej.
  ///
  /// [tolerancja] to dopuszczalna różnica wysokości w jednym wierszu —
  /// w tabelach wniosku wartości w jednym wierszu stoją na tej samej
  /// podstawie z dokładnością do dwóch punktów.
  List<List<SlowoPdf>> wiersze({
    double tolerancja = 2,
    double odcietaStopka = 0,
  }) {
    final granica = wysokosc - odcietaStopka;
    final grupy = <int, List<SlowoPdf>>{};
    for (final slowo in slowa) {
      if (odcietaStopka > 0 && slowo.gora > granica) {
        continue;
      }
      final klucz = (slowo.gora / tolerancja).round();
      grupy.putIfAbsent(klucz, () => []).add(slowo);
    }
    final klucze = grupy.keys.toList()..sort();
    return [
      for (final klucz in klucze)
        grupy[klucz]!..sort((a, b) => a.x0.compareTo(b.x0)),
    ];
  }
}

/// Pojedynczy znak z położeniem — surowiec, z którego składamy słowa.
class _ZnakPdf {
  _ZnakPdf(this.znak, this.x0, this.x1, this.gora);

  final String znak;
  final double x0;
  final double x1;
  final double gora;
}

/// Wykonuje treść strony na tyle, ile potrzeba do odczytania tekstu
/// z położeniem: operatory tekstu, przekształcenia i czcionki.
///
/// Nie rysujemy niczego — grafika, obrazy i kolory są pomijane.
abstract final class OdczytTekstuPdf {
  /// Przerwa między znakami, od której zaczyna się nowe słowo.
  static const double przerwaMiedzySlowami = 3;

  static List<StronaTekstuPdf> strony(Uint8List plik) {
    final dokument = DokumentPdf.zBajtow(plik);
    return [for (final strona in dokument.strony) stronaTekstu(strona)];
  }

  static StronaTekstuPdf stronaTekstu(StronaSurowaPdf strona) {
    final znaki = _znaki(strona);
    return StronaTekstuPdf(
      szerokosc: strona.szerokosc,
      wysokosc: strona.wysokosc,
      slowa: _slowa(znaki),
    );
  }

  static List<_ZnakPdf> _znaki(StronaSurowaPdf strona) {
    final znaki = <_ZnakPdf>[];
    final czytnik = CzytnikSkladniPdf(strona.tresc);
    final argumenty = <Object?>[];
    final stosPrzeksztalcen = <List<double>>[];

    var ctm = _jednostkowa();
    var tm = _jednostkowa();
    var tlm = _jednostkowa();
    var czcionka = CzcionkaPdf.zastepcza;
    var rozmiar = 0.0;
    var odstepZnaku = 0.0;
    var odstepSlowa = 0.0;
    var skalaPozioma = 1.0;
    var wysokoscPisma = 0.0;
    var interlinia = 0.0;

    double liczba(int odKonca) {
      final i = argumenty.length - odKonca;
      if (i < 0 || i >= argumenty.length) {
        return 0;
      }
      final wartosc = argumenty[i];
      return wartosc is num ? wartosc.toDouble() : 0;
    }

    void pokaz(Uint8List bajty) {
      final krok = czcionka.dwaBajty ? 2 : 1;
      for (var i = 0; i + krok <= bajty.length; i += krok) {
        final kod = krok == 2 ? bajty[i] * 256 + bajty[i + 1] : bajty[i];
        final szerokoscZnaku = czcionka.szerokosc(kod) / 1000 * rozmiar;
        var przesuniecie = (szerokoscZnaku + odstepZnaku) * skalaPozioma;
        if (krok == 1 && kod == 32) {
          przesuniecie += odstepSlowa * skalaPozioma;
        }

        final pismo = <double>[
          rozmiar * skalaPozioma,
          0,
          0,
          rozmiar,
          0,
          wysokoscPisma,
        ];
        final tekstNaStronie = _pomnoz(tm, ctm);
        final polozenie = _pomnoz(pismo, tekstNaStronie);
        // Przesunięcie liczymy w przestrzeni tekstu, więc na stronę przenosi
        // je skala złożenia macierzy tekstu i strony.
        final skala = math
            .sqrt(
              tekstNaStronie[0] * tekstNaStronie[0] +
                  tekstNaStronie[1] * tekstNaStronie[1],
            )
            .abs();
        final x0 = polozenie[4];
        final szerokoscNaStronie = przesuniecie * skala;

        final znak = czcionka.znak(kod);
        if (znak.isNotEmpty) {
          znaki.add(
            _ZnakPdf(
              znak,
              x0,
              x0 + szerokoscNaStronie,
              strona.wysokosc - polozenie[5],
            ),
          );
        }
        tm = _pomnoz([1, 0, 0, 1, przesuniecie, 0], tm);
      }
    }

    while (true) {
      final element = czytnik.czytaj();
      if (element == ZnacznikPdf.koniec) {
        break;
      }
      if (element is! SlowoKluczowePdf) {
        argumenty.add(element);
        if (argumenty.length > 32) {
          argumenty.removeAt(0);
        }
        continue;
      }

      switch (element.tekst) {
        case 'q':
          stosPrzeksztalcen.add(List<double>.from(ctm));
        case 'Q':
          if (stosPrzeksztalcen.isNotEmpty) {
            ctm = stosPrzeksztalcen.removeLast();
          }
        case 'cm':
          ctm = _pomnoz([
            liczba(6),
            liczba(5),
            liczba(4),
            liczba(3),
            liczba(2),
            liczba(1),
          ], ctm);
        case 'BT':
          tm = _jednostkowa();
          tlm = _jednostkowa();
        case 'ET':
          tm = _jednostkowa();
          tlm = _jednostkowa();
        case 'Tf':
          rozmiar = liczba(1);
          final nazwa = argumenty.length >= 2
              ? argumenty[argumenty.length - 2]
              : null;
          czcionka = nazwa is NazwaPdf
              ? (strona.czcionki[nazwa.nazwa] ?? CzcionkaPdf.zastepcza)
              : CzcionkaPdf.zastepcza;
        case 'Td':
          tlm = _pomnoz([1, 0, 0, 1, liczba(2), liczba(1)], tlm);
          tm = List<double>.from(tlm);
        case 'TD':
          interlinia = -liczba(1);
          tlm = _pomnoz([1, 0, 0, 1, liczba(2), liczba(1)], tlm);
          tm = List<double>.from(tlm);
        case 'Tm':
          tlm = [
            liczba(6),
            liczba(5),
            liczba(4),
            liczba(3),
            liczba(2),
            liczba(1),
          ];
          tm = List<double>.from(tlm);
        case 'T*':
          tlm = _pomnoz([1, 0, 0, 1, 0, -interlinia], tlm);
          tm = List<double>.from(tlm);
        case 'TL':
          interlinia = liczba(1);
        case 'Tc':
          odstepZnaku = liczba(1);
        case 'Tw':
          odstepSlowa = liczba(1);
        case 'Tz':
          skalaPozioma = liczba(1) / 100;
        case 'Ts':
          wysokoscPisma = liczba(1);
        case 'Tj':
          final ciag = argumenty.isNotEmpty ? argumenty.last : null;
          if (ciag is CiagPdf) {
            pokaz(ciag.bajty);
          }
        case '\'':
        case '"':
          tlm = _pomnoz([1, 0, 0, 1, 0, -interlinia], tlm);
          tm = List<double>.from(tlm);
          final ciag = argumenty.isNotEmpty ? argumenty.last : null;
          if (ciag is CiagPdf) {
            pokaz(ciag.bajty);
          }
        case 'TJ':
          final tablica = argumenty.isNotEmpty ? argumenty.last : null;
          if (tablica is List) {
            for (final element in tablica) {
              if (element is CiagPdf) {
                pokaz(element.bajty);
              } else if (element is num) {
                final przesuniecie =
                    -element.toDouble() / 1000 * rozmiar * skalaPozioma;
                tm = _pomnoz([1, 0, 0, 1, przesuniecie, 0], tm);
              }
            }
          }
      }
      argumenty.clear();
    }
    return znaki;
  }

  /// Składa znaki w słowa: nowe słowo zaczyna spacja albo przerwa większa
  /// od [przerwaMiedzySlowami].
  static List<SlowoPdf> _slowa(List<_ZnakPdf> znaki) {
    final wedlugWiersza = <int, List<_ZnakPdf>>{};
    for (final znak in znaki) {
      wedlugWiersza.putIfAbsent((znak.gora / 2).round(), () => []).add(znak);
    }

    final slowa = <SlowoPdf>[];
    for (final klucz in wedlugWiersza.keys.toList()..sort()) {
      final wiersz = wedlugWiersza[klucz]!
        ..sort((a, b) => a.x0.compareTo(b.x0));
      var tekst = '';
      var x0 = 0.0;
      var x1 = 0.0;
      var gora = 0.0;

      void zakoncz() {
        if (tekst.trim().isNotEmpty) {
          slowa.add(SlowoPdf(tekst: tekst.trim(), x0: x0, x1: x1, gora: gora));
        }
        tekst = '';
      }

      for (final znak in wiersz) {
        if (znak.znak.trim().isEmpty) {
          zakoncz();
          continue;
        }
        if (tekst.isEmpty) {
          x0 = znak.x0;
          gora = znak.gora;
        } else if (znak.x0 - x1 > przerwaMiedzySlowami) {
          zakoncz();
          x0 = znak.x0;
          gora = znak.gora;
        }
        tekst += znak.znak;
        x1 = znak.x1;
      }
      zakoncz();
    }
    return slowa;
  }

  static List<double> _jednostkowa() => [1, 0, 0, 1, 0, 0];

  /// Mnożenie macierzy 3×2 w zapisie PDF: [a b c d e f].
  static List<double> _pomnoz(List<double> m, List<double> n) => [
    m[0] * n[0] + m[1] * n[2],
    m[0] * n[1] + m[1] * n[3],
    m[2] * n[0] + m[3] * n[2],
    m[2] * n[1] + m[3] * n[3],
    m[4] * n[0] + m[5] * n[2] + n[4],
    m[4] * n[1] + m[5] * n[3] + n[5],
  ];
}
