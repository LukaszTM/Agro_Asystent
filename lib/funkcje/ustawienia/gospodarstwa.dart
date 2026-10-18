import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/dostep/dostep_funkcji.dart';
import '../../rdzen/dostep/funkcja.dart';

/// Gospodarstwo: nazwa, numer producenta i powierzchnia użytków rolnych.
/// Nazwa i numer stoją na każdym wydruku dla ARiMR i inspekcji, dlatego
/// rolnik musi móc je poprawić bez żadnej opłaty.
class Gospodarstwo {
  const Gospodarstwo({
    required this.id,
    required this.nazwa,
    this.numerProducenta,
    this.powierzchniaUrHa = 0,
  });

  final String id;
  final String nazwa;

  /// Numer producenta z ARiMR — rolnik wpisuje go sam, nie zgadujemy.
  final String? numerProducenta;

  final double powierzchniaUrHa;

  static Gospodarstwo zBazy(Map<String, Object?> w) => Gospodarstwo(
    id: w['id']! as String,
    nazwa: (w['nazwa'] as String?) ?? 'Moje gospodarstwo',
    numerProducenta: w['numer_producenta'] as String?,
    powierzchniaUrHa: (w['powierzchnia_ur_ha'] as num?)?.toDouble() ?? 0,
  );
}

/// Konto — nazwa właściciela danych, obejmująca jedno lub kilka gospodarstw
/// (plan, pkt 7). Jest tylko w telefonie: aplikacja nie ma własnego serwera
/// i nie zakłada żadnego logowania. Konto przyda się przy synchronizacji
/// przez dysk rolnika, żeby wiedzieć, czyje dane są w paczce.
class Konto {
  const Konto({required this.id, required this.nazwa});

  final String id;
  final String nazwa;

  static Konto zBazy(Map<String, Object?> w) =>
      Konto(id: w['id']! as String, nazwa: w['nazwa']! as String);
}

/// Wynik próby dodania gospodarstwa. Drugie i kolejne gospodarstwo to
/// dodatek premium (plan, pkt 8) — ale już istniejące gospodarstwa zostają
/// w pełni dostępne, nawet gdy premium się skończy. Dokumentacji nigdy
/// nie blokujemy (CLAUDE.md, reguła 4).
enum WynikDodania {
  dodane,

  /// Pierwsze gospodarstwo jest, a dodanie kolejnego wymaga premium.
  potrzebnePremium,

  /// Rolnik nie podał nazwy.
  brakNazwy,
}

/// Lista gospodarstw, wybór tego, nad którym pracujemy, i konto.
class RepozytoriumGospodarstw {
  const RepozytoriumGospodarstw({
    required this.baza,
    this.dostep = const DostepFunkcji.zBudowy(),
  });

  final DatabaseExecutor baza;

  /// Pytamy o dostęp tylko przez `DostepFunkcji` — jedyne miejsce
  /// decydujące o premium (CLAUDE.md).
  final DostepFunkcji dostep;

  /// Klucz w tabeli `ustawienia` z gospodarstwem, nad którym pracujemy.
  static const String kluczAktywnego = 'gospodarstwo_aktywne';

  Future<List<Gospodarstwo>> wszystkie() async {
    final wiersze = await baza.query(
      'gospodarstwo',
      where: 'usuniety = 0',
      orderBy: 'nazwa',
    );
    return wiersze.map(Gospodarstwo.zBazy).toList(growable: false);
  }

  Future<Gospodarstwo?> jedno(String id) async {
    final wiersze = await baza.query(
      'gospodarstwo',
      where: 'id = ? AND usuniety = 0',
      whereArgs: [id],
      limit: 1,
    );
    return wiersze.isEmpty ? null : Gospodarstwo.zBazy(wiersze.first);
  }

  /// Gospodarstwo, nad którym pracujemy. Gdy zapisany wybór zniknął
  /// (gospodarstwo usunięte, kopia z innego telefonu), bierzemy pierwsze
  /// z listy — aplikacja nigdy nie zostaje bez gospodarstwa.
  Future<Gospodarstwo?> aktywne() async {
    final zapisane = await baza.query(
      'ustawienia',
      where: 'klucz = ?',
      whereArgs: [kluczAktywnego],
      limit: 1,
    );
    final id = zapisane.isEmpty ? null : zapisane.first['wartosc'] as String?;
    if (id != null) {
      final wybrane = await jedno(id);
      if (wybrane != null) {
        return wybrane;
      }
    }
    final lista = await wszystkie();
    return lista.isEmpty ? null : lista.first;
  }

