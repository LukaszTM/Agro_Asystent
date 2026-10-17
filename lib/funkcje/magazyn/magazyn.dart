import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/wspolne/daty.dart';
import '../../rdzen/wspolne/tekst.dart';

/// Co leży w magazynie: środek ochrony roślin albo nawóz.
enum RodzajPozycji {
  srodek('srodek', 'Środek ochrony roślin'),
  nawoz('nawoz', 'Nawóz');

  const RodzajPozycji(this.wBazie, this.dlaRolnika);

  final String wBazie;
  final String dlaRolnika;

  static RodzajPozycji zBazy(String wartosc) => RodzajPozycji.values.firstWhere(
    (r) => r.wBazie == wartosc,
    orElse: () => RodzajPozycji.srodek,
  );
}

/// Skąd się bierze zmiana stanu.
enum RodzajRuchu {
  zakup('zakup', 'Zakup', 1),
  zuzycie('zuzycie', 'Zużycie', -1),

  /// Poprawka po przeliczeniu w magazynie — rolnik widzi, ile było naprawdę.
  korekta('korekta', 'Poprawka stanu', 1);

  const RodzajRuchu(this.wBazie, this.dlaRolnika, this.znak);

  final String wBazie;
  final String dlaRolnika;

  /// `+1` dodaje do stanu, `-1` odejmuje.
  final int znak;

  static RodzajRuchu zBazy(String wartosc) => RodzajRuchu.values.firstWhere(
    (r) => r.wBazie == wartosc,
    orElse: () => RodzajRuchu.korekta,
  );
}

/// Pozycja magazynu — jeden środek albo nawóz.
class PozycjaMagazynu {
  const PozycjaMagazynu({
    required this.id,
    required this.gospodarstwoId,
    required this.rodzaj,
    required this.nazwa,
    required this.jednostka,
    this.nrZezwolenia,
    this.nawozId,
    this.terminDoStosowania,
  });

  factory PozycjaMagazynu.zBazy(Map<String, Object?> w) => PozycjaMagazynu(
    id: w['id']! as String,
    gospodarstwoId: w['gospodarstwo_id']! as String,
    rodzaj: RodzajPozycji.zBazy(w['rodzaj']! as String),
    nazwa: (w['nazwa'] as String?) ?? '',
    jednostka: (w['jednostka'] as String?) ?? '',
    nrZezwolenia: w['nr_zezwolenia'] as String?,
    nawozId: w['nawoz_id'] as String?,
    terminDoStosowania: w['termin_do_stosowania'] == null
        ? null
        : DateTime.tryParse(w['termin_do_stosowania']! as String),
  );

  final String id;
  final String gospodarstwoId;
  final RodzajPozycji rodzaj;
  final String nazwa;

  /// `l`, `kg`, `t` — jednostka, w której rolnik kupuje i zużywa.
  final String jednostka;

  /// Numer zezwolenia środka z rejestru MRiRW; `null` przy nawozach.
  final String? nrZezwolenia;

  /// Powiązanie z pozycją spisu nawozów, gdy to nawóz z ewidencji.
  final String? nawozId;

  /// Do kiedy wolno stosować środek wycofany z obrotu — ze słownika
  /// środków. `null` znaczy „słownik nic o tym nie mówi", nie „bez
  /// ograniczeń".
  final DateTime? terminDoStosowania;

  /// Identyfikator wyliczany z nazwy, nie losowy: ten sam środek wpisany
  /// na telefonie i na komputerze ma trafić w jeden wiersz, żeby po
  /// scaleniu nie było dwóch magazynów.
  static String identyfikator({
    required String gospodarstwoId,
    required RodzajPozycji rodzaj,
    required String nazwa,
  }) {
    final klucz = Tekst.znormalizuj(nazwa)
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'mag-$gospodarstwoId-${rodzaj.wBazie}-$klucz';
  }
}

/// Jeden ruch magazynowy: zakup, zużycie albo poprawka.
class RuchMagazynowy {
  const RuchMagazynowy({
    required this.id,
    required this.pozycjaId,
    required this.rodzaj,
    required this.ilosc,
    required this.data,
    this.zabiegId,
    this.cenaZaJednostke,
    this.uwagi,
  });

