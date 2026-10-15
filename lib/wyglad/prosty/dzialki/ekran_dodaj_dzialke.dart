import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/klient_uldk.dart';
import '../../../funkcje/dzialki/repozytorium_dzialek.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import '../widgety/klawiatura_numeru.dart';
import 'mapa_dzialek.dart';

/// Dodanie działki ewidencyjnej po numerze: numer → granice z ULDK →
/// potwierdzenie na mapie → zapis (plan, pkt 4 krok 1).
///
/// Potwierdzenie na mapie jest obowiązkowe, bo nazwy obrębów się powtarzają
/// i po samym numerze rolnik nie pozna, czy to jego działka (plan, pkt 6.1).
class EkranDodajDzialke extends StatefulWidget {
  const EkranDodajDzialke({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranDodajDzialke> createState() => _EkranDodajDzialkeState();
}

class _EkranDodajDzialkeState extends State<EkranDodajDzialke> {
  String _numer = '';
  bool _szukanie = false;
  bool _zapisywanie = false;
  BladUldk? _blad;
  DzialkaZUldk? _znaleziona;
  bool _jestJuzDodana = false;

  void _dopisz(String znak) {
    setState(() {
      _numer += znak;
      _blad = null;
    });
  }

  void _usunZnak() {
    if (_numer.isEmpty) {
      return;
    }
    setState(() {
      _numer = _numer.substring(0, _numer.length - 1);
      _blad = null;
    });
  }

  Future<void> _szukaj() async {
    setState(() {
      _szukanie = true;
      _blad = null;
      _znaleziona = null;
      _jestJuzDodana = false;
    });
    try {
      final dzialka = await widget.uslugi.uldk.pobierz(_numer);
      final jestJuz = await widget.uslugi.dzialki.czyJuzJest(
        widget.uslugi.gospodarstwoId,
        dzialka.identyfikator,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _znaleziona = dzialka;
        _jestJuzDodana = jestJuz;
        _szukanie = false;
      });
    } on BladUldk catch (blad) {
      if (!mounted) {
        return;
      }
      setState(() {
        _blad = blad;
        _szukanie = false;
      });
    } on FormatException {
      if (!mounted) {
        return;
      }
      setState(() {
        _blad = const BladUldk(
          'Granice tej działki przyszły w postaci, której nie rozumiemy.',
          coZrobic:
              'Zgłoś to w ustawieniach aplikacji — działkę można na razie '
              'dodać bez mapy jako pole.',
        );
        _szukanie = false;
      });
    }
  }

  Future<void> _zapisz() async {
    final dzialka = _znaleziona;
    if (dzialka == null) {
      return;
    }
    setState(() => _zapisywanie = true);
    await widget.uslugi.dzialki.zapisz(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      zUldk: dzialka,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _popraw() {
    setState(() {
      _znaleziona = null;
      _jestJuzDodana = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final znaleziona = _znaleziona;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          znaleziona == null ? 'Dodaj działkę' : 'Czy to ta działka?',
        ),
      ),
      body: SafeArea(
        child: znaleziona == null
            ? _wpisywanie(context)
            : _potwierdzenie(context, znaleziona),
      ),
    );
  }

  Widget _wpisywanie(BuildContext context) {
    final blad = _blad;
    // Przycisk „Znajdź działkę" zostaje na dole ekranu, a przewija się tylko
    // klawiatura — rolnik nie musi szukać przycisku pod spodem.
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            children: [
              Text(
                'Numer działki',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: MotywProsty.odstep,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: MotywProsty.powierzchnia,
                  borderRadius: BorderRadius.circular(
                    MotywProsty.zaokraglenieMale,
                  ),
                  border: Border.all(
                    color: MotywProsty.powierzchniaDruga,
                    width: 2,
                  ),
                ),
                child: Text(
                  _numer.isEmpty ? 'wpisz numer' : _numer,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: _numer.isEmpty
                        ? MotywProsty.ostrzezenieObramowanie
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Numer przepisz z wniosku — wygląda tak: 061506_2.0007.138.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: MotywProsty.odstep),
              KlawiaturaNumeru(onZnak: _dopisz, onUsun: _usunZnak),
              const SizedBox(height: MotywProsty.odstep),
              Text(
                'Granice pobieramy raz, z państwowej usługi ULDK. Potem mapa '
                'działa bez internetu.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(MotywProsty.odstep),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (blad != null) ...[
                Ostrzezenie(tresc: blad.wiadomosc, coZrobic: blad.coZrobic),
                const SizedBox(height: MotywProsty.odstep),
              ],
              if (_szukanie)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _numer.isEmpty ? null : _szukaj,
                    child: const Text('Znajdź działkę'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _potwierdzenie(BuildContext context, DzialkaZUldk dzialka) {
    final doPokazania = DzialkaEwidencyjna(
      id: 'podglad',
      identyfikator: dzialka.identyfikator,
      obreb: dzialka.obreb,
      gmina: dzialka.gmina,
      nrDzialki: dzialka.nrDzialki,
      powierzchniaHa: dzialka.powierzchniaHa,
      geometriaWkt: dzialka.wkt,
    );

    return ListView(
      padding: const EdgeInsets.all(MotywProsty.odstep),
      children: [
        MapaDzialek(dzialki: [doPokazania], wyrozniona: dzialka.identyfikator),
        const SizedBox(height: MotywProsty.odstep),
        Text(
          dzialka.identyfikator,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          dzialka.polozenie.isEmpty ? 'położenie nieznane' : dzialka.polozenie,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        // Powierzchnia z granic jest przybliżona — do dokumentu idzie ta
        // z wniosku, dlatego mówimy o niej „około".
        Text(
          'około ${doPokazania.powierzchniaOpis}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: MotywProsty.odstep),
        if (_jestJuzDodana) ...[
          const Ostrzezenie(
            tresc: 'Ta działka jest już dodana.',
            coZrobic:
                'Wróć do listy działek — nie musisz dodawać jej drugi raz.',
          ),
          const SizedBox(height: MotywProsty.odstep),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Wróć do listy'),
          ),
        ] else if (_zapisywanie)
          const Center(child: CircularProgressIndicator())
        else ...[
          FilledButton(
            onPressed: _zapisz,
            child: const Text('Tak, to moja działka'),
          ),
          const SizedBox(height: MotywProsty.odstep),
          OutlinedButton(
            onPressed: _popraw,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                MotywProsty.minCelDotyku * 2,
                MotywProsty.minCelDotyku + 8,
              ),
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            child: const Text('Nie, popraw numer'),
          ),
        ],
      ],
    );
  }
}
