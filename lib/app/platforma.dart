import 'dart:io' show Platform;

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../funkcje/odczyt/czytnik_zdjecia.dart';
import 'czytnik_zdjecia_urzadzenia.dart';

/// Na czym aplikacja właśnie działa.
///
/// Jeden kod obsługuje telefon i komputer (plan, pkt 1), ale SQLite dostaje
/// się do nich inaczej: na Androidzie przez `sqflite` (natywne SQLite
/// systemu), na Windows i Linuksie przez `sqflite_common_ffi` (biblioteka
/// dołączona do programu). Różnica jest tylko tu — reszta kodu widzi tę
/// samą bazę.
enum Platforma {
  telefon('telefon'),
  komputer('komputer');

  const Platforma(this.nazwaUrzadzenia);

  /// Nazwa trafiająca do kolumny `urzadzenie` przy każdym wpisie: po
  /// scaleniu danych z dwóch urządzeń rolnik widzi, gdzie wpis powstał.
  final String nazwaUrzadzenia;

  /// Platforma, na której program właśnie działa.
  static Platforma biezaca() =>
      Platform.isAndroid || Platform.isIOS ? telefon : komputer;
}

/// Fabryka bazy dla danej platformy.
///
/// Na komputerze trzeba najpierw włączyć `sqflite_common_ffi` — bez tego
/// otwarcie bazy kończy się błędem „databaseFactory not initialized",
/// czyli program na Windows nie wstaje wcale.
DatabaseFactory fabrykaBazy(Platforma platforma) {
  if (platforma == Platforma.telefon) {
    return sqflite.databaseFactory;
  }
  sqfliteFfiInit();
  return databaseFactoryFfi;
}

/// Odczyt tekstu ze zdjęcia — tylko w telefonie.
///
/// Rozpoznawanie pisma (ML Kit) i aparat z `image_picker` nie mają wersji
/// na Windows. Na komputerze oddajemy czytnik, który mówi o tym wprost:
/// wolimy jedno zdanie prawdy niż przycisk, który nic nie robi.
CzytnikZdjecia czytnikZdjecia(Platforma platforma) =>
    platforma == Platforma.telefon
    ? CzytnikZdjeciaUrzadzenia()
    : const CzytnikTylkoWTelefonie();

/// Czytnik na komputer: zawsze odmawia, zawsze z wyjaśnieniem.
class CzytnikTylkoWTelefonie implements CzytnikZdjecia {
  const CzytnikTylkoWTelefonie();

  @override
  Future<String?> tekst(ZrodloZdjecia zrodlo) async =>
      throw const BladOdczytuZdjecia(
        'Odczyt ze zdjęcia działa tylko w telefonie.',
        coZrobic:
            'Na komputerze wpisz dane z etykiety albo z worka ręcznie — '
            'albo zrób wpis w telefonie i dołącz dane z drugiego '
            'urządzenia.',
      );
}
