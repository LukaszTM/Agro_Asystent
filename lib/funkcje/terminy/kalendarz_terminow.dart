import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/reguly/regula_prawna.dart';
import '../zabiegi/rejestr_zabiegow.dart';
import '../ustawienia/zwierzeta_w_gospodarstwie.dart';
import '../zwierzeta/stado.dart';

/// Skąd wziął się termin.
enum ZrodloTerminu {
  /// Przepis ze słownika reguł (data roczna, okres, termin jednorazowy).
  przepis,

  /// Karencja po zabiegu wykonanym w tym gospodarstwie.
  karencja,

  /// Zgłoszenie zdarzenia zwierzęcia do IRZplus.
  zwierzeta,
}

/// Jak pilny jest termin — po tym grupujemy listę na ekranie.
enum PilnoscTerminu { minelo, dzis, wTymTygodniu, wTymMiesiacu, pozniej }

/// Jedna pozycja kalendarza obowiązków.
class PozycjaKalendarza {
  const PozycjaKalendarza({
    required this.id,
    required this.nazwa,
    required this.coZrobic,
    required this.zrodlo,
    required this.data,
    this.doKiedy,
    this.doWeryfikacji = false,
    this.obowiazekNiepewny = false,
    this.uwagi = '',
  });

  final String id;
  final String nazwa;

  /// Jedno zdanie: co rolnik ma zrobić (plan, pkt 5).
  final String coZrobic;

  final ZrodloTerminu zrodlo;

  /// Dzień, w którym termin wypada albo zaczyna się okres.
  final DateTime data;

  /// Koniec okresu — tylko dla terminów okresowych.
  final DateTime? doKiedy;

  /// Termin pochodzi ze źródła wymagającego sprawdzenia (plan, pkt 10).
  final bool doWeryfikacji;

  /// Aplikacja nie umiała ocenić, czy obowiązek dotyczy tego gospodarstwa.
  final bool obowiazekNiepewny;

  final String uwagi;

  bool get okres => doKiedy != null;

  int dniDo(DateTime dzis) => _dzien(data).difference(_dzien(dzis)).inDays;

  /// Czy okres właśnie trwa.
  bool trwa(DateTime dzis) {
    final koniec = doKiedy;
    if (koniec == null) {
      return false;
    }
    final dzien = _dzien(dzis);
    return !dzien.isBefore(_dzien(data)) && !dzien.isAfter(_dzien(koniec));
  }

  PilnoscTerminu pilnosc(DateTime dzis) {
    if (trwa(dzis)) {
      return PilnoscTerminu.dzis;
    }
    final dni = dniDo(dzis);
    if (dni < 0) {
      return PilnoscTerminu.minelo;
    }
    if (dni == 0) {
      return PilnoscTerminu.dzis;
    }
    if (dni <= 7) {
      return PilnoscTerminu.wTymTygodniu;
    }
    if (dni <= 31) {
      return PilnoscTerminu.wTymMiesiacu;
    }
    return PilnoscTerminu.pozniej;
  }

  static DateTime _dzien(DateTime kiedy) =>
      DateTime(kiedy.year, kiedy.month, kiedy.day);
}

/// Kalendarz obowiązków: terminy z przepisów i karencje z własnych zabiegów.
///
/// Terminy z przepisów biorą się **wyłącznie ze słownika reguł** — żadnej daty
/// nie ma w kodzie (CLAUDE.md, reguła 1). Obowiązki, których aplikacja nie
/// umie ocenić, pokazujemy z adnotacją, zamiast je chować.
class KalendarzTerminow {
  const KalendarzTerminow({
    required this.reguly,
    required this.rejestr,
    this.stado,
  });

  final SlownikRegul reguly;
  final RejestrZabiegow rejestr;

  /// Rejestr stada — gdy go nie ma, terminy zgłoszeń po prostu nie wchodzą.
  final RepozytoriumStada? stado;

  /// Ile dni do przodu patrzymy domyślnie.
  static const int horyzontDni = 365;

  /// Ile dni wstecz pokazujemy terminy, które właśnie minęły — żeby rolnik
  /// zobaczył, że coś przegapił, a nie żeby zniknęło bez śladu.
  static const int pamiecDni = 14;

  Future<List<PozycjaKalendarza>> najblizsze({
    required String gospodarstwoId,
    required ProfilGospodarstwa profil,
    DateTime? teraz,
    int dni = horyzontDni,
  }) async {
    final dzis = teraz ?? DateTime.now();
    final pozycje = <PozycjaKalendarza>[
      ...zPrzepisow(profil: profil, teraz: dzis, dni: dni),
      ...await _zKarencji(gospodarstwoId: gospodarstwoId, teraz: dzis),
      ...await _zeZdarzenZwierzat(
        gospodarstwoId: gospodarstwoId,
        profil: profil,
      ),
    ];

    pozycje.sort((a, b) => a.data.compareTo(b.data));
    return pozycje
        .where((p) => p.dniDo(dzis) >= -pamiecDni || p.trwa(dzis))
        .toList(growable: false);
  }

