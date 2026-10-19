import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motyw.dart';

/// Wybór jednej możliwości — zamiast listy rozwijanej (CLAUDE.md, reguły
/// interfejsu: wybór z listy zamiast pisania).
class Wybor extends StatelessWidget {
  const Wybor({
    super.key,
    required this.etykieta,
    required this.wybrany,
    required this.onTap,
    this.ikona,
  });

  final String etykieta;
  final bool wybrany;
  final VoidCallback onTap;
  final IconData? ikona;

  @override
  Widget build(BuildContext context) {
    final zaokraglenie = BorderRadius.circular(
      MotywNowoczesny.zaokraglenieMale,
    );
    final kolorTekstu = wybrany ? MotywNowoczesny.karta : MotywNowoczesny.tekst;

    return Semantics(
      button: true,
      selected: wybrany,
      child: Material(
        color: wybrany ? MotywNowoczesny.zielen : MotywNowoczesny.karta,
        borderRadius: zaokraglenie,
        child: InkWell(
          borderRadius: zaokraglenie,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: MotywNowoczesny.minCelDotyku,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ikona != null) ...[
                  Icon(ikona, size: 18, color: kolorTekstu),
                  const SizedBox(width: 6),
                ],
                // Długa etykieta łamie się na dwie linie, zamiast
                // wychodzić za ekran — nazwy ze słownika mogą być dłuższe,
                // niż zmieści się na telefonie.
                Flexible(
                  child: Text(
                    etykieta,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: kolorTekstu),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Liczba z przyciskami „−" i „+" — bez klawiatury (reguły interfejsu).
///
/// Dotknięcie liczby otwiera okno z polem do wpisania: gdy dawka różni się
/// znacznie od wyjściowej, wpisanie jej jest szybsze niż wiele dotknięć „+".
class WyborLiczbyNowoczesny extends StatelessWidget {
  const WyborLiczbyNowoczesny({
    super.key,
    required this.wartosc,
    required this.jednostka,
    required this.krok,
    required this.onZmiana,
    this.maksimum,
    this.opisMaksimum,
  });

  final double wartosc;
  final String jednostka;
  final double krok;

  /// Największa wartość z rejestru albo z etykiety — przekroczenie
  /// pokazujemy, ale nie blokujemy: decyzja należy do rolnika.
  final double? maksimum;
  final String? opisMaksimum;

  final ValueChanged<double> onZmiana;

  static String _liczba(double wartosc) =>
      wartosc.toStringAsFixed(2).replaceAll('.', ',');

  Future<void> _wpisz(BuildContext context) async {
    final nowa = await wpiszLiczbe(
      context,
      wartosc: wartosc,
      jednostka: jednostka,
    );
    if (nowa != null) onZmiana(nowa);
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Krok(
              ikona: Icons.remove,
              opis: 'Zmniejsz dawkę',
              onTap: wartosc - krok <= 0
                  ? null
                  : () => onZmiana(
                      double.parse((wartosc - krok).toStringAsFixed(3)),
                    ),
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Wpisz liczbę z klawiatury',
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    MotywNowoczesny.zaokraglenieMale,
                  ),
                  onTap: () => _wpisz(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '${_liczba(wartosc)} $jednostka',
                      textAlign: TextAlign.center,
                      style: teksty.headlineMedium,
                    ),
                  ),
                ),
              ),
            ),
            _Krok(
              ikona: Icons.add,
              opis: 'Zwiększ dawkę',
              onTap: () =>
                  onZmiana(double.parse((wartosc + krok).toStringAsFixed(3))),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          opisMaksimum ?? 'Dotknij liczby, żeby ją wpisać.',
          style: teksty.bodyMedium,
        ),
      ],
    );
  }
}

/// Otwiera okno z polem do wpisania liczby z klawiatury systemowej.
/// Zwraca `null`, gdy użytkownik zrezygnował; wartość ujemna nie przechodzi.
Future<double?> wpiszLiczbe(
  BuildContext context, {
  required double wartosc,
  required String jednostka,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _OknoLiczby(poczatkowa: wartosc, jednostka: jednostka),
  );
}

/// Zamienia wpisany tekst („1,5", „2.", „12") na liczbę. `null`, gdy tekst
/// nie jest liczbą.
double? odczytajLiczbe(String tekst) {
  final czysty = tekst.trim().replaceAll(',', '.');
  if (czysty.isEmpty || czysty == '.') return null;
  return double.tryParse(czysty.endsWith('.') ? '${czysty}0' : czysty);
}

class _OknoLiczby extends StatefulWidget {
  const _OknoLiczby({required this.poczatkowa, required this.jednostka});

  final double poczatkowa;
  final String jednostka;

  @override
  State<_OknoLiczby> createState() => _OknoLiczbyState();
}

class _OknoLiczbyState extends State<_OknoLiczby> {
  late final TextEditingController _pole = TextEditingController(
    text: WyborLiczbyNowoczesny._liczba(widget.poczatkowa),
  );

  @override
  void initState() {
    super.initState();
    // Cała stara wartość zaznaczona: pierwsza cyfra ją zastępuje.
    _pole.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _pole.text.length,
    );
    _pole.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pole.dispose();
    super.dispose();
  }

  double? get _liczba {
    final liczba = odczytajLiczbe(_pole.text);
    return liczba == null || liczba < 0 ? null : liczba;
  }

  void _zapisz() {
    final liczba = _liczba;
    if (liczba != null) Navigator.of(context).pop(liczba);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wpisz liczbę'),
      content: TextField(
        controller: _pole,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          LengthLimitingTextInputFormatter(8),
        ],
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
        decoration: InputDecoration(
          suffixText: widget.jednostka,
          helperText: 'Przecinek oddziela części, np. 1,5.',
          errorText: _pole.text.isNotEmpty && _liczba == null
              ? 'To nie jest liczba.'
              : null,
        ),
        onSubmitted: (_) => _zapisz(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: _liczba == null ? null : _zapisz,
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}

class _Krok extends StatelessWidget {
  const _Krok({required this.ikona, required this.opis, this.onTap});

  final IconData ikona;
  final String opis;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: opis,
      child: Material(
        color: MotywNowoczesny.karta,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: MotywNowoczesny.minCelDotyku,
            height: MotywNowoczesny.minCelDotyku,
            child: Icon(
              ikona,
              color: onTap == null
                  ? MotywNowoczesny.tekstPomocniczy
                  : MotywNowoczesny.zielen,
              semanticLabel: '',
            ),
          ),
        ),
      ),
    );
  }
}
