import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zabiegi/kompletnosc_ewidencji.dart';
import '../../../funkcje/zabiegi/rejestr_zabiegow.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../dokumenty/ekran_dokumenty.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_wpis_rejestru.dart';

/// Rejestr zabiegów: wszystko, co rolnik wpisał, od najnowszego (krok 3
/// etapu 1). Z tego samego rejestru powstaną wydruk i eksport (krok 4).
class EkranRejestr extends StatefulWidget {
  const EkranRejestr({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranRejestr> createState() => _EkranRejestrState();
}

class _EkranRejestrState extends State<EkranRejestr> {
  late Future<List<WpisRejestru>> _wpisy;
  RodzajZabiegu? _rodzaj;
  String _szukane = '';

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _wpisy = widget.uslugi.rejestr.wpisy(
      widget.uslugi.gospodarstwoId,
      filtr: FiltrRejestru(rodzaj: _rodzaj, szukane: _szukane),
    );
  }

  Future<void> _otworz(WpisRejestru wpis) async {
    final zmienione = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            EkranWpisRejestru(uslugi: widget.uslugi, zabiegId: wpis.zabieg.id),
      ),
    );
    if (zmienione ?? false) {
      setState(_odswiez);
    }
  }

  /// Ile wpisów ma niekompletną ewidencję — to pierwsza rzecz, którą rolnik
  /// chce wiedzieć przed kontrolą.
  int _niekompletne(List<WpisRejestru> wpisy) {
    var ile = 0;
    for (final wpis in wpisy) {
      final obowiazek = widget.uslugi.reguly.obowiazek(
        KompletnoscEwidencji.idObowiazku(wpis.zabieg.rodzaj) ?? '',
      );
      if (obowiazek == null) {
        continue;
      }
      if (!KompletnoscEwidencji.sprawdz(wpis, obowiazek).kompletna) {
        ile++;
      }
    }
    return ile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejestr zabiegów')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            child: TextField(
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Szukaj: środek, pole, uprawa',
                prefixIcon: Icon(Icons.search, size: 28),
                border: OutlineInputBorder(),
              ),
              onChanged: (tekst) => setState(() {
                _szukane = tekst.trim();
                _odswiez();
              }),
            ),
          ),
          _PaskiRodzajow(
            wybrany: _rodzaj,
            onZmiana: (rodzaj) => setState(() {
              _rodzaj = rodzaj;
              _odswiez();
            }),
          ),
          Expanded(
            child: FutureBuilder<List<WpisRejestru>>(
              future: _wpisy,
              builder: (context, stan) {
                if (!stan.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final wpisy = stan.data!;
                if (wpisy.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(MotywProsty.odstep),
                    child: Ostrzezenie(
                      tresc: _szukane.isEmpty && _rodzaj == null
                          ? 'W rejestrze nie ma jeszcze żadnego wpisu.'
                          : 'Nic nie pasuje do tego szukania.',
                      coZrobic: _szukane.isEmpty && _rodzaj == null
                          ? 'Naciśnij „Dodaj zabieg" na ekranie głównym — '
                                'wpis zajmuje pięć dotknięć.'
                          : 'Pokaż wszystkie wpisy albo wpisz inną nazwę.',
                    ),
                  );
                }

                final niekompletne = _niekompletne(wpisy);
                return ListView.separated(
                  padding: const EdgeInsets.all(MotywProsty.odstep),
                  itemCount: wpisy.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: MotywProsty.odstep),
                  itemBuilder: (context, numer) {
                    if (numer == 0) {
                      return Column(
                        children: [
                          _Podsumowanie(
                            wpisy: wpisy.length,
                            niekompletne: niekompletne,
                          ),
                          const SizedBox(height: MotywProsty.odstep),
                          DuzyPrzycisk(
                            etykieta: 'Wydruk i eksport',
                            opis: 'PDF, CSV i XLSX — zawsze bez opłat',
                            ikona: Icons.print_outlined,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    EkranDokumenty(uslugi: widget.uslugi),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return _WpisNaLiscie(
                      wpis: wpisy[numer - 1],
                      uslugi: widget.uslugi,
                      onTap: () => _otworz(wpisy[numer - 1]),
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

/// Wybór rodzaju zabiegu dużymi przyciskami — bez listy rozwijanej.
class _PaskiRodzajow extends StatelessWidget {
  const _PaskiRodzajow({required this.wybrany, required this.onZmiana});

  final RodzajZabiegu? wybrany;
  final void Function(RodzajZabiegu?) onZmiana;

  static const List<RodzajZabiegu> _widoczne = [
    RodzajZabiegu.oprysk,
    RodzajZabiegu.nawozenie,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MotywProsty.minCelDotyku + 12,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MotywProsty.odstep),
        children: [
          _Pasek(
            etykieta: 'Wszystkie',
            wybrany: wybrany == null,
            onTap: () => onZmiana(null),
          ),
          for (final rodzaj in _widoczne)
            _Pasek(
              etykieta: rodzaj.dlaRolnika,
              wybrany: wybrany == rodzaj,
              onTap: () => onZmiana(rodzaj),
            ),
        ],
      ),
    );
  }
}

class _Pasek extends StatelessWidget {
  const _Pasek({
    required this.etykieta,
    required this.wybrany,
    required this.onTap,
  });

  final String etykieta;
  final bool wybrany;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Semantics(
        button: true,
        selected: wybrany,
        child: Material(
          color: wybrany
              ? MotywProsty.zielenAkcji
              : MotywProsty.powierzchniaDruga,
          borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Center(
                child: Text(
                  etykieta,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: wybrany
                        ? MotywProsty.powierzchnia
                        : MotywProsty.tekst,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Podsumowanie extends StatelessWidget {
  const _Podsumowanie({required this.wpisy, required this.niekompletne});

  final int wpisy;
  final int niekompletne;

  @override
  Widget build(BuildContext context) {
    if (niekompletne == 0) {
      return Text(
        'Wpisów: $wpisy. Każdy ma komplet danych do ewidencji.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Ostrzezenie(
      tresc:
          'Wpisów: $wpisy, w tym $niekompletne bez pełnych danych '
          'do ewidencji.',
      coZrobic: 'Otwórz taki wpis — na dole widać, czego brakuje.',
    );
  }
}

class _WpisNaLiscie extends StatelessWidget {
  const _WpisNaLiscie({
    required this.wpis,
    required this.uslugi,
    required this.onTap,
  });

  final WpisRejestru wpis;
  final Uslugi uslugi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final obowiazek = uslugi.reguly.obowiazek(
      KompletnoscEwidencji.idObowiazku(wpis.zabieg.rodzaj) ?? '',
    );
    final kompletny =
        obowiazek == null ||
        KompletnoscEwidencji.sprawdz(wpis, obowiazek).kompletna;
    final srodek = wpis.oprysk?.srodekNazwa;

    return DuzyPrzycisk(
      etykieta:
          '${KompletnoscEwidencji.dzien(wpis.zabieg.data)} • '
          '${wpis.zabieg.rodzaj.dlaRolnika}',
      opis: [
        if (srodek case final String nazwa) nazwa,
        // Przy pracy „inny" w uwagach stoi nazwa pracy wybranej przez
        // rolnika — bez niej wpis mówiłby tylko „Inny".
        if (srodek == null)
          if (wpis.zabieg.uwagi case final String uwagi) uwagi,
        wpis.opisPol,
        wpis.powierzchniaOpis,
      ].join(' • '),
      ikona: kompletny ? Icons.check_circle_outline : Icons.error_outline,
      onTap: onTap,
    );
  }
}
