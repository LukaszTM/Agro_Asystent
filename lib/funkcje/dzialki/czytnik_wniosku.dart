import 'dart:typed_data';

import '../../rdzen/uslugi/pdf/skladnia_pdf.dart';
import '../../rdzen/uslugi/pdf/tekst_pdf.dart';

/// Działka referencyjna z tabeli X wniosku.
class DzialkaZWniosku {
  const DzialkaZWniosku({
    this.lp = '',
    this.wojewodztwo = '',
    this.powiat = '',
    this.gmina = '',
    this.obreb = '',
    this.nrObrebu = '',
    this.arkusz = '',
    this.nrDzialki = '',
    this.powierzchniaHa,
  });

  final String lp;
  final String wojewodztwo;
  final String powiat;
  final String gmina;
  final String obreb;
  final String nrObrebu;
  final String arkusz;
  final String nrDzialki;
  final double? powierzchniaHa;

  /// Tabela X podaje numer obrębu bez kodu gminy, więc to jest końcówka
  /// pełnego identyfikatora, a nie identyfikator do zapytania do ULDK.
  String get koncowkaIdentyfikatora {
    final czescArkusza = arkusz.isEmpty ? '' : 'AR_$arkusz.';
    return '$nrObrebu.$czescArkusza$nrDzialki';
  }
}

/// Część pola leżąca na jednej działce referencyjnej.
class CzescPolaZWniosku {
  const CzescPolaZWniosku({
    required this.identyfikator,
    this.ha = 0,
    this.ar = 0,
  });

  final String identyfikator;
  final int ha;
  final int ar;

  int get powierzchniaAr => ha * 100 + ar;
}

/// Działka rolna (pole) z tabeli XI wniosku.
class PoleZWniosku {
  PoleZWniosku({
    required this.oznaczenie,
    required this.uprawa,
    this.ha = 0,
    this.ar = 0,
    List<CzescPolaZWniosku>? czesci,
    this.platnosci = '',
  }) : czesci = czesci ?? <CzescPolaZWniosku>[];

  String oznaczenie;
  String uprawa;
  int ha;
  int ar;
  final List<CzescPolaZWniosku> czesci;
  String platnosci;

  int get powierzchniaAr => ha * 100 + ar;

  List<String> get identyfikatory => [
    for (final czesc in czesci)
      if (czesc.identyfikator.isNotEmpty) czesc.identyfikator,
  ];
}

/// Co odczyt wie o swojej własnej pewności.
///
/// Wniosek nie ma podsumowania powierzchni, więc sprawdzamy go wewnętrznie:
/// części pola muszą się sumować do jego powierzchni, każdy identyfikator
/// z tabeli XI musi występować w tabeli X, a oznaczenia nie mogą się
/// powtarzać. Wynik niepewny pokazujemy rolnikowi, a nie poprawiamy po cichu.
class KontrolaWniosku {
  final List<String> ostrzezenia = [];
  final List<String> przykladyPominietych = [];
  int wierszePominiete = 0;

  bool get wynikPewny => ostrzezenia.isEmpty;
}

/// Odczytany wniosek.
class WniosekZPdf {
  WniosekZPdf();

  final List<DzialkaZWniosku> dzialki = [];
  final List<PoleZWniosku> pola = [];
  final KontrolaWniosku kontrola = KontrolaWniosku();

  /// Rok, na który złożono wniosek — odczytany z nagłówka, nie wpisany
  /// w kodzie. Gdy go nie ma, zostaje `null` i sezon trzeba podać ręcznie.
  int? rok;

  int get powierzchniaPolAr =>
      pola.fold(0, (suma, pole) => suma + pole.powierzchniaAr);

  double get powierzchniaDzialekHa =>
      dzialki.fold(0, (suma, dzialka) => suma + (dzialka.powierzchniaHa ?? 0));

  List<String> get uprawy {
    final nazwy = {
      for (final pole in pola)
        if (pole.uprawa.isNotEmpty) CzytnikWniosku.oczyscUprawe(pole.uprawa),
    };
    return nazwy.toList()..sort();
  }

