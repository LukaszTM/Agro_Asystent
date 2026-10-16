import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/nawozenie/ewidencja_nawozenia.dart';
import '../../../funkcje/nawozenie/plan_nawozenia.dart';
import '../../../funkcje/nawozenie/terminy_azotowe.dart';
import '../../../rdzen/wspolne/terminy_nawozenia.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import 'ekran_nawozy.dart';

/// Nawożenie w wyglądzie nowoczesnym: limit azotu z nawozów naturalnych,
/// maksymalne dawki dla upraw (tabela 14), terminy jesienne i spis nawozów.
///
/// To zestawienie **nie jest planem nawożenia** — plan układa doradca na
/// podstawie analizy gleby. Aplikacja podaje to, co wie z ewidencji.
class EkranNawozenieNowoczesny extends StatefulWidget {
  const EkranNawozenieNowoczesny({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranNawozenieNowoczesny> createState() =>
      _EkranNawozenieNowoczesnyState();
}

typedef _Dane = ({
  StanLimituAzotu limit,
  ZestawienieAzotu zestawienie,
  List<WpisNawozenia> wpisy,
  TerminyGospodarstwa terminyGmin,
});

class _EkranNawozenieNowoczesnyState extends State<EkranNawozenieNowoczesny> {
  late Future<_Dane> _dane;

  @override
  void initState() {
    super.initState();
    _dane = _policz();
  }

  Future<_Dane> _policz() async {
    final profil = await widget.uslugi.profil.policz(
      widget.uslugi.gospodarstwoId,
    );
    final limit = await widget.uslugi.nawozenie.limitAzotu(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      powierzchniaUrHa: profil.powierzchniaUrHa,
    );
    return (
      limit: limit,
      zestawienie: await widget.uslugi.planNawozenia.zestawienie(
        gospodarstwoId: widget.uslugi.gospodarstwoId,
        profil: profil,
      ),
      wpisy: await widget.uslugi.nawozenie.wpisy(
        widget.uslugi.gospodarstwoId,
        sezon: limit.sezon,
      ),
      terminyGmin: await widget.uslugi.terminyAzotowe.dlaGospodarstwa(
        widget.uslugi.gospodarstwoId,
      ),
    );
  }

  Future<void> _nawozy() async {
    final zmiana = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranNawozyNowoczesny(uslugi: widget.uslugi),
      ),
    );
    if ((zmiana ?? false) && mounted) {
      setState(() {
        _dane = _policz();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nawożenie')),
      body: FutureBuilder<_Dane>(
        future: _dane,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final limit = stan.data!.limit;
          final zestawienie = stan.data!.zestawienie;
          final wpisy = stan.data!.wpisy;

          return ListView(
            padding: const EdgeInsets.all(MotywNowoczesny.odstep),
            children: [
              _KartaLimitu(limit: limit),
              const SizedBox(height: MotywNowoczesny.odstep),
              if (zestawienie.planWymagany || zestawienie.planNiepewny) ...[
                OstrzezenieNowoczesne(
                  tresc: zestawienie.planNiepewny
                      ? 'Nie wiemy, czy musisz mieć plan nawożenia azotem.'
                      : 'Twoje gospodarstwo musi mieć plan nawożenia azotem.',
                  coZrobic: zestawienie.planNiepewny
                      ? 'Sprawdź u doradcy — próg dotyczy '
                            '${zestawienie.kogoDotyczyPlan}.'
                      : 'Plan sporządza doradca na podstawie analizy gleby. '
                            'To zestawienie weź ze sobą.',
                ),
                const SizedBox(height: MotywNowoczesny.odstep),
              ],
              KartaTerminowNawozenia(
                terminy: widget.uslugi.reguly.terminyNawozenia,
                zasady: widget.uslugi.reguly.zasadyNawozeniaAzotem,
                wGminach: stan.data!.terminyGmin,
                styl: const StylKarty(
                  tlo: MotywNowoczesny.karta,
                  obramowanie: MotywNowoczesny.karta,
                  zaokraglenie: MotywNowoczesny.zaokraglenieKarty,
                  odstep: MotywNowoczesny.odstep,
                  grubosc: 0,
                ),
                ostrzezenie: (tresc, coZrobic) =>
                    OstrzezenieNowoczesne(tresc: tresc, coZrobic: coZrobic),
              ),
              const SizedBox(height: MotywNowoczesny.odstep),
              Text(
                'Azot na polach w ${zestawienie.sezon} r.',
                style: teksty.titleLarge,
              ),
              const SizedBox(height: 8),
              if (zestawienie.polaPonadLimit.isNotEmpty) ...[
                OstrzezenieNowoczesne(
                  tresc:
                      'Na ${zestawienie.polaPonadLimit.length} '
                      '${zestawienie.polaPonadLimit.length == 1 ? 'polu' : 'polach'} '
                      'azotu jest więcej, niż wolno dać pod tę uprawę.',
                  coZrobic:
                      'Sprawdź pola oznaczone niżej. Na glebach lekkich '
                      'limit jest jeszcze niższy — zapytaj doradcy.',
                ),
                const SizedBox(height: 8),
              ],
              if (zestawienie.pola.isEmpty)
                const OstrzezenieNowoczesne(
                  tresc: 'Nie ma jeszcze pól w tym sezonie.',
                  coZrobic:
                      'Dodaj pole w zakładce „Pola" albo wczytaj wniosek '
                      'z PDF.',
                )
              else
                for (final pole in zestawienie.pola) ...[
                  Karta(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pole.nazwa, style: teksty.bodyLarge),
                              Text(
                                '${pole.uprawa} • '
                                '${pole.powierzchniaHa.toStringAsFixed(2).replaceAll('.', ',')} ha',
                                style: teksty.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              pole.limit.kgNHa == null
                                  ? '${pole.azotKgNaHa.toStringAsFixed(0)} kg N/ha'
                                  : '${pole.azotKgNaHa.toStringAsFixed(0)} '
                                        'z ${pole.limit.kgNHa} kg N/ha',
                              style: teksty.bodyLarge?.copyWith(
                                color: pole.limitPrzekroczony
                                    ? MotywNowoczesny.ostrzezenieObramowanie
                                    : MotywNowoczesny.tekst,
                              ),
                            ),
                            if (pole.limitPrzekroczony)
                              Text(
                                'ponad limit',
                                style: teksty.bodyMedium?.copyWith(
                                  color: MotywNowoczesny.ostrzezenieObramowanie,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 8),
              Text(
                'Zestawienie pokazuje, co zapisałeś w aplikacji. Nie '
                'zastępuje planu nawożenia — plan układa doradca.',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: MotywNowoczesny.odstep),
              Text('Ostatnie nawożenia', style: teksty.titleLarge),
              const SizedBox(height: 8),
              if (wpisy.isEmpty)
                const OstrzezenieNowoczesne(
                  tresc: 'Brak wpisów w tym sezonie.',
                  coZrobic: 'Nawożenie zapisujesz przyciskiem „+".',
                )
              else
                for (final wpis in wpisy.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${wpis.data.day.toString().padLeft(2, '0')}.'
                      '${wpis.data.month.toString().padLeft(2, '0')} • '
                      '${wpis.nawozNazwa} • '
                      '${wpis.azotKgHa == null ? 'azot nieznany' : '${wpis.azotKgHa!.toStringAsFixed(0)} kg N/ha'}',
                      style: teksty.bodyLarge,
                    ),
                  ),
              const SizedBox(height: MotywNowoczesny.odstep),
              OutlinedButton.icon(
                onPressed: _nawozy,
                icon: const Icon(Icons.inventory_2_outlined, size: 20),
                label: const Text('Nawozy i zawartość azotu'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Limit azotu z nawozów naturalnych — 170 kg N/ha ze słownika reguł.
class _KartaLimitu extends StatelessWidget {
  const _KartaLimitu({required this.limit});

  final StanLimituAzotu limit;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    if (!limit.limitZnany) {
      return const OstrzezenieNowoczesne(
        tresc: 'Słownik reguł nie podaje limitu azotu.',
        coZrobic: 'Zaktualizuj dane aplikacji.',
      );
    }

    return Karta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Azot z nawozów naturalnych', style: teksty.titleLarge),
          const SizedBox(height: 8),
          Text(
            '${limit.azotNaHektar.toStringAsFixed(0)} '
            'z ${limit.limitKgNaHa.toStringAsFixed(0)} kg N/ha '
            'w ${limit.sezon} r.',
            style: teksty.bodyLarge,
          ),
          const SizedBox(height: 8),
          PasekLimitu(
            udzial: limit.wykorzystanie,
            przekroczony: limit.przekroczony,
            opis: limit.przekroczony
                ? 'Limit przekroczony. Nie stosuj więcej nawozów '
                      'naturalnych w tym roku.'
                : 'Zostało ${limit.pozostaloKg.toStringAsFixed(0)} kg azotu '
                      'na całe gospodarstwo.',
          ),
          if (!limit.pewny) ...[
            const SizedBox(height: 8),
            Text(
              '${limit.wpisyBezAzotu} wpisów ma nawóz bez znanej zawartości '
              'azotu — te nie są policzone.',
              style: teksty.bodyMedium?.copyWith(
                color: MotywNowoczesny.ostrzezenieObramowanie,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
