import 'dart:typed_data';

import 'skladnia_pdf.dart';

/// Czcionka na tyle, na ile potrzebna do odczytu tekstu: ile bajtów ma kod
/// znaku, jak przełożyć kod na znak i jak szeroki jest znak.
class CzcionkaPdf {
  const CzcionkaPdf({
    required this.dwaBajty,
    required this.znaki,
    required this.szerokosci,
    required this.domyslnaSzerokosc,
    required this.maTabliceZnakow,
  });

  /// Czcionki złożone (Type0 z Identity-H) mają kody dwubajtowe.
  final bool dwaBajty;

  /// Kod znaku → znak. Pochodzi z `/ToUnicode`, czyli z pliku, a nie z naszych
  /// domysłów.
  final Map<int, String> znaki;

  /// Kod znaku → szerokość w tysięcznych części rozmiaru pisma.
  final Map<int, double> szerokosci;

  final double domyslnaSzerokosc;

  /// `false`, gdy plik nie podał tablicy znaków. Wtedy dla czcionek
  /// jednobajtowych bierzemy układ łaciński, a dla złożonych mówimy wprost,
  /// że tekstu nie da się odczytać — zgadywanie byłoby gorsze od błędu.
  final bool maTabliceZnakow;

  static const CzcionkaPdf zastepcza = CzcionkaPdf(
    dwaBajty: false,
    znaki: {},
    szerokosci: {},
    domyslnaSzerokosc: 500,
    maTabliceZnakow: false,
  );

  String znak(int kod) {
    final zTablicy = znaki[kod];
    if (zTablicy != null) {
      return zTablicy;
    }
    if (maTabliceZnakow || dwaBajty) {
      return '';
    }
    return String.fromCharCode(kod);
  }

  double szerokosc(int kod) => szerokosci[kod] ?? domyslnaSzerokosc;
}

/// Strona pliku PDF: rozmiar, treść i czcionki.
class StronaSurowaPdf {
  const StronaSurowaPdf({
    required this.szerokosc,
    required this.wysokosc,
    required this.tresc,
    required this.czcionki,
  });

  final double szerokosc;
  final double wysokosc;
  final Uint8List tresc;
  final Map<String, CzcionkaPdf> czcionki;
}

/// Plik PDF rozłożony na obiekty.
///
/// Obiekty znajdujemy przeglądaniem pliku za zapisem „N 0 obj", a nie przez
/// tablicę xref: wnioski bywają zapisywane przyrostowo i tablica nieraz nie
/// zgadza się z treścią, a przeglądanie działa w obu przypadkach.
class DokumentPdf {
  DokumentPdf._(this._bajty, this._polozenia);

  final Uint8List _bajty;
  final Map<int, int> _polozenia;
  final Map<int, Object?> _odczytane = {};

  static DokumentPdf zBajtow(Uint8List bajty) {
    if (bajty.length < 8) {
      throw const BladPdf('plik jest za krótki, żeby był dokumentem PDF');
    }
    final naglowek = String.fromCharCodes(bajty.sublist(0, 5));
    if (naglowek != '%PDF-') {
      throw const BladPdf('to nie jest plik PDF');
    }
    return DokumentPdf._(bajty, _znajdzObiekty(bajty));
  }

  /// Przeglądanie bajtów za „obj" i cofanie się po numerze obiektu.
  static Map<int, int> _znajdzObiekty(Uint8List bajty) {
    final polozenia = <int, int>{};
    for (var i = 0; i + 2 < bajty.length; i++) {
      if (bajty[i] != 0x6f || bajty[i + 1] != 0x62 || bajty[i + 2] != 0x6a) {
        continue;
      }
      if (i + 3 < bajty.length &&
          !CzytnikSkladniPdf.biale(bajty[i + 3]) &&
          !CzytnikSkladniPdf.ogranicznik(bajty[i + 3])) {
        continue;
      }
      var j = i - 1;
      j = _cofnijBiale(bajty, j);
      final koniecWersji = j;
      j = _cofnijCyfry(bajty, j);
      if (j == koniecWersji) {
        continue;
      }
      j = _cofnijBiale(bajty, j);
      final koniecNumeru = j;
      j = _cofnijCyfry(bajty, j);
      if (j == koniecNumeru) {
        continue;
      }
      final numer = int.tryParse(
        String.fromCharCodes(bajty.sublist(j + 1, koniecNumeru + 1)),
      );
      if (numer == null) {
        continue;
      }
      // Zapis przyrostowy: nowsza wersja obiektu stoi dalej w pliku.
      polozenia[numer] = i + 3;
    }
    if (polozenia.isEmpty) {
      throw const BladPdf('w pliku nie ma żadnego obiektu PDF');
    }
    return polozenia;
  }