  /// Pełne identyfikatory działek — tylko one nadają się do zapytania o granice.
  List<String> get identyfikatoryDzialek {
    final wszystkie = {
      for (final pole in pola)
        for (final identyfikator in pole.identyfikatory) identyfikator,
    };
    return wszystkie.toList()..sort();
  }
}

/// Czytnik wniosku o płatności z eWniosekPlus — tabele X i XI.
///
/// Układ sprawdzony w zadaniu P4 na prawdziwym wniosku za 2026 r.; opis
/// pułapek w `docs/raporty/P4-raport.md`. Ten kod jest przeniesieniem
/// sprawdzonego czytnika z `tools/p4_wniosek/czytnik.py` do aplikacji, żeby
/// rolnik mógł wczytać swój wniosek z telefonu, bez komputera i bez internetu.
abstract final class CzytnikWniosku {
  static const String naglowekX = 'OŚWIADCZENIE O DZIAŁKACH REFERENCYJNYCH';
  static const String naglowekXi =
      'OŚWIADCZENIE O ZADEKLAROWANYCH POWIERZCHNIACH';

  /// Kolumny tabeli X w kolejności numeracji ze wniosku.
  static const List<String> kolumnyX = [
    'lp',
    'wojewodztwo',
    'powiat',
    'gmina',
    'obreb',
    'nr_obrebu',
    'arkusz',
    'nr_dzialki',
    'powierzchnia',
  ];

  /// Pas przy dolnej krawędzi strony zajęty przez stopkę. Bez odcięcia stopka
  /// wsiąkała w nazwę uprawy ostatniego pola na stronie (lekcja z P4).
  static const double wysokoscStopki = 20;

  static final RegExp _oznaczenie = RegExp(r'^[A-Z]{1,2}$');
  static final RegExp _identyfikatorGlowa = RegExp(r'^\d{6}_\d\.\d{4}$');
  static final RegExp _identyfikatorOgon = RegExp(
    r'^\.(?:AR_\d+\.)?\d+(?:/\d+)?$',
  );
  static final RegExp _calkowita = RegExp(r'^\d{1,4}$');
  static final RegExp _numerKolumny = RegExp(r'^(\d{1,2})\.?$');
  static final RegExp _nowaSekcja = RegExp(
    r'^[IVX]{1,5}[A-Z]?\.\s+[A-ZĄĆĘŁŃÓŚŹŻ]',
  );
  static final RegExp _rokWniosku = RegExp(r'NA ROK\s+(\d{4})');
  static final RegExp _literaUprawy = RegExp(r'^[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż_-]');

  /// Usuwa końcowy znak odsyłacza, którym wniosek znaczy niektóre uprawy
  /// („Uprawa mieszana_"). Reszty nazwy nie ruszamy.
  static String oczyscUprawe(String nazwa) =>
      nazwa.replaceAll(RegExp(r'[_\s]+$'), '').trim();

  /// Czyta wniosek z bajtów pliku PDF.
  ///
  /// Rzuca [BladPdf], gdy pliku nie da się odczytać — wtedy rolnik dostaje
  /// jedno zdanie, co zrobić, a nie pusty wynik udający poprawny.
  static WniosekZPdf zBajtow(Uint8List plik) {
    final strony = OdczytTekstuPdf.strony(plik);
    final wszystkieWiersze = [
      for (final strona in strony)
        ...strona.wiersze(odcietaStopka: wysokoscStopki),
    ];
    return zWierszy(wszystkieWiersze);
  }

