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
  /// Obowiązek, którym mierzymy dany rodzaj zabiegu w podglądzie wpisu.
  /// Wydruki wybiera się po rejestrze, nie po rodzaju zabiegu.
  ///
  /// `null` znaczy „żaden przepis nie wymaga tu dodatkowych pól" — tak jest
  /// przy siewie, zbiorze, uprawie gleby i innych pracach. Mierzenie ich
  /// wymaganiami ewidencji nawożenia pokazywałoby braki, których przepis
  /// nie wymaga.
  static String? idObowiazku(RodzajZabiegu rodzaj) => switch (rodzaj) {
    RodzajZabiegu.oprysk => 'ewidencja_sor',
    RodzajZabiegu.nawozenie => 'program_azotanowy_ewidencja',
    _ => null,
  };

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
    // Ewidencja nawożenia azotem — wzór z tabeli 15 programu azotanowego.
    'pole',
    'powierzchnia_uprawy',
    'powierzchnia_nawozona',
    'rodzaj_nawozu',
    'dawka_azotu_na_ha',
    'dawka_azotu_razem',
    'data_przyorania',
    // Rejestr ekoschematów (plan, pkt 3).
    'nawoz',
    'ilosc_nawozu',
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

      // ── ewidencja nawożenia azotem (tabela 15) ──────────────────────
      case 'pole':
        return _niePuste(wpis.opisPol == 'bez pola' ? null : wpis.opisPol);
      case 'powierzchnia_uprawy':
        final uprawa = wpis.pola.fold<int>(
          0,
          (suma, p) => suma + p.powierzchniaAr,
        );
        return uprawa > 0 ? _hektary(uprawa) : null;
      case 'powierzchnia_nawozona':
        return wpis.zabieg.powierzchniaAr > 0
            ? _hektary(wpis.zabieg.powierzchniaAr)
            : null;
      case 'rodzaj_nawozu':
        final nawozenie = wpis.nawozenie;
        if (nawozenie == null || nawozenie.nawozNazwa.isEmpty) {
          return null;
        }
        final azot = nawozenie.azotKgHa;
        // Bez znanej zawartości azotu podajemy samą nazwę — nie zgadujemy.
        return azot == null
            ? nawozenie.nawozNazwa
            : '${nawozenie.nawozNazwa} (N ${liczba(azot)} kg/ha)';
      case 'dawka_azotu_na_ha':
        final azot = wpis.nawozenie?.azotKgHa;
        return azot == null ? null : '${liczba(azot)} kg N/ha';
      case 'dawka_azotu_razem':
        final razem = wpis.azotKgRazem;
        return razem == null ? null : '${liczba(razem)} kg N';
      case 'data_przyorania':
        // Wymagane tylko na terenie o dużym nachyleniu; aplikacja nie zna
        // nachylenia pola, więc zostawia pole rolnikowi.
        return null;

      // ── rejestr ekoschematów ────────────────────────────────────────
      case 'nawoz':
        return _niePuste(wpis.nawozenie?.nawozNazwa);
      case 'ilosc_nawozu':
        final dawka = wpis.nawozenie?.dawka;
        if (dawka == null) {
          return null;
        }
        final jednostka = wpis.nawozenie?.dawkaJednostka;
        return '${liczba(dawka)}${jednostka == null ? '' : ' $jednostka'}';

      default:
        return null;
    }
  }

  static String? _niePuste(String? wartosc) =>
      wartosc == null || wartosc.trim().isEmpty ? null : wartosc;

  static String dzien(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}.'
      '${data.month.toString().padLeft(2, '0')}.${data.year}';

  static String _hektary(int ar) =>
      '${(ar / 100).toStringAsFixed(2).replaceAll('.', ',')} ha';

  static String liczba(double wartosc) =>
      wartosc.toStringAsFixed(wartosc % 1 == 0 ? 0 : 2).replaceAll('.', ',');
}