  static int _cofnijBiale(Uint8List bajty, int i) {
    while (i >= 0 && CzytnikSkladniPdf.biale(bajty[i])) {
      i--;
    }
    return i;
  }

  static int _cofnijCyfry(Uint8List bajty, int i) {
    while (i >= 0 && bajty[i] >= 0x30 && bajty[i] <= 0x39) {
      i--;
    }
    return i;
  }

  /// Rozwiązuje odwołania; pozostałe wartości zwraca bez zmian.
  Object? wartosc(Object? co) {
    var wynik = co;
    var zabezpieczenie = 0;
    while (wynik is OdwolaniePdf && zabezpieczenie++ < 32) {
      wynik = obiekt(wynik.numer);
    }
    return wynik;
  }

  Object? obiekt(int numer) {
    if (_odczytane.containsKey(numer)) {
      return _odczytane[numer];
    }
    final polozenie = _polozenia[numer];
    if (polozenie == null) {
      return null;
    }
    final czytnik = CzytnikSkladniPdf(_bajty, polozenie);
    final tresc = czytnik.czytaj();
    Object? wynik = tresc;
    if (tresc is Map<String, Object?> && czytnik.czySlowoKluczowe('stream')) {
      czytnik.pominKoniecWiersza();
      final dlugosc = wartosc(tresc['Length']);
      final poczatek = czytnik.poz;
      var koniec = dlugosc is num ? poczatek + dlugosc.toInt() : -1;
      if (koniec < poczatek || koniec > _bajty.length || !_konczySie(koniec)) {
        koniec = _szukajEndstream(poczatek);
      }
      wynik = StrumienPdf(
        tresc,
        Uint8List.sublistView(_bajty, poczatek, koniec),
      );
    }
    _odczytane[numer] = wynik;
    return wynik;
  }

  bool _konczySie(int koniec) {
    final okno = String.fromCharCodes(
      _bajty.sublist(koniec, (koniec + 20).clamp(0, _bajty.length)),
    );
    return okno.trimLeft().startsWith('endstream');
  }

  int _szukajEndstream(int poczatek) {
    const wzorzec = [0x65, 0x6e, 0x64, 0x73, 0x74, 0x72, 0x65, 0x61, 0x6d];
    for (var i = poczatek; i + wzorzec.length <= _bajty.length; i++) {
      var zgodne = true;
      for (var j = 0; j < wzorzec.length; j++) {
        if (_bajty[i + j] != wzorzec[j]) {
          zgodne = false;
          break;
        }
      }
      if (zgodne) {
        var koniec = i;
        if (koniec > poczatek && _bajty[koniec - 1] == 0x0a) {
          koniec--;
        }
        if (koniec > poczatek && _bajty[koniec - 1] == 0x0d) {
          koniec--;
        }
        return koniec;
      }
    }
    throw const BladPdf('strumień bez zakończenia');
  }

  /// Rozpakowana treść strumienia.
  Uint8List dane(StrumienPdf strumien) {
    final filtr = wartosc(strumien.slownik['Filter']);
    final nazwy = <String>[
      if (filtr is NazwaPdf) filtr.nazwa,
      if (filtr is List)
        for (final f in filtr)
          if (wartosc(f) case final NazwaPdf n) n.nazwa,
    ];
    final parametry = wartosc(strumien.slownik['DecodeParms']);
    return FiltryPdf.rozpakuj(
      strumien.dane,
      nazwy,
      parametry: parametry is Map<String, Object?> ? parametry : null,
    );
  }

