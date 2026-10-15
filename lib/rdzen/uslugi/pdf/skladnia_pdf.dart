import 'dart:io';
import 'dart:typed_data';

/// Nazwa PDF — w zapisie po ukośniku, np. `/Type`.
class NazwaPdf {
  const NazwaPdf(this.nazwa);

  final String nazwa;

  @override
  bool operator ==(Object other) => other is NazwaPdf && other.nazwa == nazwa;

  @override
  int get hashCode => nazwa.hashCode;

  @override
  String toString() => '/$nazwa';
}

/// Odwołanie do obiektu („12 0 R"). Rozwiązuje je [DokumentPdf].
class OdwolaniePdf {
  const OdwolaniePdf(this.numer);

  final int numer;

  @override
  bool operator ==(Object other) =>
      other is OdwolaniePdf && other.numer == numer;

  @override
  int get hashCode => numer.hashCode;

  @override
  String toString() => '$numer 0 R';
}

/// Ciąg bajtów z pliku. Znaczenie bajtów zależy od czcionki, więc tekst
/// powstaje dopiero po przyłożeniu tablicy znaków.
class CiagPdf {
  const CiagPdf(this.bajty);

  final Uint8List bajty;
}

/// Słowo kluczowe albo operator — ten sam czytnik obsługuje treść stron.
class SlowoKluczowePdf {
  const SlowoKluczowePdf(this.tekst);

  final String tekst;

  @override
  String toString() => tekst;
}

/// Strumień: słownik i surowe (jeszcze spakowane) dane.
class StrumienPdf {
  const StrumienPdf(this.slownik, this.dane);

  final Map<String, Object?> slownik;
  final Uint8List dane;
}

/// Znaczniki końca tablicy i słownika — zwracane przez czytnik, nie dane.
enum ZnacznikPdf { koniecTablicy, koniecSlownika, koniec }

/// Plik PDF nie daje się odczytać.
class BladPdf implements Exception {
  const BladPdf(this.wiadomosc);

  final String wiadomosc;

  @override
  String toString() => 'BladPdf: $wiadomosc';
}

/// Czytnik składni PDF: obiekty, tablice, słowniki, ciągi i operatory.
///
/// Pisany ręcznie, bo import wniosku ma działać na telefonie bez bibliotek
/// natywnych i bez internetu. Obsługuje to, co wychodzi z generatorów
/// używanych przez eWniosekPlus (pdfmake) i z naszego wzorca testowego
/// (ReportLab) — opis w `docs/decyzje/ADR-0005-odczyt-pdf.md`.
class CzytnikSkladniPdf {
  CzytnikSkladniPdf(this.bajty, [this.poz = 0]);

  final Uint8List bajty;
  int poz;

  static const int _spacja = 0x20;
  static const int _ukosnik = 0x2f;

  static bool biale(int b) =>
      b == 0x20 ||
      b == 0x0a ||
      b == 0x0d ||
      b == 0x09 ||
      b == 0x0c ||
      b == 0x00;

  static bool ogranicznik(int b) =>
      b == 0x28 ||
      b == 0x29 ||
      b == 0x3c ||
      b == 0x3e ||
      b == 0x5b ||
      b == 0x5d ||
      b == 0x7b ||
      b == 0x7d ||
      b == _ukosnik ||
      b == 0x25;

  void pominBiale() {
    while (poz < bajty.length) {
      final b = bajty[poz];
      if (biale(b)) {
        poz++;
      } else if (b == 0x25) {
        while (poz < bajty.length && bajty[poz] != 0x0a && bajty[poz] != 0x0d) {
          poz++;
        }
      } else {
        break;
      }
    }
  }

  /// Czyta jeden obiekt albo znacznik końca.
  Object? czytaj() {
    pominBiale();
    if (poz >= bajty.length) {
      return ZnacznikPdf.koniec;
    }
    final b = bajty[poz];

    if (b == _ukosnik) {
      poz++;
      return NazwaPdf(_czytajNazwe());
    }
    if (b == 0x28) {
      poz++;
      return CiagPdf(_czytajCiagZwykly());
    }
    if (b == 0x3c) {
      if (poz + 1 < bajty.length && bajty[poz + 1] == 0x3c) {
        poz += 2;
        return _czytajSlownik();
      }
      poz++;
      return CiagPdf(_czytajCiagSzesnastkowy());
    }
    if (b == 0x3e && poz + 1 < bajty.length && bajty[poz + 1] == 0x3e) {
      poz += 2;
      return ZnacznikPdf.koniecSlownika;
    }
    if (b == 0x5b) {
      poz++;
      return _czytajTablice();
    }
    if (b == 0x5d) {
      poz++;
      return ZnacznikPdf.koniecTablicy;
    }
    if (b == 0x7b || b == 0x7d) {
      poz++;
      return const SlowoKluczowePdf('{}');
    }
    if (_cyfraLubZnak(b)) {
      return _czytajLiczbeLubOdwolanie();
    }
    return SlowoKluczowePdf(_czytajSlowoKluczowe());
  }

