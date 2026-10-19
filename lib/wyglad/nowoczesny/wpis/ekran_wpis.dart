import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/nawozenie/nawoz.dart';
import '../../../funkcje/nawozenie/plan_nawozenia.dart';
import '../../../funkcje/odczyt/czytnik_zdjecia.dart';
import '../../../funkcje/odczyt/odczyt_etykiety.dart';
import '../../../funkcje/magazyn/zuzycie_z_zabiegu.dart';
import '../../../funkcje/warunkowosc/okres_legowy.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../../../funkcje/zabiegi/slownik_srodkow.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../../../rdzen/wspolne/wybor_przyorania.dart';
import '../../../rdzen/dostep/funkcja.dart';
import '../../../rdzen/reguly/regula_prawna.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';

/// Wpis zabiegu na jednym ekranie (plan, pkt 5 — wygląd nowoczesny).
///
/// Rodzaj, kilka pól naraz, środek (szukaj albo zdjęcie), dawka i powód —
/// wszystko w jednym przewijanym ekranie, bez przechodzenia krok po kroku.
/// Dane, które aplikacja zna sama (data, godzina, powierzchnia, dawka
/// z rejestru), są wypełnione od początku.
class EkranWpisu extends StatefulWidget {
  const EkranWpisu({
    super.key,
    required this.uslugi,
    this.poleNaStart,
    this.teraz,
  });

  final Uslugi uslugi;

  /// Pole wybrane z karty pola — wtedy wpis startuje z gotowym wyborem.
  final Pole? poleNaStart;

  /// Chwila zabiegu; w aplikacji „teraz".
  final DateTime? teraz;

  @override
  State<EkranWpisu> createState() => _EkranWpisuState();
}

class _EkranWpisuState extends State<EkranWpisu> {
  late DaneWpisu _dane;
  late Future<List<Pole>> _pola;

  Future<List<DopuszczonySrodek>>? _srodki;
  Future<List<Nawoz>>? _nawozy;

  /// Jednostki, którymi posługuje się rejestr — do wyboru tam, gdzie
  /// dawkę trzeba przepisać z etykiety.
  Future<List<JednostkaDawkiSrodka>>? _jednostkiDawki;

  /// Azot już zapisany na wybranych polach i limity z tabeli 14 programu
  /// azotanowego. Przeliczamy po zmianie pól, nie po zmianie dawki.
  Future<List<SkutekDlaMaksymalnejDawki>>? _stanPol;

  String _szukane = '';
  bool _czytaEtykiete = false;
  OdczytEtykiety? _odczyt;
  String? _bladOdczytu;
  bool _zapisuje = false;

  /// Zapisany zabieg — ekran przechodzi wtedy w potwierdzenie z karencją.
  Zabieg? _zapisany;

  /// Co rolnik robi przy pracy „inny" — stąd ostrzeżenie o okresie
  /// lęgowym ptaków (GAEC 8).
  PracaKrajobrazowa? _praca;

  @override
  void initState() {
    super.initState();
    _dane = DaneWpisu(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      urzadzenie: widget.uslugi.urzadzenie,
      kiedy: widget.teraz,
    );
    if (widget.poleNaStart != null) {
      _dane.pola.add(widget.poleNaStart!);
    }
    _pola = widget.uslugi.pola.wszystkie(widget.uslugi.gospodarstwoId);
    _odswiezStanPol();
  }

  void _odswiezStanPol() {
    _stanPol = _dane.pola.isEmpty
        ? null
        : widget.uslugi.planNawozenia.skutkiDlaMaksymalnejDawki(
            pola: List.of(_dane.pola),
            azotWpisuKgNaHa: 0,
            kiedy: _dane.kiedy,
          );
  }

  String get _uprawa => _dane.pola.firstOrNull?.uprawa ?? '';

  bool get _rozneUprawy => _dane.pola.map((p) => p.uprawa).toSet().length > 1;

  void _ustawRodzaj(RodzajZabiegu rodzaj) {
    setState(() {
      _dane
        ..rodzaj = rodzaj
        ..srodek = null
        ..nawoz = null
        ..dawka = null
        ..przyczyna = null;
      _odczyt = null;
      _bladOdczytu = null;
      _szukane = '';
      _praca = null;
      _odswiezSrodki();
    });
  }

  static const List<(RodzajZabiegu, IconData)> _pozostaleRodzaje = [
    (RodzajZabiegu.siew, Icons.scatter_plot_outlined),
    (RodzajZabiegu.zbior, Icons.agriculture_outlined),
    (RodzajZabiegu.uprawaGleby, Icons.landscape_outlined),
    (RodzajZabiegu.inny, Icons.handyman_outlined),
  ];

  OkresLegowy get _okresLegowy => widget.uslugi.okresLegowy;

