import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/granica_z_woda.dart';
import '../../../funkcje/dzialki/historia_upraw.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/dzialki/rodzaj_uzytku.dart';
import '../../../funkcje/dzialki/slownik_upraw.dart';
import '../../../funkcje/dzialki/uprawy_pola.dart';
import '../../../funkcje/warunkowosc/okrywa.dart';
import '../../../rdzen/reguly/regula_prawna.dart';
import '../../../rdzen/wspolne/nazwa_pola.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';
import 'ekran_wybor_uprawy.dart';

/// Rodzaj użytku i uprawy pola w kolejnych latach — wygląd nowoczesny.
///
/// Oba te dane są potrzebne normie GAEC 7: próg 10 ha liczy się od gruntów
/// ornych, a zmianowanie porównuje uprawę w plonie głównym rok po roku.
/// Aplikacja podpowiada, ale zapisuje tylko to, co wybierze rolnik.
class EkranPoleNowoczesny extends StatefulWidget {
  const EkranPoleNowoczesny({
    super.key,
    required this.uslugi,
    required this.pole,
  });

  final Uslugi uslugi;
  final Pole pole;

  @override
  State<EkranPoleNowoczesny> createState() => _EkranPoleNowoczesnyState();
}

class _EkranPoleNowoczesnyState extends State<EkranPoleNowoczesny> {
  late Pole _pole = widget.pole;
  late Future<HistoriaUprawPola> _historia;
  late Future<OpisOkrywyPola> _okrywa;
  bool _zmienione = false;

  @override
  void initState() {
    super.initState();
    _historia = widget.uslugi.historiaUpraw.dla(_pole);
    _okrywa = widget.uslugi.okrywa.dlaPola(pole: _pole);
  }

  /// Zmiana własnej nazwy pola — pola z wniosku nazywają się „Pole A",
  /// a rolnik szuka na liście „Za stodołą".
  Future<void> _zmienNazwe() async {
    final nowa = await showDialog<String>(
      context: context,
      builder: (_) => OknoNazwyPola(
        nazwa: _pole.nazwa,
        oznaczenieZWniosku: _pole.oznaczenieZWniosku,
      ),
    );
    if (nowa == null || nowa == _pole.nazwa) {
      return;
    }
    await widget.uslugi.pola.ustawNazwe(
      poleId: _pole.id,
      nazwa: nowa,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    await _odswiez();
  }

  Future<void> _odswiez() async {
    final swieze = await widget.uslugi.pola.jedno(_pole.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _pole = swieze ?? _pole;
      _zmienione = true;
      _historia = widget.uslugi.historiaUpraw.dla(_pole);
      _okrywa = widget.uslugi.okrywa.dlaPola(pole: _pole);
    });
  }

  /// Zapis deklaracji okrywy (GAEC 6). Dzień zbioru bierzemy z wpisów
  /// zabiegów, gdy tam jest — rolnik nie podaje go drugi raz.
  Future<void> _ustawOkrywe({
    required OpisOkrywyPola opis,
    FormaOkrywy? forma,
    int? przerwaDni,
  }) async {
    final wybrana = forma ?? opis.forma;
    if (wybrana == null) {
      return;
    }
    await widget.uslugi.okrywaPola.zapisz(
      poleId: _pole.id,
      sezon: opis.sezon,
      forma: wybrana.id,
      dataZbioru: opis.dataZbioru,
      przerwaDni: przerwaDni ?? opis.deklaracja?.przerwaDni,
      urzadzenie: widget.uslugi.urzadzenie,
      zrodlo: opis.podpowiedz?.forma.id == wybrana.id
          ? 'podpowiedz potwierdzona'
          : 'rolnik',
    );
    await _odswiez();
  }