  Future<void> ustawAktywne(String gospodarstwoId) async {
    await baza.insert('ustawienia', {
      'klucz': kluczAktywnego,
      'wartosc': gospodarstwoId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Czy wolno dodać jeszcze jedno gospodarstwo. Pierwsze — zawsze.
  Future<bool> czyMoznaDodac() async {
    if (dostep.czyDostepna(Funkcja.kilkaGospodarstw)) {
      return true;
    }
    final lista = await wszystkie();
    return lista.isEmpty;
  }

  /// Dodaje gospodarstwo i od razu je uaktywnia.
  Future<({WynikDodania wynik, String? id})> dodaj({
    required String nazwa,
    required String urzadzenie,
    String? numerProducenta,
    DateTime? teraz,
  }) async {
    final nazwaBezSpacji = nazwa.trim();
    if (nazwaBezSpacji.isEmpty) {
      return (wynik: WynikDodania.brakNazwy, id: null);
    }
    if (!await czyMoznaDodac()) {
      return (wynik: WynikDodania.potrzebnePremium, id: null);
    }

    final czas = teraz ?? DateTime.now();
    final id = 'gospodarstwo-${czas.microsecondsSinceEpoch}';
    await baza.insert('gospodarstwo', {
      'id': id,
      'nazwa': nazwaBezSpacji,
      'numer_producenta': numerProducenta?.trim().isEmpty ?? true
          ? null
          : numerProducenta!.trim(),
      'utworzono': czas.toIso8601String(),
      'zmieniono': czas.toIso8601String(),
      'urzadzenie': urzadzenie,
    });
    await _przypiszDoKonta(id);
    await ustawAktywne(id);
    return (wynik: WynikDodania.dodane, id: id);
  }

  /// Poprawa danych gospodarstwa — darmowa, bo bez nich wydruk jest nie do
  /// użytku. Pola zostawione puste nie są zmieniane.
  Future<void> popraw({
    required String gospodarstwoId,
    String? nazwa,
    String? numerProducenta,
    double? powierzchniaUrHa,
    DateTime? teraz,
  }) async {
    final zmiany = <String, Object?>{
      'zmieniono': (teraz ?? DateTime.now()).toIso8601String(),
    };
    if (nazwa != null && nazwa.trim().isNotEmpty) {
      zmiany['nazwa'] = nazwa.trim();
    }
    if (numerProducenta != null) {
      final numer = numerProducenta.trim();
      zmiany['numer_producenta'] = numer.isEmpty ? null : numer;
    }
    if (powierzchniaUrHa != null) {
      zmiany['powierzchnia_ur_ha'] = powierzchniaUrHa;
    }
    await baza.update(
      'gospodarstwo',
      zmiany,
      where: 'id = ?',
      whereArgs: [gospodarstwoId],
    );
  }

  /// Usunięcie gospodarstwa. Wiersz zostaje w bazie (wpisy są dopisywane,
  /// nie nadpisywane), a ostatniego gospodarstwa usunąć nie można — rolnik
  /// zostałby bez miejsca na dokumentację.
  Future<bool> usun({required String gospodarstwoId, DateTime? teraz}) async {
    final lista = await wszystkie();
    if (lista.length < 2) {
      return false;
    }
    await baza.update(
      'gospodarstwo',
      {'usuniety': 1, 'zmieniono': (teraz ?? DateTime.now()).toIso8601String()},
      where: 'id = ?',
      whereArgs: [gospodarstwoId],
    );
    final zostale = await wszystkie();
    if (zostale.isNotEmpty) {
      await ustawAktywne(zostale.first.id);
    }
    return true;
  }

  // ── konto ───────────────────────────────────────────────────────────────

  Future<Konto?> konto() async {
    final wiersze = await baza.query('konto', orderBy: 'utworzono', limit: 1);
    return wiersze.isEmpty ? null : Konto.zBazy(wiersze.first);
  }

  /// Zakłada konto (jeśli go nie ma) albo poprawia jego nazwę, i przypisuje
  /// do niego wszystkie gospodarstwa z telefonu.
  Future<Konto?> zapiszKonto({
    required String nazwa,
    required String urzadzenie,
    DateTime? teraz,
  }) async {
    final nazwaBezSpacji = nazwa.trim();
    if (nazwaBezSpacji.isEmpty) {
      return null;
    }
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    final istniejace = await konto();
    if (istniejace != null) {
      await baza.update(
        'konto',
        {'nazwa': nazwaBezSpacji, 'zmieniono': czas},
        where: 'id = ?',
        whereArgs: [istniejace.id],
      );
    } else {
      await baza.insert('konto', {
        'id': 'konto-${(teraz ?? DateTime.now()).microsecondsSinceEpoch}',
        'nazwa': nazwaBezSpacji,
        'utworzono': czas,
        'zmieniono': czas,
        'urzadzenie': urzadzenie,
      });
    }
    for (final gospodarstwo in await wszystkie()) {
      await _przypiszDoKonta(gospodarstwo.id);
    }
    return konto();
  }

  /// Gospodarstwa przypisane do konta. Bez konta aplikacja działa tak samo —
  /// dlatego powiązanie jest dopisywane po cichu, gdy konto istnieje.
  Future<void> _przypiszDoKonta(String gospodarstwoId) async {
    final istniejace = await konto();
    if (istniejace == null) {
      return;
    }
    await baza.insert('konto_gospodarstwo', {
      'konto_id': istniejace.id,
      'gospodarstwo_id': gospodarstwoId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Gospodarstwo>> gospodarstwaKonta(String kontoId) async {
    final wiersze = await baza.rawQuery(
      '''
      SELECT g.* FROM gospodarstwo g
      JOIN konto_gospodarstwo kg ON kg.gospodarstwo_id = g.id
      WHERE kg.konto_id = ? AND g.usuniety = 0
      ORDER BY g.nazwa
      ''',
      [kontoId],
    );
    return wiersze.map(Gospodarstwo.zBazy).toList(growable: false);
  }
}
