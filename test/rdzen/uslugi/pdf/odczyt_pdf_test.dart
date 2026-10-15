import 'dart:io';
import 'dart:typed_data';

import 'package:agro_asystent/rdzen/uslugi/pdf/dokument_pdf.dart';
import 'package:agro_asystent/rdzen/uslugi/pdf/skladnia_pdf.dart';
import 'package:agro_asystent/rdzen/uslugi/pdf/tekst_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Czytnik PDF napisany od zera, bo import wniosku ma działać na telefonie
/// bez bibliotek natywnych (ADR-0005). Te testy pilnują składni i tego, co
/// z niej wychodzi na prawdziwym pliku — zanonimizowanym wzorcu z P4.
void main() {
  Uint8List bajty(String tekst) => Uint8List.fromList(tekst.codeUnits);

  group('składnia', () {
    test('czyta nazwę, liczbę, ciąg i tablicę', () {
      final czytnik = CzytnikSkladniPdf(bajty('/Type 12 3.5 (tekst) [1 2]'));
      expect(czytnik.czytaj(), const NazwaPdf('Type'));
      expect(czytnik.czytaj(), 12);
      expect(czytnik.czytaj(), 3.5);
      expect((czytnik.czytaj()! as CiagPdf).bajty, bajty('tekst'));
      expect(czytnik.czytaj(), [1, 2]);
      expect(czytnik.czytaj(), ZnacznikPdf.koniec);
    });

    test('rozpoznaje odwołanie „12 0 R", a nie dwie liczby', () {
      final czytnik = CzytnikSkladniPdf(bajty('12 0 R 7 0'));
      expect(czytnik.czytaj(), const OdwolaniePdf(12));
      expect(czytnik.czytaj(), 7);
      expect(czytnik.czytaj(), 0);
    });

    test('czyta słownik z zagnieżdżeniem', () {
      final czytnik = CzytnikSkladniPdf(
        bajty('<< /Type /Page /Zasoby << /Font 4 0 R >> /Kids [1 0 R] >>'),
      );
      final slownik = czytnik.czytaj()! as Map<String, Object?>;
      expect(slownik['Type'], const NazwaPdf('Page'));
      expect(
        (slownik['Zasoby']! as Map<String, Object?>)['Font'],
        const OdwolaniePdf(4),
      );
      expect(slownik['Kids'], [const OdwolaniePdf(1)]);
    });

    test('ciąg szesnastkowy i znaki specjalne w ciągu zwykłym', () {
      final czytnik = CzytnikSkladniPdf(bajty(r'<0041> <4142> (a\(b\)c\101)'));
      // Ciąg szesnastkowy to bajty, a nie znaki: „0041" ma dwa bajty.
      expect((czytnik.czytaj()! as CiagPdf).bajty, [0x00, 0x41]);
      expect((czytnik.czytaj()! as CiagPdf).bajty, [0x41, 0x42]);
      expect(
        String.fromCharCodes((czytnik.czytaj()! as CiagPdf).bajty),
        'a(b)cA',
      );
    });

    test('ASCII85 rozpakowuje tak samo jak zapis źródłowy', () {
      // „87cURD]j7BEbo7~>" to zapis ASCII85 słów „Hello world".
      final rozpakowane = FiltryPdf.rozpakuj(bajty('87cURD]j7BEbo7~>'), [
        'ASCII85Decode',
      ]);
      expect(String.fromCharCodes(rozpakowane), 'Hello world');
    });

    test('nieznany filtr to błąd, a nie puste dane', () {
      expect(
        () => FiltryPdf.rozpakuj(bajty('cokolwiek'), ['JBIG2Decode']),
        throwsA(isA<BladPdf>()),
      );
    });
  });

  group('dokument', () {
    test('plik, który nie jest PDF-em, odrzucamy od razu', () {
      expect(
        () => DokumentPdf.zBajtow(bajty('to jest zwykły tekst, nie PDF')),
        throwsA(isA<BladPdf>()),
      );
    });

    test('pusty plik nie wywala aplikacji', () {
      expect(() => DokumentPdf.zBajtow(Uint8List(0)), throwsA(isA<BladPdf>()));
    });
  });

  group('odczyt wzorca wniosku', () {
    late List<StronaTekstuPdf> strony;

    setUpAll(() {
      strony = OdczytTekstuPdf.strony(
        File('test/dane/wzorzec_wniosku.pdf').readAsBytesSync(),
      );
    });

    test('czyta wszystkie strony i ich rozmiar', () {
      expect(strony, hasLength(3));
      expect(strony.first.szerokosc, closeTo(841.89, 0.1));
      expect(strony.first.wysokosc, closeTo(595.28, 0.1));
    });

    test('polskie znaki wychodzą z tablicy znaków pliku, nie z domysłów', () {
      final pierwszyWiersz = strony.first.wiersze().first;
      expect(
        pierwszyWiersz.map((s) => s.tekst).join(' '),
        'WNIOSEK O PRZYZNANIE PŁATNOŚCI NA ROK 2026',
      );
    });

    test('słowa mają położenie i rosną od lewej', () {
      final wiersz = strony.first.wiersze().firstWhere(
        (w) => w.first.tekst == 'X.',
      );
      expect(wiersz.first.x0, lessThan(wiersz.last.x0));
      expect(wiersz.first.x1, greaterThan(wiersz.first.x0));
      expect(wiersz.first.gora, greaterThan(0));
    });

    test('odcięcie stopki usuwa wiersz z dolnej krawędzi strony', () {
      final zeStopka = strony.first.wiersze().length;
      final bezStopki = strony.first.wiersze(odcietaStopka: 20).length;
      expect(bezStopki, lessThan(zeStopka));
    });
  });
}
