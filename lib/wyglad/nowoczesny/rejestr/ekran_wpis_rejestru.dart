import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zabiegi/kompletnosc_ewidencji.dart';
import '../../../funkcje/zabiegi/rejestr_zabiegow.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../../../rdzen/wspolne/opis_karencji.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';

/// Jeden wpis rejestru w wyglądzie nowoczesnym: tak, jak ma go zobaczyć
/// kontrola, razem z poprawką i cofnięciem.
///
/// Pola wymagane przez przepis bierzemy ze słownika reguł, więc gdy przepis
/// doda pole, lista rośnie bez zmiany kodu (CLAUDE.md, reguła 1).
class EkranWpisuRejestru extends StatefulWidget {
  const EkranWpisuRejestru({
    super.key,
    required this.uslugi,
    required this.zabiegId,
    this.teraz,
  });

  final Uslugi uslugi;
  final String zabiegId;

  /// Dzień, od którego liczymy karencję; w aplikacji „dzisiaj".
  final DateTime? teraz;

  @override
  State<EkranWpisuRejestru> createState() => _EkranWpisuRejestruState();
}

class _EkranWpisuRejestruState extends State<EkranWpisuRejestru> {
  /// Godzinę przesuwamy kwadransami — rolnik pamięta „około dziesiątej".
  static const int krokMinut = 15;

  late Future<WpisRejestru?> _wpis;
  bool _zmienione = false;
  bool _poprawiam = false;
  bool _zapisuje = false;

  /// Wartości w trakcie poprawki; `null`, dopóki rolnik jej nie otworzył.
  double? _dawka;
  int? _minuty;
  int? _karencjaDni;

  @override
  void initState() {
    super.initState();
    _wpis = widget.uslugi.rejestr.wpis(widget.zabiegId);
  }

  void _odswiez() {
    setState(() {
      _wpis = widget.uslugi.rejestr.wpis(widget.zabiegId);
    });
  }

  static int _zGodziny(String? godzina) {
    final czesci = (godzina ?? '').split(':');
    if (czesci.length != 2) {
      return 12 * 60;
    }
    final h = int.tryParse(czesci[0]) ?? 12;
    final m = int.tryParse(czesci[1]) ?? 0;
    return (h * 60 + m).clamp(0, 24 * 60 - 1);
  }

  static String _godzinaZMinut(int minuty) =>
      '${(minuty ~/ 60).toString().padLeft(2, '0')}:'
      '${(minuty % 60).toString().padLeft(2, '0')}';

  void _otworzPoprawke(WpisRejestru wpis) {
    setState(() {
      _poprawiam = true;
      _dawka = wpis.oprysk?.dawka;
      _minuty = _zGodziny(wpis.zabieg.godzina);
      _karencjaDni = wpis.oprysk?.karencjaDni;
    });
  }

  Future<void> _zapiszPoprawke(WpisRejestru wpis) async {
    if (_zapisuje) {
      return;
    }
    setState(() => _zapisuje = true);
    await widget.uslugi.zabiegi.popraw(
      zabiegId: wpis.zabieg.id,
      urzadzenie: widget.uslugi.urzadzenie,
      godzina: _minuty == null ? null : _godzinaZMinut(_minuty!),
      dawka: _dawka,
    );

    // Karencję zapisujemy osobno: od tej chwili jej źródłem jest rolnik,
    // a nie baza etykiet.
    final oprysk = wpis.oprysk;
    if (oprysk != null &&
        _karencjaDni != null &&
        _karencjaDni != oprysk.karencjaDni) {
      await widget.uslugi.zabiegi.zapiszKarencje(
        zabiegId: wpis.zabieg.id,
        dni: _karencjaDni,
        zrodlo: 'opakowanie, wpisane przez rolnika',
        potwierdzona: true,
        dataEtykiety: oprysk.karencjaDataEtykiety,
        urzadzenie: widget.uslugi.urzadzenie,
      );
    }

    if (mounted) {
      setState(() {
        _zapisuje = false;
        _poprawiam = false;
        _zmienione = true;
      });
      _odswiez();
    }
  }

