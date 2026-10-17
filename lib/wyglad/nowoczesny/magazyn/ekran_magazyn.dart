import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/magazyn/magazyn.dart';
import '../../../rdzen/dostep/funkcja.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';

/// Magazyn w wyglądzie nowoczesnym — te same liczby i te same zdania co
/// w prostym, bo liczy je `funkcje/magazyn/`.
class EkranMagazynNowoczesny extends StatefulWidget {
  const EkranMagazynNowoczesny({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;
  final DateTime? teraz;

  @override
  State<EkranMagazynNowoczesny> createState() => _EkranMagazynNowoczesnyState();
}

class _EkranMagazynNowoczesnyState extends State<EkranMagazynNowoczesny> {
  late Future<List<StanPozycji>> _stany;
  bool _pracuje = false;

  DateTime get _teraz => widget.teraz ?? DateTime.now();

  bool get _dostepny => widget.uslugi.dostep.czyDostepna(Funkcja.magazyn);

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _stany = widget.uslugi.magazyn.stan(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      naDzien: _teraz,
    );
  }

  Future<void> _dodajNawoz() async {
    final nawozy = await widget.uslugi.nawozy.wszystkie(
      widget.uslugi.gospodarstwoId,
    );
    for (final nawoz in nawozy) {
      await widget.uslugi.magazyn.zapiszPozycje(
        gospodarstwoId: widget.uslugi.gospodarstwoId,
        rodzaj: RodzajPozycji.nawoz,
        nazwa: nawoz.nazwa,
        jednostka: 'kg',
        nawozId: nawoz.id,
        urzadzenie: widget.uslugi.urzadzenie,
        teraz: _teraz,
      );
    }
    if (mounted) {
      setState(_odswiez);
    }
  }

  Future<void> _dodajSrodki() async {
    final propozycje = await widget.uslugi.magazyn.srodkiZZabiegow(
      widget.uslugi.gospodarstwoId,
    );
    for (final propozycja in propozycje) {
      await widget.uslugi.magazyn.zapiszPozycje(
        gospodarstwoId: widget.uslugi.gospodarstwoId,
        rodzaj: RodzajPozycji.srodek,
        nazwa: propozycja.nazwa,
        jednostka: propozycja.jednostka,
        nrZezwolenia: propozycja.nrZezwolenia,
        // Termin stosowania z rejestru — bez niego magazyn nie ostrzeże
        // o zapasie środka, którego nie wolno już stosować.
        terminDoStosowania: await widget.uslugi.srodki.terminDoStosowania(
          propozycja.nazwa,
        ),
        urzadzenie: widget.uslugi.urzadzenie,
        teraz: _teraz,
      );
    }
    if (mounted) {
      setState(_odswiez);
    }
  }

  Future<void> _zakup(StanPozycji stanPozycji) async {
    final ilosc = await showDialog<double>(
      context: context,
      builder: (context) => _WpisIlosci(
        tytul: 'Ile kupione?',
        jednostka: stanPozycji.pozycja.jednostka,
      ),
    );
    if (ilosc == null || _pracuje) {
      return;
    }
    setState(() => _pracuje = true);
    try {
      await widget.uslugi.magazyn.zapiszZakup(
        pozycjaId: stanPozycji.pozycja.id,
        ilosc: ilosc,
        kiedy: _teraz,
        urzadzenie: widget.uslugi.urzadzenie,
        teraz: _teraz,
      );
    } finally {
      if (mounted) {
        setState(() {
          _pracuje = false;
          _odswiez();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Magazyn')),
      body: FutureBuilder<List<StanPozycji>>(
        future: _stany,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stany = stan.data!;
          return ListView(
            padding: const EdgeInsets.all(MotywNowoczesny.odstep),
            children: [
              if (!_dostepny)
                const OstrzezenieNowoczesne(
                  tresc: 'Magazyn należy do wersji płatnej.',
                  coZrobic:
                      'Wpisy, rejestry, wydruk i eksport działają bez '
                      'opłaty — magazyn tylko oszczędza czas.',
                )
              else ...[
                Text(
                  'Stan na ${Daty.krotko(_teraz)}',
                  style: teksty.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Liczony z zakupów i zużycia; zużycie dopisuje się samo '
                  'przy wpisie zabiegu.',
                  style: teksty.bodyMedium,
                ),
                const SizedBox(height: 8),
                if (stany.isEmpty)
                  const OstrzezenieNowoczesne(
                    tresc: 'Magazyn jest jeszcze pusty.',
                    coZrobic:
                        'Dodaj nawozy ze spisu albo środki, którymi już '
                        'opryskiwałeś.',
                  ),
                for (final stanPozycji in stany) ...[
                  Karta(
                    onTap: _pracuje ? null : () => _zakup(stanPozycji),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stanPozycji.pozycja.nazwa,
                          style: teksty.titleLarge,
                        ),
                        Text(
                          '${stanPozycji.iloscOpis} • '
                          '${stanPozycji.pozycja.rodzaj.dlaRolnika}',
                          style: teksty.bodyLarge,
                        ),
                        Text(
                          'kupione ${_liczba(stanPozycji.zakupy)} • '
                          'zużyte ${_liczba(stanPozycji.zuzycie)} '
                          '${stanPozycji.pozycja.jednostka}',
                          style: teksty.bodyMedium,
                        ),
                        for (final ostrzezenie
                            in widget.uslugi.magazyn.ostrzezenia(
                              stanPozycji,
                            )) ...[
                          const SizedBox(height: 8),
                          OstrzezenieNowoczesne(
                            tresc: ostrzezenie.tresc,
                            coZrobic: ostrzezenie.coZrobic,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: MotywNowoczesny.odstep),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Wybor(
                      etykieta: 'Dodaj nawozy ze spisu',
                      ikona: Icons.grass_outlined,
                      wybrany: false,
                      onTap: _dodajNawoz,
                    ),
                    Wybor(
                      etykieta: 'Dodaj środki z zabiegów',
                      ikona: Icons.water_drop_outlined,
                      wybrany: false,
                      onTap: _dodajSrodki,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Dotknij pozycji, żeby dopisać zakup.',
                  style: teksty.bodyMedium,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _liczba(double wartosc) =>
      wartosc.toStringAsFixed(2).replaceAll('.', ',');
}

/// Ilość przyciskami „−" i „+" — bez klawiatury (reguły interfejsu).
class _WpisIlosci extends StatefulWidget {
  const _WpisIlosci({required this.tytul, required this.jednostka});

  final String tytul;
  final String jednostka;

  @override
  State<_WpisIlosci> createState() => _WpisIlosciState();
}

class _WpisIlosciState extends State<_WpisIlosci> {
  double _ilosc = 0;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.tytul),
    content: SizedBox(
      width: 320,
      child: WyborLiczbyNowoczesny(
        wartosc: _ilosc,
        jednostka: widget.jednostka,
        krok: 1,
        onZmiana: (nowa) => setState(() => _ilosc = nowa < 0 ? 0 : nowa),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Wróć'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_ilosc),
        child: const Text('Zapisz'),
      ),
    ],
  );
}
