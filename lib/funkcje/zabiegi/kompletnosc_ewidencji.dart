import '../../rdzen/modele/zabieg.dart';
import '../../rdzen/reguly/regula_prawna.dart';
import 'rejestr_zabiegow.dart';

/// Stan jednego pola ewidencji.
enum StanPola {
  /// Pole jest wypełnione.
  jest,

  /// Pole jest puste, a przepis go wymaga.
  brak,

  /// Słownik reguł wymaga pola, którego ta wersja aplikacji nie zna.
  /// Nie udajemy, że jest w porządku — rolnik ma to sprawdzić sam.
  nieWiadomo,
}

/// Ocena jednego wymaganego pola wraz z wartością do pokazania.
class OcenaPola {
  const OcenaPola({required this.pole, required this.stan, this.wartosc});

  final PoleWymagane pole;
  final StanPola stan;
  final String? wartosc;
}

/// Ocena całego wpisu: czego brakuje do ewidencji wymaganej przepisem.
class OcenaEwidencji {
  const OcenaEwidencji({required this.obowiazek, required this.pola});

  final Obowiazek obowiazek;
  final List<OcenaPola> pola;

  List<OcenaPola> get braki =>
      pola.where((o) => o.stan == StanPola.brak).toList(growable: false);

  List<OcenaPola> get nieznane =>
      pola.where((o) => o.stan == StanPola.nieWiadomo).toList(growable: false);

  /// Kompletna tylko wtedy, gdy wszystkie pola są wypełnione **i** aplikacja
  /// rozumie każde pole ze słownika.
  bool get kompletna => braki.isEmpty && nieznane.isEmpty;

  /// Jedno zdanie dla rolnika: czego brakuje (plan, pkt 5).
  String get jednymZdaniem {
    if (kompletna) {
      return 'Ewidencja tego wpisu jest kompletna.';
    }
    final brakujace = [
      ...braki.map((o) => o.pole.nazwa),
      ...nieznane.map((o) => o.pole.nazwa),
    ];
    if (brakujace.length == 1) {
      return 'W ewidencji brakuje jednej rzeczy: ${brakujace.single}.';
    }
    return 'W ewidencji brakuje ${brakujace.length} rzeczy: '
        '${brakujace.take(3).join(', ')}'
        '${brakujace.length > 3 ? '…' : ''}.';
  }
}

/// Sprawdza wpis rejestru pod kątem pól wymaganych przez przepis.
///
/// Lista pól pochodzi ze słownika reguł (`assets/dane/reguly_prawne.json`),
/// więc zmiana przepisu nie wymaga zmiany kodu (CLAUDE.md, reguła 1).
abstract final class KompletnoscEwidencji {
  /// Obowiązek, którym mierzymy dany rodzaj zabiegu.
  static String idObowiazku(RodzajZabiegu rodzaj) =>
      rodzaj == RodzajZabiegu.oprysk ? 'ewidencja_sor' : 'ekoschematy_rejestr';

  static OcenaEwidencji sprawdz(WpisRejestru wpis, Obowiazek obowiazek) =>
      OcenaEwidencji(
        obowiazek: obowiazek,
        pola: [for (final pole in obowiazek.wymaganePola) _ocen(wpis, pole)],
      );

  static OcenaPola _ocen(WpisRejestru wpis, PoleWymagane pole) {
    final wartosc = _wartosc(wpis, pole.id);
    if (wartosc == null) {
      // Pola, którego nie znamy, nie wolno uznać za wypełnione.
      return OcenaPola(
        pole: pole,
        stan: _znanePola.contains(pole.id)
            ? StanPola.brak
            : StanPola.nieWiadomo,
      );
    }
    return OcenaPola(pole: pole, stan: StanPola.jest, wartosc: wartosc);
  }

  /// Pola, które aplikacja umie wypełnić. Wszystko poza tą listą oznacza
  /// „nie wiadomo", a nie „brak danych rolnika".
  static const Set<String> _znanePola = {
    'srodek_nazwa',
    'nr_zezwolenia',
    'data',
    'godzina',
    'dawka',
    'powierzchnia',
    'uprawa',
    'kod_eppo',
    'faza_bbch',
    'przyczyna',
    'rodzaj_zastosowania',
    'dzialka_referencyjna',
    'rodzaj_zabiegu',
  };

  static String? _wartosc(WpisRejestru wpis, String id) {
    final oprysk = wpis.oprysk;
    switch (id) {
      case 'srodek_nazwa':
        return _niePuste(oprysk?.srodekNazwa);
      case 'nr_zezwolenia':
        return _niePuste(oprysk?.nrZezwolenia);
      case 'data':
        return dzien(wpis.zabieg.data);
      case 'godzina':
        return _niePuste(wpis.zabieg.godzina);
      case 'dawka':
        final dawka = oprysk?.dawka;
        if (dawka == null) {
          return null;
        }
        final jednostka = [
          oprysk?.dawkaJednostka,
          oprysk?.dawkaOdniesienie,
        ].whereType<String>().join('/');
        return '${liczba(dawka)}${jednostka.isEmpty ? '' : ' $jednostka'}';
      case 'powierzchnia':
        return wpis.zabieg.powierzchniaAr > 0 ? wpis.powierzchniaOpis : null;
      case 'uprawa':
        return _niePuste(wpis.uprawy);
      case 'kod_eppo':
        final kody = {
          for (final pole in wpis.pola)
            if (pole.kodEppo != null && pole.kodEppo!.isNotEmpty) pole.kodEppo!,
        };
        // Brak kodu choćby dla jednego pola to brak w ewidencji.
        final bezKodu = wpis.pola.where(
          (p) => p.kodEppo == null || p.kodEppo!.isEmpty,
        );
        return kody.isEmpty || bezKodu.isNotEmpty ? null : kody.join(', ');
      case 'faza_bbch':
        final od = oprysk?.bbchOd;
        final doFazy = oprysk?.bbchDo;
        if (od == null && doFazy == null) {
          return null;
        }
        return od != null && doFazy != null && od != doFazy
            ? 'BBCH $od–$doFazy'
            : 'BBCH ${od ?? doFazy}';
      case 'przyczyna':
        return _niePuste(oprysk?.przyczyna) ?? _niePuste(oprysk?.agrofag);
      case 'rodzaj_zastosowania':
        return _niePuste(oprysk?.rodzajZastosowania);
      case 'dzialka_referencyjna':
        final dzialki = wpis.dzialkiReferencyjne;
        return dzialki.isEmpty ? null : dzialki.join(', ');
      case 'rodzaj_zabiegu':
        return wpis.zabieg.rodzaj.naWydruku;
      default:
        return null;
    }
  }

  static String? _niePuste(String? wartosc) =>
      wartosc == null || wartosc.trim().isEmpty ? null : wartosc;

  static String dzien(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}.'
      '${data.month.toString().padLeft(2, '0')}.${data.year}';

  static String liczba(double wartosc) =>
      wartosc.toStringAsFixed(wartosc % 1 == 0 ? 0 : 2).replaceAll('.', ',');
}
