import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../rdzen/dostep/dostep_funkcji.dart';
import '../../../funkcje/dzialki/granica_z_woda.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/dzialki/rodzaj_uzytku.dart';
import '../../../funkcje/pulpit/zasiewy.dart';
import '../../../rdzen/dostep/funkcja.dart';
import '../../../rdzen/dostep/opis_premium.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/tabela.dart';
import 'okna_pola.dart';

/// Pola gospodarstwa w tabeli: co rośnie, ile ma hektarów i czego jeszcze
/// brakuje do policzenia warunkowości.
///
/// Rodzaj użytku i odpowiedź o wodzie ustawia się tu wprost — na komputerze
/// rolnik zwykle siada do uzupełniania danych całego gospodarstwa naraz.
class WidokPolaKomputer extends StatefulWidget {
  const WidokPolaKomputer({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;

  /// Dzień, z którego bierzemy sezon dla nowego pola.
  final DateTime? teraz;

  @override
  State<WidokPolaKomputer> createState() => _WidokPolaKomputerState();
}

class _WidokPolaKomputerState extends State<WidokPolaKomputer> {
  late Future<List<Pole>> _pola;
  Pole? _wybrane;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _pola = widget.uslugi.pola.wszystkie(widget.uslugi.gospodarstwoId);
  }

  Future<void> _ustawRodzaj(Pole pole, RodzajUzytku rodzaj) async {
    await widget.uslugi.pola.ustawRodzajUzytku(
      poleId: pole.id,
      rodzaj: rodzaj,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    await _poZmianie(pole.id);
  }

  Future<void> _ustawWode(Pole pole, GranicaZWoda granica) async {
    await widget.uslugi.pola.ustawGranicaZWoda(
      poleId: pole.id,
      granica: granica,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    await _poZmianie(pole.id);
  }

  /// Sezon nowego pola: ten, w którym gospodarstwo już coś ma, a gdy nie
  /// ma nic — bieżący rok.
  int _sezon(List<Pole> pola) =>
      Zasiewy.ostatniSezon(pola) ?? (widget.teraz ?? DateTime.now()).year;

  Future<void> _dodajPole(List<Pole> pola) async {
    final dodane = await showDialog<bool>(
      context: context,
      builder: (_) => OknoNowePole(uslugi: widget.uslugi, sezon: _sezon(pola)),
    );
    if (dodane ?? false) {
      setState(_odswiez);
    }
  }

  Future<void> _dodajDzialke() async {
    final dodana = await showDialog<bool>(
      context: context,
      builder: (_) => OknoDzialkaPoNumerze(uslugi: widget.uslugi),
    );
    if (dodana ?? false) {
      setState(_odswiez);
    }
  }

  Future<void> _wczytajWniosek() async {
    final zapisane = await showDialog<bool>(
      context: context,
      builder: (_) => OknoWniosek(uslugi: widget.uslugi),
    );
    if (zapisane ?? false) {
      setState(() {
        _wybrane = null;
        _odswiez();
      });
    }
  }

  Future<void> _poZmianie(String poleId) async {
    final swieze = await widget.uslugi.pola.jedno(poleId);
    if (!mounted) {
      return;
    }
    // Pozostałe zakładki czytają dane od nowa przy wejściu, więc tu
    // wystarczy odświeżyć tabelę i panel pola.
    setState(() {
      _wybrane = swieze;
      _odswiez();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Pole>>(
      future: _pola,
      builder: (context, stan) {
        if (!stan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pola = stan.data!;
        final hektary = pola.fold<double>(
          0,
          (suma, p) => suma + p.powierzchniaHa,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ListView(
                children: [
                  NaglowekWidoku(
                    tytul: 'Pola w gospodarstwie',
                    opis:
                        '${pola.length} pól, razem '
                        '${hektary.toStringAsFixed(2).replaceAll('.', ',')} ha. '
                        'Kliknij pole, żeby uzupełnić dane.',
                  ),
                  const SizedBox(height: MotywKomputer.odstep),
                  _Przyciski(
                    dostep: widget.uslugi.dostep,
                    onNowePole: () => _dodajPole(pola),
                    onDzialka: _dodajDzialke,
                    onWniosek: _wczytajWniosek,
                  ),
                  const SizedBox(height: MotywKomputer.odstep),
                  Tabela(
                    kolumny: const [
                      KolumnaTabeli('Pole', udzial: 2),
                      KolumnaTabeli('Uprawa', udzial: 2),
                      KolumnaTabeli('Powierzchnia', doPrawej: true),
                      KolumnaTabeli('Rodzaj użytku', udzial: 2),
                      KolumnaTabeli('Woda'),
                    ],
                    gdyPusta:
                        'Nie masz jeszcze żadnego pola. Dodaj je przyciskiem '
                        'wyżej albo wczytaj wniosek z eWniosekPlus.',
                    wiersze: [
                      for (final pole in pola)
                        WierszTabeli(
                          wartosci: [
                            pole.nazwa,
                            pole.uprawa.isEmpty ? 'brak' : pole.uprawa,
                            pole.powierzchniaOpis,
                            pole.rodzajUzytku.dlaRolnika,
                            pole.granicaZWoda.znana
                                ? (pole.granicaZWoda == GranicaZWoda.tak
                                      ? 'tak'
                                      : 'nie')
                                : 'nie wiadomo',
                          ],
                          wyrozniony:
                              !pole.rodzajUzytku.znany ||
                              !pole.granicaZWoda.znana,
                          onKlik: () => setState(() => _wybrane = pole),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: MotywKomputer.odstep),
            Expanded(
              flex: 2,
              child: _wybrane == null
                  ? const KartaKomputer(
                      child: Text(
                        'Wybierz pole z tabeli, żeby uzupełnić rodzaj użytku '
                        'i odpowiedź o wodzie. Bez nich aplikacja nie '
                        'policzy norm GAEC.',
                      ),
                    )
                  : _SzczegolyPola(
                      pole: _wybrane!,
                      pytanieOWode: widget.uslugi.pasOdWody.pytanie,
                      onRodzaj: (rodzaj) => _ustawRodzaj(_wybrane!, rodzaj),
                      onWoda: (granica) => _ustawWode(_wybrane!, granica),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Dane jednego pola do uzupełnienia. Aplikacja niczego nie zgaduje —
/// zapisuje to, co rolnik kliknie.
class _SzczegolyPola extends StatelessWidget {
  const _SzczegolyPola({
    required this.pole,
    required this.pytanieOWode,
    required this.onRodzaj,
    required this.onWoda,
  });

  final Pole pole;
  final String pytanieOWode;
  final void Function(RodzajUzytku rodzaj) onRodzaj;
  final void Function(GranicaZWoda granica) onWoda;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return ListView(
      children: [
        KartaKomputer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pole.nazwa, style: teksty.titleLarge),
              Text(
                '${pole.uprawa.isEmpty ? 'bez uprawy' : pole.uprawa} • '
                '${pole.powierzchniaOpis}'
                '${pole.sezon == null ? '' : ' • sezon ${pole.sezon}'}',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: MotywKomputer.odstep),
              Text('Rodzaj użytku', style: teksty.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Od niego zależą progi normy GAEC 7.',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final rodzaj in RodzajUzytku.doWyboru)
                    rodzaj == pole.rodzajUzytku
                        ? FilledButton(
                            onPressed: () => onRodzaj(rodzaj),
                            child: Text(rodzaj.dlaRolnika),
                          )
                        : OutlinedButton(
                            onPressed: () => onRodzaj(rodzaj),
                            child: Text(rodzaj.dlaRolnika),
                          ),
                ],
              ),
              const SizedBox(height: MotywKomputer.odstep),
              Text('Woda przy polu', style: teksty.titleLarge),
              const SizedBox(height: 4),
              Text(pytanieOWode, style: teksty.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final granica in GranicaZWoda.doWyboru)
                    granica == pole.granicaZWoda
                        ? FilledButton(
                            onPressed: () => onWoda(granica),
                            child: Text(granica.dlaRolnika),
                          )
                        : OutlinedButton(
                            onPressed: () => onWoda(granica),
                            child: Text(granica.dlaRolnika),
                          ),
                ],
              ),
            ],
          ),
        ),
        if (!pole.rodzajUzytku.znany) ...[
          const SizedBox(height: MotywKomputer.odstep),
          const OstrzezenieKomputer(
            tresc: 'Nie wiemy, czy to grunt orny, łąka czy sad.',
            coZrobic:
                'Wybierz wyżej. Bez tego warunkowość zostaje „do '
                'sprawdzenia", a nie „spełniona".',
          ),
        ],
      ],
    );
  }
}

/// Trzy drogi do pola: z klawiatury, z rejestru gruntów i z wniosku.
class _Przyciski extends StatelessWidget {
  const _Przyciski({
    required this.dostep,
    required this.onNowePole,
    required this.onDzialka,
    required this.onWniosek,
  });

  final DostepFunkcji dostep;
  final VoidCallback onNowePole;
  final VoidCallback onDzialka;
  final VoidCallback onWniosek;

  @override
  Widget build(BuildContext context) {
    // Wczytanie wniosku to dodatek płatny (plan, pkt 8). Bez premium nie ma
    // przycisku, ale jest zdanie, jak zrobić to samo bez opłaty — funkcji
    // nie chowamy bez wyjaśnienia.
    final zWnioskiem = dostep.czyDostepna(Funkcja.importDzialekZWnioskuPdf);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onNowePole,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj pole'),
            ),
            OutlinedButton.icon(
              onPressed: onDzialka,
              icon: const Icon(Icons.pin_drop_outlined),
              label: const Text('Działka po numerze'),
            ),
            if (zWnioskiem)
              OutlinedButton.icon(
                onPressed: onWniosek,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Wczytaj wniosek z PDF'),
              ),
          ],
        ),
        if (!zWnioskiem) ...[
          const SizedBox(height: MotywKomputer.odstep),
          OstrzezenieKomputer(
            tresc: OpisPremium.tresc(Funkcja.importDzialekZWnioskuPdf),
            coZrobic: OpisPremium.coZrobic(Funkcja.importDzialekZWnioskuPdf),
          ),
        ],
      ],
    );
  }
}