  Future<void> _ustawGranicaZWoda(GranicaZWoda granica) async {
    await widget.uslugi.pola.ustawGranicaZWoda(
      poleId: _pole.id,
      granica: granica,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    await _odswiez();
  }

  Future<void> _ustawRodzajUzytku(RodzajUzytku rodzaj) async {
    await widget.uslugi.pola.ustawRodzajUzytku(
      poleId: _pole.id,
      rodzaj: rodzaj,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    await _odswiez();
  }

  Future<void> _dopiszRok(int rok) async {
    final wybrana = await Navigator.of(context).push<UprawaDoWyboru>(
      MaterialPageRoute<UprawaDoWyboru>(
        builder: (_) => EkranWyborUprawyNowoczesny(uslugi: widget.uslugi),
      ),
    );
    if (wybrana == null || !mounted) {
      return;
    }
    await widget.uslugi.uprawyPola.zapisz(
      poleId: _pole.id,
      sezon: rok,
      uprawa: wybrana.nazwa,
      kodEppo: wybrana.kodEppo,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    await _odswiez();
  }

  Future<void> _przyjmijPropozycje(UprawaSezonu propozycja) async {
    await widget.uslugi.uprawyPola.zapisz(
      poleId: _pole.id,
      sezon: propozycja.sezon,
      uprawa: propozycja.uprawa,
      kodEppo: propozycja.kodEppo,
      urzadzenie: widget.uslugi.urzadzenie,
      zrodlo: 'wniosek',
    );
    await _odswiez();
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (juzZdjety, _) {
        if (!juzZdjety) {
          Navigator.of(context).pop(_zmienione);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pole.nazwa),
          actions: [
            IconButton(
              icon: const Icon(Icons.drive_file_rename_outline),
              tooltip: 'Zmień nazwę pola',
              onPressed: _zmienNazwe,
            ),
          ],
        ),
        body: FutureBuilder<HistoriaUprawPola>(
          future: _historia,
          builder: (context, stan) {
            if (!stan.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final historia = stan.data!;
            return ListView(
              padding: const EdgeInsets.all(MotywNowoczesny.odstep),
              children: [
                Karta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pole.uprawa.isEmpty ? 'Bez uprawy' : _pole.uprawa,
                        style: teksty.titleLarge,
                      ),
                      Text(
                        '${_pole.powierzchniaOpis}'
                        '${_pole.sezon == null ? '' : ' • sezon ${_pole.sezon}'}',
                        style: teksty.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MotywNowoczesny.odstep),
                Text('Rodzaj użytku', style: teksty.titleLarge),
                const SizedBox(height: 4),
                if (historia.rodzajUzytkuDoPodania)
                  OstrzezenieNowoczesne(
                    tresc: 'Nie wiemy, czy to grunt orny, łąka czy sad.',
                    coZrobic:
                        'Od tego zależą progi normy GAEC 7 (zmianowanie '
                        'i dywersyfikacja).'
                        '${historia.podpowiedzRodzajuUzytku.znany ? ' Z nazwy uprawy wychodzi: ${historia.podpowiedzRodzajuUzytku.dlaRolnika}.' : ''}',
                  )
                else
                  Text(_pole.rodzajUzytku.dlaRolnika, style: teksty.bodyLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final rodzaj in RodzajUzytku.doWyboru)
                      Wybor(
                        etykieta: rodzaj.dlaRolnika,
                        wybrany: rodzaj == _pole.rodzajUzytku,
                        onTap: () => _ustawRodzajUzytku(rodzaj),
                      ),
                  ],
                ),
                const SizedBox(height: MotywNowoczesny.odstep),
                Text('Co rosło w poprzednich latach', style: teksty.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Kontrola zmianowania porównuje uprawy rok po roku, '
                  'od ${historia.odRoku} r.',
                  style: teksty.bodyMedium,
                ),
                const SizedBox(height: 8),
                for (final wpis in historia.wpisy) ...[
                  Karta(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            '${wpis.sezon}',
                            style: teksty.titleLarge,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(wpis.uprawa, style: teksty.bodyLarge),
                              Text(
                                wpis.maKod
                                    ? 'kod EPPO: ${wpis.kodEppo}'
                                    : 'bez kodu EPPO',
                                style: teksty.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (historia.propozycje.isNotEmpty) ...[
                  Text(
                    'Z wniosków z wcześniejszych lat — to samo oznaczenie '
                    'działki rolnej. Dopisz, jeśli to ten sam kawałek pola.',
                    style: teksty.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final propozycja in historia.propozycje) ...[
                    Karta(
                      onTap: () => _przyjmijPropozycje(propozycja),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${propozycja.sezon}: ${propozycja.uprawa}',
                              style: teksty.bodyLarge,
                            ),
                          ),
                          const Icon(
                            Icons.playlist_add_outlined,
                            size: 20,
                            color: MotywNowoczesny.tekstPomocniczy,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                for (final rok in historia.brakujaceLata) ...[
                  OutlinedButton.icon(
                    onPressed: () => _dopiszRok(rok),
                    icon: const Icon(Icons.add, size: 20),
                    label: Text('Dopisz rok $rok'),
                  ),
                  const SizedBox(height: 8),
                ],
                if (historia.kompletna)
                  Text(
                    'Historia jest pełna od ${historia.odRoku} r.',
                    style: teksty.bodyMedium,
                  ),
                const SizedBox(height: MotywNowoczesny.odstep),
                Text('Woda przy polu', style: teksty.titleLarge),
                const SizedBox(height: 4),
                if (!_pole.granicaZWoda.znana)
                  OstrzezenieNowoczesne(
                    tresc: 'Nie wiemy, czy to pole graniczy z wodą.',
                    coZrobic: widget.uslugi.pasOdWody.pytanie,
                  )
                else ...[
                  Text(_pole.granicaZWoda.dlaRolnika, style: teksty.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    widget.uslugi.pasOdWody.pytanie,
                    style: teksty.bodyMedium,
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final granica in GranicaZWoda.doWyboru)
                      Wybor(
                        etykieta: granica.dlaRolnika,
                        wybrany: granica == _pole.granicaZWoda,
                        onTap: () => _ustawGranicaZWoda(granica),
                      ),
                  ],
                ),
                const SizedBox(height: MotywNowoczesny.odstep),
                FutureBuilder<OpisOkrywyPola>(
                  future: _okrywa,
                  builder: (context, stanOkrywy) {
                    if (!stanOkrywy.hasData) {
                      return const SizedBox.shrink();
                    }
                    final opis = stanOkrywy.data!;
                    if (opis.formy.pusta) {
                      return const SizedBox.shrink();
                    }
                    return _OkrywaPoZbiorze(
                      opis: opis,
                      onForma: (forma) =>
                          _ustawOkrywe(opis: opis, forma: forma),
                      onPrzerwa: (wybor) =>
                          _ustawOkrywe(opis: opis, przerwaDni: wybor.dni),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Co zostaje na polu po zbiorze — deklaracja do normy GAEC 6.
///
/// Te same zdania co w wyglądzie prostym (stoją w `OpisOkrywyPola`),
/// tylko wybór idzie chipami zamiast dużych przycisków.
class _OkrywaPoZbiorze extends StatelessWidget {
  const _OkrywaPoZbiorze({
    required this.opis,
    required this.onForma,
    required this.onPrzerwa,
  });

  final OpisOkrywyPola opis;
  final void Function(FormaOkrywy forma) onForma;
  final void Function(WyborPrzerwy wybor) onPrzerwa;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final wybrana = opis.forma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(opis.naglowek, style: teksty.titleLarge),
        const SizedBox(height: 4),
        if (opis.doPodania)
          OstrzezenieNowoczesne(
            tresc: 'Nie wiemy, co zostaje po zbiorze.',
            coZrobic: opis.wyjasnienie,
          )
        else
          Text(
            wybrana?.nazwa ?? 'nie znamy tej formy',
            style: teksty.bodyLarge,
          ),
        if (opis.opisZbioru != null) ...[
          const SizedBox(height: 4),
          Text(opis.opisZbioru!, style: teksty.bodyMedium),
        ],
        if (opis.opisPodpowiedzi != null) ...[
          const SizedBox(height: 4),
          Text(opis.opisPodpowiedzi!, style: teksty.bodyMedium),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final forma in opis.formy.formy)
              Wybor(
                etykieta: forma.nazwa,
                wybrany: forma.id == wybrana?.id,
                onTap: () => onForma(forma),
              ),
          ],
        ),
        if (opis.pytacOPrzerwe && opis.wyboryPrzerwy.isNotEmpty) ...[
          const SizedBox(height: MotywNowoczesny.odstep),
          Text('Przerwa bez okrywy', style: teksty.titleLarge),
          if (opis.opisPrzerwy != null) ...[
            const SizedBox(height: 4),
            Text(opis.opisPrzerwy!, style: teksty.bodyMedium),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final wybor in opis.wyboryPrzerwy)
                Wybor(
                  etykieta: wybor.etykieta,
                  wybrany: wybor.dni == opis.wybranaPrzerwa?.dni,
                  onTap: () => onPrzerwa(wybor),
                ),
            ],
          ),
          if (opis.wybranaPrzerwa?.ponadLimit ?? false) ...[
            const SizedBox(height: 8),
            OstrzezenieNowoczesne(
              tresc: 'Przerwa dłuższa, niż pozwala przepis.',
              coZrobic:
                  'Przy kontroli to pole nie liczy się do okrywy. Wpis '
                  'zostaje taki, jak było — dokumentacja ma być prawdziwa.',
            ),
          ],
        ],
      ],
    );
  }
}
