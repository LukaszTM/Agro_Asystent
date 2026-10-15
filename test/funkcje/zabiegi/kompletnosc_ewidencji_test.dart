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

  test('zabieg inny niż oprysk mierzymy rejestrem ekoschematów', () {
    expect(
      KompletnoscEwidencji.idObowiazku(RodzajZabiegu.oprysk),
      'ewidencja_sor',
    );
    expect(
      KompletnoscEwidencji.idObowiazku(RodzajZabiegu.nawozenie),
      'ekoschematy_rejestr',
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
    );
    final ocena = KompletnoscEwidencji.sprawdz(
      nawozenie,
      slownik.obowiazek('ekoschematy_rejestr')!,
    );
    expect(ocena.kompletna, isTrue);
  });
}
