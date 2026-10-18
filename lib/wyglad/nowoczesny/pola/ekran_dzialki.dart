import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/klient_uldk.dart';
import '../../../funkcje/dzialki/szukanie_dzialki.dart';
import '../../../rdzen/wspolne/szukanie_dzialki.dart';
import '../../../funkcje/dzialki/repozytorium_dzialek.dart';
import '../../../rdzen/wspolne/mapa_dzialek.dart';
import '../motyw.dart';
import '../widgety/karta.dart';

/// Działki ewidencyjne w wyglądzie nowoczesnym: lista, mapa granic
/// i dodanie działki po numerze z państwowej usługi ULDK.
///
/// Granice pobieramy **raz**, w chwili dodawania; potem mapa działa bez
/// zasięgu (plan, pkt 2). Potwierdzenie na mapie jest obowiązkowe, bo
/// numery i obręby się powtarzają (plan, pkt 6.1).
class EkranDzialkiNowoczesny extends StatefulWidget {
  const EkranDzialkiNowoczesny({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranDzialkiNowoczesny> createState() => _EkranDzialkiNowoczesnyState();
}

class _EkranDzialkiNowoczesnyState extends State<EkranDzialkiNowoczesny> {
  final TextEditingController _numer = TextEditingController();

  /// Działki spoza wniosku (dzierżawa, zakup po jego złożeniu) szuka się
  /// po województwie, nazwie miejscowości (obrębu) i numerze z umowy.
  late final SzukanieDzialkiPoNazwie _poNazwie = SzukanieDzialkiPoNazwie(
    klient: widget.uslugi.uldk,
    wojewodztwa: widget.uslugi.wojewodztwa,
  );

  bool _zList = true;

  late Future<List<DzialkaEwidencyjna>> _dzialki;
  String? _wyrozniona;

  bool _szukanie = false;
  bool _zapisywanie = false;
  BladUldk? _blad;
  DzialkaZUldk? _znaleziona;
  bool _jestJuzDodana = false;

  /// Czy ekran dodał choć jedną działkę — zakładka „Pola" musi wtedy
  /// przeliczyć mapę.
  bool _cosDodano = false;

  @override
  void initState() {
    super.initState();
    _dzialki = widget.uslugi.dzialki.wszystkie(widget.uslugi.gospodarstwoId);
  }

  @override
  void dispose() {
    _numer.dispose();
    super.dispose();
  }

  /// Czy jest już co wysłać do usługi.
  bool get _moznaSzukac =>
      _zList ? _poNazwie.moznaSzukac : _numer.text.trim().isNotEmpty;

  /// Szukanie po nazwie: jedna znaleziona działka — od razu granice;
  /// kilka — rolnik wybiera z listy, bo obręby o tej nazwie są w wielu
  /// gminach.
  Future<void> _szukaj() async {
    if (_szukanie) {
      return;
    }
    if (!_moznaSzukac) {
      // Przycisk nie śpi — rolnik dostaje zdanie, czego brakuje.
      setState(
        () => _blad = BladUldk(
          _zList
              ? 'Wpisz nazwę miejscowości (obrębu) i numer działki z umowy.'
              : 'Wpisz numer działki z wniosku.',
        ),
      );
      return;
    }
    if (!_zList) {
      return _pobierz(_numer.text.trim());
    }
    setState(() {
      _szukanie = true;
      _blad = null;
    });
    try {
      final znalezione = await _poNazwie.szukaj();
      if (!mounted) {
        return;
      }
      if (znalezione.length == 1) {
        await _pobierz(znalezione.single.teryt);
        return;
      }
      setState(() => _szukanie = false);
    } on BladUldk catch (blad) {
      if (!mounted) {
        return;
      }
      setState(() {
        _blad = blad;
        _szukanie = false;
      });
    }
  }

  Future<void> _pobierz(String numer) async {
    setState(() {
      _szukanie = true;
      _blad = null;
      _znaleziona = null;
      _jestJuzDodana = false;
    });
    try {
      final dzialka = await widget.uslugi.uldk.pobierz(numer);
      final jestJuz = await widget.uslugi.dzialki.czyJuzJest(
        widget.uslugi.gospodarstwoId,
        dzialka.identyfikator,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _znaleziona = dzialka;
        _jestJuzDodana = jestJuz;
        _szukanie = false;
      });
    } on BladUldk catch (blad) {
      if (!mounted) {
        return;
      }
      setState(() {
        _blad = blad;
        _szukanie = false;
      });
    } on FormatException {
      if (!mounted) {
        return;
      }
      setState(() {
        _blad = const BladUldk(
          'Granice tej działki przyszły w postaci, której nie rozumiemy.',
          coZrobic:
              'Zgłoś to w ustawieniach — działkę można na razie dodać bez '
              'mapy jako pole.',
        );
        _szukanie = false;
      });
    }
  }

  Future<void> _zapisz() async {
    final dzialka = _znaleziona;
    if (dzialka == null || _zapisywanie) {
      return;
    }
    setState(() => _zapisywanie = true);
    await widget.uslugi.dzialki.zapisz(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      zUldk: dzialka,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _zapisywanie = false;
      _cosDodano = true;
      _wyrozniona = dzialka.identyfikator;
      _znaleziona = null;
      _numer.clear();
      _dzialki = widget.uslugi.dzialki.wszystkie(widget.uslugi.gospodarstwoId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Działki'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(_cosDodano),
        ),
      ),
      body: FutureBuilder<List<DzialkaEwidencyjna>>(
        future: _dzialki,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dzialki = stan.data!;
          final zGranicami = dzialki
              .where((d) => d.maGranice)
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.all(MotywNowoczesny.odstep),
            children: [
              if (zGranicami.isNotEmpty) ...[
                MapaDzialek(
                  dzialki: zGranicami,
                  barwy: MotywNowoczesny.barwyMapy,
                  wyrozniona: _wyrozniona,
                  wysokosc: 200,
                ),
                const SizedBox(height: MotywNowoczesny.odstep),
              ],
              if (_znaleziona case final DzialkaZUldk dzialka)
                _Potwierdzenie(
                  dzialka: dzialka,
                  jestJuzDodana: _jestJuzDodana,
                  zapisywanie: _zapisywanie,
                  onZapisz: _zapisz,
                  onPopraw: () => setState(() {
                    _znaleziona = null;
                    _jestJuzDodana = false;
                  }),
                )
              else
                _Dodawanie(
                  numer: _numer,
                  szukanie: _szukanie,
                  blad: _blad,
                  onSzukaj: _szukaj,
                  poNazwie: _poNazwie,
                  zList: _zList,
                  onSposob: (zList) => setState(() {
                    _zList = zList;
                    _numer.clear();
                    _blad = null;
                  }),
                  onZmiana: () => setState(() => _blad = null),
                  onWybor: (dzialka) => _pobierz(dzialka.teryt),
                ),
              const SizedBox(height: MotywNowoczesny.odstep),
              Text('Twoje działki', style: teksty.titleLarge),
              const SizedBox(height: 8),
              if (dzialki.isEmpty)
                const OstrzezenieNowoczesne(
                  tresc: 'Nie masz jeszcze żadnej działki.',
                  coZrobic:
                      'Przepisz numer z wniosku i naciśnij „Znajdź '
                      'działkę".',
                )
              else
                for (final dzialka in dzialki) ...[
                  Karta(
                    onTap: dzialka.maGranice
                        ? () => setState(
                            () => _wyrozniona = dzialka.identyfikator,
                          )
                        : null,
                    wyrozniona: dzialka.identyfikator == _wyrozniona,
                    child: Row(
                      children: [
                        Icon(
                          dzialka.maGranice
                              ? Icons.pentagon_outlined
                              : Icons.help_outline,
                          size: 20,
                          color: dzialka.identyfikator == _wyrozniona
                              ? MotywNowoczesny.karta
                              : MotywNowoczesny.tekstPomocniczy,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dzialka.identyfikator,
                                style: teksty.bodyLarge?.copyWith(
                                  color: dzialka.identyfikator == _wyrozniona
                                      ? MotywNowoczesny.karta
                                      : MotywNowoczesny.tekst,
                                ),
                              ),
                              Text(
                                [
                                  if (dzialka.polozenie.isNotEmpty)
                                    dzialka.polozenie,
                                  'około ${dzialka.powierzchniaOpis}',
                                ].join(' • '),
                                style: teksty.bodyMedium?.copyWith(
                                  color: dzialka.identyfikator == _wyrozniona
                                      ? MotywNowoczesny.karta
                                      : MotywNowoczesny.tekstPomocniczy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// Wpisanie numeru i pobranie granic.
class _Dodawanie extends StatelessWidget {
  const _Dodawanie({
    required this.numer,
    required this.szukanie,
    required this.blad,
    required this.onSzukaj,
    required this.poNazwie,
    required this.zList,
    required this.onSposob,
    required this.onZmiana,
    required this.onWybor,
  });

  final TextEditingController numer;
  final bool szukanie;
  final BladUldk? blad;
  final VoidCallback onSzukaj;

  final SzukanieDzialkiPoNazwie poNazwie;
  final bool zList;
  final void Function(bool zList) onSposob;
  final VoidCallback onZmiana;
  final void Function(DzialkaZnaleziona dzialka) onWybor;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dodaj działkę', style: teksty.titleLarge),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Po miejscowości')),
            ButtonSegment(value: false, label: Text('Numer z wniosku')),
          ],
          selected: {zList},
          onSelectionChanged: (wybrane) => onSposob(wybrane.first),
        ),
        const SizedBox(height: MotywNowoczesny.odstep),
        if (zList) ...[
          SzukanieDzialki(
            szukanie: poNazwie,
            onZmiana: onZmiana,
            onWybor: onWybor,
            onSzukaj: onSzukaj,
          ),
          const SizedBox(height: MotywNowoczesny.odstep),
        ] else
          TextField(
            controller: numer,
            style: teksty.bodyLarge,
            // Klawiatura wychodzi po dotknięciu okienka, nie sama.
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'Numer działki z wniosku',
              hintText: '061506_2.0007.138',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => onZmiana(),
            onSubmitted: (_) => onSzukaj(),
          ),
        const SizedBox(height: 8),
        Text(
          'Granice pobieramy raz, z państwowej usługi ULDK. Potem mapa '
          'działa bez internetu.',
          style: teksty.bodyMedium,
        ),
        if (blad != null) ...[
          const SizedBox(height: MotywNowoczesny.odstep),
          OstrzezenieNowoczesne(
            tresc: blad!.wiadomosc,
            coZrobic: blad!.coZrobic,
          ),
        ],
        const SizedBox(height: MotywNowoczesny.odstep),
        if (szukanie)
          const Center(child: CircularProgressIndicator())
        else
          FilledButton.icon(
            onPressed: onSzukaj,
            icon: const Icon(Icons.search, size: 20),
            label: const Text('Znajdź działkę'),
          ),
      ],
    );
  }
}

/// „Czy to ta działka?" — mapa i dane przed zapisem.
class _Potwierdzenie extends StatelessWidget {
  const _Potwierdzenie({
    required this.dzialka,
    required this.jestJuzDodana,
    required this.zapisywanie,
    required this.onZapisz,
    required this.onPopraw,
  });

  final DzialkaZUldk dzialka;
  final bool jestJuzDodana;
  final bool zapisywanie;
  final VoidCallback onZapisz;
  final VoidCallback onPopraw;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final doPokazania = DzialkaEwidencyjna(
      id: 'podglad',
      identyfikator: dzialka.identyfikator,
      obreb: dzialka.obreb,
      gmina: dzialka.gmina,
      nrDzialki: dzialka.nrDzialki,
      powierzchniaHa: dzialka.powierzchniaHa,
      geometriaWkt: dzialka.wkt,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Czy to ta działka?', style: teksty.titleLarge),
        const SizedBox(height: 8),
        MapaDzialek(
          dzialki: [doPokazania],
          barwy: MotywNowoczesny.barwyMapy,
          wyrozniona: dzialka.identyfikator,
          wysokosc: 200,
        ),
        const SizedBox(height: 8),
        Text(dzialka.identyfikator, style: teksty.bodyLarge),
        Text(
          dzialka.polozenie.isEmpty ? 'położenie nieznane' : dzialka.polozenie,
          style: teksty.bodyMedium,
        ),
        // Powierzchnia z granic jest przybliżona — do dokumentu idzie ta
        // z wniosku, dlatego mówimy „około".
        Text('około ${doPokazania.powierzchniaOpis}', style: teksty.bodyMedium),
        const SizedBox(height: MotywNowoczesny.odstep),
        if (jestJuzDodana) ...[
          const OstrzezenieNowoczesne(
            tresc: 'Ta działka jest już dodana.',
            coZrobic: 'Nie musisz dodawać jej drugi raz.',
          ),
          const SizedBox(height: MotywNowoczesny.odstep),
          OutlinedButton(
            onPressed: onPopraw,
            child: const Text('Wpisz inny numer'),
          ),
        ] else if (zapisywanie)
          const Center(child: CircularProgressIndicator())
        else ...[
          FilledButton(
            onPressed: onZapisz,
            child: const Text('Tak, to moja działka'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onPopraw,
            child: const Text('Nie, popraw numer'),
          ),
        ],
      ],
    );
  }
}
