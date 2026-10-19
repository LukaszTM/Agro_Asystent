import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/terminy/kalendarz_terminow.dart';
import '../../../funkcje/terminy/przypomnienia.dart';
import '../motyw.dart';
import '../warunkowosc/ekran_warunkowosc.dart';
import '../widgety/karta.dart';

/// Zakładka „Terminy" wyglądu nowoczesnego.
///
/// Te same pozycje co w wyglądzie prostym — kalendarz liczy je w
/// `lib/funkcje/terminy/`, wygląd tylko je pokazuje.
class WidokTerminy extends StatefulWidget {
  const WidokTerminy({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;

  /// Dzień, od którego liczymy terminy. W aplikacji „dzisiaj"; testy podają
  /// stałą datę, żeby wynik nie zmieniał się z dnia na dzień.
  final DateTime? teraz;

  @override
  State<WidokTerminy> createState() => _WidokTerminyState();
}

class _WidokTerminyState extends State<WidokTerminy> {
  late Future<List<PozycjaKalendarza>> _pozycje;
  late Future<bool> _przypomnieniaWlaczone;
  bool _przelaczam = false;

  DateTime get _teraz => widget.teraz ?? DateTime.now();

  static const List<(PilnoscTerminu, String)> _grupy = [
    (PilnoscTerminu.minelo, 'Termin już minął'),
    (PilnoscTerminu.dzis, 'Dziś'),
    (PilnoscTerminu.wTymTygodniu, 'W tym tygodniu'),
    (PilnoscTerminu.wTymMiesiacu, 'W tym miesiącu'),
    (PilnoscTerminu.pozniej, 'Później'),
  ];

  @override
  void initState() {
    super.initState();
    _pozycje = _policz();
    _przypomnieniaWlaczone = widget.uslugi.ustawieniaPrzypomnien.czyWlaczone();
  }

  Future<List<PozycjaKalendarza>> _policz() async {
    final profil = await widget.uslugi.profil.policz(
      widget.uslugi.gospodarstwoId,
    );
    return widget.uslugi.kalendarz.najblizsze(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      profil: profil,
      teraz: widget.teraz,
    );
  }

  Future<void> _przelacz({required bool wlacz}) async {
    if (_przelaczam) {
      return;
    }
    setState(() => _przelaczam = true);
    try {
      if (!wlacz) {
        await widget.uslugi.przypomnienia.wylacz();
        await widget.uslugi.ustawieniaPrzypomnien.zapisz(wlaczone: false);
        if (mounted) {
          setState(() {
            _przypomnieniaWlaczone = Future<bool>.value(false);
          });
        }
        return;
      }

      final wolno =
          await widget.uslugi.przypomnienia.czyWolno() ||
          await widget.uslugi.przypomnienia.popros();
      if (!wolno) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Telefon nie pozwala na powiadomienia. Włącz je w '
                'ustawieniach telefonu dla aplikacji Mój Łan.',
              ),
            ),
          );
        }
        return;
      }

      await widget.uslugi.przypomnienia.zaplanuj(
        PlanPrzypomnien.uloz(await _pozycje, teraz: _teraz),
      );
      await widget.uslugi.ustawieniaPrzypomnien.zapisz(wlaczone: true);
      if (mounted) {
        setState(() {
          _przypomnieniaWlaczone = Future<bool>.value(true);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _przelaczam = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PozycjaKalendarza>>(
      future: _pozycje,
      builder: (context, stan) {
        if (!stan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pozycje = stan.data!;
        final teraz = _teraz;

        return ListView(
          padding: const EdgeInsets.all(MotywNowoczesny.odstep),
          children: [
            // Warunkowość to obowiązki bez dat — stan norm GAEC zależy od
            // upraw i wpisów, nie od kalendarza. Wejście stoi tam, gdzie
            // rolnik szuka obowiązków.
            Karta(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EkranWarunkowoscNowoczesny(
                    uslugi: widget.uslugi,
                    teraz: widget.teraz,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.rule_outlined,
                    size: 20,
                    color: MotywNowoczesny.tekstPomocniczy,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Warunkowość',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'Stan norm GAEC i wydruk na kontrolę.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Karta(
              child: FutureBuilder<bool>(
                future: _przypomnieniaWlaczone,
                builder: (context, stanPrzypomnien) {
                  final wlaczone = stanPrzypomnien.data ?? false;
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Przypominaj o terminach',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              wlaczone
                                  ? 'Telefon odezwie się trzy dni przed '
                                        'terminem i w dniu terminu.'
                                  : 'Telefon nie będzie przypominał.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (_przelaczam)
                        const SizedBox(
                          width: MotywNowoczesny.minCelDotyku,
                          height: MotywNowoczesny.minCelDotyku,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Switch(
                          value: wlaczone,
                          onChanged: (wlacz) => _przelacz(wlacz: wlacz),
                          activeThumbColor: MotywNowoczesny.zielen,
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: MotywNowoczesny.odstep),
            if (pozycje.isEmpty)
              const OstrzezenieNowoczesne(
                tresc: 'Nie ma teraz żadnego terminu do pilnowania.',
                coZrobic:
                    'Zajrzyj tu po dodaniu pól albo po pierwszym oprysku — '
                    'karencje liczą się same.',
              )
            else
              for (final (pilnosc, naglowek) in _grupy)
                ..._sekcja(context, pilnosc, naglowek, pozycje, teraz),
          ],
        );
      },
    );
  }

  List<Widget> _sekcja(
    BuildContext context,
    PilnoscTerminu pilnosc,
    String naglowek,
    List<PozycjaKalendarza> wszystkie,
    DateTime teraz,
  ) {
    final pozycje = wszystkie
        .where((p) => p.pilnosc(teraz) == pilnosc)
        .toList(growable: false);
    if (pozycje.isEmpty) {
      return const [];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(naglowek, style: Theme.of(context).textTheme.titleLarge),
      ),
      for (final pozycja in pozycje) ...[
        _Termin(pozycja: pozycja, teraz: teraz),
        const SizedBox(height: 8),
      ],
    ];
  }
}

class _Termin extends StatelessWidget {
  const _Termin({required this.pozycja, required this.teraz});

  final PozycjaKalendarza pozycja;
  final DateTime teraz;

  static String _dzien(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}.'
      '${data.month.toString().padLeft(2, '0')}.${data.year}';

  String get _kiedy {
    if (pozycja.trwa(teraz) && pozycja.doKiedy != null) {
      return 'trwa do ${_dzien(pozycja.doKiedy!)}';
    }
    final dni = pozycja.dniDo(teraz);
    final data = _dzien(pozycja.data);
    return switch (dni) {
      0 => 'dziś, $data',
      1 => 'jutro, $data',
      < 0 => 'minął $data',
      _ => 'za $dni dni, $data',
    };
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final pilne = switch (pozycja.pilnosc(teraz)) {
      PilnoscTerminu.minelo || PilnoscTerminu.dzis => true,
      _ => false,
    };

    final tresc = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              pozycja.zrodlo == ZrodloTerminu.karencja
                  ? Icons.grass_outlined
                  : Icons.event_outlined,
              size: 20,
              color: pilne
                  ? MotywNowoczesny.ostrzezenieObramowanie
                  : MotywNowoczesny.zielen,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(pozycja.nazwa, style: teksty.titleLarge)),
          ],
        ),
        const SizedBox(height: 6),
        Text(_kiedy, style: teksty.bodyLarge),
        Text(pozycja.coZrobic, style: teksty.bodyLarge),
        if (pozycja.uwagi.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(pozycja.uwagi, style: teksty.bodyMedium),
        ],
        if (pozycja.doWeryfikacji || pozycja.obowiazekNiepewny) ...[
          const SizedBox(height: 6),
          Text(
            pozycja.obowiazekNiepewny
                ? 'Nie wiemy, czy ten obowiązek dotyczy Twojego '
                      'gospodarstwa — sprawdź u doradcy.'
                : 'Ten termin wymaga potwierdzenia u doradcy.',
            style: teksty.bodyMedium?.copyWith(
              color: MotywNowoczesny.ostrzezenieObramowanie,
            ),
          ),
        ],
      ],
    );

    if (!pilne) {
      return Karta(child: tresc);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MotywNowoczesny.odstep),
      decoration: BoxDecoration(
        color: MotywNowoczesny.ostrzezenieTlo,
        borderRadius: BorderRadius.circular(MotywNowoczesny.zaokraglenieKarty),
        border: Border.all(
          color: MotywNowoczesny.ostrzezenieObramowanie,
          width: 1.5,
        ),
      ),
      child: tresc,
    );
  }
}