  bool get _pytacOPrace =>
      _dane.rodzaj == RodzajZabiegu.inny && !_okresLegowy.prace.pusta;

  /// Zapis jest gotowy, gdy dane wpisu są pełne, a przy pracy „inny" —
  /// gdy rolnik powiedział, co robi (od tego zależy ostrzeżenie GAEC 8).
  bool get _gotowyDoZapisu =>
      _dane.gotowyDoZapisu && (!_pytacOPrace || _praca != null);

  bool get _wielePolNaraz =>
      widget.uslugi.dostep.czyDostepna(Funkcja.zabiegNaWieluPolach);

  void _przelaczPole(Pole pole) {
    setState(() {
      final juzJest = _dane.pola.indexWhere((p) => p.id == pole.id);
      if (juzJest >= 0) {
        _dane.pola.removeAt(juzJest);
      } else {
        // Zabieg na kilku polach naraz to dodatek płatny (plan, pkt 8).
        // Bez niego wybór pola zamienia poprzedni — ewidencja wyjdzie taka
        // sama, tylko wpisów będzie tyle, ile pól.
        if (!_wielePolNaraz) {
          _dane.pola.clear();
        }
        _dane.pola.add(pole);
      }
      // Lista środków zależy od uprawy pierwszego pola, więc po zmianie pól
      // trzeba ją przeliczyć — inaczej pokazywałaby środki do innej uprawy.
      _dane
        ..srodek = null
        ..dawka = null;
      _odswiezSrodki();
      _odswiezStanPol();
    });
  }

  void _odswiezSrodki() {
    if (_dane.rodzaj == RodzajZabiegu.oprysk && _uprawa.isNotEmpty) {
      _srodki = _szukane.isEmpty
          ? widget.uslugi.srodki.dlaUprawy(_uprawa)
          : widget.uslugi.srodki.szukaj(_uprawa, _szukane);
      return;
    }
    if (_dane.rodzaj == RodzajZabiegu.nawozenie) {
      _nawozy = widget.uslugi.nawozy.wszystkie(widget.uslugi.gospodarstwoId);
    }
  }

