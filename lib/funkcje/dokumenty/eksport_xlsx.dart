import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'dokument_ewidencji.dart';

/// Eksport dokumentu do arkusza XLSX.
///
/// Plik składamy sami z kilku plików XML spakowanych do ZIP-a — XLSX to
/// właśnie to. Dzięki temu nie potrzeba biblioteki, która ciągnęłaby za sobą
/// kolejne zależności, a wynik otwiera Excel, LibreOffice i Arkusze Google.
abstract final class EksportXlsx {
  static Uint8List bajty(DokumentEwidencji dokument) {
    final archiwum = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _typyTresci))
      ..addFile(ArchiveFile.string('_rels/.rels', _powiazaniaGlowne))
      ..addFile(ArchiveFile.string('xl/workbook.xml', _skoroszyt))
      ..addFile(
        ArchiveFile.string('xl/_rels/workbook.xml.rels', _powiazaniaSkoroszytu),
      )
      ..addFile(ArchiveFile.string('xl/styles.xml', _style))
      ..addFile(
        ArchiveFile.string('xl/worksheets/sheet1.xml', _arkusz(dokument)),
      );

    return ZipEncoder().encodeBytes(archiwum);
  }

  static String _arkusz(DokumentEwidencji dokument) {
    final wiersze = <String>[];
    var numer = 1;

    void dopisz(List<String?> komorki, {bool naglowek = false}) {
      final tresc = StringBuffer('<row r="$numer">');
      for (var i = 0; i < komorki.length; i++) {
        final wartosc = komorki[i];
        if (wartosc == null || wartosc.isEmpty) {
          continue;
        }
        tresc.write(
          '<c r="${_kolumna(i)}$numer" t="inlineStr"'
          '${naglowek ? ' s="1"' : ''}>'
          '<is><t xml:space="preserve">${_zabezpiecz(wartosc)}</t></is></c>',
        );
      }
      tresc.write('</row>');
      wiersze.add(tresc.toString());
      numer++;
    }

    dopisz([dokument.tytul], naglowek: true);
    dopisz(['Gospodarstwo', dokument.gospodarstwo]);
    dopisz(['Właściciel', dokument.wlasciciel ?? 'brak']);
    dopisz(['Numer producenta', dokument.numerProducenta ?? 'brak']);
    dopisz(['Okres', dokument.okres]);
    dopisz(['Podstawa', dokument.podstawa]);
    dopisz(['Słownik reguł', dokument.wersjaRegul]);
    dopisz(['Sporządzono', _data(dokument.sporzadzono)]);
    dopisz(const []);
    dopisz([
      for (final kolumna in dokument.kolumny) kolumna.nazwa,
    ], naglowek: true);
    for (final wiersz in dokument.wiersze) {
      dopisz([for (final wartosc in wiersz.wartosci) wartosc ?? 'brak']);
    }
    final niekompletne = dokument.niekompletne.length;
    if (niekompletne > 0) {
      dopisz(const []);
      dopisz([
        'Uwaga',
        '$niekompletne z ${dokument.liczbaWpisow} wpisów nie ma kompletu '
            'danych wymaganych przepisem',
      ]);
    }

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="$_przestrzenArkusza">'
        '<sheetData>${wiersze.join()}</sheetData>'
        '</worksheet>';
  }

  /// Numer kolumny na literę: 0 → A, 26 → AA.
  static String _kolumna(int numer) {
    var wynik = '';
    var pozostalo = numer;
    while (true) {
      wynik = String.fromCharCode(65 + pozostalo % 26) + wynik;
      pozostalo = pozostalo ~/ 26 - 1;
      if (pozostalo < 0) {
        return wynik;
      }
    }
  }

  static String _zabezpiecz(String tekst) => tekst
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _data(DateTime kiedy) =>
      '${kiedy.day.toString().padLeft(2, '0')}.'
      '${kiedy.month.toString().padLeft(2, '0')}.${kiedy.year}';

  static const String _przestrzenArkusza =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

  static const String _typyTresci =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" '
      'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.'
      'spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.'
      'spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.'
      'spreadsheetml.styles+xml"/>'
      '</Types>';

  static const String _powiazaniaGlowne =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const String _skoroszyt =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="$_przestrzenArkusza" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="Ewidencja" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';

  static const String _powiazaniaSkoroszytu =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
      'Target="styles.xml"/>'
      '</Relationships>';

  /// Dwa style: zwykły i pogrubiony na nagłówki tabeli.
  static const String _style =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="$_przestrzenArkusza">'
      '<fonts count="2">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
      '<borders count="1"><border/></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="2">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '</cellXfs>'
      // Bez nazwanego stylu „Normal" część programów zgłasza brak stylu
      // domyślnego przy otwieraniu pliku.
      '<cellStyles count="1">'
      '<cellStyle name="Normal" xfId="0" builtinId="0"/>'
      '</cellStyles>'
      '</styleSheet>';
}
