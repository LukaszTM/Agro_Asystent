import 'package:flutter/material.dart';

import '../../../funkcje/biodynamika/biodynamika.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../../../rdzen/wspolne/ikony_siewu.dart';
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 40,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: _barwaKwadry(dzien),
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
                // Oznaczenia jak w kalendarzu na ścianie: rączka siewna
                // i rodzaj pracy; w dzień fazy głównej — tarcza Księżyca.
                SizedBox(width: 56, child: _Raczki(dzien: dzien, rozmiar: 28)),
                const SizedBox(width: 8),
                SizedBox(width: 36, child: _Praca(dzien: dzien, rozmiar: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_glowneZdanie(dzien), style: teksty.bodyLarge),
                      Text(
                        [
                          'Księżyc w znaku ${dzien.znak.nazwa} '
                              '(dzień ${dzien.praca})',
                          '${dzien.faza.nazwa}, ${dzien.oswietlenieOpis} tarczy',
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

  static String _glowneZdanie(DzienBiodynamiczny dzien) {
    if (dzien.zmianaFazy case final ZmianaFazy zmiana) {
      return '${zmiana.faza.nazwa} o ${zmiana.godzinaOpis} — '
          '${dzien.ocenaSiewu.dlaRolnika}';
    }
    final praca = dzien.kwadra.praca;
    return praca == null
        ? dzien.ocenaSiewu.dlaRolnika
        : '${dzien.ocenaSiewu.dlaRolnika}: $praca';
  }
}

Color _barwaKwadry(DzienBiodynamiczny dzien) {
  final praca = dzien.kwadra.praca;
  return praca == null
      ? MotywKomputer.tekstPomocniczy
      : MotywKomputer.barwaPracy(praca);
}

/// Rączka siewna albo tarcza Księżyca (w dzień fazy głównej rączka jest
/// przekreślona, więc tarcza stoi obok).
class _Raczki extends StatelessWidget {
  const _Raczki({required this.dzien, this.rozmiar = 22});

  final DzienBiodynamiczny dzien;
  final double rozmiar;

  @override
  Widget build(BuildContext context) {
    return switch (dzien.ocenaSiewu) {
      OcenaSiewu.zly => IkonaRaczki(
        ile: 1,
        przekreslona: true,
        kolor: MotywKomputer.tekstPomocniczy,
        kolorKreski: MotywKomputer.ostrzezenieObramowanie,
        rozmiar: rozmiar,
      ),
      OcenaSiewu.dobry => IkonaRaczki(
        ile: 1,
        kolor: MotywKomputer.zielen,
        rozmiar: rozmiar,
      ),
      OcenaSiewu.bardzoDobry => IkonaRaczki(
        ile: 2,
        kolor: MotywKomputer.zielen,
        rozmiar: rozmiar,
      ),
      OcenaSiewu.bezSiewu => const SizedBox.shrink(),
    };
  }
}

/// Rodzaj pracy w kwadrze; w dzień fazy głównej — tarcza Księżyca.
class _Praca extends StatelessWidget {
  const _Praca({required this.dzien, this.rozmiar = 24});

  final DzienBiodynamiczny dzien;
  final double rozmiar;

  @override
  Widget build(BuildContext context) {
    if (dzien.zmianaFazy case final ZmianaFazy zmiana) {
      return IkonaFazy(
        stopnie: zmiana.faza.stopnie,
        kolorCiemny: MotywKomputer.tekst,
        kolorJasny: MotywKomputer.karta,
        rozmiar: rozmiar,
      );
    }
    return IkonaPracy(
      praca: dzien.kwadra.praca,
      kolor: _barwaKwadry(dzien),
      rozmiar: rozmiar,
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
    final barwa = _barwaKwadry(dzien);
    return Semantics(
      label:
          '${dzien.data.day} ${Daty.miesiaceWDopelniaczu[dzien.data.month - 1]}'
          ', ${dzien.ocenaSiewu.dlaRolnika}'
          '${dzien.kwadra.praca == null ? '' : ': ${dzien.kwadra.praca}'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: barwa.withValues(alpha: 0.12),
          border: Border.all(
            color: dzisiaj
                ? MotywKomputer.zielen
                : barwa.withValues(alpha: 0.5),
            width: dzisiaj ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(MotywKomputer.zaokraglenieMale),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${dzien.data.day}', style: teksty.labelLarge),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Raczki(dzien: dzien, rozmiar: 16),
                if (dzien.ocenaSiewu != OcenaSiewu.bezSiewu)
                  const SizedBox(width: 4),
                _Praca(dzien: dzien, rozmiar: 18),
              ],
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
    Widget pozycja(Widget ikona, String opis) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ikona,
        const SizedBox(width: 6),
        Text(opis, style: teksty.bodyMedium),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        pozycja(
          const IkonaRaczki(ile: 1, kolor: MotywKomputer.zielen, rozmiar: 18),
          'dobry dzień do siewu',
        ),
        pozycja(
          const IkonaRaczki(ile: 2, kolor: MotywKomputer.zielen, rozmiar: 18),
          'bardzo dobry',
        ),
        pozycja(
          const IkonaRaczki(
            ile: 1,
            przekreslona: true,
            kolor: MotywKomputer.tekstPomocniczy,
            kolorKreski: MotywKomputer.ostrzezenieObramowanie,
            rozmiar: 18,
          ),
          'zły (zmiana fazy)',
        ),
        for (final praca in MotywKomputer.barwyPracy.keys)
          pozycja(
            IkonaPracy(
              praca: praca,
              kolor: MotywKomputer.barwaPracy(praca),
              rozmiar: 18,
            ),
            praca,
          ),
        pozycja(
          const IkonaPracy(
            praca: null,
            kolor: MotywKomputer.tekstPomocniczy,
            rozmiar: 18,
          ),
          'prace w glebie',
        ),
      ],
    );
  }
}
