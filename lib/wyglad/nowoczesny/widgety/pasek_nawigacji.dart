import 'package:flutter/material.dart';

import '../motyw.dart';

/// Jedna zakładka dolnego paska.
class ZakladkaPaska {
  const ZakladkaPaska({required this.etykieta, required this.ikona});

  final String etykieta;
  final IconData ikona;
}

/// Dolny pasek nawigacji z wyróżnionym przyciskiem „+" w środku
/// (plan, pkt 5 — tabela dwóch wyglądów).
///
/// Przycisk „+" jest osobny, bo wpis zabiegu to najczęstsze działanie
/// w aplikacji: ma być pod palcem, nie w menu.
class PasekNawigacji extends StatelessWidget {
  const PasekNawigacji({
    super.key,
    required this.zakladki,
    required this.wybrana,
    required this.onZakladka,
    required this.onDodaj,
  });

  final List<ZakladkaPaska> zakladki;
  final int wybrana;
  final ValueChanged<int> onZakladka;
  final VoidCallback onDodaj;

  @override
  Widget build(BuildContext context) {
    // „+" wchodzi w środek paska: połowa zakładek po lewej, połowa po prawej.
    final polowa = (zakladki.length / 2).ceil();

    return Container(
      color: MotywNowoczesny.pasekNawigacji,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MotywNowoczesny.wysokoscPaska,
          child: Row(
            children: [
              for (var numer = 0; numer < polowa; numer++)
                Expanded(
                  child: _Zakladka(numer: numer, pasek: this),
                ),
              _PrzyciskDodaj(onTap: onDodaj),
              for (var numer = polowa; numer < zakladki.length; numer++)
                Expanded(
                  child: _Zakladka(numer: numer, pasek: this),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Zakladka extends StatelessWidget {
  const _Zakladka({required this.numer, required this.pasek});

  final int numer;
  final PasekNawigacji pasek;

  @override
  Widget build(BuildContext context) {
    final zakladka = pasek.zakladki[numer];
    final wybrana = numer == pasek.wybrana;
    final kolor = wybrana
        ? MotywNowoczesny.przyciskDodaj
        : MotywNowoczesny.karta;

    return Semantics(
      button: true,
      selected: wybrana,
      child: InkWell(
        onTap: () => pasek.onZakladka(numer),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(zakladka.ikona, size: 22, color: kolor),
            const SizedBox(height: 2),
            // Rozmiar bierzemy z motywu tego wyglądu, nie z `Theme.of`:
            // pasek ma cztery podpisy w jednym wierszu i musi się zmieścić
            // także wtedy, gdy ekran przebudowuje się po zmianie wyglądu.
            Text(
              zakladka.etykieta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: kolor,
                fontFamily: MotywNowoczesny.krojPisma,
                fontSize: MotywNowoczesny.minRozmiarTekstu,
                fontWeight: wybrana ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrzyciskDodaj extends StatelessWidget {
  const _PrzyciskDodaj({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Semantics(
        button: true,
        label: 'Dodaj zabieg',
        child: Material(
          color: MotywNowoczesny.przyciskDodaj,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: MotywNowoczesny.minCelDotyku + 4,
              height: MotywNowoczesny.minCelDotyku + 4,
              child: Icon(
                Icons.add,
                size: 28,
                color: MotywNowoczesny.tekst,
                // Czytnik ekranu czyta etykietę przycisku, nie nazwę ikony.
                semanticLabel: '',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
