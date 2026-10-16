import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// Co siedzi w pliku kopii — do pokazania rolnikowi, zanim cokolwiek
/// wczytamy.
class OpisKopii {
  const OpisKopii({
    required this.zrobiona,
    required this.wersjaSchematu,
    required this.gospodarstwa,
    required this.liczby,
  });

  final DateTime zrobiona;

  /// Wersja schematu bazy, z której powstała kopia.
  final int wersjaSchematu;

  /// Nazwy gospodarstw w kopii.
  final List<String> gospodarstwa;

  /// Liczba wierszy w każdej tabeli.
  final Map<String, int> liczby;

  int get liczbaZabiegow => liczby['zabieg'] ?? 0;
  int get liczbaPol => liczby['dzialka_rolna'] ?? 0;
  int get liczbaZwierzat => liczby['zwierze'] ?? 0;
}

/// Dlaczego kopii nie dało się wczytać.
enum BladKopii {
  /// Plik nie jest kopią z tej aplikacji.
  nieNaszPlik,

  /// Kopia pochodzi z nowszej wersji aplikacji — nie zgadujemy, jak ją
  /// przerobić.
  nowszaWersja,

  /// W telefonie są już wpisy. Scalanie dwóch zbiorów to synchronizacja,
  /// a nie wczytanie kopii — tego nie robimy po cichu.
  saJuzDane,
}

/// Wynik wczytania kopii.
sealed class WynikWczytania {
  const WynikWczytania();
}

class KopiaWczytana extends WynikWczytania {
  const KopiaWczytana(this.opis);

  final OpisKopii opis;
}

class KopiaOdrzucona extends WynikWczytania {
  const KopiaOdrzucona(this.blad, {this.szczegoly = ''});

  final BladKopii blad;
  final String szczegoly;
}

/// Kopia danych aplikacji do jednego pliku i z powrotem.
///
/// Plan (pkt 8) obiecuje kopię do pliku w wersji darmowej: rolnik ma móc
/// odzyskać dokumentację po zgubieniu telefonu, bez żadnej opłaty i bez
/// naszego serwera. Plik to zwykły ZIP z jednym JSON-em — da się go
/// otworzyć na komputerze i przeczytać, nawet gdyby aplikacja zniknęła.
///
/// Kopiujemy **całą bazę**, nie pojedyncze gospodarstwo: tak jest jedna
/// odpowiedź na pytanie „czy mam wszystko".
class KopiaDanych {
  const KopiaDanych({required this.baza, required this.wersjaSchematu});

  final DatabaseExecutor baza;

  /// Wersja schematu, którą rozumie ta wersja aplikacji.
  final int wersjaSchematu;

  static const String nazwaWpisu = 'kopia.json';
  static const String znacznik = 'agro-asystent-kopia';

  /// Tabele w kolejności zapisu i wczytania — rodzice przed dziećmi,
  /// bo klucze obce są pilnowane.
  static const List<String> tabele = [
    'konto',
    'gospodarstwo',
    'konto_gospodarstwo',
    'dzialka_ewidencyjna',
    'dzialka_rolna',
    'dzialka_rolna_czesc',
    'nawoz',
    'zabieg',
    'zabieg_pole',
    'zabieg_oprysk',
    'zabieg_nawozenie',
    'stado',
    'zwierze',
    'zdarzenie_zwierzecia',
    'ustawienia',
    'historia_zmian',
  ];

  /// Nazwa pliku kopii — z datą, żeby rolnik widział, która jest nowsza.
  static String nazwaPliku(DateTime kiedy) {
    String dwucyfrowo(int liczba) => liczba.toString().padLeft(2, '0');
    return 'agro-asystent-kopia-${kiedy.year}'
        '${dwucyfrowo(kiedy.month)}${dwucyfrowo(kiedy.day)}'
        '-${dwucyfrowo(kiedy.hour)}${dwucyfrowo(kiedy.minute)}.zip';
  }

  /// Zbiera całą bazę do jednego pliku.
  Future<Uint8List> zrob({DateTime? teraz}) async {
    final zawartosc = <String, List<Map<String, Object?>>>{};
    for (final tabela in tabele) {
      zawartosc[tabela] = await baza.query(tabela);
    }
    final json = jsonEncode({
      'znacznik': znacznik,
      'wersja_schematu': wersjaSchematu,
      'zrobiona': (teraz ?? DateTime.now()).toIso8601String(),
      'tabele': zawartosc,
    });

    final archiwum = Archive()
      ..addFile(ArchiveFile.bytes(nazwaWpisu, utf8.encode(json)));
    return Uint8List.fromList(ZipEncoder().encode(archiwum));
  }

