import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'dokument_ewidencji.dart';

/// Czcionki wydruku. Trzymamy je osobno, bo wczytuje je warstwa aplikacji
/// (z zasobów), a sam wydruk ma działać też w testach, bez Fluttera.
class CzcionkiWydruku {
  const CzcionkiWydruku({required this.zwykla, required this.pogrubiona});

  final Uint8List zwykla;
  final Uint8List pogrubiona;
}

/// Wydruk ewidencji do pliku PDF.
///
/// Strona pozioma, bo kolumn wymaganych przepisem jest kilkanaście.
/// Czcionka ma polskie znaki (fragment DejaVu Sans) — bez niej nazwy upraw
/// wyszłyby z dziurami.
abstract final class WydrukPdf {
  static Future<Uint8List> bajty(
    DokumentEwidencji dokument, {
    required CzcionkiWydruku czcionki,
  }) async {
    final zwykla = pw.Font.ttf(czcionki.zwykla.buffer.asByteData());
    final pogrubiona = pw.Font.ttf(czcionki.pogrubiona.buffer.asByteData());

    final plik = pw.Document(
      title: dokument.tytul,
      theme: pw.ThemeData.withFont(base: zwykla, bold: pogrubiona),
    );

    plik.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape.copyWith(
          marginLeft: 20,
          marginRight: 20,
          marginTop: 20,
          marginBottom: 24,
        ),
        header: (context) => context.pageNumber == 1
            ? _naglowek(dokument)
            : pw.SizedBox(height: 0),
        footer: (context) => _stopka(context, dokument),
        build: (context) => [
          _tabela(dokument),
          if (dokument.niekompletne.isNotEmpty) _uwagaOBrakach(dokument),
        ],
      ),
    );

    return plik.save();
  }

  static pw.Widget _naglowek(DokumentEwidencji dokument) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        dokument.tytul,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'Gospodarstwo: ${dokument.gospodarstwo}'
        '   •   Właściciel: ${dokument.wlasciciel ?? 'brak'}'
        '   •   Numer producenta: ${dokument.numerProducenta ?? 'brak'}'
        '   •   Okres: ${dokument.okres}'
        '   •   Wpisów: ${dokument.liczbaWpisow}',
        style: const pw.TextStyle(fontSize: 9),
      ),
      pw.Text(
        'Podstawa: ${dokument.podstawa}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 8),
    ],
  );

  static pw.Widget _stopka(pw.Context context, DokumentEwidencji dokument) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Sporządzono ${_data(dokument.sporzadzono)} w aplikacji Mój Łan '
            '(słownik reguł ${dokument.wersjaRegul})',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
          pw.Text(
            'Strona ${context.pageNumber} z ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ],
      );

  static pw.Widget _tabela(DokumentEwidencji dokument) {
    if (dokument.wiersze.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          'W tym okresie nie ma żadnego wpisu.',
          style: const pw.TextStyle(fontSize: 10),
        ),
      );
    }

    return pw.TableHelper.fromTextArray(
      headers: ['Lp.', for (final kolumna in dokument.kolumny) kolumna.nazwa],
      data: [
        for (var i = 0; i < dokument.wiersze.length; i++)
          [
            '${i + 1}',
            for (final wartosc in dokument.wiersze[i].wartosci)
              // Puste pole oznaczamy wprost — pusta kratka na wydruku
              // wygląda jak przeoczenie, a to jest brak do uzupełnienia.
              wartosc ?? 'brak',
          ],
      ],
      cellStyle: const pw.TextStyle(fontSize: 6.5),
      headerStyle: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      columnWidths: _szerokosciKolumn(dokument),
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
    );
  }

  /// Krótkim kolumnom dajemy stałą szerokość, żeby data ani godzina nie
  /// łamały się na dwa wiersze; reszta dzieli pozostałe miejsce.
  ///
  /// Dobieramy po identyfikatorze pola ze słownika reguł — kolumna, której
  /// nie znamy, dostaje zwykłą szerokość, więc nowe pole w przepisie niczego
  /// nie psuje.
  static const Map<String, double> _staleSzerokosci = {
    'data': 44,
    'godzina': 32,
    'dawka': 44,
    'powierzchnia': 44,
    'kod_eppo': 36,
    'faza_bbch': 46,
    // Ewidencja nawożenia azotem (tabela 15 programu azotanowego).
    'powierzchnia_uprawy': 46,
    'powierzchnia_nawozona': 52,
    'dawka_azotu_na_ha': 50,
    'dawka_azotu_razem': 48,
    'data_przyorania': 46,
    // Rejestr ekoschematów.
    'ilosc_nawozu': 48,
  };

  static Map<int, pw.TableColumnWidth> _szerokosciKolumn(
    DokumentEwidencji dokument,
  ) {
    final szerokosci = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(18),
    };
    for (var i = 0; i < dokument.kolumny.length; i++) {
      final stala = _staleSzerokosci[dokument.kolumny[i].id];
      if (stala != null) {
        // Pierwsza kolumna tabeli to numer porządkowy, stąd przesunięcie.
        szerokosci[i + 1] = pw.FixedColumnWidth(stala);
      }
    }
    return szerokosci;
  }

  static pw.Widget _uwagaOBrakach(DokumentEwidencji dokument) {
    final niekompletne = dokument.niekompletne.length;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Uwaga: $niekompletne z ${dokument.liczbaWpisow} wpisów nie ma '
        'kompletu danych wymaganych przepisem. Brakujące pola oznaczono '
        'słowem „brak" — uzupełnij je przed kontrolą.',
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }

  static String _data(DateTime kiedy) =>
      '${kiedy.day.toString().padLeft(2, '0')}.'
      '${kiedy.month.toString().padLeft(2, '0')}.${kiedy.year}';
}
