import '../../rdzen/reguly/regula_prawna.dart';
import '../zabiegi/kompletnosc_ewidencji.dart';
import '../zabiegi/rejestr_zabiegow.dart';

/// Dokument do podglądu, wydruku i eksportu.
///
/// Kolumny **nie są wpisane w kod**: to pola wymagane przez przepis, wzięte
/// ze słownika reguł (`assets/dane/reguly_prawne.json`). Dzięki temu wydruk
/// i eksport zmieniają się razem z przepisem, bez przebudowy aplikacji
/// (CLAUDE.md, reguła 1).
class DokumentEwidencji {
  const DokumentEwidencji({
    required this.tytul,
    required this.podstawa,
    required this.wersjaRegul,
    required this.gospodarstwo,
    required this.rok,
    this.numerProducenta,
    required this.kolumny,
    required this.wiersze,
    required this.sporzadzono,
  });

  final String tytul;
  final String podstawa;
  final String wersjaRegul;
  final String gospodarstwo;

  /// Numer producenta z ARiMR. `null` znaczy „rolnik go nie podał" —
  /// na wydruku piszemy „brak", niczego nie zgadujemy.
  final String? numerProducenta;

  /// `null` oznacza „wszystkie lata".
  final int? rok;

  final List<PoleWymagane> kolumny;
  final List<WierszDokumentu> wiersze;
  final DateTime sporzadzono;

  int get liczbaWpisow => wiersze.length;

  List<WierszDokumentu> get niekompletne =>
      wiersze.where((w) => !w.kompletny).toList(growable: false);

  String get okres => rok == null ? 'wszystkie lata' : 'rok $rok';

  /// Nazwa pliku bez rozszerzenia — czytelna dla rolnika i dla urzędu.
  String nazwaPliku(String rozszerzenie) {
    final czesci = [
      tytul.toLowerCase().replaceAll(RegExp(r'[^a-ząćęłńóśźż0-9]+'), '_'),
      if (rok != null) '$rok',
    ];
    return '${czesci.join('_').replaceAll(RegExp(r'_+'), '_')}.$rozszerzenie';
  }
}

/// Jeden wiersz dokumentu: wartości w kolejności kolumn.
class WierszDokumentu {
  const WierszDokumentu({required this.wartosci, required this.braki});

  /// `null` oznacza pole, którego nie ma w ewidencji.
  final List<String?> wartosci;

  /// Nazwy pól, których brakuje — wypisujemy je pod tabelą, zamiast
  /// zostawiać puste miejsce bez wyjaśnienia.
  final List<String> braki;

  bool get kompletny => braki.isEmpty;
}

/// Składa dokument z wpisów rejestru.
abstract final class BudowniczyDokumentu {
  static DokumentEwidencji zbuduj({
    required Obowiazek obowiazek,
    required List<WpisRejestru> wpisy,
    required String gospodarstwo,
    required String wersjaRegul,
    String? numerProducenta,
    int? rok,
    DateTime? sporzadzono,
  }) {
    final wiersze = <WierszDokumentu>[];
    for (final wpis in wpisy) {
      final ocena = KompletnoscEwidencji.sprawdz(wpis, obowiazek);
      wiersze.add(
        WierszDokumentu(
          wartosci: [for (final pole in ocena.pola) pole.wartosc],
          braki: [
            for (final pole in ocena.pola)
              if (pole.stan != StanPola.jest) pole.pole.nazwa,
          ],
        ),
      );
    }

    return DokumentEwidencji(
      tytul: obowiazek.nazwa,
      podstawa: obowiazek.podstawa,
      wersjaRegul: wersjaRegul,
      gospodarstwo: gospodarstwo,
      numerProducenta: numerProducenta,
      rok: rok,
      kolumny: obowiazek.wymaganePola,
      wiersze: wiersze,
      sporzadzono: sporzadzono ?? DateTime.now(),
    );
  }
}
