import 'package:flutter/material.dart';

import '../motyw.dart';
import 'klawiatura_numeru.dart';

/// Wybór liczby przyciskami „+" i „−" — bez klawiatury (plan, pkt 5).
///
/// Dotknięcie liczby otwiera dużą klawiaturę numeryczną: gdy dawka różni
/// się znacznie od wyjściowej, wpisanie jej jest szybsze niż wiele
/// dotknięć „+".
class WyborLiczby extends StatelessWidget {
  const WyborLiczby({
    super.key,
    required this.wartosc,
    required this.onZmiana,
    required this.jednostka,
    this.krok = 0.05,
    this.minimum = 0,
    this.maksimum,
    this.opisMaksimum,
  });

  final double wartosc;
  final double krok;
  final double minimum;
  final double? maksimum;
  final String jednostka;
  final String? opisMaksimum;
  final ValueChanged<double> onZmiana;

  bool get _przekroczonoMaksimum =>
      maksimum != null && wartosc > maksimum! + 1e-9;

  static String napis(double wartosc) =>
      wartosc.toStringAsFixed(2).replaceAll('.', ',');

  Future<void> _wpisz(BuildContext context) async {
    final nowa = await wpiszLiczbe(
      context,
      wartosc: wartosc,
      jednostka: jednostka,
      minimum: minimum,
    );
    if (nowa != null) onZmiana(nowa);
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Przycisk(
              znak: '−',
              etykieta: 'Mniej',
              onTap: wartosc - krok < minimum
                  ? null
                  : () => onZmiana(
                      double.parse((wartosc - krok).toStringAsFixed(3)),
                    ),
            ),
            Expanded(
              child: Column(
                children: [
                  Semantics(
                    button: true,
                    label: 'Wpisz liczbę z klawiatury',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        MotywProsty.zaokraglenieMale,
                      ),
                      onTap: () => _wpisz(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${napis(wartosc)} $jednostka',
                          textAlign: TextAlign.center,
                          style: teksty.displayLarge?.copyWith(
                            color: _przekroczonoMaksimum
                                ? MotywProsty.ostrzezenieObramowanie
                                : MotywProsty.tekst,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    opisMaksimum ?? 'dotknij liczby, żeby ją wpisać',
                    textAlign: TextAlign.center,
                    style: teksty.bodyMedium,
                  ),
                ],
              ),
            ),
            _Przycisk(
              znak: '+',
              etykieta: 'Więcej',
              onTap: () =>
                  onZmiana(double.parse((wartosc + krok).toStringAsFixed(3))),
            ),
          ],
        ),
      ],
    );
  }
}

/// Otwiera dużą klawiaturę do wpisania liczby. Zwraca `null`, gdy rolnik
/// zrezygnował; wartość poniżej [minimum] nie przechodzi.
Future<double?> wpiszLiczbe(
  BuildContext context, {
  required double wartosc,
  required String jednostka,
  double minimum = 0,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MotywProsty.tlo,
    builder: (_) => _OknoWpisaniaLiczby(
      poczatkowa: wartosc,
      jednostka: jednostka,
      minimum: minimum,
    ),
  );
}

/// Zamienia wpisany tekst („1,5", „2.", „12") na liczbę. `null`, gdy tekst
/// nie jest liczbą.
double? odczytajLiczbe(String tekst) {
  final czysty = tekst.trim().replaceAll(',', '.');
  if (czysty.isEmpty || czysty == '.') return null;
  return double.tryParse(czysty.endsWith('.') ? '${czysty}0' : czysty);
}

class _OknoWpisaniaLiczby extends StatefulWidget {
  const _OknoWpisaniaLiczby({
    required this.poczatkowa,
    required this.jednostka,
    required this.minimum,
  });

  final double poczatkowa;
  final String jednostka;
  final double minimum;

  @override
  State<_OknoWpisaniaLiczby> createState() => _OknoWpisaniaLiczbyState();
}

class _OknoWpisaniaLiczbyState extends State<_OknoWpisaniaLiczby> {
  /// Zaczynamy od pustego pola: pierwsza cyfra zastępuje starą wartość,
  /// a stara zostaje widoczna jako podpowiedź.
  var _tekst = '';

  double? get _liczba => odczytajLiczbe(_tekst);

  bool get _zaMalo => _liczba != null && _liczba! < widget.minimum - 1e-9;

  bool get _mozna => _liczba != null && !_zaMalo;

  void _znak(String znak) {
    if (znak == ',' && _tekst.contains(',')) return;
    if (_tekst.length >= 8) return;
    setState(() => _tekst += znak);
  }

  void _usun() {
    if (_tekst.isEmpty) return;
    setState(() => _tekst = _tekst.substring(0, _tekst.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MotywProsty.odstep,
          MotywProsty.odstep,
          MotywProsty.odstep,
          MotywProsty.odstep + MediaQuery.viewInsetsOf(context).bottom,
        ),
        // Przewijanie: przy bardzo dużym tekście albo niskim ekranie
        // klawiatura z przyciskami nie mieści się w całości.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Wpisz liczbę', style: teksty.titleLarge),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: MotywProsty.powierzchnia,
                  borderRadius: BorderRadius.circular(
                    MotywProsty.zaokraglenieMale,
                  ),
                  border: Border.all(
                    color: _zaMalo
                        ? MotywProsty.ostrzezenieObramowanie
                        : MotywProsty.zielenAkcji,
                    width: 2,
                  ),
                ),
                child: Text(
                  _tekst.isEmpty
                      ? '${WyborLiczby.napis(widget.poczatkowa)} ${widget.jednostka}'
                      : '$_tekst ${widget.jednostka}',
                  textAlign: TextAlign.center,
                  style: teksty.displayLarge?.copyWith(
                    color: _tekst.isEmpty
                        ? MotywProsty.tekstPomocniczy
                        : MotywProsty.tekst,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _zaMalo
                    ? 'Najmniej ${WyborLiczby.napis(widget.minimum)} '
                          '${widget.jednostka}.'
                    : 'Przecinek oddziela części, np. 1,5.',
                textAlign: TextAlign.center,
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: MotywProsty.odstep),
              KlawiaturaNumeru(
                onZnak: _znak,
                onUsun: _usun,
                dodatkoweZnaki: const [','],
              ),
              const SizedBox(height: MotywProsty.odstep),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Anuluj'),
                    ),
                  ),
                  const SizedBox(width: MotywProsty.odstep),
                  Expanded(
                    child: FilledButton(
                      onPressed: _mozna
                          ? () => Navigator.of(context).pop(_liczba)
                          : null,
                      child: const Text('Gotowe'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Przycisk extends StatelessWidget {
  const _Przycisk({required this.znak, required this.etykieta, this.onTap});

  final String znak;
  final String etykieta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etykieta,
      child: Material(
        color: onTap == null
            ? MotywProsty.powierzchnia
            : MotywProsty.powierzchniaDruga,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
        child: InkWell(
          borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Text(
                znak,
                style: const TextStyle(fontSize: 34, color: MotywProsty.tekst),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