  /// Ta sama logika na gotowych wierszach — używana w testach.
  static WniosekZPdf zWierszy(List<List<SlowoPdf>> wiersze) {
    final wniosek = WniosekZPdf();
    String? sekcja;
    var srodki = <double>[];
    double? xIdentyfikatora;

    for (final wiersz in wiersze) {
      if (wiersz.isEmpty) {
        continue;
      }
      final tokeny = [for (final slowo in wiersz) slowo.tekst];
      final tresc = tokeny.join(' ');

      if (wniosek.rok == null) {
        final rok = _rokWniosku.firstMatch(tresc);
        if (rok != null) {
          wniosek.rok = int.parse(rok.group(1)!);
        }
      }

      if (tresc.contains(naglowekX)) {
        sekcja = 'X';
        srodki = [];
        continue;
      }
      if (tresc.contains(naglowekXi)) {
        sekcja = 'XI';
        srodki = [];
        continue;
      }
      if (sekcja == null) {
        continue;
      }
      if (_nowaSekcja.hasMatch(tresc)) {
        sekcja = null; // kolejna sekcja wniosku — koniec tabeli
        continue;
      }

      final nowaNumeracja = _numeracjaKolumn(wiersz);
      if (nowaNumeracja != null) {
        srodki = nowaNumeracja;
        continue;
      }
      if (srodki.isEmpty) {
        // Przed wierszem numeracji stoi wielowierszowy nagłówek tabeli —
        // to nie są dane.
        continue;
      }

      if (sekcja == 'X') {
        if (!RegExp(r'^\d+$').hasMatch(tokeny.first)) {
          continue;
        }
        _dodajDzialke(_doKolumnSrodkiem(wiersz, srodki), wniosek);
      } else {
        if (xIdentyfikatora == null) {
          for (final slowo in wiersz) {
            if (_identyfikatorGlowa.hasMatch(slowo.tekst)) {
              xIdentyfikatora = slowo.x0;
              break;
            }
          }
        }
        _dodajDoXi(wiersz, wniosek, xIdentyfikatora);
      }
    }

    _podsumuj(wniosek);
    return wniosek;
  }

  /// Zwraca środki kolumn, jeśli wiersz jest numeracją „1. 2. 3. …".
  static List<double>? _numeracjaKolumn(List<SlowoPdf> wiersz) {
    if (wiersz.length < 6) {
      return null;
    }
    var oczekiwany = 1;
    final srodki = <double>[];
    for (final slowo in wiersz) {
      final dopasowanie = _numerKolumny.firstMatch(slowo.tekst);
      if (dopasowanie == null ||
          int.parse(dopasowanie.group(1)!) != oczekiwany) {
        return null;
      }
      srodki.add(slowo.srodek);
      oczekiwany++;
    }
    return srodki;
  }

  /// Przypisuje słowa do najbliższej kolumny — wartości są wyśrodkowane.
  static List<String> _doKolumnSrodkiem(
    List<SlowoPdf> wiersz,
    List<double> srodki,
  ) {
    final komorki = List<String>.filled(srodki.length, '');
    for (final slowo in wiersz) {
      var najblizsza = 0;
      var najmniejszaRoznica = double.infinity;
      for (var i = 0; i < srodki.length; i++) {
        final roznica = (srodki[i] - slowo.srodek).abs();
        if (roznica < najmniejszaRoznica) {
          najmniejszaRoznica = roznica;
          najblizsza = i;
        }
      }
      komorki[najblizsza] = '${komorki[najblizsza]} ${slowo.tekst}'.trim();
    }
    return komorki;
  }

  static double? _liczba(String tekst) =>
      double.tryParse(tekst.trim().replaceAll(' ', '').replaceAll(',', '.'));

  static void _dodajDzialke(List<String> komorki, WniosekZPdf wniosek) {
    final dane = <String, String>{
      for (var i = 0; i < kolumnyX.length && i < komorki.length; i++)
        kolumnyX[i]: komorki[i],
    };
    final powierzchnia = _liczba(dane['powierzchnia'] ?? '');
    wniosek.dzialki.add(
      DzialkaZWniosku(
        lp: dane['lp'] ?? '',
        wojewodztwo: dane['wojewodztwo'] ?? '',
        powiat: dane['powiat'] ?? '',
        gmina: dane['gmina'] ?? '',
        obreb: dane['obreb'] ?? '',
        nrObrebu: dane['nr_obrebu'] ?? '',
        arkusz: dane['arkusz'] ?? '',
        nrDzialki: dane['nr_dzialki'] ?? '',
        powierzchniaHa: powierzchnia,
      ),
    );
    if (powierzchnia == null) {
      wniosek.kontrola.ostrzezenia.add(
        'tabela X, pozycja ${dane['lp'] ?? '?'}: nie odczytano powierzchni',
      );
    }
  }

