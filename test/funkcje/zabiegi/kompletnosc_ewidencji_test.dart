import 'dart:io';

import 'package:agro_asystent/funkcje/zabiegi/kompletnosc_ewidencji.dart';
import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lista pól wymaganych w ewidencji jest **danymi** ze słownika reguł.
/// Sprawdzamy, że aplikacja umie je wypełnić i że braku nigdy nie zamiata
/// pod dywan (CLAUDE.md, reguła 5).
void main() {
  late SlownikRegul slownik;
  late Obowiazek ewidencjaSor;

  setUpAll(() {
    slownik = SlownikRegul.zTekstuJson(
      File('assets/dane/reguly_prawne.json').readAsStringSync(),
    );
    ewidencjaSor = slownik.obowiazek('ewidencja_sor')!;
  });

  WpisRejestru wpisKompletny({
    SzczegolyOprysku? oprysk,
    String? kodEppo = 'TRZAW',
    List<String> dzialki = const ['061506_2.0007.138'],
    String? godzina = '08:30',
    int powierzchniaAr = 250,
  }) => WpisRejestru(
    zabieg: Zabieg(
      id: 'z1',
      gospodarstwoId: 'g1',
      rodzaj: RodzajZabiegu.oprysk,
      data: DateTime(2026, 5, 10),
      godzina: godzina,
      powierzchniaAr: powierzchniaAr,
      urzadzenie: 'telefon',
    ),
    pola: [
      PoleWpisu(
        id: 'p1',
        nazwa: 'Za stodołą',
        uprawa: 'pszenica zwyczajna ozima',
        powierzchniaAr: powierzchniaAr,
        kodEppo: kodEppo,
        dzialkiReferencyjne: dzialki,
      ),
    ],
    oprysk:
        oprysk ??
        const SzczegolyOprysku(
          zabiegId: 'z1',
          srodekNazwa: 'Abydos 750 EC',
          nrZezwolenia: 'R-14/2025 h.r.',
          dawka: 0.75,
          dawkaJednostka: 'l',
          dawkaOdniesienie: 'ha',
          przyczyna: 'mączniak prawdziwy zbóż i traw',
          bbchOd: 29,
          bbchDo: 59,
          kodEppo: 'TRZAW',
          rodzajZastosowania: 'opryskiwanie',
        ),
  );

  test('słownik reguł podaje pola wymagane w ewidencji środków', () {
    expect(ewidencjaSor.wymaganePola, isNotEmpty);
    expect([
      for (final pole in ewidencjaSor.wymaganePola) pole.id,
    ], containsAll(['srodek_nazwa', 'nr_zezwolenia', 'kod_eppo', 'faza_bbch']));
    expect(slownik.obowiazek('ekoschematy_rejestr')!.wymaganePola, isNotEmpty);
  });

  test('wpis z pełnej ścieżki wpisu jest kompletny', () {
    final ocena = KompletnoscEwidencji.sprawdz(wpisKompletny(), ewidencjaSor);
    expect(ocena.braki, isEmpty);
    expect(ocena.nieznane, isEmpty);
    expect(ocena.kompletna, isTrue);
    expect(ocena.jednymZdaniem, contains('kompletna'));
  });

  test('wartości pokazujemy tak, jak mają stać w dokumencie', () {
    final ocena = KompletnoscEwidencji.sprawdz(wpisKompletny(), ewidencjaSor);
    String wartosc(String id) =>
        ocena.pola.firstWhere((o) => o.pole.id == id).wartosc ?? '';

    expect(wartosc('data'), '10.05.2026');
    expect(wartosc('dawka'), '0,75 l/ha');
    expect(wartosc('powierzchnia'), '2,50 ha');
    expect(wartosc('faza_bbch'), 'BBCH 29–59');
    expect(wartosc('kod_eppo'), 'TRZAW');
    expect(wartosc('dzialka_referencyjna'), '061506_2.0007.138');
  });

  test('brak godziny, kodu EPPO i działki to trzy braki', () {
    final ocena = KompletnoscEwidencji.sprawdz(
      wpisKompletny(godzina: null, kodEppo: null, dzialki: const []),
      ewidencjaSor,
    );
    expect([
      for (final brak in ocena.braki) brak.pole.id,
    ], containsAll(['godzina', 'kod_eppo', 'dzialka_referencyjna']));
    expect(ocena.kompletna, isFalse);
    expect(ocena.jednymZdaniem, contains('3 rzeczy'));
  });

  test('brak rodzaju zastosowania wymienia jedną rzecz', () {
    final ocena = KompletnoscEwidencji.sprawdz(
      wpisKompletny(
        oprysk: const SzczegolyOprysku(
          zabiegId: 'z1',
          srodekNazwa: 'Abydos 750 EC',
          nrZezwolenia: 'R-14/2025 h.r.',
          dawka: 0.75,
          dawkaJednostka: 'l',
          dawkaOdniesienie: 'ha',
          przyczyna: 'mączniak prawdziwy zbóż i traw',
          bbchOd: 29,
          bbchDo: 59,
        ),
      ),
      ewidencjaSor,
    );
    expect(ocena.braki.single.pole.id, 'rodzaj_zastosowania');
    expect(ocena.jednymZdaniem, contains('jednej rzeczy'));
  });

  test('pole ze słownika nowszego niż aplikacja daje „nie wiadomo"', () {
    // Tak wygląda sytuacja po aktualizacji danych: przepis dodał pole,
    // którego ta wersja aplikacji nie umie wypełnić.
    final nowszy = Obowiazek(
      id: 'ewidencja_sor',
      nazwa: ewidencjaSor.nazwa,
      podstawa: ewidencjaSor.podstawa,
      kogoDotyczy: ewidencjaSor.kogoDotyczy,
      progi: const [],
      progiLaczoneLub: true,
      limity: const [],
      przechowywanieLat: 3,
      statusWeryfikacji: 'potwierdzone',
      uwagi: '',
      wymaganePola: const [
        PoleWymagane(id: 'data', nazwa: 'data zabiegu'),
        PoleWymagane(id: 'numer_sprzetu', nazwa: 'numer opryskiwacza'),
      ],
    );

    final ocena = KompletnoscEwidencji.sprawdz(wpisKompletny(), nowszy);
    expect(ocena.braki, isEmpty);
    expect(ocena.nieznane.single.pole.nazwa, 'numer opryskiwacza');
    expect(ocena.kompletna, isFalse);
  });

  test('siew, zbiór i inne prace nie mają wymaganych pól z przepisu', () {
    // Mierzenie zbioru wymaganiami ewidencji nawożenia pokazywałoby braki,
    // których przepis nie wymaga — wpis byłby „niekompletny" bez powodu.
    for (final rodzaj in [
      RodzajZabiegu.siew,
      RodzajZabiegu.zbior,
      RodzajZabiegu.uprawaGleby,
      RodzajZabiegu.inny,
    ]) {
      expect(
        KompletnoscEwidencji.idObowiazku(rodzaj),
        isNull,
        reason: rodzaj.wBazie,
      );
    }
  });

  test('nawożenie mierzymy ewidencją nawożenia azotem', () {
    expect(
      KompletnoscEwidencji.idObowiazku(RodzajZabiegu.oprysk),
      'ewidencja_sor',
    );
    expect(
      KompletnoscEwidencji.idObowiazku(RodzajZabiegu.nawozenie),
      'program_azotanowy_ewidencja',
      reason: 'to ten rejestr wymaga przepis o azotanach',
    );

    final nawozenie = WpisRejestru(
      zabieg: Zabieg(
        id: 'z2',
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.nawozenie,
        data: DateTime(2026, 4, 1),
        powierzchniaAr: 250,
        urzadzenie: 'telefon',
      ),
      pola: const [
        PoleWpisu(
          id: 'p1',
          nazwa: 'Za stodołą',
          uprawa: 'pszenica zwyczajna ozima',
          powierzchniaAr: 250,
          kodEppo: 'TRZAW',
          dzialkiReferencyjne: ['061506_2.0007.138'],
        ),
      ],
      nawozenie: const SzczegolyNawozeniaWpisu(
        nawozNazwa: 'Saletra amonowa',
        naturalny: false,
        dawka: 200,
        dawkaJednostka: 'kg/ha',
        azotKgHa: 68,
      ),
    );

    for (final idRejestru in [
      'ekoschematy_rejestr',
      'program_azotanowy_ewidencja',
    ]) {
      final ocena = KompletnoscEwidencji.sprawdz(
        nawozenie,
        slownik.obowiazek(idRejestru)!,
      );
      // Nawóz mineralny: daty przyorania nie ma, bo nie dotyczy.
      expect(ocena.braki, isEmpty, reason: idRejestru);
      expect(ocena.nieznane, isEmpty, reason: idRejestru);
    }
    final azotanowa = KompletnoscEwidencji.sprawdz(
      nawozenie,
      slownik.obowiazek('program_azotanowy_ewidencja')!,
    );
    expect(
      azotanowa.pola.firstWhere((p) => p.pole.id == 'data_przyorania').wartosc,
      'nie dotyczy',
    );
  });

  test('data przyorania nawozu naturalnego: brak, dopóki rolnik jej nie '
      'wpisze', () {
    WpisRejestru obornik({DateTime? przyorano}) => WpisRejestru(
      zabieg: Zabieg(
        id: 'z-ob',
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.nawozenie,
        data: DateTime(2026, 3, 10),
        powierzchniaAr: 250,
        urzadzenie: 'telefon',
      ),
      pola: const [
        PoleWpisu(
          id: 'p1',
          nazwa: 'Za stodołą',
          uprawa: 'kukurydza',
          powierzchniaAr: 250,
          kodEppo: 'ZEAMX',
          dzialkiReferencyjne: ['061506_2.0007.138'],
        ),
      ],
      nawozenie: SzczegolyNawozeniaWpisu(
        nawozNazwa: 'Obornik bydlęcy',
        naturalny: true,
        dawka: 30,
        dawkaJednostka: 't/ha',
        azotKgHa: 150,
        dataPrzyorania: przyorano,
      ),
    );
    final obowiazek = slownik.obowiazek('program_azotanowy_ewidencja')!;

    final bezDaty = KompletnoscEwidencji.sprawdz(obornik(), obowiazek);
    expect(bezDaty.braki.map((o) => o.pole.id), ['data_przyorania']);

    final zData = KompletnoscEwidencji.sprawdz(
      obornik(przyorano: DateTime(2026, 3, 11)),
      obowiazek,
    );
    expect(zData.braki, isEmpty);
    expect(
      zData.pola.firstWhere((p) => p.pole.id == 'data_przyorania').wartosc,
      '11.03.2026',
    );
  });

  test('ewidencja nawożenia azotem pokazuje azot na ha i łącznie', () {
    final wpis = WpisRejestru(
      zabieg: Zabieg(
        id: 'z3',
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.nawozenie,
        data: DateTime(2026, 4, 1),
        powierzchniaAr: 250,
        urzadzenie: 'telefon',
      ),
      pola: const [
        PoleWpisu(
          id: 'p1',
          nazwa: 'Za stodołą',
          uprawa: 'pszenica zwyczajna ozima',
          powierzchniaAr: 300,
          dzialkiReferencyjne: ['061506_2.0007.138'],
        ),
      ],
      nawozenie: const SzczegolyNawozeniaWpisu(
        nawozNazwa: 'Saletra amonowa',
        naturalny: false,
        dawka: 200,
        dawkaJednostka: 'kg/ha',
        azotKgHa: 68,
      ),
    );
    final ocena = KompletnoscEwidencji.sprawdz(
      wpis,
      slownik.obowiazek('program_azotanowy_ewidencja')!,
    );
    final wartosci = {
      for (final pole in ocena.pola) pole.pole.id: pole.wartosc,
    };

    expect(wartosci['pole'], 'Za stodołą');
    // Powierzchnia uprawy to pole, powierzchnia nawożona to zabieg.
    expect(wartosci['powierzchnia_uprawy'], '3,00 ha');
    expect(wartosci['powierzchnia_nawozona'], '2,50 ha');
    expect(wartosci['rodzaj_nawozu'], 'Saletra amonowa (N 68 kg/ha)');
    expect(wartosci['dawka_azotu_na_ha'], '68 kg N/ha');
    expect(wartosci['dawka_azotu_razem'], '170 kg N');
  });

  test('nawóz bez znanej zawartości azotu nie udaje dawki', () {
    final wpis = WpisRejestru(
      zabieg: Zabieg(
        id: 'z4',
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.nawozenie,
        data: DateTime(2026, 4, 1),
        powierzchniaAr: 250,
        urzadzenie: 'telefon',
      ),
      pola: const [
        PoleWpisu(
          id: 'p1',
          nazwa: 'Za stodołą',
          uprawa: 'pszenica zwyczajna ozima',
          powierzchniaAr: 250,
          dzialkiReferencyjne: ['061506_2.0007.138'],
        ),
      ],
      nawozenie: const SzczegolyNawozeniaWpisu(
        nawozNazwa: 'Gnojowica bez analizy',
        naturalny: true,
        dawka: 25,
        dawkaJednostka: 'm3/ha',
      ),
    );
    final ocena = KompletnoscEwidencji.sprawdz(
      wpis,
      slownik.obowiazek('program_azotanowy_ewidencja')!,
    );
    final wartosci = {
      for (final pole in ocena.pola) pole.pole.id: pole.wartosc,
    };

    expect(wartosci['rodzaj_nawozu'], 'Gnojowica bez analizy');
    expect(wartosci['dawka_azotu_na_ha'], isNull);
    expect(wartosci['dawka_azotu_razem'], isNull);
    expect(
      ocena.braki.map((o) => o.pole.id),
      containsAll(['dawka_azotu_na_ha', 'dawka_azotu_razem']),
      reason: 'brak w ewidencji to brak, nie liczba na oko',
    );
  });
}