  factory RuchMagazynowy.zBazy(Map<String, Object?> w) => RuchMagazynowy(
    id: w['id']! as String,
    pozycjaId: w['pozycja_id']! as String,
    rodzaj: RodzajRuchu.zBazy(w['rodzaj']! as String),
    ilosc: (w['ilosc'] as num).toDouble(),
    data: DateTime.parse(w['data']! as String),
    zabiegId: w['zabieg_id'] as String?,
    cenaZaJednostke: (w['cena_za_jednostke'] as num?)?.toDouble(),
    uwagi: w['uwagi'] as String?,
  );

  final String id;
  final String pozycjaId;
  final RodzajRuchu rodzaj;

  /// Ilość zawsze dodatnia — znak bierze się z rodzaju ruchu.
  final double ilosc;

  final DateTime data;

  /// Zabieg, przy którym towar zszedł z magazynu. `null` przy zakupie
  /// i przy ręcznej poprawce.
  final String? zabiegId;

  final double? cenaZaJednostke;
  final String? uwagi;

  double get zmianaStanu => ilosc * rodzaj.znak;

  double? get wartosc =>
      cenaZaJednostke == null ? null : cenaZaJednostke! * ilosc;

  /// Identyfikator zużycia wyliczany z zabiegu i pozycji: poprawka wpisu
  /// nie odpisze towaru drugi raz, a dwa urządzenia nie zrobią z jednego
  /// oprysku dwóch zużyć.
  static String identyfikatorZuzycia({
    required String zabiegId,
    required String pozycjaId,
  }) => 'ruch-$zabiegId-$pozycjaId';
}

/// Stan jednej pozycji na dany dzień — liczony z ruchów, nie trzymany
/// jako osobna liczba do nadpisywania.
class StanPozycji {
  const StanPozycji({
    required this.pozycja,
    required this.ilosc,
    required this.ruchy,
    required this.naDzien,
  });

  final PozycjaMagazynu pozycja;

  /// Ile zostało. Może być ujemne — wtedy wpisów zużycia jest więcej niż
  /// zakupów i aplikacja mówi o tym wprost, zamiast zaokrąglać do zera.
  final double ilosc;

  final List<RuchMagazynowy> ruchy;
  final DateTime naDzien;

  double get zakupy => _suma(RodzajRuchu.zakup);

  double get zuzycie => _suma(RodzajRuchu.zuzycie);

  DateTime? get ostatniZakup => ruchy
      .where((r) => r.rodzaj == RodzajRuchu.zakup)
      .map((r) => r.data)
      .fold<DateTime?>(
        null,
        (naj, data) => naj == null || data.isAfter(naj) ? data : naj,
      );

  /// Łączna wartość zakupów — tylko z ruchów, przy których rolnik podał
  /// cenę. Czego nie podał, tego nie zgadujemy.
  double? get wartoscZakupow {
    final zCena = ruchy.where(
      (r) => r.rodzaj == RodzajRuchu.zakup && r.cenaZaJednostke != null,
    );
    if (zCena.isEmpty) {
      return null;
    }
    return zCena.fold<double>(0, (suma, r) => suma + (r.wartosc ?? 0));
  }

  bool get maStan => ilosc > 1e-9;

  bool get stanUjemny => ilosc < -1e-9;

  /// Czy środek nie wolno już stosować, a w magazynie coś zostało.
  bool get terminMinal {
    final termin = pozycja.terminDoStosowania;
    return termin != null && naDzien.isAfter(termin);
  }

  String get iloscOpis =>
      '${ilosc.toStringAsFixed(2).replaceAll('.', ',')} '
      '${pozycja.jednostka}';

  double _suma(RodzajRuchu rodzaj) => ruchy
      .where((r) => r.rodzaj == rodzaj)
      .fold<double>(0, (suma, r) => suma + r.ilosc);
}

/// Propozycja pozycji do magazynu — z tego, co rolnik już wpisywał.
class PropozycjaPozycji {
  const PropozycjaPozycji({
    required this.nazwa,
    required this.jednostka,
    this.nrZezwolenia,
  });

  final String nazwa;
  final String jednostka;
  final String? nrZezwolenia;
}

/// Ostrzeżenie o stanie magazynu — jedno zdanie i co z tym zrobić.
///
/// Treść stoi w warstwie `funkcje/`, żeby oba wyglądy mówiły to samo.
class OstrzezenieMagazynu {
  const OstrzezenieMagazynu({required this.tresc, required this.coZrobic});

  final String tresc;
  final String coZrobic;
}

