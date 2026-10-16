import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/nawozenie/ewidencja_nawozenia.dart';
import '../../../funkcje/nawozenie/plan_nawozenia.dart';
import '../../../funkcje/nawozenie/terminy_azotowe.dart';
import '../../../rdzen/reguly/regula_prawna.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_nawozy.dart';

/// Nawożenie: ile azotu już poszło na pola, ile zostało do limitu i czy
/// przepis wymaga planu nawożenia (krok 6 etapu 1).
class EkranNawozenie extends StatefulWidget {
  const EkranNawozenie({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranNawozenie> createState() => _EkranNawozenieState();
}

class _EkranNawozenieState extends State<EkranNawozenie> {
  late Future<
    ({
      StanLimituAzotu limit,
      ZestawienieAzotu zestawienie,
      List<WpisNawozenia> wpisy,
      TerminyGospodarstwa terminyGmin,
    })
  >
  _dane;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _dane = _policz();
  }

  Future<
    ({
      StanLimituAzotu limit,
      ZestawienieAzotu zestawienie,
      List<WpisNawozenia> wpisy,
      TerminyGospodarstwa terminyGmin,
    })
  >
  _policz() async {
    final profil = await widget.uslugi.profil.policz(
      widget.uslugi.gospodarstwoId,
    );
    final limit = await widget.uslugi.nawozenie.limitAzotu(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      powierzchniaUrHa: profil.powierzchniaUrHa,
    );
    final zestawienie = await widget.uslugi.planNawozenia.zestawienie(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      profil: profil,
    );
    final wpisy = await widget.uslugi.nawozenie.wpisy(
      widget.uslugi.gospodarstwoId,
      sezon: limit.sezon,
    );
    final terminyGmin = await widget.uslugi.terminyAzotowe.dlaGospodarstwa(
      widget.uslugi.gospodarstwoId,
    );
    return (
      limit: limit,
      zestawienie: zestawienie,
      wpisy: wpisy,
      terminyGmin: terminyGmin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nawożenie')),
      body:
          FutureBuilder<
            ({
              StanLimituAzotu limit,
              ZestawienieAzotu zestawienie,
              List<WpisNawozenia> wpisy,
              TerminyGospodarstwa terminyGmin,
            })
          >(
            future: _dane,
            builder: (context, stan) {
              if (!stan.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final limit = stan.data!.limit;
              final zestawienie = stan.data!.zestawienie;
              final wpisy = stan.data!.wpisy;

              return ListView(
                padding: const EdgeInsets.all(MotywProsty.odstep),
                children: [
                  _Limit(limit: limit),
                  const SizedBox(height: MotywProsty.odstep),
                  if (zestawienie.planWymagany || zestawienie.planNiepewny) ...[
                    Ostrzezenie(
                      tresc: zestawienie.planNiepewny
                          ? 'Nie wiemy, czy musisz mieć plan nawożenia azotem.'
                          : 'Twoje gospodarstwo musi mieć plan nawożenia azotem.',
                      coZrobic: zestawienie.planNiepewny
                          ? 'Sprawdź u doradcy — próg dotyczy ${zestawienie.kogoDotyczyPlan}.'
                          : 'Plan sporządza doradca na podstawie analizy gleby. '
                                'Poniższe zestawienie weź ze sobą.',
                    ),
                    const SizedBox(height: MotywProsty.odstep),
                  ],
                  _TerminyJesienne(
                    terminy: widget.uslugi.reguly.terminyNawozenia,
                    zasady: widget.uslugi.reguly.zasadyNawozeniaAzotem,
                    wGminach: stan.data!.terminyGmin,
                  ),
                  const SizedBox(height: MotywProsty.odstep),
                  Text(
                    'Azot na polach w ${zestawienie.sezon} r.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (zestawienie.pola.isEmpty)
                    Text(
                      'Nie ma jeszcze pól w tym sezonie.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  else
                    for (final pole in zestawienie.pola)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pole.nazwa,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge,
                                  ),
                                  Text(
                                    '${pole.uprawa} • '
                                    '${pole.powierzchniaHa.toStringAsFixed(2).replaceAll('.', ',')} ha',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${pole.azotKgNaHa.toStringAsFixed(0)} kg N/ha',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: MotywProsty.odstep),
                  Text(
                    'Zestawienie pokazuje, co zapisałeś w aplikacji. Nie zastępuje '
                    'planu nawożenia — plan układa doradca.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: MotywProsty.odstep),
                  Text(
                    'Ostatnie nawożenia',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (wpisy.isEmpty)
                    Text(
                      'Brak wpisów w tym sezonie. Nawożenie zapisujesz przez '
                      '„Dodaj zabieg".',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  else
                    for (final wpis in wpisy.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${wpis.data.day.toString().padLeft(2, '0')}.'
                          '${wpis.data.month.toString().padLeft(2, '0')} • '
                          '${wpis.nawozNazwa} • '
                          '${wpis.azotKgHa == null ? 'azot nieznany' : '${wpis.azotKgHa!.toStringAsFixed(0)} kg N/ha'}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                  const SizedBox(height: MotywProsty.odstep),
                  DuzyPrzycisk(
                    etykieta: 'Nawozy',
                    opis: 'spis nawozów i zawartość azotu',
                    ikona: Icons.inventory_2_outlined,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EkranNawozy(uslugi: widget.uslugi),
                        ),
                      );
                      if (mounted) {
                        setState(_odswiez);
                      }
                    },
                  ),
                ],
              );
            },
          ),
    );
  }
}

/// Pasek limitu azotu z nawozów naturalnych.
class _Limit extends StatelessWidget {
  const _Limit({required this.limit});

  final StanLimituAzotu limit;

  @override
  Widget build(BuildContext context) {
    if (!limit.limitZnany) {
      return const Ostrzezenie(
        tresc: 'Słownik reguł nie podaje limitu azotu.',
        coZrobic: 'Zaktualizuj dane aplikacji.',
      );
    }

    final kolor = limit.przekroczony
        ? MotywProsty.ostrzezenieObramowanie
        : MotywProsty.zielenAkcji;

    return Container(
      padding: const EdgeInsets.all(MotywProsty.odstep),
      decoration: BoxDecoration(
        color: limit.przekroczony
            ? MotywProsty.ostrzezenieTlo
            : MotywProsty.powierzchnia,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieDuze),
        border: Border.all(
          color: limit.przekroczony
              ? MotywProsty.ostrzezenieObramowanie
              : MotywProsty.powierzchniaDruga,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Azot z nawozów naturalnych',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${limit.azotNaHektar.toStringAsFixed(0)} '
            'z ${limit.limitKgNaHa.toStringAsFixed(0)} kg N/ha '
            'w ${limit.sezon} r.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: limit.wykorzystanie.clamp(0, 1),
              minHeight: 16,
              backgroundColor: MotywProsty.powierzchniaDruga,
              valueColor: AlwaysStoppedAnimation<Color>(kolor),
            ),
          ),
          const SizedBox(height: 8),
          if (limit.przekroczony)
            Text(
              'Limit przekroczony. Nie stosuj więcej nawozów naturalnych '
              'w tym roku.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else if (limit.blisko)
            Text(
              'Zostało mało: ${limit.pozostaloKg.toStringAsFixed(0)} kg azotu '
              'na całe gospodarstwo.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            Text(
              'Zostało ${limit.pozostaloKg.toStringAsFixed(0)} kg azotu '
              'na całe gospodarstwo.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if (!limit.pewny) ...[
            const SizedBox(height: 8),
            Text(
              '${limit.wpisyBezAzotu} wpisów ma nawóz bez znanej zawartości '
              'azotu — te nie są policzone.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: MotywProsty.ostrzezenieObramowanie),
            ),
          ],
        ],
      ),
    );
  }
}

/// Do kiedy wolno stosować nawozy azotowe — z rozbiciem na rodzaj nawozu
/// i rodzaj gruntu, bo przepis daje inną datę dla obornika i dla gnojowicy.
///
/// Dla gruntów ornych termin zależy od gminy: wykazy z załączników do
/// programu azotanowego są danymi, a kod tylko dopasowuje gminę działki.
class _TerminyJesienne extends StatelessWidget {
  const _TerminyJesienne({
    required this.terminy,
    required this.zasady,
    required this.wGminach,
  });

  final List<Termin> terminy;
  final ZasadyNawozeniaAzotem zasady;
  final TerminyGospodarstwa wGminach;

  static String _dzien(String dataRoczna) {
    final czesci = dataRoczna.split('-');
    if (czesci.length != 2) {
      return dataRoczna;
    }
    const miesiace = [
      'stycznia',
      'lutego',
      'marca',
      'kwietnia',
      'maja',
      'czerwca',
      'lipca',
      'sierpnia',
      'września',
      'października',
      'listopada',
      'grudnia',
    ];
    final miesiac = int.tryParse(czesci.first);
    final dzien = int.tryParse(czesci.last);
    if (miesiac == null || dzien == null || miesiac < 1 || miesiac > 12) {
      return dataRoczna;
    }
    return '$dzien ${miesiace[miesiac - 1]}';
  }

  /// Data dla tego terminu: z wykazu gmin, gdy przepis go przewiduje
  /// i gminy działek są znane; inaczej domyślna ze słownika.
  String? _data(Termin termin) {
    if (termin.wariantyGmin != null && !wGminach.pusty) {
      return wGminach.najwczesniejszy;
    }
    return termin.dataRoczna;
  }

  @override
  Widget build(BuildContext context) {
    if (terminy.isEmpty) {
      return const SizedBox.shrink();
    }
    final niepewne =
        zasady.doWeryfikacji || terminy.any((t) => t.doWeryfikacji);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MotywProsty.odstep),
      decoration: BoxDecoration(
        color: MotywProsty.powierzchnia,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieDuze),
        border: Border.all(color: MotywProsty.powierzchniaDruga, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Do kiedy wolno nawozić',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final termin in terminy) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${termin.coToZaNawoz ?? termin.nazwa}: '
                    'do ${_dzien(_data(termin) ?? '')}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    termin.rodzajGruntu == 'grunty_orne'
                        ? 'grunty orne'
                        : 'łąki, pastwiska, uprawy wieloletnie i trwałe',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
          if (wGminach.rozneTerminy) ...[
            const SizedBox(height: 4),
            Text(
              'Twoje działki leżą w gminach o różnych terminach. '
              'Powyżej stoi najwcześniejszy — pilnuj go, albo sprawdź '
              'termin osobno dla każdego pola.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (wGminach.dzialkiBezKoduGminy > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Przy ${wGminach.dzialkiBezKoduGminy} działkach nie rozpoznaliśmy '
              'gminy — dla nich termin może być inny.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          for (final zakaz in zasady.zakazy) ...[
            const SizedBox(height: MotywProsty.odstep),
            Ostrzezenie(tresc: zakaz.nazwa, coZrobic: zakaz.opis),
          ],
          for (final odstepstwo in zasady.odstepstwa) ...[
            const SizedBox(height: MotywProsty.odstep),
            Text(
              '${odstepstwo.nazwa} — wolno do '
              '${_dzien(odstepstwo.doDnia ?? '')}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              odstepstwo.kiedy,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (odstepstwo.limitAzotuKgNaHa != null)
              Text(
                'Najwyżej ${odstepstwo.limitAzotuKgNaHa!.toStringAsFixed(0)} '
                'kg N/ha — ${odstepstwo.limitDotyczy ?? ''}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (odstepstwo.wymagaDokumentowania)
              Text(
                'Trzeba zapisać: ${odstepstwo.wymaganeZapisy.join(', ')}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
          if (niepewne) ...[
            const SizedBox(height: MotywProsty.odstep),
            const Ostrzezenie(
              tresc: 'Daty pochodzą ze streszczenia ministerstwa.',
              coZrobic:
                  'Potwierdź u doradcy, zanim wyjedziesz w pole — wykaz gmin '
                  'jest z rozporządzenia, same daty nie.',
            ),
          ],
        ],
      ),
    );
  }
}
