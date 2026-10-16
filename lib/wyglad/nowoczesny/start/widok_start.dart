import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/nawozenie/ewidencja_nawozenia.dart';
import '../../../funkcje/terminy/kalendarz_terminow.dart';
import '../../../funkcje/zabiegi/rejestr_zabiegow.dart';
import '../motyw.dart';
import '../widgety/karta.dart';

/// To, co pokazuje ekran startowy. Liczymy raz, jednym przebiegiem — ekran
/// ma się pojawić od razu po otwarciu aplikacji.
class PodsumowanieSezonu {
  const PodsumowanieSezonu({
    required this.sezon,
    required this.pola,
    required this.powierzchniaHa,
    required this.zabiegiSezonu,
    required this.ostatnie,
    required this.limit,
    required this.najblizszy,
  });

  final int sezon;
  final List<Pole> pola;
  final double powierzchniaHa;

  /// Liczba zabiegów zapisanych w tym sezonie.
  final int zabiegiSezonu;

  /// Kilka ostatnich wpisów — rolnik najczęściej sprawdza, czy zapis wszedł.
  final List<WpisRejestru> ostatnie;

  final StanLimituAzotu limit;

  /// Najpilniejszy termin albo `null`, gdy nie ma czego pilnować.
  final PozycjaKalendarza? najblizszy;
}

/// Zakładka „Start" wyglądu nowoczesnego: podsumowanie sezonu, pasek azotu,
/// najbliższy termin i ostatnie zabiegi (plan, pkt 5).
class WidokStart extends StatefulWidget {
  const WidokStart({
    super.key,
    required this.uslugi,
    required this.onTerminy,
    required this.onDokumenty,
    required this.onRejestr,
    this.teraz,
  });

  final Uslugi uslugi;

  /// Przejście do zakładek — karty na starcie są skrótami, nie kopiami.
  final VoidCallback onTerminy;
  final VoidCallback onDokumenty;

  /// Rejestr wpisów — stąd rolnik poprawia i cofa zabiegi.
  final VoidCallback onRejestr;

  /// Dzień, od którego liczymy terminy; w aplikacji „dzisiaj".
  final DateTime? teraz;

  @override
  State<WidokStart> createState() => _WidokStartState();
}

class _WidokStartState extends State<WidokStart> {
  late Future<PodsumowanieSezonu> _dane;

  @override
  void initState() {
    super.initState();
    _dane = _policz();
  }

  Future<PodsumowanieSezonu> _policz() async {
    final uslugi = widget.uslugi;
    final teraz = widget.teraz ?? DateTime.now();
    final profil = await uslugi.profil.policz(uslugi.gospodarstwoId);
    final limit = await uslugi.nawozenie.limitAzotu(
      gospodarstwoId: uslugi.gospodarstwoId,
      powierzchniaUrHa: profil.powierzchniaUrHa,
    );
    final pola = await uslugi.pola.wszystkie(uslugi.gospodarstwoId);
    final wpisy = await uslugi.rejestr.wpisy(uslugi.gospodarstwoId);
    final terminy = await uslugi.kalendarz.najblizsze(
      gospodarstwoId: uslugi.gospodarstwoId,
      profil: profil,
      teraz: widget.teraz,
    );
    final wSezonie = wpisy
        .where((w) => w.zabieg.data.year == limit.sezon)
        .toList(growable: false);

    return PodsumowanieSezonu(
      sezon: limit.sezon,
      pola: pola,
      powierzchniaHa: profil.powierzchniaUrHa,
      zabiegiSezonu: wSezonie.length,
      ostatnie: wpisy.take(3).toList(growable: false),
      limit: limit,
      najblizszy: _najpilniejszy(terminy, teraz),
    );
  }

  /// Najpilniejszy termin: najpierw te, które już minęły, potem najbliższe.
  static PozycjaKalendarza? _najpilniejszy(
    List<PozycjaKalendarza> terminy,
    DateTime teraz,
  ) {
    if (terminy.isEmpty) {
      return null;
    }
    final posortowane = [...terminy]
      ..sort((a, b) => a.dniDo(teraz).compareTo(b.dniDo(teraz)));
    return posortowane.first;
  }