  /// Rozpoznanie etykiety ze zdjęcia zawęża listę do tego, co widać na
  /// opakowaniu. Wybór należy do rolnika — niczego nie zapisujemy za niego.
  Future<void> _rozpoznajEtykiete() async {
    if (_czytaEtykiete) {
      return;
    }
    setState(() {
      _czytaEtykiete = true;
      _bladOdczytu = null;
      _odczyt = null;
    });
    try {
      final tekst = await widget.uslugi.czytnikZdjecia.tekst(
        ZrodloZdjecia.aparat,
      );
      if (tekst == null || !mounted) {
        return;
      }
      final odczyt = await widget.uslugi.czytnikEtykiety.rozpoznaj(
        tekst,
        uprawa: _uprawa,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _odczyt = odczyt;
        if (odczyt.dopasowania.isNotEmpty) {
          _srodki = Future<List<DopuszczonySrodek>>.value(odczyt.dopasowania);
        }
      });
    } on BladOdczytuZdjecia catch (blad) {
      if (mounted) {
        setState(
          () => _bladOdczytu = [
            blad.wiadomosc,
            if (blad.coZrobic != null) blad.coZrobic!,
          ].join(' '),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _czytaEtykiete = false);
      }
    }
  }

  void _wybierzSrodek(DopuszczonySrodek srodek) {
    setState(() {
      _dane
        ..srodek = srodek
        // Dawkę podpowiadamy tylko wtedy, gdy rejestr podaje ją
        // jednoznacznie. Inaczej pole zostaje puste i rolnik przepisuje
        // ją z etykiety (CLAUDE.md, reguła 5).
        ..dawka = srodek.dawkaZnana ? srodek.dawka : null
        ..jednostkaZEtykiety = null
        ..przyczyna = srodek.agrofag;
      // Jednostki czytamy z rejestru dopiero wtedy, gdy są potrzebne.
      if (!srodek.dawkaZnana) {
        _jednostkiDawki ??= widget.uslugi.srodki.jednostkiDawki();
      }
    });
  }

  void _wybierzNawoz(Nawoz nawoz) {
    setState(() {
      _dane
        ..nawoz = nawoz
        ..dawka ??= _domyslnaDawkaNawozu;
    });
  }

  double get _domyslnaDawkaNawozu =>
      _dane.jednostkaDawki == JednostkaDawki.kilogramyNaHektar ? 100 : 20;

  double get _krokNawozu =>
      _dane.jednostkaDawki == JednostkaDawki.kilogramyNaHektar ? 10 : 1;

  Future<void> _zapisz() async {
    if (_zapisuje || !_gotowyDoZapisu) {
      return;
    }
    setState(() => _zapisuje = true);
    try {
      final zabieg = switch (_dane.rodzaj) {
        RodzajZabiegu.oprysk => await _zapiszOprysk(),
        RodzajZabiegu.nawozenie => await _zapiszNawozenie(),
        _ => await _zapiszProsty(),
      };
      // Magazyn (premium) odpisuje zużycie sam; ewidencja zapisuje się
      // tak samo w wersji darmowej.
      await ZuzycieZZabiegu.odpisz(
        magazyn: widget.uslugi.magazyn,
        dostep: widget.uslugi.dostep,
        dane: _dane,
        zabiegId: zabieg.id,
        urzadzenie: _dane.urzadzenie,
      );
      if (mounted) {
        setState(() => _zapisany = zabieg);
      }
    } finally {
      if (mounted) {
        setState(() => _zapisuje = false);
      }
    }
  }

  Future<Zabieg> _zapiszOprysk() async {
    final srodek = _dane.srodek!;
    final id = 'z-${_dane.kiedy.microsecondsSinceEpoch}-${_dane.pola.first.id}';
    final zabieg = Zabieg(
      id: id,
      gospodarstwoId: _dane.gospodarstwoId,
      rodzaj: RodzajZabiegu.oprysk,
      data: _dane.kiedy,
      godzina:
          '${_dane.kiedy.hour.toString().padLeft(2, '0')}:'
          '${_dane.kiedy.minute.toString().padLeft(2, '0')}',
      powierzchniaAr: _dane.powierzchniaAr,
      urzadzenie: _dane.urzadzenie,
    );

    await widget.uslugi.zabiegi.zapisz(
      zabieg: zabieg,
      pola: _poleZabiegu(),
      oprysk: SzczegolyOprysku(
        zabiegId: id,
        srodekNazwa: srodek.nazwa,
        nrZezwolenia: srodek.nrZezwolenia,
        dawka: _dane.dawka,
        // Przy środku bez dawki w rejestrze jednostkę wskazał rolnik.
        dawkaJednostka: _dane.dawkaJednostka,
        dawkaOdniesienie: _dane.dawkaOdniesienie,
        przyczyna: _dane.przyczyna,
        agrofag: srodek.agrofag,
        bbchOd: srodek.bbchOd,
        bbchDo: srodek.bbchDo,
        kodEppo: _dane.pola.first.kodEppo,
        // Rodzaj zastosowania wynika z wyboru rolnika („Oprysk"), nie
        // z domysłu — ewidencja wymaga tego pola.
        rodzajZastosowania: 'opryskiwanie',
        karencjaDni: srodek.karencjaZnana ? srodek.karencjaDni : null,
        karencjaZrodlo: srodek.karencjaZnana ? 'etykieta MRiRW' : null,
        karencjaDataEtykiety: srodek.karencjaDataEtykiety,
      ),
      teraz: _dane.kiedy,
    );
    return zabieg;
  }

  Future<Zabieg> _zapiszNawozenie() async {
    final id = await widget.uslugi.nawozenie.zapisz(
      gospodarstwoId: _dane.gospodarstwoId,
      nawoz: _dane.nawoz!,
      pola: _poleZabiegu(),
      dawka: _dane.dawka ?? _domyslnaDawkaNawozu,
      jednostka: _dane.jednostkaDawki,
      urzadzenie: _dane.urzadzenie,
      kiedy: _dane.kiedy,
      dataPrzyorania: _dane.nawoz!.naturalny ? _dane.dataPrzyorania : null,
    );
    return Zabieg(
      id: id,
      gospodarstwoId: _dane.gospodarstwoId,
      rodzaj: RodzajZabiegu.nawozenie,
      data: _dane.kiedy,
      powierzchniaAr: _dane.powierzchniaAr,
      urzadzenie: _dane.urzadzenie,
    );
  }

  /// Siew, zbiór, uprawa gleby i inne prace — bez środka i bez dawki.
  Future<Zabieg> _zapiszProsty() async {
    final id =
        'z-${_dane.kiedy.microsecondsSinceEpoch}-'
        '${_dane.pola.first.id}';
    final zabieg = Zabieg(
      id: id,
      gospodarstwoId: _dane.gospodarstwoId,
      rodzaj: _dane.rodzaj ?? RodzajZabiegu.inny,
      data: _dane.kiedy,
      godzina:
          '${_dane.kiedy.hour.toString().padLeft(2, '0')}:'
          '${_dane.kiedy.minute.toString().padLeft(2, '0')}',
      powierzchniaAr: _dane.powierzchniaAr,
      uwagi: _praca?.nazwa,
      podrodzaj: _praca?.id,
      urzadzenie: _dane.urzadzenie,
    );
    await widget.uslugi.zabiegi.zapisz(
      zabieg: zabieg,
      pola: _poleZabiegu(),
      teraz: _dane.kiedy,
    );
    return zabieg;
  }

  List<PoleZabiegu> _poleZabiegu() => [
    for (final pole in _dane.pola)
      PoleZabiegu(dzialkaRolnaId: pole.id, powierzchniaAr: pole.powierzchniaAr),
  ];

  @override
  Widget build(BuildContext context) {
    if (_zapisany != null) {
      return _Potwierdzenie(dane: _dane, zabieg: _zapisany!);
    }

    final teksty = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nowy zabieg')),
      body: ListView(
        padding: const EdgeInsets.all(MotywNowoczesny.odstep),
        children: [
          Text('Co robisz?', style: teksty.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Wybor(
                etykieta: RodzajZabiegu.oprysk.dlaRolnika,
                ikona: Icons.water_drop_outlined,
                wybrany: _dane.rodzaj == RodzajZabiegu.oprysk,
                onTap: () => _ustawRodzaj(RodzajZabiegu.oprysk),
              ),
              Wybor(
                etykieta: RodzajZabiegu.nawozenie.dlaRolnika,
                ikona: Icons.grass_outlined,
                wybrany: _dane.rodzaj == RodzajZabiegu.nawozenie,
                onTap: () => _ustawRodzaj(RodzajZabiegu.nawozenie),
              ),
              // Rejestr zabiegów agrotechnicznych to nie tylko oprysk
              // i nawożenie; dzień zbioru potrzebuje też norma GAEC 6.
              for (final (rodzaj, ikona) in _pozostaleRodzaje)
                Wybor(
                  etykieta: rodzaj.dlaRolnika,
                  ikona: ikona,
                  wybrany: _dane.rodzaj == rodzaj,
                  onTap: () => _ustawRodzaj(rodzaj),
                ),
            ],
          ),
          const SizedBox(height: MotywNowoczesny.odstep),
          Text('Na których polach?', style: teksty.titleLarge),
          const SizedBox(height: 8),
          FutureBuilder<List<Pole>>(
            future: _pola,
            builder: (context, stan) {
              if (!stan.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final pola = stan.data!;
              if (pola.isEmpty) {
                return const OstrzezenieNowoczesne(
                  tresc: 'Nie masz jeszcze żadnego pola.',
                  coZrobic: 'Dodaj pole w zakładce „Pola" i wróć tutaj.',
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final pole in pola)
                    Wybor(
                      etykieta: '${pole.nazwa} • ${pole.powierzchniaOpis}',
                      wybrany: _dane.pola.any((p) => p.id == pole.id),
                      onTap: () => _przelaczPole(pole),
                    ),
                ],
              );
            },
          ),
          if (_dane.pola.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Razem ${_dane.powierzchniaOpis}'
              '${_uprawa.isEmpty ? '' : ' • $_uprawa'}',
              style: teksty.bodyLarge,
            ),
          ],
          // Fakt o wersji darmowej, nie oferta: wpis dotyczy jednego pola.
          if (!_wielePolNaraz) ...[
            const SizedBox(height: 4),
            Text('Jeden wpis dotyczy jednego pola.', style: teksty.bodyMedium),
          ],
          if (_rozneUprawy) ...[
            const SizedBox(height: 8),
            OstrzezenieNowoczesne(
              tresc: 'Wybrane pola mają różne uprawy.',
              coZrobic:
                  'Lista środków jest dla uprawy „$_uprawa". Dla innej '
                  'uprawy zrób osobny wpis.',
            ),
          ],
          if (_dane.rodzaj == RodzajZabiegu.oprysk) ..._oprysk(context),
          if (_dane.rodzaj == RodzajZabiegu.nawozenie) ..._nawozenie(context),
          ..._praceKrajobrazowe(context),
          ..._pasOdWody(),
          const SizedBox(height: MotywNowoczesny.odstep),
          if (_zapisuje)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(
              onPressed: _gotowyDoZapisu ? _zapisz : null,
              child: const Text('Zapisz'),
            ),
          if (!_gotowyDoZapisu) ...[
            const SizedBox(height: 8),
            Text(
              _dane.rodzaj == null
                  ? 'Wybierz rodzaj zabiegu.'
                  : _dane.pola.isEmpty
                  ? 'Wybierz co najmniej jedno pole.'
                  : _dane.rodzaj == RodzajZabiegu.oprysk
                  ? 'Wybierz środek z listy.'
                  : _dane.rodzaj == RodzajZabiegu.nawozenie
                  ? 'Wybierz nawóz z listy.'
                  : 'Wybierz z listy, co robisz.',
              style: teksty.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  /// Wybór pracy przy „innym" zabiegu i ostrzeżenie z normy GAEC 8.
  ///
  /// Rolnik mówi, co robi — aplikacja nie odgaduje tego z uwag.
  List<Widget> _praceKrajobrazowe(BuildContext context) {
    if (!_pytacOPrace) {
      return const [];
    }
    final teksty = Theme.of(context).textTheme;
    final ostrzezenie = _okresLegowy.ostrzezeniePrzedZapisem(
      idPracy: _praca?.id,
      kiedy: _dane.kiedy,
    );
    return [
      const SizedBox(height: MotywNowoczesny.odstep),
      Text('Co robisz dokładnie?', style: teksty.titleLarge),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final praca in _okresLegowy.prace.prace)
            Wybor(
              etykieta: praca.nazwa,
              wybrany: praca.id == _praca?.id,
              onTap: () => setState(() => _praca = praca),
            ),
        ],
      ),
      if (_praca != null) ...[
        const SizedBox(height: 4),
        Text(_praca!.opis, style: teksty.bodyMedium),
      ],
      if (ostrzezenie != null) ...[
        const SizedBox(height: 8),
        OstrzezenieNowoczesne(
          tresc: ostrzezenie.tresc,
          coZrobic: ostrzezenie.coZrobic,
        ),
      ],
    ];
  }

  /// Ostrzeżenie z normy GAEC 4 — pas od brzegu wody bez nawozów
  /// i środków ochrony roślin. Nie blokuje zapisu: zabieg mógł być
  /// wykonany poza pasem, a dokumentacja ma być prawdziwa.
  List<Widget> _pasOdWody() {
    final ostrzezenie = widget.uslugi.pasOdWody.ostrzezeniePrzedZapisem(
      pola: _dane.pola,
      rodzaj: _dane.rodzaj,
    );
    if (ostrzezenie == null) {
      return const [];
    }
    return [
      const SizedBox(height: 8),
      OstrzezenieNowoczesne(
        tresc: ostrzezenie.tresc,
        coZrobic: ostrzezenie.coZrobic,
      ),
    ];
  }

  List<Widget> _oprysk(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final srodek = _dane.srodek;

    return [
      const SizedBox(height: MotywNowoczesny.odstep),
      Text('Czym opryskujesz?', style: teksty.titleLarge),
      const SizedBox(height: 8),
      if (_dane.pola.isEmpty)
        Text(
          'Najpierw wybierz pole — lista środków zależy od uprawy.',
          style: teksty.bodyMedium,
        )
      else ...[
        Row(
          children: [
            Expanded(
              child: TextField(
                style: teksty.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Szukaj po nazwie',
                  prefixIcon: Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (tekst) => setState(() {
                  _szukane = tekst.trim();
                  _odswiezSrodki();
                }),
              ),
            ),
            // Zdjęcie etykiety to dodatek płatny. Podczas wpisu zabiegu
            // nie wolno pokazywać oferty premium, więc bez dostępu nie ma
            // ani przycisku, ani żadnej wzmianki.
            if (widget.uslugi.dostep.czyDostepna(
              Funkcja.odczytZdjeciaEtykiety,
            )) ...[
              const SizedBox(width: 8),
              if (_czytaEtykiete)
                const SizedBox(
                  width: MotywNowoczesny.minCelDotyku,
                  height: MotywNowoczesny.minCelDotyku,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                IconButton.filled(
                  tooltip: 'Rozpoznaj etykietę ze zdjęcia',
                  icon: const Icon(Icons.photo_camera_outlined),
                  onPressed: _rozpoznajEtykiete,
                ),
            ],
          ],
        ),
        if (_bladOdczytu != null) ...[
          const SizedBox(height: 8),
          OstrzezenieNowoczesne(tresc: _bladOdczytu!),
        ],
        if (_odczyt != null && _odczyt!.dopasowania.isEmpty) ...[
          const SizedBox(height: 8),
          OstrzezenieNowoczesne(
            tresc: _odczyt!.cokolwiekZnaleziono
                ? 'Ze zdjęcia wyszło „${_odczyt!.nazwa ?? _odczyt!.nrZezwolenia}", '
                      'ale rejestr nie ma takiego środka dla tej uprawy.'
                : 'Ze zdjęcia nic nie dało się odczytać.',
            coZrobic:
                'Wybierz środek z listy albo zrób zdjęcie z bliska, '
                'w świetle.',
          ),
        ],
        const SizedBox(height: 8),
        FutureBuilder<List<DopuszczonySrodek>>(
          future: _srodki,
          builder: (context, stan) {
            if (!stan.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final srodki = stan.data!;
            if (srodki.isEmpty) {
              return OstrzezenieNowoczesne(
                tresc:
                    'Rejestr nie przewiduje tu żadnego środka dla uprawy '
                    '„$_uprawa".',
                coZrobic: _szukane.isEmpty
                    ? 'Sprawdź, czy uprawa pola jest wpisana poprawnie.'
                    : 'Spróbuj wpisać inną część nazwy.',
              );
            }
            // Pokazujemy tylko kilka pozycji: cały rejestr ma ich tysiące,
            // a wyszukiwarka jest wyżej.
            final widoczne = srodki.take(6).toList(growable: false);
            return Column(
              children: [
                for (final pozycja in widoczne) ...[
                  Karta(
                    onTap: () => _wybierzSrodek(pozycja),
                    wyrozniona:
                        pozycja.zastosowanieId == srodek?.zastosowanieId,
                    child: _PozycjaListy(
                      nazwa: pozycja.nazwa,
                      opis: [
                        if (pozycja.agrofag != null) pozycja.agrofag!,
                        pozycja.dawkaOpis,
                      ].join(' • '),
                      wybrana: pozycja.zastosowanieId == srodek?.zastosowanieId,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (srodki.length > widoczne.length)
                  Text(
                    'Dopuszczonych środków: ${srodki.length}. '
                    'Wpisz nazwę, żeby zawęzić listę.',
                    style: teksty.bodyMedium,
                  ),
              ],
            );
          },
        ),
      ],
      if (srodek != null) ...[
        const SizedBox(height: MotywNowoczesny.odstep),
        Text('Dawka', style: teksty.titleLarge),
        const SizedBox(height: 8),
        if (!srodek.dawkaZnana) ...[
          OstrzezenieNowoczesne(
            tresc: 'Rejestr nie podaje tu dawki w jednoznacznej postaci.',
            coZrobic:
                srodek.dawkaTekst ??
                'Odczytaj dawkę z etykiety i wpisz ją niżej.',
          ),
          const SizedBox(height: 8),
          _DawkaZEtykiety(
            dane: _dane,
            jednostki: _jednostkiDawki,
            onZmiana: () => setState(() {}),
          ),
        ] else ...[
          WyborLiczbyNowoczesny(
            wartosc: _dane.dawka ?? srodek.dawka ?? 0,
            jednostka: '${srodek.dawkaJednostka}/${srodek.dawkaOdniesienie}',
            krok: 0.05,
            maksimum: srodek.dawka,
            opisMaksimum: 'największa dopuszczalna: ${srodek.dawkaOpis}',
            onZmiana: (nowa) => setState(() => _dane.dawka = nowa),
          ),
          if (srodek.dawka != null &&
              (_dane.dawka ?? 0) > srodek.dawka! + 1e-9) ...[
            const SizedBox(height: 8),
            const OstrzezenieNowoczesne(
              tresc: 'Ta dawka przekracza dopuszczalną z rejestru.',
              coZrobic: 'Zmniejsz dawkę przyciskiem „−" albo sprawdź etykietę.',
            ),
          ],
          if (_dane.iloscSrodkaRazem case final double razem) ...[
            const SizedBox(height: 8),
            Text(
              'Na ${_dane.powierzchniaOpis} potrzeba '
              '${razem.toStringAsFixed(2).replaceAll('.', ',')} '
              '${srodek.dawkaJednostka}',
              style: teksty.bodyLarge,
            ),
          ],
        ],
        const SizedBox(height: MotywNowoczesny.odstep),
        Text('Powód zabiegu', style: teksty.titleLarge),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _dane.przyczyna,
          style: teksty.bodyLarge,
          decoration: const InputDecoration(
            labelText: 'Agrofag albo powód',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (tekst) =>
              _dane.przyczyna = tekst.trim().isEmpty ? null : tekst.trim(),
        ),
      ],
    ];
  }

  List<Widget> _nawozenie(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final nawoz = _dane.nawoz;

    return [
      const SizedBox(height: MotywNowoczesny.odstep),
      Text('Czym nawozisz?', style: teksty.titleLarge),
      const SizedBox(height: 8),
      FutureBuilder<List<Nawoz>>(
        future: _nawozy,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final nawozy = stan.data!;
          if (nawozy.isEmpty) {
            return const OstrzezenieNowoczesne(
              tresc: 'Nie masz jeszcze żadnego nawozu w spisie.',
              coZrobic:
                  'Dodaj nawóz w zakładce „Pola" → „Nawożenie", razem '
                  'z zawartością azotu z worka albo z analizy.',
            );
          }
          return Column(
            children: [
              for (final pozycja in nawozy) ...[
                Karta(
                  onTap: () => _wybierzNawoz(pozycja),
                  wyrozniona: pozycja.id == nawoz?.id,
                  child: _PozycjaListy(
                    nazwa: pozycja.nazwa,
                    opis: pozycja.skladOpis,
                    wybrana: pozycja.id == nawoz?.id,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
      if (nawoz != null) ...[
        const SizedBox(height: MotywNowoczesny.odstep),
        Text('Dawka', style: teksty.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final jednostka in JednostkaDawki.values)
              Wybor(
                etykieta: jednostka.opis,
                wybrany: _dane.jednostkaDawki == jednostka,
                onTap: () => setState(() {
                  _dane
                    ..jednostkaDawki = jednostka
                    ..dawka = null;
                  _dane.dawka = _domyslnaDawkaNawozu;
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        WyborLiczbyNowoczesny(
          wartosc: _dane.dawka ?? _domyslnaDawkaNawozu,
          jednostka: _dane.jednostkaDawki.opis,
          krok: _krokNawozu,
          onZmiana: (nowa) => setState(() => _dane.dawka = nowa),
        ),
        const SizedBox(height: 8),
        if (_dane.azotKgNaHa case final double azot) ...[
          Text(
            'To ${azot.toStringAsFixed(1).replaceAll('.', ',')} kg azotu '
            'na hektar.',
            style: teksty.bodyLarge,
          ),
          if (_stanPol case final Future<List<SkutekDlaMaksymalnejDawki>> stan)
            _MaksymalnaDawka(stanPol: stan, azotWpisu: azot),
        ] else
          const OstrzezenieNowoczesne(
            tresc: 'Nie znamy zawartości azotu w tym nawozie.',
            coZrobic:
                'Azotu nie policzymy — dopisz zawartość z worka albo '
                'z analizy gnojowicy.',
          ),
        if (nawoz.naturalny) ...[
          const SizedBox(height: MotywNowoczesny.odstep),
          Text('Przyoranie', style: teksty.titleLarge),
          const SizedBox(height: 8),
          WyborPrzyorania(
            dzienZabiegu: _dane.kiedy,
            wybrana: _dane.dataPrzyorania,
            onZmiana: (dzien) => setState(() => _dane.dataPrzyorania = dzien),
          ),
        ],
      ],
    ];
  }
}

/// Maksymalna dawka azotu dla uprawy (tabela 14 programu azotanowego).
///
/// Wpisu nie blokujemy — rolnik mógł nawóz już wysiać i musi móc to
/// zapisać. Mówimy tylko, co o tym wie tabela.
class _MaksymalnaDawka extends StatelessWidget {
  const _MaksymalnaDawka({required this.stanPol, required this.azotWpisu});

  final Future<List<SkutekDlaMaksymalnejDawki>> stanPol;
  final double azotWpisu;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<SkutekDlaMaksymalnejDawki>>(
        future: stanPol,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const SizedBox.shrink();
          }
          final pola = [for (final pole in stan.data!) pole.zDawka(azotWpisu)];
          final ostrzezenia = pola
              .where((pole) => pole.ostrzezenie != null)
              .toList(growable: false);
          final teksty = Theme.of(context).textTheme;

          if (ostrzezenia.isNotEmpty) {
            return Column(
              children: [
                for (final pole in ostrzezenia) ...[
                  const SizedBox(height: 8),
                  OstrzezenieNowoczesne(
                    tresc: pole.ostrzezenie!,
                    coZrobic: pole.coZrobic ?? '',
                  ),
                ],
              ],
            );
          }

          final zLimitem = pola
              .where((pole) => pole.limitKgNaHa != null)
              .toList(growable: false);
          if (zLimitem.isEmpty) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final pole in zLimitem) ...[
                const SizedBox(height: 4),
                Text(
                  '${pole.nazwaPola}: razem '
                  '${pole.azotRazemKgNaHa.toStringAsFixed(0)} '
                  'z ${pole.limitKgNaHa} kg azotu na hektar.',
                  style: teksty.bodyMedium,
                ),
              ],
            ],
          );
        },
      );
}

class _PozycjaListy extends StatelessWidget {
  const _PozycjaListy({
    required this.nazwa,
    required this.opis,
    required this.wybrana,
  });

  final String nazwa;
  final String opis;
  final bool wybrana;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final kolor = wybrana ? MotywNowoczesny.karta : null;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nazwa, style: teksty.bodyLarge?.copyWith(color: kolor)),
              Text(opis, style: teksty.bodyMedium?.copyWith(color: kolor)),
            ],
          ),
        ),
        if (wybrana)
          const Icon(Icons.check, color: MotywNowoczesny.karta, size: 20),
      ],
    );
  }
}

/// Po zapisie: potwierdzenie, karencja i dzień zbioru.
class _Potwierdzenie extends StatelessWidget {
  const _Potwierdzenie({required this.dane, required this.zabieg});

  final DaneWpisu dane;
  final Zabieg zabieg;

  static String _dzien(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}.'
      '${data.month.toString().padLeft(2, '0')}.${data.year}';

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final srodek = dane.srodek;
    final karencja = srodek != null && srodek.karencjaZnana
        ? srodek.karencjaDni
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Zapisano')),
      body: ListView(
        padding: const EdgeInsets.all(MotywNowoczesny.odstep),
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 32,
                color: MotywNowoczesny.zielen,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Zabieg zapisany', style: teksty.headlineMedium),
              ),
            ],
          ),
          const SizedBox(height: MotywNowoczesny.odstep),
          Karta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${zabieg.rodzaj.dlaRolnika} • ${_dzien(zabieg.data)}',
                  style: teksty.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${dane.pola.map((p) => p.nazwa).join(', ')} • '
                  '${dane.powierzchniaOpis}',
                  style: teksty.bodyLarge,
                ),
                if (srodek != null) ...[
                  const SizedBox(height: 4),
                  Text(srodek.nazwa, style: teksty.bodyLarge),
                ],
                if (dane.nawoz != null) ...[
                  const SizedBox(height: 4),
                  Text(dane.nawoz!.nazwa, style: teksty.bodyLarge),
                ],
              ],
            ),
          ),
          if (zabieg.rodzaj == RodzajZabiegu.oprysk) ...[
            const SizedBox(height: MotywNowoczesny.odstep),
            if (karencja != null)
              OstrzezenieNowoczesne(
                tresc:
                    'Karencja: $karencja dni. Zbiór najwcześniej '
                    '${_dzien(zabieg.data.add(Duration(days: karencja)))}.',
                coZrobic: srodek?.karencjaDataEtykiety == null
                    ? null
                    : 'Z etykiety z ${srodek!.karencjaDataEtykiety}. '
                          'Sprawdź opakowanie — mogło być wydane wcześniej.',
              )
            else if (srodek != null && srodek.karencjaNieDotyczy)
              Text(
                'Etykieta podaje: karencja nie dotyczy.',
                style: teksty.bodyLarge,
              )
            else
              const OstrzezenieNowoczesne(
                tresc: 'Karencji nie znamy dla tego środka.',
                coZrobic: 'Sprawdź ją na etykiecie i dopisz do wpisu.',
              ),
          ],
          const SizedBox(height: MotywNowoczesny.odstep * 2),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Gotowe'),
          ),
        ],
      ),
    );
  }
}

