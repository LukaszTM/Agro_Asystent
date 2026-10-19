import '../../rdzen/dostep/dostep_funkcji.dart';
import '../../rdzen/modele/zabieg.dart';
import '../../rdzen/reguly/regula_prawna.dart';
import '../magazyn/magazyn.dart';
import '../magazyn/zuzycie_z_zabiegu.dart';
import '../nawozenie/ewidencja_nawozenia.dart';
import '../nawozenie/nawoz.dart';
import 'dane_wpisu.dart';
import 'repozytorium_zabiegow.dart';

/// Zapis wpisu zabiegu z [DaneWpisu] — jeden dla telefonu i komputera.
///
/// Ekran zbiera dane, a tu rozstrzyga się, co z nich trafia do bazy:
/// oprysk ze szczegółami i karencją z rejestru, nawożenie przez ewidencję
/// azotu, pozostałe prace jako zwykły zabieg. Magazyn (premium) odpisuje
/// zużycie sam; ewidencja zapisuje się tak samo w wersji darmowej.
class ZapisWpisu {
  const ZapisWpisu({
    required this.zabiegi,
    required this.nawozenie,
    required this.magazyn,
    required this.dostep,
  });

  final RepozytoriumZabiegow zabiegi;
  final EwidencjaNawozenia nawozenie;
  final Magazyn magazyn;
  final DostepFunkcji dostep;

  /// Dawka podpowiadana przy nawozie, dopóki rolnik nie ustawi własnej.
  static double domyslnaDawkaNawozu(JednostkaDawki jednostka) =>
      jednostka == JednostkaDawki.kilogramyNaHektar ? 100 : 20;

  /// Zapisuje wpis i zwraca zapisany zabieg. [praca] to wybór przy pracy
  /// „inny" (prace przy elementach krajobrazu, GAEC 8).
  Future<Zabieg> zapisz(DaneWpisu dane, {PracaKrajobrazowa? praca}) async {
    final zabieg = switch (dane.rodzaj) {
      RodzajZabiegu.oprysk => await _oprysk(dane),
      RodzajZabiegu.nawozenie => await _nawozenie(dane),
      _ => await _prosty(dane, praca),
    };
    await ZuzycieZZabiegu.odpisz(
      magazyn: magazyn,
      dostep: dostep,
      dane: dane,
      zabiegId: zabieg.id,
      urzadzenie: dane.urzadzenie,
    );
    return zabieg;
  }

  static String _godzina(DateTime kiedy) =>
      '${kiedy.hour.toString().padLeft(2, '0')}:'
      '${kiedy.minute.toString().padLeft(2, '0')}';

  List<PoleZabiegu> _polaZabiegu(DaneWpisu dane) => [
    for (final pole in dane.pola)
      PoleZabiegu(dzialkaRolnaId: pole.id, powierzchniaAr: pole.powierzchniaAr),
  ];

  Future<Zabieg> _oprysk(DaneWpisu dane) async {
    final srodek = dane.srodek!;
    final id = 'z-${dane.kiedy.microsecondsSinceEpoch}-${dane.pola.first.id}';
    final zabieg = Zabieg(
      id: id,
      gospodarstwoId: dane.gospodarstwoId,
      rodzaj: RodzajZabiegu.oprysk,
      data: dane.kiedy,
      godzina: _godzina(dane.kiedy),
      powierzchniaAr: dane.powierzchniaAr,
      urzadzenie: dane.urzadzenie,
    );
    await zabiegi.zapisz(
      zabieg: zabieg,
      pola: _polaZabiegu(dane),
      oprysk: SzczegolyOprysku(
        zabiegId: id,
        srodekNazwa: srodek.nazwa,
        nrZezwolenia: srodek.nrZezwolenia,
        dawka: dane.dawka,
        // Przy środku bez dawki w rejestrze jednostkę wskazał rolnik.
        dawkaJednostka: dane.dawkaJednostka,
        dawkaOdniesienie: dane.dawkaOdniesienie,
        przyczyna: dane.przyczyna,
        agrofag: srodek.agrofag,
        bbchOd: srodek.bbchOd,
        bbchDo: srodek.bbchDo,
        kodEppo: dane.pola.first.kodEppo,
        // Rodzaj zastosowania wynika z wyboru rolnika („Oprysk"), nie
        // z domysłu — ewidencja wymaga tego pola.
        rodzajZastosowania: 'opryskiwanie',
        karencjaDni: srodek.karencjaZnana ? srodek.karencjaDni : null,
        karencjaZrodlo: srodek.karencjaZnana ? 'etykieta MRiRW' : null,
        karencjaDataEtykiety: srodek.karencjaDataEtykiety,
      ),
      teraz: dane.kiedy,
    );
    return zabieg;
  }

  Future<Zabieg> _nawozenie(DaneWpisu dane) async {
    final nawoz = dane.nawoz!;
    final id = await nawozenie.zapisz(
      gospodarstwoId: dane.gospodarstwoId,
      nawoz: nawoz,
      pola: _polaZabiegu(dane),
      dawka: dane.dawka ?? domyslnaDawkaNawozu(dane.jednostkaDawki),
      jednostka: dane.jednostkaDawki,
      urzadzenie: dane.urzadzenie,
      kiedy: dane.kiedy,
      dataPrzyorania: nawoz.naturalny ? dane.dataPrzyorania : null,
    );
    return Zabieg(
      id: id,
      gospodarstwoId: dane.gospodarstwoId,
      rodzaj: RodzajZabiegu.nawozenie,
      data: dane.kiedy,
      powierzchniaAr: dane.powierzchniaAr,
      urzadzenie: dane.urzadzenie,
    );
  }

  /// Siew, zbiór, uprawa gleby i inne prace — bez środka i bez dawki.
  Future<Zabieg> _prosty(DaneWpisu dane, PracaKrajobrazowa? praca) async {
    final id = 'z-${dane.kiedy.microsecondsSinceEpoch}-${dane.pola.first.id}';
    final zabieg = Zabieg(
      id: id,
      gospodarstwoId: dane.gospodarstwoId,
      rodzaj: dane.rodzaj ?? RodzajZabiegu.inny,
      data: dane.kiedy,
      godzina: _godzina(dane.kiedy),
      powierzchniaAr: dane.powierzchniaAr,
      uwagi: praca?.nazwa,
      podrodzaj: praca?.id,
      urzadzenie: dane.urzadzenie,
    );
    await zabiegi.zapisz(
      zabieg: zabieg,
      pola: _polaZabiegu(dane),
      teraz: dane.kiedy,
    );
    return zabieg;
  }
}
