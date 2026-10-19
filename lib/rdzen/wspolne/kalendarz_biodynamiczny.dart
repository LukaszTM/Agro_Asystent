import 'package:flutter/material.dart';

import '../../funkcje/biodynamika/biodynamika.dart';
import 'daty.dart';
import 'ikony_siewu.dart';

/// Barwy i wymiary kalendarza biodynamicznego — podaje je wygląd
/// (`lib/wyglad/*/motyw.dart`), bo sam kalendarz jest wspólny dla telefonu
/// i komputera.
class StylKalendarza {
  const StylKalendarza({
    required this.tekst,
    required this.tekstPomocniczy,
    required this.tlo,
    required this.akcent,
    required this.ostrzezenie,
    required this.barwyPracy,
    required this.zaokraglenie,
    required this.odstep,
  });

  final Color tekst;
  final Color tekstPomocniczy;

  /// Tło kart — jasna część tarczy Księżyca.
  final Color tlo;

  /// Wyróżnienie dzisiejszego dnia i rączek siewnych.
  final Color akcent;

  /// Kreska przekreślająca rączkę w dzień zły do siewu.
  final Color ostrzezenie;

  /// Barwy dni po rodzaju pracy. Nazwy prac pochodzą ze słownika
  /// (`assets/dane/kalendarz_biodynamiczny.json`), nie z kodu.
  final Map<String, Color> barwyPracy;

  final double zaokraglenie;
  final double odstep;

  Color barwaPracy(String praca) => barwyPracy[praca] ?? tekstPomocniczy;

  Color barwaKwadry(DzienBiodynamiczny dzien) {
    final praca = dzien.kwadra.praca;
    return praca == null ? tekstPomocniczy : barwaPracy(praca);
  }
}

/// Kalendarz biodynamiczny: tydzień, z rozwinięciem na cały miesiąc.
///
/// **To tradycja, nie przepis.** Zastrzeżenie stoi na ekranie zawsze, a nie
/// w drobnym druku — żeby nikt nie wziął dnia korzeniowego za termin
/// z rozporządzenia.
///
/// Na szerokim ekranie każdy dzień to jeden wiersz; na telefonie opis
/// schodzi pod oznaczenia, żeby nic nie wychodziło za ekran.
class KalendarzBiodynamicznyWidok extends StatefulWidget {
  const KalendarzBiodynamicznyWidok({
    super.key,
    required this.tydzien,
    required this.miesiac,
    required this.dzis,
    required this.zastrzezenie,
    required this.styl,
    this.tytul,
  });

  final List<DzienBiodynamiczny> tydzien;
  final List<DzienBiodynamiczny> miesiac;
  final DateTime dzis;

  /// Zdanie ze słownika: czym ten kalendarz jest, a czym nie.
  final String zastrzezenie;

  final StylKalendarza styl;

  /// Nagłówek nad kalendarzem; `null`, gdy tytuł daje już pasek ekranu.
  final String? tytul;

  /// Szerokość, poniżej której dzień zajmuje dwa wiersze.
  static const double szerokoscJednegoWiersza = 560;

  @override
  State<KalendarzBiodynamicznyWidok> createState() =>
      _KalendarzBiodynamicznyWidokState();
}

class _KalendarzBiodynamicznyWidokState
    extends State<KalendarzBiodynamicznyWidok> {
  bool _calyMiesiac = false;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final styl = widget.styl;
    return LayoutBuilder(
      builder: (context, wymiary) {
        final waski =
            wymiary.maxWidth <
            KalendarzBiodynamicznyWidok.szerokoscJednegoWiersza;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: widget.tytul == null
                      ? const SizedBox.shrink()
                      : Text(widget.tytul!, style: teksty.headlineMedium),
                ),
                TextButton(
                  onPressed: () => setState(() => _calyMiesiac = !_calyMiesiac),
                  child: Text(_calyMiesiac ? 'Pokaż tydzień' : 'Pokaż miesiąc'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(widget.zastrzezenie, style: teksty.bodyMedium),
            SizedBox(height: styl.odstep),
            if (_calyMiesiac)
              _Miesiac(
                dni: widget.miesiac,
                dzis: widget.dzis,
                styl: styl,
                waski: waski,
              )
            else
              _Tydzien(
                dni: widget.tydzien,
                dzis: widget.dzis,
                styl: styl,
                waski: waski,
              ),
            SizedBox(height: styl.odstep),
            _Legenda(styl: styl),
          ],
        );
      },
    );
  }
}

