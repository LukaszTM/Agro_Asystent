import 'package:flutter/material.dart';

import '../../rdzen/dostep/dostep_funkcji.dart';
import 'ekran_w_budowie.dart';
import 'motyw.dart';

/// Ekran główny wyglądu „Prosty": cztery duże przyciski, bez ukrytego menu
/// (plan, pkt 5). Kolejność od najczęściej używanego.
class EkranGlownyProsty extends StatelessWidget {
  const EkranGlownyProsty({super.key, required this.dostep});

  final DostepFunkcji dostep;

  static const List<_Kafelek> _kafelki = [
    _Kafelek(
      etykieta: 'Pola',
      ikona: Icons.map_outlined,
      coBedzie:
          'Lista pól i mapa działek. Dodawanie działki po numerze '
          'ewidencyjnym, granice z ULDK, praca bez internetu.',
    ),
    _Kafelek(
      etykieta: 'Dodaj zabieg',
      ikona: Icons.add_circle_outline,
      coBedzie:
          'Wpis oprysku i nawożenia w pięciu dotknięciach: pole, '
          'rodzaj zabiegu, środek, dawka i przyczyna, zapis.',
      glowny: true,
    ),
    _Kafelek(
      etykieta: 'Terminy',
      ikona: Icons.event_outlined,
      coBedzie:
          'Kalendarz obowiązków: karencja, terminy nawożenia, '
          'zgłoszenia zwierząt, nabór wniosków.',
    ),
    _Kafelek(
      etykieta: 'Dokumenty',
      ikona: Icons.description_outlined,
      coBedzie:
          'Trzy rejestry do podglądu, wydruku PDF i eksportu '
          'CSV/XLSX — zawsze w wersji darmowej.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agro Asystent')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MotywProsty.odstep),
          child: LayoutBuilder(
            builder: (context, wymiary) {
              final waskiEkran = wymiary.maxWidth < 420;
              return GridView.count(
                crossAxisCount: waskiEkran ? 1 : 2,
                mainAxisSpacing: MotywProsty.odstep,
                crossAxisSpacing: MotywProsty.odstep,
                childAspectRatio: waskiEkran ? 2.4 : 1.2,
                children: [
                  for (final kafelek in _kafelki)
                    _PrzyciskKafelek(kafelek: kafelek),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Kafelek {
  const _Kafelek({
    required this.etykieta,
    required this.ikona,
    required this.coBedzie,
    this.glowny = false,
  });

  final String etykieta;
  final IconData ikona;
  final String coBedzie;

  /// Najważniejsze działanie — wyróżnione kolorem.
  final bool glowny;
}

class _PrzyciskKafelek extends StatelessWidget {
  const _PrzyciskKafelek({required this.kafelek});

  final _Kafelek kafelek;

  @override
  Widget build(BuildContext context) {
    final tloKafelka = kafelek.glowny
        ? MotywProsty.zielenAkcji
        : MotywProsty.powierzchniaDruga;
    final kolorTekstu = kafelek.glowny
        ? MotywProsty.powierzchnia
        : MotywProsty.tekst;

    return Semantics(
      button: true,
      label: kafelek.etykieta,
      child: Material(
        color: tloKafelka,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieDuze),
        child: InkWell(
          borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieDuze),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EkranWBudowie(
                tytul: kafelek.etykieta,
                coBedzie: kafelek.coBedzie,
              ),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MotywProsty.minCelDotyku * 2,
            ),
            child: Padding(
              padding: const EdgeInsets.all(MotywProsty.odstep),
              child: Row(
                children: [
                  Icon(kafelek.ikona, size: 48, color: kolorTekstu),
                  const SizedBox(width: MotywProsty.odstep),
                  Expanded(
                    child: Text(
                      kafelek.etykieta,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: kolorTekstu),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