  static bool _cyfraLubZnak(int b) =>
      (b >= 0x30 && b <= 0x39) || b == 0x2b || b == 0x2d || b == 0x2e;

  String _czytajNazwe() {
    final znaki = <int>[];
    while (poz < bajty.length) {
      final b = bajty[poz];
      if (biale(b) || ogranicznik(b)) {
        break;
      }
      if (b == 0x23 && poz + 2 < bajty.length) {
        final kod = int.tryParse(
          String.fromCharCodes(bajty.sublist(poz + 1, poz + 3)),
          radix: 16,
        );
        if (kod != null) {
          znaki.add(kod);
          poz += 3;
          continue;
        }
      }
      znaki.add(b);
      poz++;
    }
    return String.fromCharCodes(znaki);
  }

  String _czytajSlowoKluczowe() {
    final znaki = <int>[];
    while (poz < bajty.length) {
      final b = bajty[poz];
      if (biale(b) || ogranicznik(b)) {
        break;
      }
      znaki.add(b);
      poz++;
    }
    if (znaki.isEmpty) {
      poz++;
      return '';
    }
    return String.fromCharCodes(znaki);
  }

  Object? _czytajLiczbeLubOdwolanie() {
    final poczatek = poz;
    final tekst = _czytajSlowoKluczowe();
    final calkowita = int.tryParse(tekst);
    if (calkowita != null && calkowita >= 0) {
      final zapamietana = poz;
      pominBiale();
      final drugie = _czytajSlowoKluczowe();
      if (int.tryParse(drugie) != null) {
        pominBiale();
        final trzecie = _czytajSlowoKluczowe();
        if (trzecie == 'R') {
          return OdwolaniePdf(calkowita);
        }
      }
      poz = zapamietana;
      return calkowita;
    }
    final liczba = double.tryParse(tekst);
    if (liczba != null) {
      return liczba;
    }
    // Zapis w rodzaju „--12" albo „4." — bierzemy to, co da się odczytać.
    final oczyszczony = tekst.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final ostatnia = double.tryParse(oczyszczony);
    if (ostatnia != null) {
      return ostatnia;
    }
    poz = poczatek + 1;
    return 0;
  }

  Uint8List _czytajCiagZwykly() {
    final wynik = <int>[];
    var poziom = 1;
    while (poz < bajty.length) {
      final b = bajty[poz++];
      if (b == 0x5c) {
        if (poz >= bajty.length) {
          break;
        }
        final znak = bajty[poz++];
        switch (znak) {
          case 0x6e:
            wynik.add(0x0a);
          case 0x72:
            wynik.add(0x0d);
          case 0x74:
            wynik.add(0x09);
          case 0x62:
            wynik.add(0x08);
          case 0x66:
            wynik.add(0x0c);
          case 0x0a:
            break;
          case 0x0d:
            if (poz < bajty.length && bajty[poz] == 0x0a) {
              poz++;
            }
          default:
            if (znak >= 0x30 && znak <= 0x37) {
              var kod = znak - 0x30;
              for (var i = 0; i < 2; i++) {
                if (poz < bajty.length &&
                    bajty[poz] >= 0x30 &&
                    bajty[poz] <= 0x37) {
                  kod = kod * 8 + (bajty[poz++] - 0x30);
                }
              }
              wynik.add(kod & 0xff);
            } else {
              wynik.add(znak);
            }
        }
        continue;
      }
      if (b == 0x28) {
        poziom++;
      } else if (b == 0x29) {
        poziom--;
        if (poziom == 0) {
          break;
        }
      }
      wynik.add(b);
    }
    return Uint8List.fromList(wynik);
  }

  Uint8List _czytajCiagSzesnastkowy() {
    final cyfry = <int>[];
    while (poz < bajty.length) {
      final b = bajty[poz++];
      if (b == 0x3e) {
        break;
      }
      if (biale(b)) {
        continue;
      }
      final cyfra = _cyfraSzesnastkowa(b);
      if (cyfra != null) {
        cyfry.add(cyfra);
      }
    }
    if (cyfry.length.isOdd) {
      cyfry.add(0);
    }
    final wynik = Uint8List(cyfry.length ~/ 2);
    for (var i = 0; i < wynik.length; i++) {
      wynik[i] = cyfry[i * 2] * 16 + cyfry[i * 2 + 1];
    }
    return wynik;
  }

  static int? _cyfraSzesnastkowa(int b) {
    if (b >= 0x30 && b <= 0x39) {
      return b - 0x30;
    }
    if (b >= 0x41 && b <= 0x46) {
      return b - 0x41 + 10;
    }
    if (b >= 0x61 && b <= 0x66) {
      return b - 0x61 + 10;
    }
    return null;
  }

  List<Object?> _czytajTablice() {
    final wynik = <Object?>[];
    while (true) {
      final element = czytaj();
      if (element == ZnacznikPdf.koniecTablicy ||
          element == ZnacznikPdf.koniec ||
          element == ZnacznikPdf.koniecSlownika) {
        return wynik;
      }
      wynik.add(element);
    }
  }