  /// Terminy z przepisów przeliczone na konkretne dni.
  List<PozycjaKalendarza> zPrzepisow({
    required ProfilGospodarstwa profil,
    required DateTime teraz,
    int dni = horyzontDni,
  }) {
    final wynik = <PozycjaKalendarza>[];
    final koniec = teraz.add(Duration(days: dni));

    for (final termin in reguly.terminy) {
      final obowiazek = reguly.obowiazek(termin.idObowiazku);
      final ocena = obowiazek?.ocena(profil) ?? Ocena.nieWiadomo;
      if (ocena == Ocena.nieDotyczy) {
        continue;
      }
      final niepewny = ocena == Ocena.nieWiadomo;

      switch (termin.rodzaj) {
        case RodzajTerminu.dataRoczna:
          final data = _najblizszaRocznica(termin.dataRoczna, teraz);
          if (data == null || data.isAfter(koniec)) {
            continue;
          }
          wynik.add(
            _pozycja(
              termin,
              obowiazek,
              data: data,
              coZrobic: termin.uwagi.isEmpty
                  ? 'Dopilnuj tego do podanego dnia.'
                  : termin.uwagi,
              niepewny: niepewny,
            ),
          );
        case RodzajTerminu.okresRoczny:
          final okres = _najblizszyOkres(termin.okresOd, termin.okresDo, teraz);
          if (okres == null || okres.od.isAfter(koniec)) {
            continue;
          }
          wynik.add(
            _pozycja(
              termin,
              obowiazek,
              data: okres.od,
              doKiedy: okres.doKiedy,
              coZrobic: termin.uwagi.isEmpty
                  ? 'W tym okresie obowiązuje zakaz.'
                  : termin.uwagi,
              niepewny: niepewny,
            ),
          );
        case RodzajTerminu.dataJednorazowa:
          final data = DateTime.tryParse(termin.data ?? '');
          if (data == null || data.isAfter(koniec)) {
            continue;
          }
          wynik.add(
            _pozycja(
              termin,
              obowiazek,
              data: data,
              coZrobic: termin.uwagi.isEmpty
                  ? 'Przygotuj się do tej zmiany.'
                  : termin.uwagi,
              niepewny: niepewny,
            ),
          );
        case RodzajTerminu.dniOdZdarzenia:
          // Termin liczony od zdarzenia (np. urodzenia cielęcia) policzymy,
          // gdy w aplikacji będą zwierzęta — plan, krok 9 etapu 1.
          continue;
        case RodzajTerminu.nieznany:
          // Rodzaj ze słownika nowszego niż aplikacja: nie zgadujemy daty.
          continue;
      }
    }
    return wynik;
  }

  PozycjaKalendarza _pozycja(
    Termin termin,
    Obowiazek? obowiazek, {
    required DateTime data,
    required String coZrobic,
    required bool niepewny,
    DateTime? doKiedy,
  }) => PozycjaKalendarza(
    id: termin.id,
    nazwa: termin.nazwa,
    coZrobic: coZrobic,
    zrodlo: ZrodloTerminu.przepis,
    data: data,
    doKiedy: doKiedy,
    doWeryfikacji: termin.doWeryfikacji,
    obowiazekNiepewny: niepewny,
    uwagi: obowiazek?.nazwa ?? '',
  );

  /// Zgłoszenia zdarzeń zwierząt: termin liczony od dnia zdarzenia.
  ///
  /// Które zdarzenie uruchamia który termin, mówi **słownik reguł** (pole
  /// `zdarzenie` przy terminie) — nowy termin nie wymaga zmiany kodu.
  Future<List<PozycjaKalendarza>> _zeZdarzenZwierzat({
    required String gospodarstwoId,
    required ProfilGospodarstwa profil,
  }) async {
    final rejestrStada = stado;
    if (rejestrStada == null) {
      return const [];
    }

    final wynik = <PozycjaKalendarza>[];
    for (final termin in reguly.terminy) {
      if (termin.rodzaj != RodzajTerminu.dniOdZdarzenia) {
        continue;
      }
      final dni = termin.dni;
      final nazwaZdarzenia = termin.zdarzenie;
      if (dni == null || nazwaZdarzenia == null) {
        continue;
      }
      final obowiazek = reguly.obowiazek(termin.idObowiazku);
      final ocena = obowiazek?.ocena(profil) ?? Ocena.nieWiadomo;
      if (ocena == Ocena.nieDotyczy) {
        continue;
      }

      final zdarzenia = await rejestrStada.zdarzenia(
        gospodarstwoId,
        rodzaj: RodzajZdarzenia.zBazy(nazwaZdarzenia),
        tylkoNiezgloszone: true,
      );
      for (final zdarzenie in zdarzenia) {
        final numer = zdarzenie.numerZwierzecia;
        wynik.add(
          PozycjaKalendarza(
            id: 'zgloszenie-${zdarzenie.id}',
            nazwa: numer == null ? termin.nazwa : '${termin.nazwa}: $numer',
            coZrobic: 'Zgłoś do IRZplus w ciągu $dni dni od zdarzenia.',
            zrodlo: ZrodloTerminu.zwierzeta,
            data: zdarzenie.data.add(Duration(days: dni)),
            doWeryfikacji: termin.doWeryfikacji,
            obowiazekNiepewny: ocena == Ocena.nieWiadomo,
            uwagi: obowiazek?.nazwa ?? '',
          ),
        );
      }
    }
    return wynik;
  }

