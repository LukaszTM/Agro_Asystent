import 'package:flutter/material.dart';

import 'daty.dart';

/// Wybór dnia przyorania nawozu naturalnego — bez klawiatury: trzy
/// najczęstsze odpowiedzi jako przyciski, „inna data" z kalendarza.
///
/// Wspólny dla wyglądów telefonu (kolory bierze z `Theme`). Tabela 15
/// programu azotanowego wymaga tej daty na terenie o dużym nachyleniu;
/// gdy rolnik jeszcze nie przyorał, pole zostaje puste.
class WyborPrzyorania extends StatelessWidget {
  const WyborPrzyorania({
    super.key,
    required this.dzienZabiegu,
    required this.wybrana,
    required this.onZmiana,
  });

  /// Dzień nawożenia — od niego liczą się „tego samego dnia" i „nazajutrz".
  final DateTime dzienZabiegu;

  /// Wybrany dzień przyorania; `null` — jeszcze nie przyorano.
  final DateTime? wybrana;

  final ValueChanged<DateTime?> onZmiana;

  DateTime get _tegoDnia =>
      DateTime(dzienZabiegu.year, dzienZabiegu.month, dzienZabiegu.day);

  DateTime get _nazajutrz => _tegoDnia.add(const Duration(days: 1));

  bool _toJest(DateTime? dzien) =>
      wybrana != null && dzien != null && Daty.tenSamDzien(wybrana!, dzien);

  bool get _innaData =>
      wybrana != null && !_toJest(_tegoDnia) && !_toJest(_nazajutrz);

  Future<void> _zKalendarza(BuildContext context) async {
    final dzien = await showDatePicker(
      context: context,
      initialDate: wybrana ?? _tegoDnia,
      // Przyorać można najwcześniej w dniu nawożenia; daty z przyszłości
      // nie zapisujemy — to ewidencja, nie plan.
      firstDate: _tegoDnia,
      lastDate: DateTime.now().isBefore(_tegoDnia) ? _tegoDnia : DateTime.now(),
      helpText: 'Dzień przyorania',
      confirmText: 'Zapisz',
      cancelText: 'Anuluj',
    );
    if (dzien != null) {
      onZmiana(dzien);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final chipy = <(String, bool, VoidCallback)>[
      ('Jeszcze nie', wybrana == null, () => onZmiana(null)),
      ('Tego samego dnia', _toJest(_tegoDnia), () => onZmiana(_tegoDnia)),
      ('Nazajutrz', _toJest(_nazajutrz), () => onZmiana(_nazajutrz)),
      (
        _innaData ? 'Inna data: ${Daty.krotko(wybrana!)}' : 'Inna data',
        _innaData,
        () => _zKalendarza(context),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final (etykieta, wybrany, onTap) in chipy)
              ChoiceChip(
                label: Text(etykieta, style: teksty.labelLarge),
                selected: wybrany,
                onSelected: (_) => onTap(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          wybrana == null
              ? 'Datę przyorania dopiszesz później z rejestru — wymaga jej '
                    'ewidencja na terenie o dużym nachyleniu.'
              : 'Przyorano ${Daty.zRokiem(wybrana!)}.',
          style: teksty.bodyMedium,
        ),
      ],
    );
  }
}
