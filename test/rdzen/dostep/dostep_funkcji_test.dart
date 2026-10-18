import 'package:agro_asystent/rdzen/dostep/dostep_funkcji.dart';
import 'package:agro_asystent/rdzen/dostep/funkcja.dart';
import 'package:agro_asystent/rdzen/dostep/opis_premium.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const darmowa = DostepFunkcji.darmowa();
  const premium = DostepFunkcji(maPremium: true);

  group('wersja darmowa wystarcza do spełnienia obowiązków', () {
    test('dokumentacja nigdy nie jest zablokowana', () {
      for (final funkcja in DostepFunkcji.wymaganePrzepisami) {
        expect(
          darmowa.czyDostepna(funkcja),
          isTrue,
          reason: '$funkcja musi działać bez opłaty (plan, pkt 8).',
        );
      }
    });

    test('wpis zabiegu, trzy rejestry i eksport są darmowe', () {
      expect(darmowa.czyDostepna(Funkcja.wpisZabiegu), isTrue);
      expect(
        darmowa.czyDostepna(Funkcja.trzyRejestryPodgladWydrukEksport),
        isTrue,
      );
      expect(darmowa.czyDostepna(Funkcja.listaDopuszczonychSrodkow), isTrue);
      expect(darmowa.czyDostepna(Funkcja.karencjaWpisRecznie), isTrue);
      expect(
        darmowa.czyDostepna(Funkcja.ewidencjaNawozeniaILimitAzotu),
        isTrue,
      );
    });
  });

  group('funkcje oszczędzające czas', () {
    test('import wniosku i zdjęcie etykiety tylko w premium', () {
      expect(darmowa.czyDostepna(Funkcja.importDzialekZWnioskuPdf), isFalse);
      expect(darmowa.czyDostepna(Funkcja.odczytZdjeciaEtykiety), isFalse);
      expect(darmowa.czyDostepna(Funkcja.planNawozeniaAzotem), isFalse);
      expect(premium.czyDostepna(Funkcja.importDzialekZWnioskuPdf), isTrue);
    });

    test('premium otwiera wszystkie funkcje', () {
      for (final funkcja in Funkcja.values) {
        expect(premium.czyDostepna(funkcja), isTrue, reason: '$funkcja');
      }
    });

    test('każda funkcja ma rozstrzygniętą przynależność', () {
      // Nowa pozycja w enum musi trafić do jednej z list w DostepFunkcji —
      // inaczej byłaby darmowa przez przypadek.
      for (final funkcja in Funkcja.values) {
        final wymagana = DostepFunkcji.wymaganePrzepisami.contains(funkcja);
        final platna = !darmowa.czyDostepna(funkcja);
        expect(
          wymagana || platna,
          isTrue,
          reason:
              '$funkcja nie jest ani wymagana przepisami, ani płatna. '
              'Dopisz ją do właściwej listy w DostepFunkcji.',
        );
      }
    });
  });

  group('zachęta do premium', () {
    test('nigdy podczas wpisu zabiegu', () {
      expect(
        darmowa.czyMoznaZaproponowacPremium(trwaWpisZabiegu: true),
        isFalse,
      );
      expect(
        darmowa.czyMoznaZaproponowacPremium(trwaWpisZabiegu: false),
        isTrue,
      );
    });

    test('nie pokazujemy jej osobie, która już zapłaciła', () {
      expect(
        premium.czyMoznaZaproponowacPremium(trwaWpisZabiegu: false),
        isFalse,
      );
    });
  });

  group('słowa o funkcjach płatnych', () {
    test('każda funkcja płatna ma nazwę w języku rolnika', () {
      final bezNazwy = Funkcja.values
          .where((f) => !darmowa.czyDostepna(f))
          .where((f) => OpisPremium.nazwa(f) == 'Ta funkcja')
          .toList();
      expect(
        bezNazwy,
        isEmpty,
        reason:
            'Nowa funkcja płatna musi dostać nazwę w OpisPremium — inaczej '
            'ekran powie rolnikowi „Ta funkcja".',
      );
    });

    test('wyjaśnienie zawsze kończy się obietnicą darmowej dokumentacji', () {
      for (final funkcja in Funkcja.values.where(
        (f) => !darmowa.czyDostepna(f),
      )) {
        expect(
          OpisPremium.coZrobic(funkcja),
          endsWith(OpisPremium.dokumentacjaDarmowa),
          reason: funkcja.name,
        );
      }
    });

    test('nigdzie nie namawiamy do zakupu', () {
      // Aplikacja niczego nie sprzedaje w trakcie pracy (plan, pkt 8).
      for (final funkcja in Funkcja.values) {
        final slowa =
            '${OpisPremium.tresc(funkcja)} '
                    '${OpisPremium.coZrobic(funkcja)}'
                .toLowerCase();
        expect(slowa, isNot(contains('kup')), reason: funkcja.name);
        expect(slowa, isNot(contains('zapłać')), reason: funkcja.name);
      }
    });

    test('funkcja darmowa nie ma po co wyjaśniać', () {
      // Wymagane przepisami są dostępne zawsze — tych nie opisujemy jako
      // płatnych.
      for (final funkcja in DostepFunkcji.wymaganePrzepisami) {
        expect(darmowa.czyDostepna(funkcja), isTrue, reason: funkcja.name);
      }
    });
  });

  group('wydanie testowe', () {
    // Wydanie dla rolnika buduje się **bez** flagi i wtedy ma zachowywać
    // się jak wersja darmowa. Gdyby ktoś kiedyś przestawił to na stałe,
    // rolnik dostałby za darmo dodatki, których sprzedaż jest w planie —
    // a przy wygaśnięciu wszystko zniknęłoby mu z dnia na dzień.
    test('bez flagi budowania program zachowuje się jak darmowy', () {
      const zBudowy = DostepFunkcji.zBudowy();

      expect(DostepFunkcji.wydanieTestowe, isFalse);
      expect(zBudowy.czyDostepna(Funkcja.magazyn), isFalse);
      expect(zBudowy.czyDostepna(Funkcja.importDzialekZWnioskuPdf), isFalse);
    });

    test('funkcje wymagane przepisami działają w każdym wydaniu', () {
      const zBudowy = DostepFunkcji.zBudowy();

      for (final funkcja in DostepFunkcji.wymaganePrzepisami) {
        expect(zBudowy.czyDostepna(funkcja), isTrue, reason: '$funkcja');
      }
    });

    test('odblokowanie dodatków nie rusza listy funkcji darmowych', () {
      // Premium dokłada dodatki, nigdy nie zabiera tego, co wymagane
      // przepisami.
      for (final funkcja in DostepFunkcji.wymaganePrzepisami) {
        expect(premium.czyDostepna(funkcja), isTrue, reason: '$funkcja');
      }
    });
  });
}
