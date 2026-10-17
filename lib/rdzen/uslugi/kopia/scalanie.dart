import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';

import 'kopia_danych.dart';

/// Jak scalać wiersze danej tabeli.
enum RodzajScalania {
  /// Wiersz ma własny czas zmiany — wygrywa nowszy.
  poCzasie,

  /// Wiersz należy do rodzica (np. szczegóły oprysku do zabiegu) i idzie
  /// razem z nim: gdy nowszy jest zabieg z pliku, jego szczegóły zastępują
  /// lokalne; gdy nowszy jest lokalny, plik się pomija.
  poRodzicu,

  /// Samo powiązanie, bez treści — dopisujemy brakujące.
  dopiszBrakujace,

  /// Ustawienia tego telefonu (wygląd, przypomnienia) zostają jego własne.
  lokalneZostaje,
}

/// Reguła scalania jednej tabeli.
class ReguloScalania {
  const ReguloScalania(
    this.rodzaj, {
    this.klucz = const ['id'],
    this.czas = 'zmieniono',
    this.rodzic,
    this.kluczRodzica,
  });

  final RodzajScalania rodzaj;

  /// Kolumny klucza głównego — po nich poznajemy ten sam wiersz.
  final List<String> klucz;

  /// Kolumna z czasem ostatniej zmiany.
  final String czas;

  /// Tabela rodzica przy [RodzajScalania.poRodzicu].
  final String? rodzic;

  /// Kolumna wskazująca rodzica.
  final String? kluczRodzica;
}

/// Reguły dla wszystkich tabel kopii.
///
/// Tabele bez własnego czasu zmiany (powiązania pól z zabiegiem, szczegóły
/// oprysku i nawożenia) idą razem z rodzicem — inaczej dałoby się scalić
/// zabieg z pliku ze szczegółami z telefonu i wyszłaby ewidencja, której
/// nie wykonał nikt.
const Map<String, ReguloScalania> regulyScalania = {
  'konto': ReguloScalania(RodzajScalania.poCzasie),
  'gospodarstwo': ReguloScalania(RodzajScalania.poCzasie),
  'konto_gospodarstwo': ReguloScalania(
    RodzajScalania.dopiszBrakujace,
    klucz: ['konto_id', 'gospodarstwo_id'],
  ),
  'dzialka_ewidencyjna': ReguloScalania(RodzajScalania.poCzasie),
  'dzialka_rolna': ReguloScalania(RodzajScalania.poCzasie),
  'dzialka_rolna_czesc': ReguloScalania(
    RodzajScalania.poRodzicu,
    klucz: ['dzialka_rolna_id', 'dzialka_ewidencyjna_id'],
    rodzic: 'dzialka_rolna',
    kluczRodzica: 'dzialka_rolna_id',
  ),
  // Uprawa pola ma własny czas zmiany, więc wygrywa nowsza; wiersze mają
  // identyfikator wyliczany z pola i sezonu, więc dwa urządzenia dopisujące
  // to samo trafiają w ten sam wiersz.
  'uprawa_pola': ReguloScalania(RodzajScalania.poCzasie),
  // Deklaracja okrywy — tak samo: identyfikator z pola i sezonu, więc
  // wygrywa nowsza deklaracja, a starsza zostaje w dzienniku zmian.
  'okrywa_pola': ReguloScalania(RodzajScalania.poCzasie),
  'nawoz': ReguloScalania(RodzajScalania.poCzasie),
  // Pozycja magazynu ma identyfikator wyliczany z nazwy, więc ten sam
  // środek wpisany na dwóch urządzeniach to jeden wiersz.
  'magazyn_pozycja': ReguloScalania(RodzajScalania.poCzasie),
  // Ruch ma własny czas zmiany, a zużycie przy zabiegu — identyfikator
  // wyliczany z zabiegu i pozycji, więc ten sam oprysk nie odpisze towaru
  // dwa razy po scaleniu.
  'magazyn_ruch': ReguloScalania(RodzajScalania.poCzasie),
  'zabieg': ReguloScalania(RodzajScalania.poCzasie),
  'zabieg_pole': ReguloScalania(
    RodzajScalania.poRodzicu,
    klucz: ['zabieg_id', 'dzialka_rolna_id'],
    rodzic: 'zabieg',
    kluczRodzica: 'zabieg_id',
  ),
  'zabieg_oprysk': ReguloScalania(
    RodzajScalania.poRodzicu,
    klucz: ['zabieg_id'],
    rodzic: 'zabieg',
    kluczRodzica: 'zabieg_id',
  ),
  'zabieg_nawozenie': ReguloScalania(
    RodzajScalania.poRodzicu,
    klucz: ['zabieg_id'],
    rodzic: 'zabieg',
    kluczRodzica: 'zabieg_id',
  ),
  'stado': ReguloScalania(RodzajScalania.poCzasie),
  'zwierze': ReguloScalania(RodzajScalania.poCzasie),
  'zdarzenie_zwierzecia': ReguloScalania(RodzajScalania.poCzasie),
  'ustawienia': ReguloScalania(RodzajScalania.lokalneZostaje, klucz: ['klucz']),
};

