import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/wspolne/tekst.dart';
import 'uprawy_dopisane.dart';

/// Co aplikacja wie o nazwie uprawy ze słownika.
enum StanUprawy {
  /// Jest kod EPPO — ta uprawa wyjdzie na wydruku z kodem.
  kod('kod'),

  /// Nazwa rodzajowa: rejestr nie podaje gatunku („łubin"), a gatunki mają
  /// różne kody. Rolnik wybiera gatunek z listy.
  rodzajowa('rodzajowa'),

  /// Roślina spoza zakresu aplikacji (ozdobna, leśna, tropikalna).
  pozaZakresem('poza_zakresem'),

  /// Nazwa zbiorcza („zboża", „warzywa kapustne").
  grupa('grupa'),

  /// Miejsce stosowania albo przedmiot, nie roślina.
  nieUprawa('nie_uprawa'),

  /// Nazwa bez rozstrzygnięcia — da się wybrać, ale kodu EPPO nie ma.
  brak('brak');

  const StanUprawy(this.wBazie);

  final String wBazie;

  static StanUprawy zBazy(String? wartosc) => StanUprawy.values.firstWhere(
    (s) => s.wBazie == wartosc,
    orElse: () => StanUprawy.brak,
  );
}

/// Uprawa na liście wyboru.
class UprawaDoWyboru {
  const UprawaDoWyboru({
    required this.nazwa,
    required this.stan,
    this.kodEppo,
    this.gatunki = const [],
    this.pytanie,
    this.zastosowan = 0,
    this.wlasna = false,
  });

  final String nazwa;
  final StanUprawy stan;

  /// Kod EPPO uprawy — wymagany w ewidencji zabiegów (rozp. UE 2023/564).
  /// `null` znaczy, że go nie znamy; wtedy na wydruku zostaje „brak".
  final String? kodEppo;

  /// Gatunki do wyboru, gdy nazwa jest rodzajowa.
  final List<String> gatunki;

  /// O co pyta ekran wyboru przy nazwie rodzajowej („Jaki łubin?").
  final String? pytanie;

  /// Ile zastosowań w rejestrze dotyczy tej uprawy — po tym układamy listę,
  /// żeby najczęstsze uprawy były na górze.
  final int zastosowan;

  /// Nazwa wpisana przez rolnika, której nie ma w słowniku.
  final bool wlasna;

  /// Uprawa wpisana ręcznie: bez kodu EPPO i bez listy środków.
  factory UprawaDoWyboru.wlasnaNazwa(String nazwa) =>
      UprawaDoWyboru(nazwa: nazwa.trim(), stan: StanUprawy.brak, wlasna: true);

  bool get maKod => kodEppo != null && kodEppo!.isNotEmpty;

  /// Czy trzeba jeszcze dopytać o gatunek.
  bool get wymagaGatunku => stan == StanUprawy.rodzajowa && gatunki.isNotEmpty;

  static UprawaDoWyboru zBazy(Map<String, Object?> w) => UprawaDoWyboru(
    nazwa: w['nazwa']! as String,
    stan: StanUprawy.zBazy(w['stan'] as String?),
    kodEppo: w['kod_eppo'] as String?,
    gatunki: _lista(w['gatunki'] as String?),
    pytanie: w['pytanie'] as String?,
    zastosowan: (w['zastosowan'] as int?) ?? 0,
  );

  static List<String> _lista(String? zapis) => (zapis ?? '')
      .split('|')
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty)
      .toList(growable: false);
}

/// Wynik szukania: uprawy do pokazania i ile pasuje w ogóle.
///
/// Rolnik musi wiedzieć, że lista jest ucięta — inaczej szukałby wzrokiem
/// czegoś, czego na ekranie nie ma.
class WynikSzukaniaUpraw {
  const WynikSzukaniaUpraw({required this.uprawy, required this.razem});

  final List<UprawaDoWyboru> uprawy;

  /// Ile upraw pasuje do szukania — także tych poza listą.
  final int razem;

  bool get jestWiecej => razem > uprawy.length;

  bool get pusty => uprawy.isEmpty;
}