/// Magazyn: zakupy, zużycie i stan na dziś.
///
/// Zużycie przy zabiegu dopisuje aplikacja z dawki i powierzchni, ale
/// **nie zgaduje** ilości, której nie umie policzyć: gdy dawka jest
/// niepewna albo jednostki się nie zgadzają, ruchu nie ma, a rolnik
/// wpisuje go sam.
class Magazyn {
  const Magazyn(this._baza);

  final DatabaseExecutor _baza;

  Future<List<PozycjaMagazynu>> pozycje(String gospodarstwoId) async {
    final wiersze = await _baza.query(
      'magazyn_pozycja',
      where: 'gospodarstwo_id = ? AND usuniety = 0',
      whereArgs: [gospodarstwoId],
      orderBy: 'rodzaj, nazwa',
    );
    return wiersze.map(PozycjaMagazynu.zBazy).toList(growable: false);
  }

  Future<List<RuchMagazynowy>> ruchy(
    String pozycjaId, {
    DateTime? doDnia,
  }) async {
    final wiersze = await _baza.query(
      'magazyn_ruch',
      where: [
        'pozycja_id = ?',
        'usuniety = 0',
        if (doDnia != null) 'data <= ?',
      ].join(' AND '),
      whereArgs: [
        pozycjaId,
        if (doDnia != null) doDnia.toIso8601String().split('T').first,
      ],
      orderBy: 'data DESC, utworzono DESC',
    );
    return wiersze.map(RuchMagazynowy.zBazy).toList(growable: false);
  }

  /// Pozycja magazynu o tej nazwie albo `null`, gdy rolnik jej nie
  /// prowadzi. Aplikacja nie zakłada pozycji sama przy zabiegu: magazyn
  /// ma pokazywać to, co rolnik do niego wpisał.
  Future<PozycjaMagazynu?> pozycjaONazwie({
    required String gospodarstwoId,
    required RodzajPozycji rodzaj,
    required String nazwa,
  }) async {
    final wiersze = await _baza.query(
      'magazyn_pozycja',
      where: 'id = ? AND usuniety = 0',
      whereArgs: [
        PozycjaMagazynu.identyfikator(
          gospodarstwoId: gospodarstwoId,
          rodzaj: rodzaj,
          nazwa: nazwa,
        ),
      ],
      limit: 1,
    );
    return wiersze.isEmpty ? null : PozycjaMagazynu.zBazy(wiersze.single);
  }

  /// Środki, które rolnik już wpisywał w zabiegach — propozycje pozycji
  /// do magazynu. Nie zakładamy ich same; rolnik wybiera z listy.
  Future<List<PropozycjaPozycji>> srodkiZZabiegow(String gospodarstwoId) async {
    final wiersze = await _baza.rawQuery(
      '''
      SELECT o.srodek_nazwa AS nazwa, o.nr_zezwolenia AS nr_zezwolenia,
             MAX(z.data) AS ostatni, o.dawka_jednostka AS jednostka
      FROM zabieg_oprysk o
      JOIN zabieg z ON z.id = o.zabieg_id
      WHERE z.gospodarstwo_id = ? AND z.usuniety = 0
      GROUP BY o.srodek_nazwa, o.nr_zezwolenia
      ORDER BY ostatni DESC
      ''',
      [gospodarstwoId],
    );
    return [
      for (final w in wiersze)
        PropozycjaPozycji(
          nazwa: (w['nazwa'] as String?) ?? '',
          nrZezwolenia: w['nr_zezwolenia'] as String?,
          jednostka: (w['jednostka'] as String?) ?? 'l',
        ),
    ].where((p) => p.nazwa.isNotEmpty).toList(growable: false);
  }

  /// Stan wszystkich pozycji gospodarstwa na dany dzień.
  Future<List<StanPozycji>> stan({
    required String gospodarstwoId,
    DateTime? naDzien,
  }) async {
    final dzien = naDzien ?? DateTime.now();
    final stany = <StanPozycji>[];
    for (final pozycja in await pozycje(gospodarstwoId)) {
      final lista = await ruchy(pozycja.id, doDnia: dzien);
      stany.add(
        StanPozycji(
          pozycja: pozycja,
          ilosc: lista.fold<double>(0, (suma, r) => suma + r.zmianaStanu),
          ruchy: lista,
          naDzien: dzien,
        ),
      );
    }
    return stany;
  }