  /// Rozbiera wiersz tabeli XI wokół identyfikatora działki referencyjnej.
  ///
  /// Układ: `[oznaczenie] uprawa… ha a IDENTYFIKATOR ha a płatności…`
  /// Numeracja kolumn w tej tabeli nie pokrywa się z położeniem wartości,
  /// dlatego punktem zaczepienia jest wzorzec identyfikatora.
  static Map<String, Object?>? _rozbierzWierszXi(List<String> tokeny) {
    var pozycja = -1;
    for (var i = 0; i < tokeny.length; i++) {
      if (_identyfikatorGlowa.hasMatch(tokeny[i])) {
        pozycja = i;
        break;
      }
    }
    if (pozycja < 0) {
      return null;
    }

    final przed = tokeny.sublist(0, pozycja);
    final po = tokeny.sublist(pozycja + 1);
    final czescHa = po.isNotEmpty && _calkowita.hasMatch(po[0])
        ? int.parse(po[0])
        : null;
    final czescAr = po.length > 1 && _calkowita.hasMatch(po[1])
        ? int.parse(po[1])
        : null;
    final platnosci = po.length > 2 ? po.sublist(2).join(' ') : '';

    if (przed.isEmpty) {
      // Wiersz kolejnej działki referencyjnej tego samego pola: bez
      // oznaczenia, bez nazwy uprawy i bez powierzchni zadeklarowanej.
      return {
        'identyfikator': tokeny[pozycja],
        'ha': null,
        'ar': null,
        'czesc_ha': czescHa,
        'czesc_ar': czescAr,
        'platnosci': platnosci,
        'oznaczenie': '',
        'uprawa': '',
      };
    }

    if (przed.length < 2 ||
        !_calkowita.hasMatch(przed[przed.length - 2]) ||
        !_calkowita.hasMatch(przed[przed.length - 1])) {
      return null;
    }

    final reszta = przed.sublist(0, przed.length - 2);
    final maOznaczenie =
        reszta.isNotEmpty && _oznaczenie.hasMatch(reszta.first);
    return {
      'identyfikator': tokeny[pozycja],
      'ha': int.parse(przed[przed.length - 2]),
      'ar': int.parse(przed[przed.length - 1]),
      'czesc_ha': czescHa,
      'czesc_ar': czescAr,
      'platnosci': platnosci,
      'oznaczenie': maOznaczenie ? reszta.first : '',
      'uprawa': maOznaczenie ? reszta.sublist(1).join(' ') : reszta.join(' '),
    };
  }

  static void _dodajDoXi(
    List<SlowoPdf> wiersz,
    WniosekZPdf wniosek,
    double? xIdentyfikatora,
  ) {
    final tokeny = [for (final slowo in wiersz) slowo.tekst];
    final rozebrany = _rozbierzWierszXi(tokeny);

    if (rozebrany == null) {
      _ciagDalszyXi(wiersz, wniosek, xIdentyfikatora);
      return;
    }

    final czesc = CzescPolaZWniosku(
      identyfikator: rozebrany['identyfikator']! as String,
      ha: (rozebrany['czesc_ha'] as int?) ?? 0,
      ar: (rozebrany['czesc_ar'] as int?) ?? 0,
    );
    final oznaczenie = rozebrany['oznaczenie']! as String;

    if (rozebrany['ha'] == null && oznaczenie.isEmpty) {
      // Sam identyfikator z powierzchnią — kolejna część ostatniego pola.
      if (wniosek.pola.isNotEmpty) {
        wniosek.pola.last.czesci.add(czesc);
      } else {
        _pomin(tokeny, wniosek);
      }
      return;
    }

    if (oznaczenie.isNotEmpty) {
      wniosek.pola.add(
        PoleZWniosku(
          oznaczenie: oznaczenie,
          uprawa: rozebrany['uprawa']! as String,
          ha: rozebrany['ha']! as int,
          ar: rozebrany['ar']! as int,
          czesci: [czesc],
          platnosci: rozebrany['platnosci']! as String,
        ),
      );
    } else if (wniosek.pola.isNotEmpty) {
      wniosek.pola.last.czesci.add(czesc);
    } else {
      _pomin(tokeny, wniosek);
    }
  }

