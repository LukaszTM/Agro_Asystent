import 'package:flutter/material.dart';

import '../../app/uslugi.dart';
import '../../rdzen/dostep/dostep_funkcji.dart';
import '../../rdzen/marka/marka.dart';
import 'ekran_pola.dart';
import 'ekran_w_budowie.dart';
import 'rejestr/ekran_rejestr.dart';
import 'terminy/ekran_terminy.dart';
import 'motyw.dart';
import 'wpis/ekran_wybor_pola.dart';

/// Ekran główny wyglądu „Prosty": cztery duże przyciski, bez ukrytego menu
/// (plan, pkt 5). Kolejność od najczęściej używanego.
class EkranGlownyProsty extends StatelessWidget {
  const EkranGlownyProsty({super.key, required this.dostep, this.uslugi});

  final DostepFunkcji dostep;

  /// Usługi są dostępne dopiero po otwarciu bazy; bez nich pokazujemy ekrany
  /// zastępcze zamiast pustej aplikacji.
  final Uslugi? uslugi;

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
          'Rejestr zabiegów do podglądu; wydruk PDF i eksport '
          'CSV/XLSX — zawsze w wersji darmowej.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: MotywProsty.odstep,
        title: Row(
          children: [
            Image.asset(
              Marka.logo,
              height: 40,
              // Logo jest znakiem aplikacji, nie treścią ekranu — czytnik
              // ekranu ma czytać nazwę, nie opisywać obrazek.
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 12),
            const Text(Marka.nazwa),
          ],
        ),
      ),
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
                    _PrzyciskKafelek(kafelek: kafelek, uslugi: uslugi),
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
  const _PrzyciskKafelek({required this.kafelek, this.uslugi});

  final _Kafelek kafelek;
  final Uslugi? uslugi;

  Widget _ekranDocelowy() {
    final dostepneUslugi = uslugi;
    if (dostepneUslugi != null) {
      switch (kafelek.etykieta) {
        case 'Pola':
          return EkranPola(uslugi: dostepneUslugi);
        case 'Dodaj zabieg':
          return EkranWyborPola(uslugi: dostepneUslugi);
        case 'Dokumenty':
          return EkranRejestr(uslugi: dostepneUslugi);
        case 'Terminy':
          return EkranTerminy(uslugi: dostepneUslugi);
      }
    }
    return EkranWBudowie(tytul: kafelek.etykieta, coBedzie: kafelek.coBedzie);
  }

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
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => _ekranDocelowy())),
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
