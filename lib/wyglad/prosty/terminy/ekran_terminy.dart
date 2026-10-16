import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/terminy/kalendarz_terminow.dart';
import '../../../funkcje/terminy/przypomnienia.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';

/// Kalendarz obowiązków: co trzeba zrobić i do kiedy (krok 5 etapu 1).
///
/// Terminy pochodzą ze słownika reguł i z karencji po własnych zabiegach.
/// Każdy ma jedno zdanie „co zrobić" — zgodnie z zasadą z planu (pkt 5).
class EkranTerminy extends StatefulWidget {
  const EkranTerminy({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;

  /// Dzień, od którego liczymy terminy. W aplikacji zawsze „dzisiaj";
  /// testy podają stałą datę, żeby wynik nie zmieniał się z dnia na dzień.
  final DateTime? teraz;

  @override
  State<EkranTerminy> createState() => _EkranTerminyState();
}

class _EkranTerminyState extends State<EkranTerminy> {
  late Future<List<PozycjaKalendarza>> _pozycje;

  DateTime get _teraz => widget.teraz ?? DateTime.now();

  late Future<bool> _przypomnieniaWlaczone;
  bool _przelaczam = false;

  @override
  void initState() {
    super.initState();
    _odswiez();
    _przypomnieniaWlaczone = widget.uslugi.ustawieniaPrzypomnien.czyWlaczone();
  }

  void _odswiez() {
    _pozycje = _policz();
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

  Future<void> _przelaczPrzypomnienia({required bool wlacz}) async {
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
            SnackBar(
              content: Text(
                'Telefon nie pozwala na powiadomienia. Włącz je w ustawieniach '
                'telefonu dla Agro Asystenta.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: MotywProsty.powierzchnia),
              ),
            ),
          );
        }
        return;
      }

      final pozycje = await _pozycje;
      await widget.uslugi.przypomnienia.zaplanuj(
        PlanPrzypomnien.uloz(pozycje, teraz: _teraz),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Terminy')),
      body: FutureBuilder<List<PozycjaKalendarza>>(
        future: _pozycje,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pozycje = stan.data!;
          final teraz = _teraz;

          return ListView(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            children: [
              _PrzelacznikPrzypomnien(
                wlaczone: _przypomnieniaWlaczone,
                pracuje: _przelaczam,
                onZmiana: (wlacz) => _przelaczPrzypomnienia(wlacz: wlacz),
              ),
              const SizedBox(height: MotywProsty.odstep),
              if (pozycje.isEmpty)
                const Ostrzezenie(
                  tresc: 'Nie ma teraz żadnego terminu do pilnowania.',
                  coZrobic:
                      'Zajrzyj tu po dodaniu pól albo po pierwszym '
                      'oprysku — karencje liczą się same.',
                )
              else
                for (final grupa in _grupy)
                  ..._sekcja(context, grupa, pozycje, teraz),
            ],
          );
        },
      ),
    );
  }

  static const List<(PilnoscTerminu, String)> _grupy = [
    (PilnoscTerminu.minelo, 'Termin już minął'),
    (PilnoscTerminu.dzis, 'Dziś'),
    (PilnoscTerminu.wTymTygodniu, 'W tym tygodniu'),
    (PilnoscTerminu.wTymMiesiacu, 'W tym miesiącu'),
    (PilnoscTerminu.pozniej, 'Później'),
  ];

  List<Widget> _sekcja(
    BuildContext context,
    (PilnoscTerminu, String) grupa,
    List<PozycjaKalendarza> wszystkie,
    DateTime teraz,
  ) {
    final pozycje = wszystkie
        .where((p) => p.pilnosc(teraz) == grupa.$1)
        .toList(growable: false);
    if (pozycje.isEmpty) {
      return const [];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(grupa.$2, style: Theme.of(context).textTheme.titleLarge),
      ),
      for (final pozycja in pozycje) ...[
        _Termin(pozycja: pozycja, teraz: teraz),
        const SizedBox(height: MotywProsty.odstep),
      ],
    ];
  }
}

class _PrzelacznikPrzypomnien extends StatelessWidget {
  const _PrzelacznikPrzypomnien({
    required this.wlaczone,
    required this.pracuje,
    required this.onZmiana,
  });

  final Future<bool> wlaczone;
  final bool pracuje;
  final void Function(bool) onZmiana;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: wlaczone,
      builder: (context, stan) {
        final wlaczone = stan.data ?? false;
        return Container(
          padding: const EdgeInsets.all(MotywProsty.odstep),
          decoration: BoxDecoration(
            color: MotywProsty.powierzchnia,
            borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieDuze),
            border: Border.all(color: MotywProsty.powierzchniaDruga, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Przypominaj o terminach',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wlaczone
                          ? 'Telefon odezwie się rano, trzy dni przed terminem '
                                'i w dniu terminu.'
                          : 'Telefon nie będzie przypominał.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (pracuje)
                const Padding(
                  padding: EdgeInsets.only(left: MotywProsty.odstep),
                  child: CircularProgressIndicator(),
                )
              else
                Switch(
                  value: wlaczone,
                  onChanged: onZmiana,
                  activeThumbColor: MotywProsty.zielenAkcji,
                ),
            ],
          ),
        );
      },
    );
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
    if (dni == 0) {
      return 'dziś, $data';
    }
    if (dni < 0) {
      return 'minął $data';
    }
    if (dni == 1) {
      return 'jutro, $data';
    }
    return 'za $dni dni, $data';
  }

  @override
  Widget build(BuildContext context) {
    final pilne =
        pozycja.pilnosc(teraz) == PilnoscTerminu.dzis ||
        pozycja.pilnosc(teraz) == PilnoscTerminu.minelo;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MotywProsty.odstep),
      decoration: BoxDecoration(
        color: pilne ? MotywProsty.ostrzezenieTlo : MotywProsty.powierzchnia,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieDuze),
        border: Border.all(
          color: pilne
              ? MotywProsty.ostrzezenieObramowanie
              : MotywProsty.powierzchniaDruga,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                pozycja.zrodlo == ZrodloTerminu.karencja
                    ? Icons.grass_outlined
                    : Icons.event_outlined,
                size: 32,
                color: MotywProsty.zielenAkcji,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pozycja.nazwa,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_kiedy, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(pozycja.coZrobic, style: Theme.of(context).textTheme.bodyLarge),
          if (pozycja.uwagi.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(pozycja.uwagi, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (pozycja.doWeryfikacji || pozycja.obowiazekNiepewny) ...[
            const SizedBox(height: 8),
            Text(
              pozycja.obowiazekNiepewny
                  ? 'Nie wiemy, czy ten obowiązek dotyczy Twojego '
                        'gospodarstwa — sprawdź u doradcy.'
                  : 'Ten termin wymaga potwierdzenia u doradcy.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: MotywProsty.ostrzezenieObramowanie),
            ),
          ],
        ],
      ),
    );
  }
}