  /// Wiersz bez identyfikatora: dalszy ciąg nazwy uprawy albo ogon
  /// identyfikatora złamanego na dwa wiersze.
  ///
  /// O przynależności do nazwy uprawy decyduje położenie na stronie —
  /// inaczej do nazwy wsiąkałyby kody płatności z prawej strony wiersza.
  static void _ciagDalszyXi(
    List<SlowoPdf> wiersz,
    WniosekZPdf wniosek,
    double? xIdentyfikatora,
  ) {
    final tokeny = [for (final slowo in wiersz) slowo.tekst];
    if (wniosek.pola.isEmpty) {
      _pomin(tokeny, wniosek);
      return;
    }

    final pole = wniosek.pola.last;
    var uzyte = false;
    for (final slowo in wiersz) {
      final token = slowo.tekst;
      final naLewoOdIdentyfikatora =
          xIdentyfikatora == null || slowo.x0 < xIdentyfikatora - 10;

      if (_identyfikatorOgon.hasMatch(token) && pole.czesci.isNotEmpty) {
        // Numer działki referencyjnej łamie się do następnego wiersza.
        for (var i = pole.czesci.length - 1; i >= 0; i--) {
          if (_identyfikatorGlowa.hasMatch(pole.czesci[i].identyfikator)) {
            final stara = pole.czesci[i];
            pole.czesci[i] = CzescPolaZWniosku(
              identyfikator: '${stara.identyfikator}$token',
              ha: stara.ha,
              ar: stara.ar,
            );
            uzyte = true;
            break;
          }
        }
      } else if (naLewoOdIdentyfikatora && _literaUprawy.hasMatch(token)) {
        pole.uprawa = '${pole.uprawa} $token'.trim();
        uzyte = true;
      }
    }
    if (!uzyte) {
      _pomin(tokeny, wniosek);
    }
  }

  static void _pomin(List<String> tokeny, WniosekZPdf wniosek) {
    wniosek.kontrola.wierszePominiete++;
    if (wniosek.kontrola.przykladyPominietych.length < 5) {
      final tresc = tokeny.join(' ');
      wniosek.kontrola.przykladyPominietych.add(
        tresc.length > 70 ? tresc.substring(0, 70) : tresc,
      );
    }
  }

  static void _podsumuj(WniosekZPdf wniosek) {
    final kontrola = wniosek.kontrola;

    // Kontrola 1: części muszą się sumować do powierzchni pola.
    for (final pole in wniosek.pola) {
      final sumaCzesci = pole.czesci.fold(
        0,
        (suma, czesc) => suma + czesc.powierzchniaAr,
      );
      if (sumaCzesci != 0 && sumaCzesci != pole.powierzchniaAr) {
        kontrola.ostrzezenia.add(
          'pole ${pole.oznaczenie}: powierzchnia '
          '${_ha(pole.powierzchniaAr)} ha, a części dają ${_ha(sumaCzesci)} ha',
        );
      }
    }

    // Kontrola 2: identyfikatory z tabeli XI muszą być w tabeli X. Tabela X
    // podaje numer obrębu bez kodu gminy, więc porównujemy końcówki.
    final znane = {
      for (final dzialka in wniosek.dzialki) dzialka.koncowkaIdentyfikatora,
    };
    if (znane.isNotEmpty) {
      final nieznane = <String>{};
      for (final pole in wniosek.pola) {
        for (final identyfikator in pole.identyfikatory) {
          if (!znane.any(identyfikator.endsWith)) {
            nieznane.add(identyfikator);
          }
        }
      }
      if (nieznane.isNotEmpty) {
        kontrola.ostrzezenia.add(
          '${nieznane.length} identyfikatorów z tabeli XI nie ma w tabeli X',
        );
      }
    }

    // Kontrola 3: oznaczenia pól nie mogą się powtarzać.
    final oznaczenia = [for (final pole in wniosek.pola) pole.oznaczenie];
    if (oznaczenia.toSet().length != oznaczenia.length) {
      kontrola.ostrzezenia.add('oznaczenia pól się powtarzają');
    }
  }

  static String _ha(int ar) =>
      (ar / 100).toStringAsFixed(2).replaceAll('.', ',');
}