class _Tydzien extends StatelessWidget {
  const _Tydzien({
    required this.dni,
    required this.dzis,
    required this.styl,
    required this.waski,
  });

  final List<DzienBiodynamiczny> dni;
  final DateTime dzis;
  final StylKalendarza styl;
  final bool waski;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final dzien in dni)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: waski
                ? _dwaWiersze(context, dzien)
                : _wiersz(context, dzien),
          ),
      ],
    );
  }

  Widget _pasek(DzienBiodynamiczny dzien, double wysokosc) => Container(
    width: 6,
    height: wysokosc,
    margin: const EdgeInsets.only(right: 10),
    decoration: BoxDecoration(
      color: styl.barwaKwadry(dzien),
      borderRadius: BorderRadius.circular(3),
    ),
  );

  Widget _data(BuildContext context, DzienBiodynamiczny dzien) {
    final teksty = Theme.of(context).textTheme;
    return Text(
      '${Daty.dzienTygodniaKrotko(dzien.data)} '
      '${dzien.data.day}.${dzien.data.month}',
      style: Daty.tenSamDzien(dzien.data, dzis)
          ? teksty.labelLarge?.copyWith(color: styl.akcent)
          : teksty.bodyLarge,
    );
  }

  // Oznaczenia jak w kalendarzu na ścianie: rączka siewna i rodzaj pracy;
  // w dzień fazy głównej — tarcza Księżyca.
  Widget _oznaczenia(DzienBiodynamiczny dzien) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 56,
        child: _Raczki(dzien: dzien, styl: styl, rozmiar: 28),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 36,
        child: _Praca(dzien: dzien, styl: styl, rozmiar: 28),
      ),
    ],
  );

  Widget _opis(BuildContext context, DzienBiodynamiczny dzien) {
    final teksty = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_glowneZdanie(dzien), style: teksty.bodyLarge),
        Text(
          [
            'Księżyc w znaku ${dzien.znak.nazwa} (dzień ${dzien.praca})',
            '${dzien.faza.nazwa}, ${dzien.oswietlenieOpis} tarczy',
            if (dzien.zmiana case final ZmianaZnaku zmiana)
              'od ${zmiana.godzinaOpis} dzień ${zmiana.na.zywiol.praca}',
          ].join(' • '),
          style: teksty.bodyMedium,
        ),
      ],
    );
  }

  Widget _wiersz(BuildContext context, DzienBiodynamiczny dzien) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _pasek(dzien, 40),
      SizedBox(width: 112, child: _data(context, dzien)),
      _oznaczenia(dzien),
      const SizedBox(width: 10),
      Expanded(child: _opis(context, dzien)),
    ],
  );

  Widget _dwaWiersze(BuildContext context, DzienBiodynamiczny dzien) =>
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _pasek(dzien, double.infinity),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _data(context, dzien)),
                      _oznaczenia(dzien),
                    ],
                  ),
                  const SizedBox(height: 2),
                  _opis(context, dzien),
                ],
              ),
            ),
          ],
        ),
      );

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

/// Rączka siewna (w dzień fazy głównej przekreślona).
class _Raczki extends StatelessWidget {
  const _Raczki({required this.dzien, required this.styl, this.rozmiar = 22});

  final DzienBiodynamiczny dzien;
  final StylKalendarza styl;
  final double rozmiar;

  @override
  Widget build(BuildContext context) {
    return switch (dzien.ocenaSiewu) {
      OcenaSiewu.zly => IkonaRaczki(
        ile: 1,
        przekreslona: true,
        kolor: styl.tekstPomocniczy,
        kolorKreski: styl.ostrzezenie,
        rozmiar: rozmiar,
      ),
      OcenaSiewu.dobry => IkonaRaczki(
        ile: 1,
        kolor: styl.akcent,
        rozmiar: rozmiar,
      ),
      OcenaSiewu.bardzoDobry => IkonaRaczki(
        ile: 2,
        kolor: styl.akcent,
        rozmiar: rozmiar,
      ),
      OcenaSiewu.bezSiewu => const SizedBox.shrink(),
    };
  }
}

/// Rodzaj pracy w kwadrze; w dzień fazy głównej — tarcza Księżyca.
class _Praca extends StatelessWidget {
  const _Praca({required this.dzien, required this.styl, this.rozmiar = 24});

