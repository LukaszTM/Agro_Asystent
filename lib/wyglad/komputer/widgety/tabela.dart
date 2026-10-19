import 'package:flutter/material.dart';

import '../motyw.dart';

/// Kolumna tabeli: nagłówek i szerokość względna.
class KolumnaTabeli {
  const KolumnaTabeli(this.naglowek, {this.udzial = 1, this.doPrawej = false});

  final String naglowek;

  /// Ile miejsca zajmuje kolumna wobec pozostałych.
  final int udzial;

  /// Liczby czyta się po prawej — tak wygląda każda ewidencja na papierze.
  final bool doPrawej;
}

/// Wiersz tabeli: wartości w kolejności kolumn.
class WierszTabeli {
  const WierszTabeli({
    required this.wartosci,
    this.onKlik,
    this.wyrozniony = false,
    this.podpis,
  });

  /// Tekst w kolejnych kolumnach. Puste pole piszemy jako „brak" — tabela
  /// nie zostawia dziur bez wyjaśnienia.
  final List<String> wartosci;

  final VoidCallback? onKlik;

  /// Wiersz wymagający uwagi (np. wpis niekompletny).
  final bool wyrozniony;

  /// Drugi wiersz drobnym tekstem pod wartościami — na uwagi i ostrzeżenia.
  final String? podpis;
}

/// Tabela programu na komputer.
///
/// Na telefonie dane pokazują się kafelkami, bo palcem trafia się w duży
/// cel. Na komputerze rolnik patrzy na cały rejestr naraz i porównuje
/// wiersze — dlatego tu jest tabela z nagłówkiem, który zostaje na miejscu
/// przy przewijaniu.
class Tabela extends StatelessWidget {
  const Tabela({
    super.key,
    required this.kolumny,
    required this.wiersze,
    this.gdyPusta,
  });

  final List<KolumnaTabeli> kolumny;
  final List<WierszTabeli> wiersze;

  /// Co napisać, gdy nie ma ani jednego wiersza. Pusta tabela bez zdania
  /// wygląda jak zepsuty program.
  final String? gdyPusta;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: MotywKomputer.karta,
        border: Border.all(color: MotywKomputer.obramowanie),
        borderRadius: BorderRadius.circular(MotywKomputer.zaokraglenieKarty),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MotywKomputer.odstep,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: MotywKomputer.powierzchniaDruga,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(MotywKomputer.zaokraglenieKarty),
                topRight: Radius.circular(MotywKomputer.zaokraglenieKarty),
              ),
            ),
            child: Row(
              // Odstęp między kolumnami: liczba wyrównana do prawej nie może
              // stykać się z tekstem sąsiedniej komórki.
              spacing: MotywKomputer.odstep,
              children: [
                for (final kolumna in kolumny)
                  Expanded(
                    flex: kolumna.udzial,
                    child: Text(
                      kolumna.naglowek,
                      textAlign: kolumna.doPrawej
                          ? TextAlign.right
                          : TextAlign.left,
                      style: teksty.labelLarge,
                    ),
                  ),
              ],
            ),
          ),
          if (wiersze.isEmpty)
            Padding(
              padding: const EdgeInsets.all(MotywKomputer.odstep),
              child: Text(
                gdyPusta ?? 'Nie ma tu jeszcze żadnego wiersza.',
                style: teksty.bodyLarge,
              ),
            )
          else
            for (final (numer, wiersz) in wiersze.indexed)
              _Wiersz(
                kolumny: kolumny,
                wiersz: wiersz,
                ostatni: numer == wiersze.length - 1,
              ),
        ],
      ),
    );
  }
}

class _Wiersz extends StatelessWidget {
  const _Wiersz({
    required this.kolumny,
    required this.wiersz,
    required this.ostatni,
  });

  final List<KolumnaTabeli> kolumny;
  final WierszTabeli wiersz;
  final bool ostatni;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final tresc = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MotywKomputer.odstep,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: MotywKomputer.odstep,
            children: [
              for (final (numer, kolumna) in kolumny.indexed)
                Expanded(
                  flex: kolumna.udzial,
                  child: Text(
                    numer < wiersz.wartosci.length
                        ? wiersz.wartosci[numer]
                        : 'brak',
                    textAlign: kolumna.doPrawej
                        ? TextAlign.right
                        : TextAlign.left,
                    style: teksty.bodyLarge,
                  ),
                ),
            ],
          ),
          if (wiersz.podpis case final String podpis) ...[
            const SizedBox(height: 2),
            Text(podpis, style: teksty.bodyMedium),
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: wiersz.wyrozniony
            ? MotywKomputer.ostrzezenieTlo
            : MotywKomputer.karta,
        border: ostatni
            ? null
            : const Border(
                bottom: BorderSide(color: MotywKomputer.obramowanie),
              ),
      ),
      child: wiersz.onKlik == null
          ? tresc
          : InkWell(onTap: wiersz.onKlik, child: tresc),
    );
  }
}