  /// Karencje po opryskach: do kiedy nie wolno zbierać plonu.
  Future<List<PozycjaKalendarza>> _zKarencji({
    required String gospodarstwoId,
    required DateTime teraz,
  }) async {
    final wpisy = await rejestr.wpisy(gospodarstwoId);
    final wynik = <PozycjaKalendarza>[];

    for (final wpis in wpisy) {
      final dzienZbioru = wpis.dzienZbioru;
      if (dzienZbioru == null) {
        continue;
      }
      final pola = wpis.opisPol;
      wynik.add(
        PozycjaKalendarza(
          id: 'karencja-${wpis.zabieg.id}',
          nazwa: 'Koniec karencji: $pola',
          coZrobic: wpis.karencjaTrwa(teraz)
              ? 'Nie zbieraj plonu z tego pola do tego dnia.'
              : 'Karencja minęła — plon można zbierać.',
          zrodlo: ZrodloTerminu.karencja,
          data: dzienZbioru,
          uwagi: wpis.oprysk?.srodekNazwa ?? '',
          doWeryfikacji:
              !(wpis.oprysk?.karencjaPotwierdzona ?? false) &&
              (wpis.oprysk?.karencjaZrodlo == null),
        ),
      );
    }
    return wynik;
  }

  /// Najbliższe wystąpienie daty „MM-DD": w tym roku albo w następnym.
  static DateTime? _najblizszaRocznica(String? zapis, DateTime teraz) {
    final czesci = (zapis ?? '').split('-');
    if (czesci.length != 2) {
      return null;
    }
    final miesiac = int.tryParse(czesci[0]);
    final dzien = int.tryParse(czesci[1]);
    if (miesiac == null || dzien == null) {
      return null;
    }
    final wTymRoku = DateTime(teraz.year, miesiac, dzien);
    if (!wTymRoku.isBefore(DateTime(teraz.year, teraz.month, teraz.day))) {
      return wTymRoku;
    }
    return DateTime(teraz.year + 1, miesiac, dzien);
  }

  /// Najbliższy okres „MM-DD – MM-DD". Gdy właśnie trwa, zwracamy ten trwający.
  static ({DateTime od, DateTime doKiedy})? _najblizszyOkres(
    String? zapisOd,
    String? zapisDo,
    DateTime teraz,
  ) {
    final od = _wRoku(zapisOd, teraz.year);
    final doKiedy = _wRoku(zapisDo, teraz.year);
    if (od == null || doKiedy == null) {
      return null;
    }
    final dzis = DateTime(teraz.year, teraz.month, teraz.day);
    if (!dzis.isAfter(doKiedy)) {
      return (od: od, doKiedy: doKiedy);
    }
    return (
      od: DateTime(teraz.year + 1, od.month, od.day),
      doKiedy: DateTime(teraz.year + 1, doKiedy.month, doKiedy.day),
    );
  }

  static DateTime? _wRoku(String? zapis, int rok) {
    final czesci = (zapis ?? '').split('-');
    if (czesci.length != 2) {
      return null;
    }
    final miesiac = int.tryParse(czesci[0]);
    final dzien = int.tryParse(czesci[1]);
    if (miesiac == null || dzien == null) {
      return null;
    }
    return DateTime(rok, miesiac, dzien);
  }
}

/// Liczy profil gospodarstwa z danych w bazie: od niego zależy, które
/// obowiązki się włączają (plan, pkt 3).
class ProfilZBazy {
  const ProfilZBazy(this._baza, {this.stado, this.zwierzeta, this.reguly});

  final DatabaseExecutor _baza;