  /// Strony w kolejności z drzewa stron; gdy drzewa nie da się przejść,
  /// bierzemy wszystkie obiekty `/Type /Page` po numerach.
  List<StronaSurowaPdf> get strony {
    final zDrzewa = _stronyZDrzewa();
    final slowniki = zDrzewa.isNotEmpty ? zDrzewa : _wszystkieStrony();
    final wynik = <StronaSurowaPdf>[];
    for (final (slownik, odziedziczone) in slowniki) {
      final strona = _zlozStrone(slownik, odziedziczone);
      if (strona != null) {
        wynik.add(strona);
      }
    }
    if (wynik.isEmpty) {
      throw const BladPdf('w pliku nie ma stron z tekstem');
    }
    return wynik;
  }

  List<(Map<String, Object?>, Map<String, Object?>)> _stronyZDrzewa() {
    final katalog = _katalog();
    if (katalog == null) {
      return const [];
    }
    final korzen = wartosc(katalog['Pages']);
    if (korzen is! Map<String, Object?>) {
      return const [];
    }
    final wynik = <(Map<String, Object?>, Map<String, Object?>)>[];
    _przejdzDrzewo(korzen, const {}, wynik, 0);
    return wynik;
  }

  void _przejdzDrzewo(
    Map<String, Object?> wezel,
    Map<String, Object?> odziedziczone,
    List<(Map<String, Object?>, Map<String, Object?>)> wynik,
    int glebokosc,
  ) {
    if (glebokosc > 32) {
      return;
    }
    final doPrzekazania = <String, Object?>{
      ...odziedziczone,
      for (final klucz in const ['Resources', 'MediaBox'])
        if (wezel[klucz] != null) klucz: wezel[klucz],
    };
    final typ = wartosc(wezel['Type']);
    final dzieci = wartosc(wezel['Kids']);
    if (dzieci is List) {
      for (final dziecko in dzieci) {
        final slownik = wartosc(dziecko);
        if (slownik is Map<String, Object?>) {
          _przejdzDrzewo(slownik, doPrzekazania, wynik, glebokosc + 1);
        }
      }
      return;
    }
    if (typ is NazwaPdf && typ.nazwa == 'Page') {
      wynik.add((wezel, odziedziczone));
    }
  }

  Map<String, Object?>? _katalog() {
    for (final numer in _polozenia.keys.toList()..sort()) {
      final obiekt = this.obiekt(numer);
      if (obiekt is Map<String, Object?>) {
        final typ = wartosc(obiekt['Type']);
        if (typ is NazwaPdf && typ.nazwa == 'Catalog') {
          return obiekt;
        }
      }
    }
    return null;
  }

  List<(Map<String, Object?>, Map<String, Object?>)> _wszystkieStrony() {
    final wynik = <(Map<String, Object?>, Map<String, Object?>)>[];
    for (final numer in _polozenia.keys.toList()..sort()) {
      final obiekt = this.obiekt(numer);
      if (obiekt is Map<String, Object?>) {
        final typ = wartosc(obiekt['Type']);
        if (typ is NazwaPdf && typ.nazwa == 'Page') {
          wynik.add((obiekt, const {}));
        }
      }
    }
    return wynik;
  }