/// Co scalanie zrobiło — liczby dla rolnika, nie dla dziennika programisty.
class RaportScalenia {
  const RaportScalenia({
    required this.zrobiona,
    required this.dodane,
    required this.zastapione,
    required this.pominieteStarsze,
    required this.bezZmian,
    required this.wpisyDziennika,
  });

  /// Kiedy zrobiono plik, z którego scalaliśmy.
  final DateTime zrobiona;

  /// Wiersze, których w telefonie nie było — doszły.
  final Map<String, int> dodane;

  /// Wiersze, które w pliku były nowsze — zastąpiły lokalne. Poprzednia
  /// wersja została w dzienniku zmian.
  final Map<String, int> zastapione;

  /// Wiersze z pliku starsze od lokalnych — pominięte, ale zapisane
  /// w dzienniku zmian, żeby nic nie zginęło bez śladu.
  final Map<String, int> pominieteStarsze;

  /// Wiersze identyczne po obu stronach.
  final int bezZmian;

  /// Wpisy dziennika zmian, które doszły z pliku.
  final int wpisyDziennika;

  static int _suma(Map<String, int> liczby) =>
      liczby.values.fold(0, (suma, ile) => suma + ile);

  int get dodaneRazem => _suma(dodane);
  int get zastapioneRazem => _suma(zastapione);
  int get pominieteRazem => _suma(pominieteStarsze);

  bool get cokolwiekSieZmienilo =>
      dodaneRazem > 0 || zastapioneRazem > 0 || wpisyDziennika > 0;

  /// Zabiegi, które doszły z drugiego telefonu — to liczba, o którą rolnik
  /// pyta najpierw.
  int get zabiegiDodane => dodane['zabieg'] ?? 0;
  int get polaDodane => dodane['dzialka_rolna'] ?? 0;
  int get zwierzetaDodane => dodane['zwierze'] ?? 0;
}

/// Wynik scalania.
sealed class WynikScalania {
  const WynikScalania();
}

class ScalenieZrobione extends WynikScalania {
  const ScalenieZrobione(this.raport);

  final RaportScalenia raport;
}

class ScalenieOdrzucone extends WynikScalania {
  const ScalenieOdrzucone(this.blad, {this.szczegoly = ''});

  final BladKopii blad;
  final String szczegoly;
}

/// Synchronizacja przez dysk użytkownika (plan, pkt 2): dołączenie danych
/// z pliku kopii zrobionej na **drugim** urządzeniu.
///
/// Nie ma tu żadnego serwera ani konta w chmurze. Rolnik robi kopię na
/// jednym telefonie, przenosi plik tak, jak mu wygodnie (pendrive, dysk
/// w telefonie, poczta), i dołącza ją na drugim.
///
/// Zasada rozstrzygania jest jedna i da się ją powiedzieć jednym zdaniem:
/// **nowszy wpis wygrywa, starszy zostaje w dzienniku zmian.** Dzięki temu
/// scalanie nigdy nie usuwa dokumentacji — kontrola i rolnik widzą obie
/// wersje, z czasem i nazwą urządzenia.
class Scalanie {
  const Scalanie({
    required this.baza,
    required this.wersjaSchematu,
    required this.urzadzenie,
  });