  Map<String, Object?> _czytajSlownik() {
    final wynik = <String, Object?>{};
    while (true) {
      final klucz = czytaj();
      if (klucz == ZnacznikPdf.koniecSlownika || klucz == ZnacznikPdf.koniec) {
        return wynik;
      }
      if (klucz is! NazwaPdf) {
        continue;
      }
      final wartosc = czytaj();
      if (wartosc == ZnacznikPdf.koniecSlownika ||
          wartosc == ZnacznikPdf.koniec) {
        return wynik;
      }
      wynik[klucz.nazwa] = wartosc;
    }
  }

  /// Czyta nazwę słowa kluczowego stojącego pod kursorem, nie przesuwając go,
  /// gdy to nie jest oczekiwane słowo.
  bool czySlowoKluczowe(String oczekiwane) {
    pominBiale();
    final zapamietana = poz;
    final slowo = _czytajSlowoKluczowe();
    if (slowo == oczekiwane) {
      return true;
    }
    poz = zapamietana;
    return false;
  }

  /// Przeskakuje jeden znak końca wiersza po słowie `stream`.
  void pominKoniecWiersza() {
    if (poz < bajty.length && bajty[poz] == 0x0d) {
      poz++;
    }
    if (poz < bajty.length && bajty[poz] == 0x0a) {
      poz++;
    }
  }

  static int get spacja => _spacja;
}

/// Rozpakowanie strumienia. Obsługujemy filtry, które naprawdę pojawiają się
/// w wnioskach i w naszym wzorcu: Flate, ASCII85 i ASCIIHex.
abstract final class FiltryPdf {
  static Uint8List rozpakuj(
    Uint8List dane,
    List<String> filtry, {
    Map<String, Object?>? parametry,
  }) {
    var wynik = dane;
    for (final filtr in filtry) {
      switch (filtr) {
        case 'FlateDecode':
        case 'Fl':
          wynik = _flate(wynik);
        case 'ASCII85Decode':
        case 'A85':
          wynik = _ascii85(wynik);
        case 'ASCIIHexDecode':
        case 'AHx':
          wynik = _asciiHex(wynik);
        default:
          throw BladPdf('nieobsługiwany filtr strumienia: $filtr');
      }
    }
    final predyktor = parametry?['Predictor'];
    if (predyktor is num && predyktor > 1) {
      throw const BladPdf('strumień z predyktorem nie jest obsługiwany');
    }
    return wynik;
  }

  static Uint8List _flate(Uint8List dane) {
    try {
      return Uint8List.fromList(ZLibCodec().decode(dane));
    } on FormatException {
      // Część generatorów zapisuje czysty deflate, bez nagłówka zlib.
      return Uint8List.fromList(ZLibCodec(raw: true).decode(dane));
    }
  }

  static Uint8List _asciiHex(Uint8List dane) {
    final cyfry = <int>[];
    for (final b in dane) {
      if (b == 0x3e) {
        break;
      }
      final cyfra = CzytnikSkladniPdf._cyfraSzesnastkowa(b);
      if (cyfra != null) {
        cyfry.add(cyfra);
      }
    }
    if (cyfry.length.isOdd) {
      cyfry.add(0);
    }
    final wynik = Uint8List(cyfry.length ~/ 2);
    for (var i = 0; i < wynik.length; i++) {
      wynik[i] = cyfry[i * 2] * 16 + cyfry[i * 2 + 1];
    }
    return wynik;
  }

  static Uint8List _ascii85(Uint8List dane) {
    final wynik = <int>[];
    final grupa = <int>[];
    var i = 0;
    // Przedrostek „<~" jest opcjonalny.
    if (dane.length > 1 && dane[0] == 0x3c && dane[1] == 0x7e) {
      i = 2;
    }
    while (i < dane.length) {
      final b = dane[i++];
      if (CzytnikSkladniPdf.biale(b)) {
        continue;
      }
      if (b == 0x7e) {
        break;
      }
      if (b == 0x7a && grupa.isEmpty) {
        wynik.addAll(const [0, 0, 0, 0]);
        continue;
      }
      if (b < 0x21 || b > 0x75) {
        throw const BladPdf('błąd w zapisie ASCII85');
      }
      grupa.add(b - 0x21);
      if (grupa.length == 5) {
        wynik.addAll(_grupaAscii85(grupa, 4));
        grupa.clear();
      }
    }
    if (grupa.isNotEmpty) {
      final brakuje = 5 - grupa.length;
      for (var j = 0; j < brakuje; j++) {
        grupa.add(84);
      }
      wynik.addAll(_grupaAscii85(grupa, 4 - brakuje));
    }
    return Uint8List.fromList(wynik);
  }

  static List<int> _grupaAscii85(List<int> grupa, int ile) {
    var wartosc = 0;
    for (final cyfra in grupa) {
      wartosc = wartosc * 85 + cyfra;
    }
    final bajty = [
      (wartosc >> 24) & 0xff,
      (wartosc >> 16) & 0xff,
      (wartosc >> 8) & 0xff,
      wartosc & 0xff,
    ];
    return bajty.sublist(0, ile);
  }
}