  Future<void> _potwierdzKarencje(WpisRejestru wpis) async {
    final oprysk = wpis.oprysk;
    if (oprysk == null || oprysk.karencjaDni == null) {
      return;
    }
    await widget.uslugi.zabiegi.zapiszKarencje(
      zabiegId: wpis.zabieg.id,
      dni: oprysk.karencjaDni,
      zrodlo: 'etykieta MRiRW, potwierdzona przez rolnika',
      potwierdzona: true,
      dataEtykiety: oprysk.karencjaDataEtykiety,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (mounted) {
      _zmienione = true;
      _odswiez();
    }
  }

  Future<void> _cofnij() async {
    final potwierdzone = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cofnąć ten wpis?'),
        content: Text(
          'Wpis zniknie z ewidencji, ale zostanie w dzienniku zmian — '
          'kontrola zobaczy, że był i że go cofnięto.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zostaw'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cofnij wpis'),
          ),
        ],
      ),
    );
    if (!(potwierdzone ?? false) || !mounted) {
      return;
    }
    await widget.uslugi.zabiegi.oznaczUsuniety(
      zabiegId: widget.zabiegId,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
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
        appBar: AppBar(title: const Text('Wpis w rejestrze')),
        body: FutureBuilder<WpisRejestru?>(
          future: _wpis,
          builder: (context, stan) {
            if (!stan.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final wpis = stan.data!;
            final teksty = Theme.of(context).textTheme;
            final obowiazek = widget.uslugi.reguly.obowiazek(
              KompletnoscEwidencji.idObowiazku(wpis.zabieg.rodzaj) ?? '',
            );
            final ocena = obowiazek == null
                ? null
                : KompletnoscEwidencji.sprawdz(wpis, obowiazek);

            return ListView(
              padding: const EdgeInsets.all(MotywNowoczesny.odstep),
              children: [
                Karta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${KompletnoscEwidencji.dzien(wpis.zabieg.data)}'
                        '${wpis.zabieg.godzina == null ? '' : ', godz. ${wpis.zabieg.godzina}'}',
                        style: teksty.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${wpis.zabieg.rodzaj.dlaRolnika} • ${wpis.opisPol} • '
                        '${wpis.powierzchniaOpis}',
                        style: teksty.bodyLarge,
                      ),
                    ],
                  ),
                ),
                if (wpis.oprysk case final SzczegolyOprysku oprysk) ...[
                  const SizedBox(height: MotywNowoczesny.odstep),
                  if (wpis.dzienZbioru case final DateTime dzien)
                    OstrzezenieNowoczesne(
                      tresc: wpis.karencjaTrwa(widget.teraz ?? DateTime.now())
                          ? 'Karencja: zbiór najwcześniej '
                                '${KompletnoscEwidencji.dzien(dzien)}.'
                          : 'Karencja minęła '
                                '${KompletnoscEwidencji.dzien(dzien)}.',
                      coZrobic: oprysk.karencjaZrodlo == null
                          ? null
                          : 'Źródło: ${oprysk.karencjaZrodlo}.',
                    )
                  else
                    OstrzezenieNowoczesne(
                      tresc: 'Karencja: ${OpisKarencji.dlaWpisu(oprysk)}',
                      coZrobic:
                          'Przepisz liczbę dni z opakowania — bez niej nie '
                          'policzymy dnia zbioru.',
                    ),
                  if (!oprysk.karencjaPotwierdzona &&
                      oprysk.karencjaDni != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _potwierdzKarencje(wpis),
                      child: const Text('Potwierdzam karencję z etykiety'),
                    ),
                  ],
                ],
                if (ocena != null) ...[
                  const SizedBox(height: MotywNowoczesny.odstep),
                  _Ewidencja(
                    ocena: ocena,
                    wersjaRegul: widget.uslugi.reguly.wersja,
                  ),
                ],
                const SizedBox(height: MotywNowoczesny.odstep),
                if (_poprawiam)
                  _Poprawka(
                    wpis: wpis,
                    dawka: _dawka,
                    minuty: _minuty ?? _zGodziny(wpis.zabieg.godzina),
                    karencjaDni: _karencjaDni,
                    zapisuje: _zapisuje,
                    onDawka: (nowa) => setState(() => _dawka = nowa),
                    onGodzina: (oMinut) => setState(() {
                      _minuty =
                          ((_minuty ?? _zGodziny(wpis.zabieg.godzina)) + oMinut)
                              .clamp(0, 24 * 60 - 1);
                    }),
                    onKarencja: (dni) => setState(() => _karencjaDni = dni),
                    onZapisz: () => _zapiszPoprawke(wpis),
                    onPorzuc: () => setState(() => _poprawiam = false),
                  )
                else ...[
                  FilledButton(
                    onPressed: () => _otworzPoprawke(wpis),
                    child: const Text('Popraw wpis'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _cofnij,
                    child: const Text('Cofnij wpis'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Poprawka wpisu: dawka, godzina i karencja — przyciskami, bez klawiatury.
/// Poprzednie wartości zostają w dzienniku zmian, więc poprawka jest jawna.
class _Poprawka extends StatelessWidget {
  const _Poprawka({
    required this.wpis,
    required this.dawka,
    required this.minuty,
    required this.karencjaDni,
    required this.zapisuje,
    required this.onDawka,
    required this.onGodzina,
    required this.onKarencja,
    required this.onZapisz,
    required this.onPorzuc,
  });

  final WpisRejestru wpis;
  final double? dawka;
  final int minuty;
  final int? karencjaDni;
  final bool zapisuje;
  final ValueChanged<double> onDawka;
  final ValueChanged<int> onGodzina;
  final ValueChanged<int> onKarencja;
  final VoidCallback onZapisz;
  final VoidCallback onPorzuc;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final oprysk = wpis.oprysk;
    final jednostka = [
      oprysk?.dawkaJednostka,
      oprysk?.dawkaOdniesienie,
    ].whereType<String>().join('/');

    return Karta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Poprawka wpisu', style: teksty.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Poprzednie wartości zostają w dzienniku zmian — kontrola widzi '
            'każdą poprawkę.',
            style: teksty.bodyMedium,
          ),
          if (oprysk != null && dawka != null) ...[
            const SizedBox(height: MotywNowoczesny.odstep),
            Text('Dawka', style: teksty.labelLarge),
            WyborLiczbyNowoczesny(
              wartosc: dawka!,
              jednostka: jednostka,
              krok: 0.05,
              onZmiana: onDawka,
            ),
          ],
          const SizedBox(height: MotywNowoczesny.odstep),
          Text('Godzina zabiegu', style: teksty.labelLarge),
          const SizedBox(height: 4),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => onGodzina(-_EkranWpisuRejestruState.krokMinut),
                child: const Text('− 15 min'),
              ),
              Expanded(
                child: Text(
                  _EkranWpisuRejestruState._godzinaZMinut(minuty),
                  textAlign: TextAlign.center,
                  style: teksty.headlineMedium,
                ),
              ),
              OutlinedButton(
                onPressed: () => onGodzina(_EkranWpisuRejestruState.krokMinut),
                child: const Text('+ 15 min'),
              ),
            ],
          ),
          if (oprysk != null) ...[
            const SizedBox(height: MotywNowoczesny.odstep),
            Text('Karencja z opakowania', style: teksty.labelLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () =>
                      onKarencja(((karencjaDni ?? 0) - 1).clamp(0, 365)),
                  child: const Text('−'),
                ),
                Expanded(
                  child: Text(
                    karencjaDni == null ? 'nie znamy' : '$karencjaDni dni',
                    textAlign: TextAlign.center,
                    style: teksty.headlineMedium,
                  ),
                ),
                OutlinedButton(
                  onPressed: () =>
                      onKarencja(((karencjaDni ?? 0) + 1).clamp(0, 365)),
                  child: const Text('+'),
                ),
              ],
            ),
          ],
          const SizedBox(height: MotywNowoczesny.odstep),
          if (zapisuje)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onZapisz,
                    child: const Text('Zapisz poprawkę'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPorzuc,
                    child: const Text('Zostaw bez zmian'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Pola wymagane przepisem: co jest, czego brakuje i czego ta wersja
/// aplikacji nie zna.
class _Ewidencja extends StatelessWidget {
  const _Ewidencja({required this.ocena, required this.wersjaRegul});

  final OcenaEwidencji ocena;
  final String wersjaRegul;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Karta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ocena.obowiazek.nazwa, style: teksty.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Podstawa: ${ocena.obowiazek.podstawa}. '
            'Słownik reguł $wersjaRegul.',
            style: teksty.bodyMedium,
          ),
          const SizedBox(height: MotywNowoczesny.odstep),
          for (final pole in ocena.pola) _PoleEwidencji(ocena: pole),
          const SizedBox(height: 4),
          Text(
            ocena.jednymZdaniem,
            style: teksty.bodyLarge?.copyWith(
              color: ocena.kompletna
                  ? null
                  : MotywNowoczesny.ostrzezenieObramowanie,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoleEwidencji extends StatelessWidget {
  const _PoleEwidencji({required this.ocena});

  final OcenaPola ocena;

  @override
  Widget build(BuildContext context) {
    final (ikona, kolor, tresc) = switch (ocena.stan) {
      StanPola.jest => (
        Icons.check,
        MotywNowoczesny.zielen,
        ocena.wartosc ?? '',
      ),
      StanPola.brak => (
        Icons.priority_high,
        MotywNowoczesny.ostrzezenieObramowanie,
        'brak — uzupełnij',
      ),
      StanPola.nieWiadomo => (
        Icons.help_outline,
        MotywNowoczesny.ostrzezenieObramowanie,
        'tego pola ta wersja aplikacji nie zna — sprawdź sam',
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikona, size: 18, color: kolor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ocena.pole.nazwa,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(tresc, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