  final DatabaseExecutor baza;

  /// Wersja schematu, którą rozumie ta wersja aplikacji.
  final int wersjaSchematu;

  /// Nazwa tego urządzenia — idzie do dziennika przy scalaniu.
  final String urzadzenie;

  KopiaDanych get _kopia =>
      KopiaDanych(baza: baza, wersjaSchematu: wersjaSchematu);

  /// Czyta plik bez zmieniania czegokolwiek — ekran pokazuje to rolnikowi
  /// przed scaleniem.
  OpisKopii? przeczytaj(Uint8List bajty) => _kopia.przeczytaj(bajty);

  /// Dołącza dane z pliku do tego, co już jest w telefonie.
  Future<WynikScalania> scal(Uint8List bajty, {DateTime? teraz}) async {
    final dane = _rozpakuj(bajty);
    if (dane == null) {
      return const ScalenieOdrzucone(BladKopii.nieNaszPlik);
    }
    final opis = _kopia.przeczytaj(bajty)!;
    if (opis.wersjaSchematu > wersjaSchematu) {
      return ScalenieOdrzucone(
        BladKopii.nowszaWersja,
        szczegoly:
            'plik ze schematu ${opis.wersjaSchematu}, '
            'aplikacja rozumie $wersjaSchematu',
      );
    }

    final chwila = (teraz ?? DateTime.now()).toIso8601String();
    final tabelePliku = dane['tabele'] as Map<String, dynamic>;

    final dodane = <String, int>{};
    final zastapione = <String, int>{};
    final pominieteStarsze = <String, int>{};
    var bezZmian = 0;

    /// Rodzice, przy których wygrał plik — ich dzieci też biorą z pliku.
    final plikWygral = <String, Set<String>>{};

    for (final tabela in KopiaDanych.tabele) {
      if (tabela == 'historia_zmian') {
        continue; // dziennik scalamy na końcu, po wszystkich wyzwalaczach
      }
      final regula = regulyScalania[tabela];
      final wiersze = (tabelePliku[tabela] as List<dynamic>?) ?? const [];
      if (regula == null || wiersze.isEmpty) {
        continue;
      }

      for (final surowy in wiersze) {
        final wiersz = Map<String, Object?>.from(
          surowy as Map<String, dynamic>,
        );
        final gdzie = regula.klucz.map((k) => '$k = ?').join(' AND ');
        final wartosciKlucza = [for (final k in regula.klucz) wiersz[k]];
        final lokalne = await baza.query(
          tabela,
          where: gdzie,
          whereArgs: wartosciKlucza,
          limit: 1,
        );

        if (lokalne.isEmpty) {
          await baza.insert(tabela, wiersz);
          dodane[tabela] = (dodane[tabela] ?? 0) + 1;
          if (regula.rodzaj == RodzajScalania.poCzasie) {
            (plikWygral[tabela] ??= {}).add('${wiersz[regula.klucz.first]}');
          }
          continue;
        }

        switch (regula.rodzaj) {
          case RodzajScalania.dopiszBrakujace:
          case RodzajScalania.lokalneZostaje:
            bezZmian++;

          case RodzajScalania.poRodzicu:
            final idRodzica = '${wiersz[regula.kluczRodzica]}';
            if (plikWygral[regula.rodzic]?.contains(idRodzica) ?? false) {
              await baza.update(
                tabela,
                wiersz,
                where: gdzie,
                whereArgs: wartosciKlucza,
              );
              zastapione[tabela] = (zastapione[tabela] ?? 0) + 1;
            } else {
              bezZmian++;
            }

          case RodzajScalania.poCzasie:
            final czasPliku = '${wiersz[regula.czas] ?? ''}';
            final czasLokalny = '${lokalne.single[regula.czas] ?? ''}';
            if (czasPliku == czasLokalny) {
              bezZmian++;
            } else if (czasPliku.compareTo(czasLokalny) > 0) {
              // Plik nowszy: poprzednią wersję zapisujemy do dziennika
              // zmian, zanim ją nadpiszemy. Wyzwalacze robią to same dla
              // zabiegów i pól — tam nie dublujemy wpisu.
              if (!await _maWyzwalaczNaZmiane(tabela)) {
                await _doDziennika(
                  tabela: tabela,
                  wierszId: '${wiersz[regula.klucz.first]}',
                  dane: {'poprzednio': lokalne.single, 'scalenie': true},
                  czas: chwila,
                );
              }
              await baza.update(
                tabela,
                wiersz,
                where: gdzie,
                whereArgs: wartosciKlucza,
              );
              zastapione[tabela] = (zastapione[tabela] ?? 0) + 1;
              (plikWygral[tabela] ??= {}).add('${wiersz[regula.klucz.first]}');
            } else {
              // Lokalny nowszy: wersja z pliku nie przepada bez śladu.
              await _doDziennika(
                tabela: tabela,
                wierszId: '${wiersz[regula.klucz.first]}',
                dane: {'pominieto_z_pliku': wiersz, 'scalenie': true},
                czas: chwila,
              );
              pominieteStarsze[tabela] = (pominieteStarsze[tabela] ?? 0) + 1;
            }
        }
      }
    }

    final wpisyDziennika = await _scalDziennik(
      (tabelePliku['historia_zmian'] as List<dynamic>?) ?? const [],
    );

    return ScalenieZrobione(
      RaportScalenia(
        zrobiona: opis.zrobiona,
        dodane: dodane,
        zastapione: zastapione,
        pominieteStarsze: pominieteStarsze,
        bezZmian: bezZmian,
        wpisyDziennika: wpisyDziennika,
      ),
    );
  }