  StronaSurowaPdf? _zlozStrone(
    Map<String, Object?> strona,
    Map<String, Object?> odziedziczone,
  ) {
    final ramka = wartosc(strona['MediaBox'] ?? odziedziczone['MediaBox']);
    var szerokosc = 595.28;
    var wysokosc = 841.89;
    if (ramka is List && ramka.length == 4) {
      final liczby = ramka
          .map((e) => (wartosc(e) as num?)?.toDouble() ?? 0)
          .toList();
      szerokosc = (liczby[2] - liczby[0]).abs();
      wysokosc = (liczby[3] - liczby[1]).abs();
    }

    final tresc = _trescStrony(strona);
    if (tresc == null) {
      return null;
    }

    final zasoby = wartosc(strona['Resources'] ?? odziedziczone['Resources']);
    final czcionki = <String, CzcionkaPdf>{};
    if (zasoby is Map<String, Object?>) {
      final spisCzcionek = wartosc(zasoby['Font']);
      if (spisCzcionek is Map<String, Object?>) {
        for (final wpis in spisCzcionek.entries) {
          final slownik = wartosc(wpis.value);
          if (slownik is Map<String, Object?>) {
            czcionki[wpis.key] = _zlozCzcionke(slownik);
          }
        }
      }
    }

    return StronaSurowaPdf(
      szerokosc: szerokosc,
      wysokosc: wysokosc,
      tresc: tresc,
      czcionki: czcionki,
    );
  }

  Uint8List? _trescStrony(Map<String, Object?> strona) {
    final tresc = wartosc(strona['Contents']);
    final czesci = <int>[];
    if (tresc is StrumienPdf) {
      czesci.addAll(dane(tresc));
    } else if (tresc is List) {
      for (final czesc in tresc) {
        final strumien = wartosc(czesc);
        if (strumien is StrumienPdf) {
          czesci.addAll(dane(strumien));
          czesci.add(0x0a);
        }
      }
    } else {
      return null;
    }
    return Uint8List.fromList(czesci);
  }

  CzcionkaPdf _zlozCzcionke(Map<String, Object?> slownik) {
    final podtyp = wartosc(slownik['Subtype']);
    final zlozona = podtyp is NazwaPdf && podtyp.nazwa == 'Type0';
    final kodowanie = wartosc(slownik['Encoding']);
    final dwaBajty =
        zlozona &&
        (kodowanie is! NazwaPdf || kodowanie.nazwa.startsWith('Identity'));

    final znaki = _tablicaZnakow(slownik);
    final szerokosci = <int, double>{};
    var domyslna = 500.0;

    if (zlozona) {
      final potomne = wartosc(slownik['DescendantFonts']);
      final potomna = potomne is List && potomne.isNotEmpty
          ? wartosc(potomne.first)
          : null;
      if (potomna is Map<String, Object?>) {
        final dw = wartosc(potomna['DW']);
        domyslna = dw is num ? dw.toDouble() : 1000;
        _czytajSzerokosciW(wartosc(potomna['W']), szerokosci);
      } else {
        domyslna = 1000;
      }
    } else {
      final pierwszy = wartosc(slownik['FirstChar']);
      final lista = wartosc(slownik['Widths']);
      if (pierwszy is num && lista is List) {
        for (var i = 0; i < lista.length; i++) {
          final szerokosc = wartosc(lista[i]);
          if (szerokosc is num) {
            szerokosci[pierwszy.toInt() + i] = szerokosc.toDouble();
          }
        }
      }
    }

    return CzcionkaPdf(
      dwaBajty: dwaBajty,
      znaki: znaki ?? const {},
      szerokosci: szerokosci,
      domyslnaSzerokosc: domyslna,
      maTabliceZnakow: znaki != null,
    );
  }

  void _czytajSzerokosciW(Object? w, Map<int, double> szerokosci) {
    if (w is! List) {
      return;
    }
    var i = 0;
    while (i < w.length) {
      final pierwszy = wartosc(w[i]);
      if (pierwszy is! num) {
        i++;
        continue;
      }
      if (i + 1 >= w.length) {
        break;
      }
      final drugi = wartosc(w[i + 1]);
      if (drugi is List) {
        for (var j = 0; j < drugi.length; j++) {
          final szerokosc = wartosc(drugi[j]);
          if (szerokosc is num) {
            szerokosci[pierwszy.toInt() + j] = szerokosc.toDouble();
          }
        }
        i += 2;
      } else if (drugi is num && i + 2 < w.length) {
        final szerokosc = wartosc(w[i + 2]);
        if (szerokosc is num) {
          for (var kod = pierwszy.toInt(); kod <= drugi.toInt(); kod++) {
            szerokosci[kod] = szerokosc.toDouble();
          }
        }
        i += 3;
      } else {
        break;
      }
    }
  }

