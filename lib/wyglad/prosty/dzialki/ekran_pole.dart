import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/historia_upraw.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/dzialki/rodzaj_uzytku.dart';
import '../../../funkcje/dzialki/slownik_upraw.dart';
import '../../../funkcje/dzialki/uprawy_pola.dart';
import '../../../funkcje/warunkowosc/okrywa.dart';
import '../../../rdzen/reguly/regula_prawna.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_wybor_uprawy.dart';

/// Jedno pole: co na nim rośnie, jaki ma kod EPPO, jakim jest użytkiem
/// i co rosło na nim w poprzednich latach.
///
/// Uprawa zmienia się co sezon, a wpisy zabiegów zostają przy tym samym
/// polu — dlatego zmiana uprawy idzie do dziennika zmian, a kontrola widzi,
/// co było wcześniej. Rodzaj użytku i uprawy z lat poprzednich są potrzebne
/// normie GAEC 7 (zmianowanie i dywersyfikacja).
class EkranPole extends StatefulWidget {
  const EkranPole({super.key, required this.uslugi, required this.pole});

  final Uslugi uslugi;
  final Pole pole;

  @override
  State<EkranPole> createState() => _EkranPoleState();
}

class _EkranPoleState extends State<EkranPole> {
  late Pole _pole = widget.pole;
  bool _zmienione = false;
  bool _pracuje = false;
  Future<HistoriaUprawPola>? _historia;
  Future<OpisOkrywyPola>? _okrywa;

  @override
  void initState() {
    super.initState();
    _odswiezHistorie();
  }

  void _odswiezHistorie() {
    _historia = widget.uslugi.historiaUpraw.dla(_pole);
    _okrywa = widget.uslugi.okrywa.dlaPola(pole: _pole);
  }