  static String _liczba(double wartosc, {int miejsca = 2}) =>
      wartosc.toStringAsFixed(miejsca).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PodsumowanieSezonu>(
      future: _dane,
      builder: (context, stan) {
        if (!stan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final dane = stan.data!;
        final teksty = Theme.of(context).textTheme;

        return ListView(
          padding: const EdgeInsets.all(MotywNowoczesny.odstep),
          children: [
            Karta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sezon ${dane.sezon}', style: teksty.headlineMedium),
                  const SizedBox(height: MotywNowoczesny.odstep),
                  Row(
                    children: [
                      _Liczba(wartosc: '${dane.pola.length}', opis: 'pól'),
                      _Liczba(
                        wartosc: '${_liczba(dane.powierzchniaHa)} ha',
                        opis: 'użytków rolnych',
                      ),
                      _Liczba(
                        wartosc: '${dane.zabiegiSezonu}',
                        opis: 'zabiegów',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MotywNowoczesny.odstep),
            _KartaAzotu(limit: dane.limit),
            const SizedBox(height: MotywNowoczesny.odstep),
            if (dane.najblizszy != null)
              Karta(
                onTap: widget.onTerminy,
                child: _NajblizszyTermin(
                  pozycja: dane.najblizszy!,
                  teraz: widget.teraz ?? DateTime.now(),
                ),
              )
            else
              Karta(
                onTap: widget.onTerminy,
                child: Text(
                  'Nie ma teraz żadnego terminu do pilnowania.',
                  style: teksty.bodyLarge,
                ),
              ),
            const SizedBox(height: MotywNowoczesny.odstep * 1.5),
            Text('Ostatnie zabiegi', style: teksty.titleLarge),
            const SizedBox(height: 8),
            if (dane.ostatnie.isEmpty)
              const OstrzezenieNowoczesne(
                tresc: 'Nie ma jeszcze żadnego zabiegu.',
                coZrobic: 'Naciśnij „+" na dolnym pasku i zapisz pierwszy.',
              )
            else
              for (final wpis in dane.ostatnie) ...[
                Karta(
                  onTap: widget.onRejestr,
                  child: _Wpis(wpis: wpis),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onRejestr,
                    child: const Text('Wszystkie wpisy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDokumenty,
                    child: const Text('Wydruk i eksport'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Liczba extends StatelessWidget {
  const _Liczba({required this.wartosc, required this.opis});

  final String wartosc;
  final String opis;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(wartosc, style: Theme.of(context).textTheme.titleLarge),
          Text(opis, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Pasek azotu z nawozów naturalnych. Gdy limitu albo zawartości azotu nie
/// znamy, mówimy to wprost — zamiast pokazywać pasek, który kłamie.
class _KartaAzotu extends StatelessWidget {
  const _KartaAzotu({required this.limit});

  final StanLimituAzotu limit;

  static String _liczba(double wartosc) =>
      wartosc.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Karta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Azot z nawozów naturalnych', style: teksty.titleLarge),
          const SizedBox(height: MotywNowoczesny.odstep),
          if (!limit.limitZnany)
            Text(
              'Słownik reguł nie podaje tu limitu — paska nie rysujemy.',
              style: teksty.bodyLarge,
            )
          else
            PasekLimitu(
              udzial: limit.wykorzystanie,
              przekroczony: limit.przekroczony,
              opis:
                  '${_liczba(limit.azotNaturalnyKg)} kg z '
                  '${_liczba(limit.limitKg)} kg na sezon '
                  '(${_liczba(limit.azotNaHektar)} kg/ha)',
            ),
          if (limit.przekroczony) ...[
            const SizedBox(height: MotywNowoczesny.odstep),
            const OstrzezenieNowoczesne(
              tresc: 'Limit azotu z nawozów naturalnych jest przekroczony.',
              coZrobic: 'Sprawdź wpisy nawożenia i omów to z doradcą.',
            ),
          ] else if (limit.blisko) ...[
            const SizedBox(height: MotywNowoczesny.odstep),
            const OstrzezenieNowoczesne(
              tresc: 'Zostało mało azotu do limitu.',
              coZrobic: 'Zaplanuj kolejne nawożenie z zapasem.',
            ),
          ],
          if (!limit.pewny) ...[
            const SizedBox(height: 8),
            Text(
              'Wpisów bez znanej zawartości azotu: ${limit.wpisyBezAzotu}. '
              'Nie doliczamy ich — nie zgadujemy dawek.',
              style: teksty.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _NajblizszyTermin extends StatelessWidget {
  const _NajblizszyTermin({required this.pozycja, required this.teraz});

  final PozycjaKalendarza pozycja;
  final DateTime teraz;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final dni = pozycja.dniDo(teraz);
    final kiedy = switch (dni) {
      0 => 'dziś',
      1 => 'jutro',
      < 0 => 'termin minął ${-dni} dni temu',
      _ => 'za $dni dni',
    };

    return Row(
      children: [
        const Icon(
          Icons.event_outlined,
          color: MotywNowoczesny.zielen,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pozycja.nazwa, style: teksty.titleLarge),
              const SizedBox(height: 2),
              Text('$kiedy • ${pozycja.coZrobic}', style: teksty.bodyMedium),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: MotywNowoczesny.tekstPomocniczy),
      ],
    );
  }
}

class _Wpis extends StatelessWidget {
  const _Wpis({required this.wpis});

  final WpisRejestru wpis;

  static String _dzien(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}.'
      '${data.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final co =
        wpis.oprysk?.srodekNazwa ??
        wpis.nawozenie?.nawozNazwa ??
        wpis.zabieg.rodzaj.dlaRolnika;

    return Row(
      children: [
        Text(_dzien(wpis.zabieg.data), style: teksty.titleLarge),
        const SizedBox(width: MotywNowoczesny.odstep),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(co, style: teksty.bodyLarge),
              Text(
                '${wpis.zabieg.rodzaj.dlaRolnika} • ${wpis.opisPol} • '
                '${wpis.powierzchniaOpis}',
                style: teksty.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