  /// Rejestr stada. Produkcja zwierzęca jest poza zakresem tej wersji
  /// (plan, pkt 2), więc aplikacja go nie podaje — parametr zostaje dla
  /// ścieżki rozwoju: gdy rejestr jest, DJP liczy się z niego.
  final RepozytoriumStada? stado;

  /// Odpowiedź rolnika „czy masz zwierzęta" — stąd DJP, gdy rejestru nie ma.
  final ZwierzetaWGospodarstwie? zwierzeta;

  /// Słownik reguł — potrzebny do listy upraw intensywnych. Bez niego
  /// powierzchnia tych upraw zostaje nieznana, a nie zerowa.
  final SlownikRegul? reguly;

  Future<ProfilGospodarstwa> policz(String gospodarstwoId, {int? sezon}) async {
    final rok = sezon ?? DateTime.now().year;
    final wiersze = await _baza.rawQuery(
      '''
      SELECT COALESCE(SUM(powierzchnia_ar), 0) AS ar
      FROM dzialka_rolna
      WHERE gospodarstwo_id = ? AND usuniety = 0 AND sezon = ?
    ''',
      [gospodarstwoId, rok],
    );
    final ar = (wiersze.first['ar'] as num?)?.toDouble() ?? 0;
    final intensywneHa = await _powierzchniaUprawIntensywnych(
      gospodarstwoId,
      rok,
    );

    final stanStada = await stado?.djp(gospodarstwoId);
    if (stanStada != null) {
      return ProfilGospodarstwa(
        powierzchniaUrHa: ar / 100,
        powierzchniaUprawIntensywnychHa: intensywneHa,
        djp: stanStada.djp,
        posiadaczZwierzat: stanStada.sztuk > 0,
      );
    }

    // Bez rejestru stada bierzemy odpowiedź rolnika. Gdy nie odpowiedział
    // albo ma zwierzęta, DJP zostaje nieznane — obowiązki od DJP wyjdą
    // jako „do sprawdzenia", a nie jako niedotyczące.
    final odpowiedz = await zwierzeta?.odczytaj();

    // Deklaracja ekoschematów dojdzie z importu wniosku; do tego czasu
    // liczymy tylko to, co naprawdę wiemy.
    return ProfilGospodarstwa(
      powierzchniaUrHa: ar / 100,
      powierzchniaUprawIntensywnychHa: intensywneHa,
      djp: odpowiedz?.djp,
      posiadaczZwierzat: odpowiedz?.posiadaczZwierzat,
    );
  }

  /// Powierzchnia upraw intensywnych z załącznika nr 7.
  ///
  /// Przy części upraw „intensywna" zależy od dawki azotu na hektar, więc
  /// liczymy azot wniesiony na każde pole w sezonie. Pole bez nawożenia
  /// ma zero azotu, czyli uprawą intensywną jeszcze nie jest.
  Future<double> _powierzchniaUprawIntensywnych(
    String gospodarstwoId,
    int rok,
  ) async {
    final lista = reguly?.uprawyIntensywne;
    if (lista == null || lista.uprawy.isEmpty) {
      return 0;
    }
    final wiersze = await _baza.rawQuery(
      '''
      -- Powierzchnie trzymamy w arach, a azot liczymy na hektar — stąd
      -- dzielenie przez sto. To przeliczenie jednostek, nie próg z przepisu.
      SELECT r.uprawa, r.powierzchnia_ar,
             COALESCE(SUM(n.azot_kg_ha * zp.powierzchnia_ar / 100), 0) AS azot_kg
      FROM dzialka_rolna r
      LEFT JOIN zabieg_pole zp ON zp.dzialka_rolna_id = r.id
      LEFT JOIN zabieg z ON z.id = zp.zabieg_id
                        AND z.usuniety = 0
                        AND strftime('%Y', z.data) = ?
      LEFT JOIN zabieg_nawozenie n ON n.zabieg_id = z.id
      WHERE r.gospodarstwo_id = ? AND r.usuniety = 0 AND r.sezon = ?
      GROUP BY r.id
    ''',
      ['$rok', gospodarstwoId, rok],
    );

    var arIntensywnych = 0;
    for (final wiersz in wiersze) {
      final uprawa = lista.dopasuj((wiersz['uprawa'] as String?) ?? '');
      if (uprawa == null) {
        continue;
      }
      final ar = (wiersz['powierzchnia_ar'] as int?) ?? 0;
      final azotKg = (wiersz['azot_kg'] as num?)?.toDouble() ?? 0;
      final azotNaHa = ar > 0 ? azotKg / (ar / 100) : 0.0;
      if (uprawa.liczySie(azotKgNaHa: azotNaHa)) {
        arIntensywnych += ar;
      }
    }
    return arIntensywnych / 100;
  }
}
