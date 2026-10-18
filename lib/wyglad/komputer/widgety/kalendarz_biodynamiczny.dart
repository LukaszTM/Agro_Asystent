import 'package:flutter/material.dart';

import '../../../funkcje/biodynamika/biodynamika.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../motyw.dart';
import 'karta.dart';

/// Kalendarz biodynamiczny: tydzień, z rozwinięciem na cały miesiąc.
///
/// **To tradycja, nie przepis.** Zastrzeżenie stoi na ekranie zawsze, a nie
/// w drobnym druku — żeby nikt nie wziął dnia korzeniowego za termin
/// z rozporządzenia.
class KalendarzBiodynamicznyKarta extends StatefulWidget {
  const KalendarzBiodynamicznyKarta({
    super.key,
    required this.tydzien,
    required this.miesiac,
    required this.dzis,
    required this.zastrzezenie,
  });

  final List<DzienBiodynamiczny> tydzien;
  final List<DzienBiodynamiczny> miesiac;
  final DateTime dzis;

  /// Zdanie ze słownika: czym ten kalendarz jest, a czym nie.
  final String zastrzezenie;

  @override
  State<KalendarzBiodynamicznyKarta> createState() =>
      _KalendarzBiodynamicznyKartaState();
}

class _KalendarzBiodynamicznyKartaState
    extends State<KalendarzBiodynamicznyKarta> {
  bool _calyMiesiac = false;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return KartaKomputer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kalendarz biodynamiczny',
                  style: teksty.headlineMedium,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _calyMiesiac = !_calyMiesiac),
                child: Text(_calyMiesiac ? 'Pokaż tydzień' : 'Pokaż miesiąc'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(widget.zastrzezenie, style: teksty.bodyMedium),
          const SizedBox(height: MotywKomputer.odstep),
          if (_calyMiesiac)
            _Miesiac(dni: widget.miesiac, dzis: widget.dzis)
          else
            _Tydzien(dni: widget.tydzien, dzis: widget.dzis),
          const SizedBox(height: MotywKomputer.odstep),
          const _Legenda(),
        ],
      ),
    );
  }
}

class _Tydzien extends StatelessWidget {
  const _Tydzien({required this.dni, required this.dzis});

  final List<DzienBiodynamiczny> dni;
  final DateTime dzis;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final dzien in dni)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 38,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: MotywKomputer.barwaPracy(dzien.praca),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SizedBox(
                  width: 112,
                  child: Text(
                    '${Daty.dzienTygodniaKrotko(dzien.data)} '
                    '${dzien.data.day}.${dzien.data.month}',
                    style: Daty.tenSamDzien(dzien.data, dzis)
                        ? teksty.labelLarge?.copyWith(
                            color: MotywKomputer.zielen,
                          )
                        : teksty.bodyLarge,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'dzień ${dzien.praca} • ${dzien.znak.nazwa}',
                        style: teksty.bodyLarge,
                      ),
                      Text(
                        [
                          '${dzien.faza.nazwa}, '
                              '${dzien.oswietlenieOpis} tarczy',
                          if (dzien.zmiana case final ZmianaZnaku zmiana)
                            'od ${zmiana.godzinaOpis} '
                                'dzień ${zmiana.na.zywiol.praca}',
                        ].join(' • '),
                        style: teksty.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Miesiac extends StatelessWidget {
  const _Miesiac({required this.dni, required this.dzis});

  final List<DzienBiodynamiczny> dni;
  final DateTime dzis;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    if (dni.isEmpty) {
      return const SizedBox.shrink();
    }
    // Miesiąc zaczynamy od poniedziałku — tak wiszą kalendarze w kuchni.
    final pustePola = dni.first.data.weekday - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${Daty.miesiaceWDopelniaczu[dni.first.data.month - 1]} '
          '${dni.first.data.year}',
          style: teksty.titleLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final nazwa in Daty.dniTygodniaKrotko)
              Expanded(
                child: Text(
                  nazwa,
                  textAlign: TextAlign.center,
                  style: teksty.labelLarge,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.25,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var puste = 0; puste < pustePola; puste++)
              const SizedBox.shrink(),
            for (final dzien in dni) _Kratka(dzien: dzien, dzis: dzis),
          ],
        ),
      ],
    );
  }
}

class _Kratka extends StatelessWidget {
  const _Kratka({required this.dzien, required this.dzis});

  final DzienBiodynamiczny dzien;
  final DateTime dzis;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final dzisiaj = Daty.tenSamDzien(dzien.data, dzis);
    return Semantics(
      label:
          '${dzien.data.day} ${Daty.miesiaceWDopelniaczu[dzien.data.month - 1]}'
          ', dzień ${dzien.praca}, ${dzien.znak.nazwa}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: MotywKomputer.barwaPracy(dzien.praca).withValues(alpha: 0.12),
          border: Border.all(
            color: dzisiaj
                ? MotywKomputer.zielen
                : MotywKomputer.barwaPracy(dzien.praca).withValues(alpha: 0.5),
            width: dzisiaj ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(MotywKomputer.zaokraglenieMale),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${dzien.data.day}', style: teksty.labelLarge),
            Text(
              dzien.praca,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: teksty.bodyMedium?.copyWith(
                color: MotywKomputer.barwaPracy(dzien.praca),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final praca in MotywKomputer.barwyPracy.keys)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: MotywKomputer.barwaPracy(praca),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Text(praca, style: teksty.bodyMedium),
            ],
          ),
      ],
    );
  }
}
