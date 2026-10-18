import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/odczyt/czytnik_zdjecia.dart';
import '../../../rdzen/dostep/funkcja.dart';
import '../../../funkcje/odczyt/odczyt_etykiety.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../../../funkcje/zabiegi/slownik_srodkow.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_dawka.dart';

/// Krok 3: czym opryskujemy. Lista zawężona do środków **dopuszczonych
/// w tej uprawie** — rolnik nie przewija całego rejestru.
class EkranWyborSrodka extends StatefulWidget {
  const EkranWyborSrodka({super.key, required this.uslugi, required this.dane});

  final Uslugi uslugi;
  final DaneWpisu dane;

  @override
  State<EkranWyborSrodka> createState() => _EkranWyborSrodkaState();
}

class _EkranWyborSrodkaState extends State<EkranWyborSrodka> {
  late Future<List<DopuszczonySrodek>> _srodki;
  String _szukane = '';
  bool _czytaEtykiete = false;
  OdczytEtykiety? _odczyt;
  String? _bladOdczytu;

  /// Rozpoznanie etykiety ze zdjęcia: zawęża listę do tego, co widać na
  /// opakowaniu. Wybór i tak należy do rolnika — niczego nie zapisujemy
  /// za niego.
  Future<void> _rozpoznajEtykiete() async {
    if (_czytaEtykiete) {
      return;
    }
    setState(() {
      _czytaEtykiete = true;
      _bladOdczytu = null;
      _odczyt = null;
    });
    try {
      final tekst = await widget.uslugi.czytnikZdjecia.tekst(
        ZrodloZdjecia.aparat,
      );
      if (tekst == null || !mounted) {
        return;
      }
      final odczyt = await widget.uslugi.czytnikEtykiety.rozpoznaj(
        tekst,
        uprawa: _uprawa,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _odczyt = odczyt;
        if (odczyt.dopasowania.isNotEmpty) {
          _srodki = Future<List<DopuszczonySrodek>>.value(odczyt.dopasowania);
        }
      });
    } on BladOdczytuZdjecia catch (blad) {
      if (mounted) {
        setState(
          () => _bladOdczytu = [
            blad.wiadomosc,
            if (blad.coZrobic != null) blad.coZrobic!,
          ].join(' '),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _czytaEtykiete = false);
      }
    }
  }

  String get _uprawa => widget.dane.pola.first.uprawa;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _srodki = _szukane.isEmpty
        ? widget.uslugi.srodki.dlaUprawy(_uprawa)
        : widget.uslugi.srodki.szukaj(_uprawa, _szukane);
  }

  void _wybierz(DopuszczonySrodek srodek) {
    widget.dane
      ..srodek = srodek
      // Dawkę podpowiadamy tylko wtedy, gdy rejestr podaje ją
      // jednoznacznie. Inaczej pole zostaje puste i rolnik przepisuje ją
      // z etykiety (CLAUDE.md, reguła 5).
      ..dawka = srodek.dawkaZnana ? srodek.dawka : null
      ..jednostkaZEtykiety = null
      ..przyczyna = srodek.agrofag;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EkranDawka(uslugi: widget.uslugi, dane: widget.dane),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Czym opryskujesz?')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            child: TextField(
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Szukaj po nazwie',
                prefixIcon: Icon(Icons.search, size: 28),
                border: OutlineInputBorder(),
              ),
              onChanged: (tekst) => setState(() {
                _szukane = tekst.trim();
                _odswiez();
              }),
            ),
          ),
          // Zdjęcie etykiety to dodatek płatny (plan, pkt 8). Podczas
          // wpisu zabiegu nie wolno pokazywać żadnej oferty premium, więc
          // bez dostępu przycisku po prostu nie ma — rolnik wybiera środek
          // z listy, tak jak zawsze.
          if (widget.uslugi.dostep.czyDostepna(Funkcja.odczytZdjeciaEtykiety))
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MotywProsty.odstep,
              ),
              child: _czytaEtykiete
                  ? const Center(child: CircularProgressIndicator())
                  : DuzyPrzycisk(
                      etykieta: 'Rozpoznaj etykietę',
                      opis: 'zrób zdjęcie napisu na opakowaniu',
                      ikona: Icons.photo_camera_outlined,
                      onTap: _rozpoznajEtykiete,
                    ),
            ),
          if (_bladOdczytu != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MotywProsty.odstep,
                MotywProsty.odstep,
                MotywProsty.odstep,
                0,
              ),
              child: Ostrzezenie(tresc: _bladOdczytu!),
            ),
          if (_odczyt != null && _odczyt!.dopasowania.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MotywProsty.odstep,
                MotywProsty.odstep,
                MotywProsty.odstep,
                0,
              ),
              child: Ostrzezenie(
                tresc: _odczyt!.cokolwiekZnaleziono
                    ? 'Ze zdjęcia wyszło „${_odczyt!.nazwa ?? _odczyt!.nrZezwolenia}", '
                          'ale rejestr nie ma takiego środka dla tej uprawy.'
                    : 'Ze zdjęcia nic nie dało się odczytać.',
                coZrobic:
                    'Wybierz środek z listy albo zrób zdjęcie z bliska, '
                    'w świetle.',
              ),
            ),
          const SizedBox(height: MotywProsty.odstep),
          Expanded(
            child: FutureBuilder<List<DopuszczonySrodek>>(
              future: _srodki,
              builder: (context, stan) {
                if (!stan.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final srodki = stan.data!;
                if (srodki.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(MotywProsty.odstep),
                    child: Ostrzezenie(
                      tresc:
                          'Rejestr nie przewiduje tu żadnego środka '
                          'dla uprawy „$_uprawa".',
                      coZrobic: _szukane.isEmpty
                          ? 'Sprawdź, czy uprawa pola jest wpisana poprawnie.'
                          : 'Spróbuj wpisać inną część nazwy.',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(MotywProsty.odstep),
                  itemCount: srodki.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: MotywProsty.odstep),
                  itemBuilder: (context, numer) {
                    final srodek = srodki[numer];
                    return DuzyPrzycisk(
                      etykieta: srodek.nazwa,
                      opis: [
                        if (srodek.agrofag != null) srodek.agrofag!,
                        srodek.dawkaOpis,
                      ].join(' • '),
                      onTap: () => _wybierz(srodek),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