  /// Dziennik zmian jest dopisywany, nigdy nadpisywany: bierzemy z pliku
  /// te wpisy, których jeszcze nie ma. Identyczność poznajemy po treści,
  /// bo numer wpisu jest lokalny dla każdego telefonu.
  Future<int> _scalDziennik(List<dynamic> wiersze) async {
    var doszlo = 0;
    for (final surowy in wiersze) {
      final wiersz = Map<String, Object?>.from(surowy as Map<String, dynamic>)
        ..remove('id');
      final juzJest = await baza.query(
        'historia_zmian',
        where:
            'tabela = ? AND wiersz_id = ? AND operacja = ? AND czas = ? '
            'AND IFNULL(urzadzenie, \'\') = IFNULL(?, \'\') '
            'AND IFNULL(dane_json, \'\') = IFNULL(?, \'\')',
        whereArgs: [
          wiersz['tabela'],
          wiersz['wiersz_id'],
          wiersz['operacja'],
          wiersz['czas'],
          wiersz['urzadzenie'],
          wiersz['dane_json'],
        ],
        limit: 1,
      );
      if (juzJest.isEmpty) {
        await baza.insert('historia_zmian', wiersz);
        doszlo++;
      }
    }
    return doszlo;
  }

  Future<void> _doDziennika({
    required String tabela,
    required String wierszId,
    required Map<String, Object?> dane,
    required String czas,
  }) => baza.insert('historia_zmian', {
    'tabela': tabela,
    'wiersz_id': wierszId,
    'operacja': 'zmiana',
    'dane_json': jsonEncode(dane),
    'czas': czas,
    'urzadzenie': urzadzenie,
  });

  /// Czy tabela ma wyzwalacz zapisujący zmianę do dziennika. Pytamy bazy,
  /// a nie listy w kodzie — wyzwalacze dochodzą z migracjami.
  Future<bool> _maWyzwalaczNaZmiane(String tabela) async {
    final wiersze = await baza.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = ?",
      [tabela],
    );
    return wiersze.any(
      (w) => '${w['sql'] ?? ''}'.toUpperCase().contains('AFTER UPDATE'),
    );
  }

  Map<String, dynamic>? _rozpakuj(Uint8List bajty) {
    // Ten sam plik, ta sama kontrola znacznika — czyta go `KopiaDanych`.
    final opis = _kopia.przeczytaj(bajty);
    if (opis == null) {
      return null;
    }
    return _kopia.rozpakujDoScalania(bajty);
  }
}