/// Dawka przepisana z etykiety — dla środków, których dawki rejestr nie
/// podaje w jednoznacznej postaci. Ewidencja wymaga dawki zastosowanej,
/// a rolnik ma ją na etykiecie; aplikacja niczego nie podpowiada
/// (CLAUDE.md, reguła 5).
class _DawkaZEtykiety extends StatelessWidget {
  const _DawkaZEtykiety({
    required this.dane,
    required this.jednostki,
    required this.onZmiana,
  });

  final DaneWpisu dane;
  final Future<List<JednostkaDawkiSrodka>>? jednostki;
  final VoidCallback onZmiana;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final wybrana = dane.jednostkaZEtykiety;
    final dawka = dane.dawka ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'W ewidencji musi stać dawka, którą naprawdę zastosowałeś. '
          'Zero znaczy „bez dawki" — dopiszesz ją później.',
          style: teksty.bodyMedium,
        ),
        const SizedBox(height: 8),
        WyborLiczbyNowoczesny(
          wartosc: dawka,
          jednostka: wybrana?.opis ?? '',
          krok: 0.05,
          onZmiana: (nowa) {
            dane.dawka = nowa <= 0 ? null : nowa;
            onZmiana();
          },
        ),
        const SizedBox(height: 8),
        Text('W czym podana jest dawka?', style: teksty.bodyLarge),
        const SizedBox(height: 8),
        FutureBuilder<List<JednostkaDawkiSrodka>>(
          future: jednostki,
          builder: (context, stan) {
            if (!stan.hasData) {
              return Text(
                'Czytam jednostki z rejestru…',
                style: teksty.bodyMedium,
              );
            }
            final lista = stan.data!;
            if (lista.isEmpty) {
              return Text(
                'Rejestr nie podaje tu żadnej jednostki, więc nie mamy jej '
                'skąd wziąć. Zapisz zabieg bez dawki i dopisz ją na '
                'wydruku.',
                style: teksty.bodyMedium,
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final jednostka in lista)
                  Wybor(
                    etykieta: jednostka.opis,
                    wybrany: jednostka == wybrana,
                    onTap: () {
                      dane.jednostkaZEtykiety = jednostka;
                      onZmiana();
                    },
                  ),
              ],
            );
          },
        ),
        if (dawka > 0 && wybrana == null) ...[
          const SizedBox(height: 8),
          const OstrzezenieNowoczesne(
            tresc: 'Nie wiadomo, w czym podana jest ta dawka.',
            coZrobic:
                'Wybierz jednostkę powyżej — bez niej liczba w '
                'ewidencji nic nie znaczy.',
          ),
        ],
        if (dane.iloscSrodkaRazem case final double razem) ...[
          const SizedBox(height: 8),
          Text(
            'Na ${dane.powierzchniaOpis} potrzeba '
            '${razem.toStringAsFixed(2).replaceAll('.', ',')} '
            '${wybrana?.jednostka ?? ''}',
            style: teksty.bodyLarge,
          ),
        ],
      ],
    );
  }
}