  Future<StanPozycji?> stanPozycji({
    required String pozycjaId,
    DateTime? naDzien,
  }) async {
    final wiersze = await _baza.query(
      'magazyn_pozycja',
      where: 'id = ? AND usuniety = 0',
      whereArgs: [pozycjaId],
      limit: 1,
    );
    if (wiersze.isEmpty) {
      return null;
    }
    final dzien = naDzien ?? DateTime.now();
    final lista = await ruchy(pozycjaId, doDnia: dzien);
    return StanPozycji(
      pozycja: PozycjaMagazynu.zBazy(wiersze.single),
      ilosc: lista.fold<double>(0, (suma, r) => suma + r.zmianaStanu),
      ruchy: lista,
      naDzien: dzien,
    );
  }

  /// Dopisanie albo odświeżenie pozycji. Zwraca jej identyfikator.
  Future<String> zapiszPozycje({
    required String gospodarstwoId,
    required RodzajPozycji rodzaj,
    required String nazwa,
    required String jednostka,
    required String urzadzenie,
    String? nrZezwolenia,
    String? nawozId,
    DateTime? terminDoStosowania,
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    final id = PozycjaMagazynu.identyfikator(
      gospodarstwoId: gospodarstwoId,
      rodzaj: rodzaj,
      nazwa: nazwa,
    );
    final dane = {
      'nazwa': nazwa,
      'jednostka': jednostka,
      'nr_zezwolenia': nrZezwolenia,
      'nawoz_id': nawozId,
      'termin_do_stosowania': terminDoStosowania
          ?.toIso8601String()
          .split('T')
          .first,
      'zmieniono': czas,
      'urzadzenie': urzadzenie,
      'usuniety': 0,
    };
    final istnieje = await _baza.query(
      'magazyn_pozycja',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (istnieje.isEmpty) {
      await _baza.insert('magazyn_pozycja', {
        'id': id,
        'gospodarstwo_id': gospodarstwoId,
        'rodzaj': rodzaj.wBazie,
        'utworzono': czas,
        ...dane,
      });
      return id;
    }
    await _baza.update(
      'magazyn_pozycja',
      dane,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  /// Zakup: ile przyszło i za ile (cena jest nieobowiązkowa).
  Future<String> zapiszZakup({
    required String pozycjaId,
    required double ilosc,
    required DateTime kiedy,
    required String urzadzenie,
    double? cenaZaJednostke,
    String? uwagi,
    DateTime? teraz,
  }) => _zapiszRuch(
    id: 'ruch-${(teraz ?? DateTime.now()).microsecondsSinceEpoch}-$pozycjaId',
    pozycjaId: pozycjaId,
    rodzaj: RodzajRuchu.zakup,
    ilosc: ilosc,
    kiedy: kiedy,
    urzadzenie: urzadzenie,
    cenaZaJednostke: cenaZaJednostke,
    uwagi: uwagi,
    teraz: teraz,
  );

  /// Poprawka stanu po przeliczeniu w magazynie — różnica wobec tego, co
  /// liczy aplikacja. Dodatnia dokłada, ujemna odejmuje.
  Future<String> zapiszPoprawke({
    required String pozycjaId,
    required double roznica,
    required DateTime kiedy,
    required String urzadzenie,
    String? uwagi,
    DateTime? teraz,
  }) => _zapiszRuch(
    id: 'ruch-${(teraz ?? DateTime.now()).microsecondsSinceEpoch}-$pozycjaId',
    pozycjaId: pozycjaId,
    rodzaj: roznica >= 0 ? RodzajRuchu.korekta : RodzajRuchu.zuzycie,
    ilosc: roznica.abs(),
    kiedy: kiedy,
    urzadzenie: urzadzenie,
    uwagi: uwagi,
    teraz: teraz,
  );

  /// Zużycie przy zabiegu. Wywoływane **po** zapisie zabiegu, z ilością
  /// policzoną z dawki i powierzchni; `null` ilości znaczy „nie umiemy
  /// policzyć" i wtedy nic nie zapisujemy.
  Future<String?> odpiszPoZabiegu({
    required String zabiegId,
    required String pozycjaId,
    required double? ilosc,
    required DateTime kiedy,
    required String urzadzenie,
    DateTime? teraz,
  }) async {
    if (ilosc == null || ilosc <= 0) {
      return null;
    }
    return _zapiszRuch(
      id: RuchMagazynowy.identyfikatorZuzycia(
        zabiegId: zabiegId,
        pozycjaId: pozycjaId,
      ),
      pozycjaId: pozycjaId,
      rodzaj: RodzajRuchu.zuzycie,
      ilosc: ilosc,
      kiedy: kiedy,
      urzadzenie: urzadzenie,
      zabiegId: zabiegId,
      teraz: teraz,
    );
  }

  /// Zapis ruchu. Ten sam identyfikator (zużycie przy zabiegu) nadpisuje
  /// poprzedni wiersz, a wyzwalacz bazy zostawia poprzednią treść
  /// w dzienniku zmian.
  Future<String> _zapiszRuch({
    required String id,
    required String pozycjaId,
    required RodzajRuchu rodzaj,
    required double ilosc,
    required DateTime kiedy,
    required String urzadzenie,
    String? zabiegId,
    double? cenaZaJednostke,
    String? uwagi,
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    final dane = {
      'rodzaj': rodzaj.wBazie,
      'ilosc': ilosc,
      'data': kiedy.toIso8601String().split('T').first,
      'zabieg_id': zabiegId,
      'cena_za_jednostke': cenaZaJednostke,
      'uwagi': uwagi,
      'zmieniono': czas,
      'urzadzenie': urzadzenie,
      'usuniety': 0,
    };
    final istnieje = await _baza.query(
      'magazyn_ruch',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (istnieje.isEmpty) {
      await _baza.insert('magazyn_ruch', {
        'id': id,
        'pozycja_id': pozycjaId,
        'utworzono': czas,
        ...dane,
      });
      return id;
    }
    await _baza.update('magazyn_ruch', dane, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  /// Odpisanie towaru po zapisie zabiegu — gdy rolnik prowadzi taką
  /// pozycję w magazynie.
  ///
  /// Zwraca `null`, gdy pozycji nie ma albo ilości nie da się policzyć.
  /// Magazyn nie zakłada pozycji sam i nie zgaduje ilości: ewidencja
  /// zabiegu jest ważniejsza i zostaje nietknięta.
  Future<String?> odpiszZabieg({
    required String gospodarstwoId,
    required String zabiegId,
    required RodzajPozycji rodzaj,
    required String nazwa,
    required double? ilosc,
    required DateTime kiedy,
    required String urzadzenie,
    DateTime? teraz,
  }) async {
    if (ilosc == null || ilosc <= 0) {
      return null;
    }
    final pozycja = await pozycjaONazwie(
      gospodarstwoId: gospodarstwoId,
      rodzaj: rodzaj,
      nazwa: nazwa,
    );
    if (pozycja == null) {
      return null;
    }
    return odpiszPoZabiegu(
      zabiegId: zabiegId,
      pozycjaId: pozycja.id,
      ilosc: ilosc,
      kiedy: kiedy,
      urzadzenie: urzadzenie,
      teraz: teraz,
    );
  }

  /// Cofnięcie ruchu — wiersz zostaje w bazie ze śladem w dzienniku zmian.
  Future<void> usunRuch({
    required String ruchId,
    required String urzadzenie,
    DateTime? teraz,
  }) => _baza.update(
    'magazyn_ruch',
    {
      'usuniety': 1,
      'zmieniono': (teraz ?? DateTime.now()).toIso8601String(),
      'urzadzenie': urzadzenie,
    },
    where: 'id = ?',
    whereArgs: [ruchId],
  );

  /// Ostrzeżenia dla pozycji: wycofany środek i stan ujemny.
  List<OstrzezenieMagazynu> ostrzezenia(StanPozycji stanPozycji) => [
    if (stanPozycji.terminMinal && stanPozycji.maStan)
      OstrzezenieMagazynu(
        tresc:
            '${stanPozycji.pozycja.nazwa} wolno było stosować do '
            '${Daty.krotko(stanPozycji.pozycja.terminDoStosowania!)}, '
            'a w magazynie zostało ${stanPozycji.iloscOpis}.',
        coZrobic:
            'Nie stosuj go już na polu. Zapytaj sprzedawcę albo gminę, jak '
            'oddać środek do unieszkodliwienia.',
      ),
    if (stanPozycji.stanUjemny)
      OstrzezenieMagazynu(
        tresc:
            'Zużycie ${stanPozycji.pozycja.nazwa} przewyższa zakupy o '
            '${stanPozycji.ilosc.abs().toStringAsFixed(2).replaceAll('.', ',')} '
            '${stanPozycji.pozycja.jednostka}.',
        coZrobic:
            'Dopisz brakujący zakup albo popraw stan — ewidencja zabiegów '
            'zostaje bez zmian, magazyn jej nie zmienia.',
      ),
  ];
}
