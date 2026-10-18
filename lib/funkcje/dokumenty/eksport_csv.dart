import 'dart:convert';
import 'dart:typed_data';

import 'dokument_ewidencji.dart';

/// Eksport dokumentu do pliku CSV.
///
/// Średnik zamiast przecinka i znacznik BOM — tak, żeby plik otworzył się
/// poprawnie w polskim Excelu dwuklikiem, bez kreatora importu.
abstract final class EksportCsv {
  static const String separator = ';';

  /// Znacznik kolejności bajtów: bez niego Excel pokazuje „krzaki" zamiast
  /// polskich znaków.
  static const String znacznikBom = '﻿';

  static String tekst(DokumentEwidencji dokument) {
    final wiersze = <String>[
      _wiersz([dokument.tytul]),
      _wiersz(['Gospodarstwo', dokument.gospodarstwo]),
      _wiersz(['Właściciel', dokument.wlasciciel ?? 'brak']),
      _wiersz(['Numer producenta', dokument.numerProducenta ?? 'brak']),
      _wiersz(['Okres', dokument.okres]),
      _wiersz(['Podstawa', dokument.podstawa]),
      _wiersz(['Słownik reguł', dokument.wersjaRegul]),
      _wiersz(['Sporządzono', _data(dokument.sporzadzono)]),
      '',
      _wiersz([for (final kolumna in dokument.kolumny) kolumna.nazwa]),
      for (final wiersz in dokument.wiersze)
        _wiersz([for (final wartosc in wiersz.wartosci) wartosc ?? 'brak']),
    ];

    final niekompletne = dokument.niekompletne.length;
    if (niekompletne > 0) {
      wiersze
        ..add('')
        ..add(
          _wiersz([
            'Uwaga',
            '$niekompletne z ${dokument.liczbaWpisow} wpisów nie ma '
                'kompletu danych wymaganych przepisem',
          ]),
        );
    }
    return wiersze.join('\r\n');
  }

  static Uint8List bajty(DokumentEwidencji dokument) =>
      Uint8List.fromList(utf8.encode(znacznikBom + tekst(dokument)));

  static String _wiersz(List<String> komorki) =>
      komorki.map(_komorka).join(separator);

  static String _komorka(String wartosc) {
    final oczyszczona = wartosc.replaceAll('\r\n', ' ').replaceAll('\n', ' ');
    if (oczyszczona.contains(separator) ||
        oczyszczona.contains('"') ||
        oczyszczona.contains('\n')) {
      return '"${oczyszczona.replaceAll('"', '""')}"';
    }
    return oczyszczona;
  }

  static String _data(DateTime kiedy) =>
      '${kiedy.day.toString().padLeft(2, '0')}.'
      '${kiedy.month.toString().padLeft(2, '0')}.${kiedy.year}';
}