  /// Czyta `/ToUnicode` — tablicę znaków zapisaną w pliku przez generator.
  Map<int, String>? _tablicaZnakow(Map<String, Object?> slownik) {
    final strumien = wartosc(slownik['ToUnicode']);
    if (strumien is! StrumienPdf) {
      return null;
    }
    final Uint8List tresc;
    try {
      tresc = dane(strumien);
    } on BladPdf {
      return null;
    }
    final czytnik = CzytnikSkladniPdf(tresc);
    final wynik = <int, String>{};

    while (true) {
      final element = czytnik.czytaj();
      if (element == ZnacznikPdf.koniec) {
        break;
      }
      if (element is! SlowoKluczowePdf) {
        continue;
      }
      switch (element.tekst) {
        case 'beginbfchar':
          _czytajBfchar(czytnik, wynik);
        case 'beginbfrange':
          _czytajBfrange(czytnik, wynik);
      }
    }
    return wynik.isEmpty ? null : wynik;
  }

  void _czytajBfchar(CzytnikSkladniPdf czytnik, Map<int, String> wynik) {
    while (true) {
      final zrodlo = czytnik.czytaj();
      if (zrodlo is SlowoKluczowePdf || zrodlo == ZnacznikPdf.koniec) {
        return;
      }
      final cel = czytnik.czytaj();
      if (cel is SlowoKluczowePdf || cel == ZnacznikPdf.koniec) {
        return;
      }
      if (zrodlo is CiagPdf && cel is CiagPdf) {
        wynik[_kod(zrodlo.bajty)] = _tekstUtf16(cel.bajty);
      }
    }
  }

  void _czytajBfrange(CzytnikSkladniPdf czytnik, Map<int, String> wynik) {
    while (true) {
      final od = czytnik.czytaj();
      if (od is SlowoKluczowePdf || od == ZnacznikPdf.koniec) {
        return;
      }
      final doKodu = czytnik.czytaj();
      final cel = czytnik.czytaj();
      if (od is! CiagPdf || doKodu is! CiagPdf) {
        return;
      }
      final poczatek = _kod(od.bajty);
      final koniec = _kod(doKodu.bajty);
      if (cel is CiagPdf) {
        final bazowy = _tekstUtf16(cel.bajty);
        for (
          var kod = poczatek;
          kod <= koniec && kod - poczatek < 65536;
          kod++
        ) {
          wynik[kod] = _przesunietyZnak(bazowy, kod - poczatek);
        }
      } else if (cel is List) {
        for (var i = 0; i < cel.length && poczatek + i <= koniec; i++) {
          final znak = wartosc(cel[i]);
          if (znak is CiagPdf) {
            wynik[poczatek + i] = _tekstUtf16(znak.bajty);
          }
        }
      }
    }
  }

  static String _przesunietyZnak(String bazowy, int przesuniecie) {
    if (przesuniecie == 0 || bazowy.isEmpty) {
      return bazowy;
    }
    final jednostki = bazowy.codeUnits.toList();
    jednostki[jednostki.length - 1] += przesuniecie;
    return String.fromCharCodes(jednostki);
  }

  static int _kod(Uint8List bajty) {
    var wynik = 0;
    for (final b in bajty) {
      wynik = wynik * 256 + b;
    }
    return wynik;
  }

  /// Tablice znaków zapisują docelowe znaki jako UTF-16BE.
  static String _tekstUtf16(Uint8List bajty) {
    if (bajty.length == 1) {
      return String.fromCharCode(bajty[0]);
    }
    final jednostki = <int>[];
    for (var i = 0; i + 1 < bajty.length; i += 2) {
      jednostki.add(bajty[i] * 256 + bajty[i + 1]);
    }
    return String.fromCharCodes(jednostki);
  }
}
