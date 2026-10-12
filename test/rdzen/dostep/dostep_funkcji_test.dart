import 'package:agro_asystent/rdzen/dostep/dostep_funkcji.dart';
import 'package:agro_asystent/rdzen/dostep/funkcja.dart';
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
}