  /// Czyta plik kopii bez zmieniania czegokolwiek w bazie.
  OpisKopii? przeczytaj(Uint8List bajty) {
    final dane = _rozpakuj(bajty);
    if (dane == null) {
      return null;
    }
    final tabele = (dane['tabele'] as Map<String, dynamic>?) ?? const {};
    final gospodarstwa = [
      for (final wiersz
          in (tabele['gospodarstwo'] as List<dynamic>?) ?? const [])
        ((wiersz as Map<String, dynamic>)['nazwa'] as String?) ?? '',
    ];
    return OpisKopii(
      zrobiona:
          DateTime.tryParse(dane['zrobiona'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      wersjaSchematu: (dane['wersja_schematu'] as num?)?.toInt() ?? 0,
      gospodarstwa: gospodarstwa.where((n) => n.isNotEmpty).toList(),
      liczby: {
        for (final wpis in tabele.entries)
          wpis.key: (wpis.value as List<dynamic>).length,
      },
    );
  }

  /// Wczytuje kopię do **pustej** aplikacji.
  ///
  /// Gdy w telefonie są już wpisy, odmawiamy: scalanie dwóch zbiorów danych
  /// to synchronizacja (etap „Windows i synchronizacja"), a nie wczytanie
  /// kopii. Lepiej powiedzieć wprost, niż po cichu zdublować dokumentację.
  Future<WynikWczytania> wczytaj(Uint8List bajty) async {
    final dane = _rozpakuj(bajty);
    if (dane == null) {
      return const KopiaOdrzucona(BladKopii.nieNaszPlik);
    }
    final opis = przeczytaj(bajty)!;
    if (opis.wersjaSchematu > wersjaSchematu) {
      return KopiaOdrzucona(
        BladKopii.nowszaWersja,
        szczegoly:
            'kopia ze schematu ${opis.wersjaSchematu}, '
            'aplikacja rozumie $wersjaSchematu',
      );
    }
    if (await _saDane()) {
      return const KopiaOdrzucona(BladKopii.saJuzDane);
    }

    final tabeleKopii = dane['tabele'] as Map<String, dynamic>;
    for (final tabela in tabele) {
      for (final wiersz
          in (tabeleKopii[tabela] as List<dynamic>?) ?? const []) {
        await baza.insert(
          tabela,
          Map<String, Object?>.from(wiersz as Map<String, dynamic>),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    // Wyzwalacze dopisały własne wiersze dziennika przy wstawianiu zabiegów.
    // Dziennik ma być taki jak w kopii — kontrola porównuje go z wpisami.
    final dziennik =
        (tabeleKopii['historia_zmian'] as List<dynamic>?) ?? const [];
    await baza.delete('historia_zmian');
    for (final wiersz in dziennik) {
      await baza.insert(
        'historia_zmian',
        Map<String, Object?>.from(wiersz as Map<String, dynamic>),
      );
    }

    return KopiaWczytana(opis);
  }

  Future<bool> _saDane() async {
    for (final tabela in ['zabieg', 'dzialka_rolna', 'zwierze']) {
      final wiersze = await baza.query(tabela, limit: 1);
      if (wiersze.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Zawartość pliku kopii dla scalania (`Scalanie`) — ta sama kontrola
  /// znacznika, ten sam format. Zwraca `null`, gdy plik nie jest kopią
  /// z tej aplikacji.
  Map<String, dynamic>? rozpakujDoScalania(Uint8List bajty) => _rozpakuj(bajty);

  Map<String, dynamic>? _rozpakuj(Uint8List bajty) {
    try {
      final archiwum = ZipDecoder().decodeBytes(bajty);
      final wpis = archiwum.files
          .where((p) => p.name == nazwaWpisu)
          .firstOrNull;
      if (wpis == null) {
        return null;
      }
      final dane =
          jsonDecode(utf8.decode(wpis.content)) as Map<String, dynamic>;
      return dane['znacznik'] == znacznik ? dane : null;
    } catch (_) {
      // Rolnik mógł wybrać dowolny plik — to nie błąd aplikacji.
      return null;
    }
  }
}