  final DzienBiodynamiczny dzien;
  final StylKalendarza styl;
  final double rozmiar;

  @override
  Widget build(BuildContext context) {
    if (dzien.zmianaFazy case final ZmianaFazy zmiana) {
      return IkonaFazy(
        stopnie: zmiana.faza.stopnie,
        kolorCiemny: styl.tekst,
        kolorJasny: styl.tlo,
        rozmiar: rozmiar,
      );
    }
    return IkonaPracy(
      praca: dzien.kwadra.praca,
      kolor: styl.barwaKwadry(dzien),
      rozmiar: rozmiar,
    );
  }
}

class _Miesiac extends StatelessWidget {
  const _Miesiac({
    required this.dni,
    required this.dzis,
    required this.styl,
    required this.waski,
  });

  final List<DzienBiodynamiczny> dni;
  final DateTime dzis;
  final StylKalendarza styl;
  final bool waski;

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
                // „niedz" przy dużym tekście nie mieści się w wąskiej
                // kolumnie — raczej się zmniejszy, niż złamie na dwie linie.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    nazwa,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: teksty.labelLarge,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Na telefonie kratka jest wąska, więc musi być wyższa, żeby
          // zmieścić numer dnia i oznaczenia jedno pod drugim.
          childAspectRatio: waski ? 0.72 : 1.25,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var puste = 0; puste < pustePola; puste++)
              const SizedBox.shrink(),
            for (final dzien in dni)
              _Kratka(dzien: dzien, dzis: dzis, styl: styl, waski: waski),
          ],
        ),
      ],
    );
  }
}

class _Kratka extends StatelessWidget {
  const _Kratka({
    required this.dzien,
    required this.dzis,
    required this.styl,
    required this.waski,
  });

  final DzienBiodynamiczny dzien;
  final DateTime dzis;
  final StylKalendarza styl;
  final bool waski;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final dzisiaj = Daty.tenSamDzien(dzien.data, dzis);
    final barwa = styl.barwaKwadry(dzien);
    final oznaczenia = [
      _Raczki(dzien: dzien, styl: styl, rozmiar: 16),
      if (dzien.ocenaSiewu != OcenaSiewu.bezSiewu) const SizedBox(width: 4),
      _Praca(dzien: dzien, styl: styl, rozmiar: 18),
    ];
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
            color: dzisiaj ? styl.akcent : barwa.withValues(alpha: 0.5),
            width: dzisiaj ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(styl.zaokraglenie),
        ),
        // Przy bardzo dużym tekście zawartość kratki zmniejsza się, zamiast
        // wychodzić poza nią.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${dzien.data.day}', style: teksty.labelLarge),
              const SizedBox(height: 2),
              if (waski)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final oznaczenie in oznaczenia)
                      if (oznaczenie is! SizedBox) oznaczenie,
                  ],
                )
              else
                Row(mainAxisSize: MainAxisSize.min, children: oznaczenia),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.styl});

  final StylKalendarza styl;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    // Przy dużym tekście opis łamie się na dwie linie, zamiast wystawać
    // poza ekran telefonu.
    Widget pozycja(Widget ikona, String opis) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ikona,
        const SizedBox(width: 6),
        Flexible(child: Text(opis, style: teksty.bodyMedium)),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        pozycja(
          IkonaRaczki(ile: 1, kolor: styl.akcent, rozmiar: 18),
          'dobry dzień do siewu',
        ),
        pozycja(
          IkonaRaczki(ile: 2, kolor: styl.akcent, rozmiar: 18),
          'bardzo dobry',
        ),
        pozycja(
          IkonaRaczki(
            ile: 1,
            przekreslona: true,
            kolor: styl.tekstPomocniczy,
            kolorKreski: styl.ostrzezenie,
            rozmiar: 18,
          ),
          'zły (zmiana fazy)',
        ),
        for (final praca in styl.barwyPracy.keys)
          pozycja(
            IkonaPracy(
              praca: praca,
              kolor: styl.barwaPracy(praca),
              rozmiar: 18,
            ),
            praca,
          ),
        pozycja(
          IkonaPracy(praca: null, kolor: styl.tekstPomocniczy, rozmiar: 18),
          'prace w glebie',
        ),
      ],
    );
  }
}