  /// Zapis deklaracji okrywy. Dzień zbioru bierzemy z wpisów zabiegów,
  /// gdy tam jest — rolnik nie musi go podawać drugi raz.
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
    if (mounted) {
      setState(() {
        _zmienione = true;
        _odswiezHistorie();
      });
    }
  }

  Future<void> _ustawRodzajUzytku(RodzajUzytku rodzaj) async {
    await widget.uslugi.pola.ustawRodzajUzytku(
      poleId: _pole.id,
      rodzaj: rodzaj,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    final swieze = await widget.uslugi.pola.jedno(_pole.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _pole = swieze ?? _pole;
      _zmienione = true;
      _odswiezHistorie();
    });
  }

  /// Dopisanie uprawy z wcześniejszego roku — rolnik wybiera rok i uprawę.
  Future<void> _dopiszRok(int rok) async {
    final wybrana = await Navigator.of(context).push<UprawaDoWyboru>(
      MaterialPageRoute<UprawaDoWyboru>(
        builder: (_) => EkranWyborUprawy(uslugi: widget.uslugi),
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
    if (mounted) {
      setState(() {
        _zmienione = true;
        _odswiezHistorie();
      });
    }
  }

  /// Przyjęcie propozycji z wniosku z wcześniejszego roku.
  Future<void> _przyjmijPropozycje(UprawaSezonu propozycja) async {
    await widget.uslugi.uprawyPola.zapisz(
      poleId: _pole.id,
      sezon: propozycja.sezon,
      uprawa: propozycja.uprawa,
      kodEppo: propozycja.kodEppo,
      urzadzenie: widget.uslugi.urzadzenie,
      zrodlo: 'wniosek',
    );
    if (mounted) {
      setState(() {
        _zmienione = true;
        _odswiezHistorie();
      });
    }
  }

  Future<void> _zmienUprawe() async {
    if (_pracuje) {
      return;
    }
    final wybrana = await Navigator.of(context).push<UprawaDoWyboru>(
      MaterialPageRoute<UprawaDoWyboru>(
        builder: (_) => EkranWyborUprawy(uslugi: widget.uslugi),
      ),
    );
    if (wybrana == null || !mounted) {
      return;
    }

    // Czwarty rok tej samej uprawy to złamanie normy GAEC 7. Mówimy to
    // **przed** zapisem, bo wtedy rolnik może jeszcze zasiać co innego.
    final ostrzezenie = await widget.uslugi.zmianowanie.ostrzezeniePrzedZapisem(
      pole: _pole,
      uprawa: wybrana.nazwa,
    );
    if (!mounted) {
      return;
    }
    if (ostrzezenie != null) {
      final zapisac = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Czwarty rok tej samej uprawy'),
          content: Text(
            '${ostrzezenie.tresc}\n\n${ostrzezenie.coZrobic}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Wybiorę inną'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Zapisz mimo to'),
            ),
          ],
        ),
      );
      if (!(zapisac ?? false) || !mounted) {
        return;
      }
    }

    setState(() => _pracuje = true);
    await widget.uslugi.pola.zmienUprawe(
      poleId: _pole.id,
      uprawa: wybrana.nazwa,
      kodEppo: wybrana.kodEppo,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    final swieze = await widget.uslugi.pola.jedno(_pole.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _pole = swieze ?? _pole;
      _zmienione = true;
      _pracuje = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Zmieniono uprawę na „${wybrana.nazwa}". Poprzednia została '
          'w dzienniku zmian.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: MotywProsty.powierzchnia),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (juzZdjety, _) {
        if (!juzZdjety) {
          Navigator.of(context).pop(_zmienione);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_pole.nazwa)),
        body: ListView(
          padding: const EdgeInsets.all(MotywProsty.odstep),
          children: [
            Text('Uprawa', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              _pole.uprawa.isEmpty ? 'nie podano' : _pole.uprawa,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _pole.kodEppo == null
                  ? 'Kod EPPO: brak — w ewidencji wyjdzie „brak"'
                  : 'Kod EPPO: ${_pole.kodEppo}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: MotywProsty.odstep),
            Text(
              'Powierzchnia: ${_pole.powierzchniaOpis}'
              '${_pole.sezon == null ? '' : ' • sezon ${_pole.sezon}'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: MotywProsty.odstep * 2),
            if (_pracuje)
              const Center(child: CircularProgressIndicator())
            else
              DuzyPrzycisk(
                etykieta: 'Zmień uprawę',
                opis: 'po zbiorze albo gdy wpisałeś coś innego',
                ikona: Icons.grass_outlined,
                wyrozniony: true,
                onTap: _zmienUprawe,
              ),
            const SizedBox(height: MotywProsty.odstep),
            Text(
              'Zabiegi zapisane na tym polu zostają bez zmian. Zmiana '
              'uprawy nie wpływa na to, co już wpisałeś.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: MotywProsty.odstep * 2),
            FutureBuilder<HistoriaUprawPola>(
              future: _historia,
              builder: (context, stan) {
                if (!stan.hasData) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RodzajUzytkuPola(
                      historia: stan.data!,
                      onWybor: _ustawRodzajUzytku,
                    ),
                    const SizedBox(height: MotywProsty.odstep * 2),
                    _UprawyWLatach(
                      historia: stan.data!,
                      onDopisz: _dopiszRok,
                      onPropozycja: _przyjmijPropozycje,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: MotywProsty.odstep * 2),
            FutureBuilder<OpisOkrywyPola>(
              future: _okrywa,
              builder: (context, stan) {
                if (!stan.hasData) {
                  return const SizedBox.shrink();
                }
                return _OkrywaPoZbiorze(
                  opis: stan.data!,
                  onForma: (forma) =>
                      _ustawOkrywe(opis: stan.data!, forma: forma),
                  onPrzerwa: (wybor) =>
                      _ustawOkrywe(opis: stan.data!, przerwaDni: wybor.dni),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Rodzaj użytku pola — od niego zależą progi normy GAEC 7.
///
/// Aplikacja podpowiada po nazwie uprawy, ale zapisuje tylko to, co rolnik
/// wybierze: zgadnięty rodzaj użytku dałby zgadnięty wynik kontroli.
class _RodzajUzytkuPola extends StatelessWidget {
  const _RodzajUzytkuPola({required this.historia, required this.onWybor});

  final HistoriaUprawPola historia;
  final void Function(RodzajUzytku rodzaj) onWybor;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final pole = historia.pole;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rodzaj użytku', style: teksty.titleLarge),
        const SizedBox(height: 8),
        if (historia.rodzajUzytkuDoPodania)
          Ostrzezenie(
            tresc: 'Nie wiemy, czy to grunt orny, łąka czy sad.',
            coZrobic:
                'Wybierz niżej. Od tego zależy, czy i jak liczyć '
                'zmianowanie upraw (norma GAEC 7). '
                '${_opisPodpowiedzi(historia.podpowiedzRodzajuUzytku)}',
          )
        else
          Text(pole.rodzajUzytku.dlaRolnika, style: teksty.headlineMedium),
        const SizedBox(height: MotywProsty.odstep),
        for (final rodzaj in RodzajUzytku.doWyboru) ...[
          DuzyPrzycisk(
            etykieta: rodzaj.dlaRolnika,
            opis: rodzaj == pole.rodzajUzytku
                ? 'tak zapisane'
                : (rodzaj == historia.podpowiedzRodzajuUzytku &&
                      historia.rodzajUzytkuDoPodania)
                ? 'podpowiedź aplikacji'
                : 'dotknij, żeby wybrać',
            ikona: rodzaj == pole.rodzajUzytku
                ? Icons.check_circle_outline
                : Icons.circle_outlined,
            wyrozniony: rodzaj == pole.rodzajUzytku,
            onTap: () => onWybor(rodzaj),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  static String _opisPodpowiedzi(RodzajUzytku podpowiedz) => podpowiedz.znany
      ? 'Z nazwy uprawy wychodzi: ${podpowiedz.dlaRolnika}.'
      : '';
}

/// Co rosło na polu w kolejnych latach — bez tego nie da się policzyć
/// zmianowania. Zakres lat bierze się z przepisu, nie z kodu.
class _UprawyWLatach extends StatelessWidget {
  const _UprawyWLatach({
    required this.historia,
    required this.onDopisz,
    required this.onPropozycja,
  });

  final HistoriaUprawPola historia;
  final void Function(int rok) onDopisz;
  final void Function(UprawaSezonu propozycja) onPropozycja;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Co rosło w poprzednich latach', style: teksty.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Kontrola zmianowania (GAEC 7) porównuje uprawy rok po roku, '
          'od ${historia.odRoku} r. Dopisz, co pamiętasz — bez tego '
          'aplikacja nie policzy, czy zmianowanie się zgadza.',
          style: teksty.bodyMedium,
        ),
        const SizedBox(height: MotywProsty.odstep),
        for (final wpis in historia.wpisy) ...[
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Text('${wpis.sezon}', style: teksty.titleLarge),
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
          const SizedBox(height: 10),
        ],
        if (historia.propozycje.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Z wniosków z wcześniejszych lat — to samo oznaczenie działki '
            'rolnej. Sprawdź i dopisz, jeśli to ten sam kawałek pola.',
            style: teksty.bodyMedium,
          ),
          const SizedBox(height: 8),
          for (final propozycja in historia.propozycje) ...[
            DuzyPrzycisk(
              etykieta: '${propozycja.sezon}: ${propozycja.uprawa}',
              opis: 'dotknij, żeby dopisać do tego pola',
              ikona: Icons.playlist_add_outlined,
              onTap: () => onPropozycja(propozycja),
            ),
            const SizedBox(height: 10),
          ],
        ],
        for (final rok in historia.brakujaceLata) ...[
          DuzyPrzycisk(
            etykieta: 'Dopisz rok $rok',
            opis: 'wybierzesz uprawę z listy',
            ikona: Icons.add_circle_outline,
            onTap: () => onDopisz(rok),
          ),
          const SizedBox(height: 10),
        ],
        if (historia.kompletna) ...[
          const SizedBox(height: 4),
          Text(
            'Historia jest pełna od ${historia.odRoku} r.',
            style: teksty.bodyMedium,
          ),
        ],
      ],
    );
  }
}

/// Co zostaje na polu po zbiorze — deklaracja do normy GAEC 6.
///
/// Formy są danymi ze słownika reguł. Aplikacja podpowiada z wpisów
/// rolnika, ale zapisuje tylko to, co rolnik dotknie: zgadnięta okrywa
/// dałaby zgadnięty wynik kontroli.
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
    if (opis.formy.pusta) {
      return const SizedBox.shrink();
    }
    final wybrana = opis.forma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(opis.naglowek, style: teksty.titleLarge),
        const SizedBox(height: 8),
        if (opis.doPodania)
          Ostrzezenie(
            tresc: 'Nie wiemy, co zostaje po zbiorze.',
            coZrobic: opis.wyjasnienie,
          )
        else
          Text(
            wybrana?.nazwa ?? 'nie znamy tej formy',
            style: teksty.headlineMedium,
          ),
        if (opis.opisZbioru != null) ...[
          const SizedBox(height: 8),
          Text(opis.opisZbioru!, style: teksty.bodyLarge),
        ],
        if (opis.opisPodpowiedzi != null) ...[
          const SizedBox(height: 8),
          Text(opis.opisPodpowiedzi!, style: teksty.bodyMedium),
        ],
        const SizedBox(height: MotywProsty.odstep),
        for (final forma in opis.formy.formy) ...[
          DuzyPrzycisk(
            etykieta: forma.nazwa,
            opis: forma.id == wybrana?.id
                ? 'tak zapisane'
                : (forma.id == opis.podpowiedz?.forma.id
                      ? 'podpowiedź aplikacji'
                      : forma.opis),
            ikona: forma.id == wybrana?.id
                ? Icons.check_circle_outline
                : Icons.circle_outlined,
            wyrozniony: forma.id == wybrana?.id,
            onTap: () => onForma(forma),
          ),
          const SizedBox(height: 10),
        ],
        if (opis.pytacOPrzerwe && opis.wyboryPrzerwy.isNotEmpty) ...[
          const SizedBox(height: MotywProsty.odstep),
          Text('Przerwa bez okrywy', style: teksty.titleLarge),
          const SizedBox(height: 8),
          if (opis.opisPrzerwy != null)
            Text(opis.opisPrzerwy!, style: teksty.bodyMedium),
          const SizedBox(height: MotywProsty.odstep),
          for (final wybor in opis.wyboryPrzerwy) ...[
            DuzyPrzycisk(
              etykieta: wybor.etykieta,
              opis: wybor.dni == opis.wybranaPrzerwa?.dni
                  ? 'tak zapisane'
                  : (wybor.ponadLimit
                        ? 'przy kontroli pole nie liczy się do okrywy'
                        : 'dotknij, żeby wybrać'),
              ikona: wybor.dni == opis.wybranaPrzerwa?.dni
                  ? Icons.check_circle_outline
                  : Icons.circle_outlined,
              wyrozniony: wybor.dni == opis.wybranaPrzerwa?.dni,
              onTap: () => onPrzerwa(wybor),
            ),
            const SizedBox(height: 10),
          ],
          if (opis.wybranaPrzerwa?.ponadLimit ?? false)
            Ostrzezenie(
              tresc: 'Przerwa dłuższa, niż pozwala przepis.',
              coZrobic:
                  'Przy kontroli to pole nie liczy się do okrywy. Wpis '
                  'zostaje taki, jak było — dokumentacja ma być prawdziwa.',
            ),
        ],
      ],
    );
  }
}
