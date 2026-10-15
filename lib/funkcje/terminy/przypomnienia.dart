import 'kalendarz_terminow.dart';

/// Jedno przypomnienie, które ma się odezwać w telefonie.
class Przypomnienie {
  const Przypomnienie({
    required this.id,
    required this.kiedy,
    required this.tytul,
    required this.tresc,
  });

  /// Numer potrzebny systemowi, żeby móc przypomnienie odwołać.
  final int id;

  final DateTime kiedy;
  final String tytul;
  final String tresc;
}

/// Układa przypomnienia z pozycji kalendarza.
///
/// Logika jest osobno od systemu powiadomień, żeby dało się ją sprawdzić
/// testem bez telefonu.
abstract final class PlanPrzypomnien {
  /// Godzina przypomnienia — rano, zanim rolnik wyjedzie w pole.
  static const int godzina = 7;

  /// Ile dni wcześniej uprzedzamy o terminie.
  static const int dniUprzedzenia = 3;

  /// Dalej niż na miesiąc nie planujemy: do tego czasu kalendarz i tak się
  /// zmieni, a system ma ograniczoną liczbę zaplanowanych powiadomień.
  static const int horyzontDni = 31;

  /// Ile przypomnień najwyżej zostawiamy w systemie.
  static const int najwiecej = 32;

  static List<Przypomnienie> uloz(
    List<PozycjaKalendarza> pozycje, {
    required DateTime teraz,
  }) {
    final wynik = <Przypomnienie>[];

    for (final pozycja in pozycje) {
      final dni = pozycja.dniDo(teraz);
      if (dni < 0 || dni > horyzontDni) {
        continue;
      }

      final wDniuTerminu = _oGodzinie(pozycja.data);
      if (wDniuTerminu.isAfter(teraz)) {
        wynik.add(
          Przypomnienie(
            id: _numer(pozycja.id, 0),
            kiedy: wDniuTerminu,
            tytul: pozycja.nazwa,
            tresc: pozycja.coZrobic,
          ),
        );
      }

      final zWyprzedzeniem = _oGodzinie(
        pozycja.data.subtract(const Duration(days: dniUprzedzenia)),
      );
      if (zWyprzedzeniem.isAfter(teraz)) {
        wynik.add(
          Przypomnienie(
            id: _numer(pozycja.id, 1),
            kiedy: zWyprzedzeniem,
            tytul: '$dniUprzedzenia dni do terminu: ${pozycja.nazwa}',
            tresc: pozycja.coZrobic,
          ),
        );
      }
    }

    wynik.sort((a, b) => a.kiedy.compareTo(b.kiedy));
    return wynik.length <= najwiecej ? wynik : wynik.sublist(0, najwiecej);
  }

  static DateTime _oGodzinie(DateTime dzien) =>
      DateTime(dzien.year, dzien.month, dzien.day, godzina);

  /// Stały numer dla danej pozycji — żeby ponowne ułożenie planu zastąpiło
  /// stare przypomnienia, a nie dołożyło drugich takich samych.
  static int _numer(String id, int odmiana) =>
      (id.hashCode & 0x3FFFFFF) * 2 + odmiana;
}

/// Powiadomienia w telefonie. Granica między logiką a systemem.
abstract interface class UslugaPrzypomnien {
  /// Czy system pozwala nam pokazywać powiadomienia.
  Future<bool> czyWolno();

  /// Pyta użytkownika o zgodę; zwraca jej wynik.
  Future<bool> popros();

  /// Zastępuje wszystkie wcześniejsze przypomnienia podanymi.
  Future<void> zaplanuj(List<Przypomnienie> przypomnienia);

  /// Kasuje wszystkie zaplanowane przypomnienia.
  Future<void> wylacz();
}