/// Słownik upraw do wyboru przy zakładaniu pola.
///
/// Rolnik wybiera uprawę z listy — pisanie jest wyjściem awaryjnym, gdy
/// jego uprawy w słowniku nie ma (reguły interfejsu: wybór z listy zamiast
/// pisania). Nazwy zbiorcze, miejsca stosowania i rośliny spoza zakresu
/// aplikacji na listę nie wchodzą.
class SlownikUpraw {
  const SlownikUpraw(
    this._baza, {
    this.dopisane = SlownikUprawDopisanych.pusty,
  });

  final DatabaseExecutor _baza;

  /// Uprawy dopisane poza rejestrem — przede wszystkim trwałe użytki
  /// zielone. Stoją na początku listy, bo rolnik, który ich szuka, nie
  /// znajdzie ich w rejestrze.
  final SlownikUprawDopisanych dopisane;

  /// Stany, które wolno wybrać jako uprawę pola.
  static const List<StanUprawy> _doWyboru = [
    StanUprawy.kod,
    StanUprawy.rodzajowa,
    StanUprawy.brak,
  ];

  static String get _warunekStanu =>
      "stan IN (${_doWyboru.map((s) => "'${s.wBazie}'").join(',')})";

  /// Uprawy do wyboru, najczęstsze pierwsze.
  ///
  /// [szukane] dzielimy na słowa i szukamy po postaci znormalizowanej, więc
  /// „lubin" znajduje „łubin", „ZYTO" — „żyto", a „psz ozim" — „pszenicę
  /// ozimą". Słownik ma ponad 600 upraw do wyboru, więc bez wyszukiwarki
  /// nie da się znaleźć konkretnej przewijaniem.
  Future<WynikSzukaniaUpraw> doWyboru({
    String szukane = '',
    int limit = 60,
  }) async {
    final slowa = Tekst.slowaDoSzukania(szukane);
    final warunki = [
      _warunekStanu,
      for (final _ in slowa) 'szukanie LIKE ?',
    ].join(' AND ');
    final argumenty = [for (final slowo in slowa) '%$slowo%'];

    final wiersze = await _baza.rawQuery(
      '''
      SELECT nazwa, kod_eppo, stan, gatunki, pytanie, zastosowan
      FROM uprawa
      WHERE $warunki
      ORDER BY zastosowan DESC, nazwa
      LIMIT ?
      ''',
      [...argumenty, limit],
    );
    final razem = wiersze.length < limit
        ? wiersze.length
        : ((await _baza.rawQuery(
                'SELECT COUNT(*) AS ile FROM uprawa WHERE $warunki',
                argumenty,
              )).first['ile']
              as int);

    final zPliku = dopisane.pasujace(szukane);
    return WynikSzukaniaUpraw(
      uprawy: [
        ...zPliku,
        ...wiersze.map(UprawaDoWyboru.zBazy),
      ].take(limit).toList(growable: false),
      razem: razem + zPliku.length,
    );
  }

  /// Jedna uprawa ze słownika — albo `null`, gdy słownik jej nie zna.
  Future<UprawaDoWyboru?> jedna(String nazwa) async {
    if (dopisane.jedna(nazwa) case final UprawaDoWyboru zPliku) {
      return zPliku;
    }
    final wiersze = await _baza.rawQuery(
      '''
      SELECT nazwa, kod_eppo, stan, gatunki, pytanie, zastosowan
      FROM uprawa WHERE nazwa = ? LIMIT 1
      ''',
      [nazwa],
    );
    return wiersze.isEmpty ? null : UprawaDoWyboru.zBazy(wiersze.first);
  }

  /// Gatunki do wyboru dla nazwy rodzajowej, w kolejności z danych.
  ///
  /// Gatunek bez wiersza w słowniku pomijamy — nie wymyślamy upraw.
  Future<List<UprawaDoWyboru>> gatunki(UprawaDoWyboru rodzajowa) async {
    if (rodzajowa.gatunki.isEmpty) {
      return const [];
    }
    final miejsca = List.filled(rodzajowa.gatunki.length, '?').join(',');
    final wiersze = await _baza.rawQuery('''
      SELECT nazwa, kod_eppo, stan, gatunki, pytanie, zastosowan
      FROM uprawa WHERE nazwa IN ($miejsca)
      ''', rodzajowa.gatunki);
    final znalezione = {
      for (final w in wiersze) w['nazwa']! as String: UprawaDoWyboru.zBazy(w),
    };
    return [
      for (final nazwa in rodzajowa.gatunki)
        if (znalezione[nazwa] case final UprawaDoWyboru uprawa) uprawa,
    ];
  }
}
