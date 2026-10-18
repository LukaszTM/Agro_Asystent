import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/magazyn/magazyn.dart';
import '../../../rdzen/dostep/funkcja.dart';
import '../../../rdzen/dostep/opis_premium.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/tabela.dart';

/// Magazyn na komputerze: stan, zakupy i zużycie w jednej tabeli.
///
/// Stan liczy się z ruchów (`funkcje/magazyn/`), a zużycie dopisuje się
/// samo przy wpisie zabiegu — tutaj rolnik wpisuje zakupy, bo faktury
/// zwykle przepisuje przy komputerze.
class WidokMagazynKomputer extends StatefulWidget {
  const WidokMagazynKomputer({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;
  final DateTime? teraz;

  @override
  State<WidokMagazynKomputer> createState() => _WidokMagazynKomputerState();
}

class _WidokMagazynKomputerState extends State<WidokMagazynKomputer> {
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

  Future<void> _zakup(StanPozycji stanPozycji) async {
    final ilosc = await showDialog<double>(
      context: context,
      builder: (context) => _WpisZakupu(
        nazwa: stanPozycji.pozycja.nazwa,
        jednostka: stanPozycji.pozycja.jednostka,
      ),
    );
    if (ilosc == null || ilosc <= 0 || _pracuje) {
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

  Future<void> _dodajZeSpisow() async {
    setState(() => _pracuje = true);
    try {
      final magazyn = widget.uslugi.magazyn;
      for (final nawoz in await widget.uslugi.nawozy.wszystkie(
        widget.uslugi.gospodarstwoId,
      )) {
        await magazyn.zapiszPozycje(
          gospodarstwoId: widget.uslugi.gospodarstwoId,
          rodzaj: RodzajPozycji.nawoz,
          nazwa: nawoz.nazwa,
          jednostka: 'kg',
          nawozId: nawoz.id,
          urzadzenie: widget.uslugi.urzadzenie,
          teraz: _teraz,
        );
      }
      for (final propozycja in await magazyn.srodkiZZabiegow(
        widget.uslugi.gospodarstwoId,
      )) {
        await magazyn.zapiszPozycje(
          gospodarstwoId: widget.uslugi.gospodarstwoId,
          rodzaj: RodzajPozycji.srodek,
          nazwa: propozycja.nazwa,
          jednostka: propozycja.jednostka,
          nrZezwolenia: propozycja.nrZezwolenia,
          terminDoStosowania: await widget.uslugi.srodki.terminDoStosowania(
            propozycja.nazwa,
          ),
          urzadzenie: widget.uslugi.urzadzenie,
          teraz: _teraz,
        );
      }
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
    if (!_dostepny) {
      return ListView(
        children: [
          NaglowekWidoku(tytul: 'Magazyn'),
          const SizedBox(height: MotywKomputer.odstep),
          OstrzezenieKomputer(
            tresc: OpisPremium.tresc(Funkcja.magazyn),
            coZrobic: OpisPremium.coZrobic(Funkcja.magazyn),
          ),
        ],
      );
    }

    return FutureBuilder<List<StanPozycji>>(
      future: _stany,
      builder: (context, stan) {
        if (!stan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stany = stan.data!;
        final ostrzezenia = [
          for (final stanPozycji in stany)
            ...widget.uslugi.magazyn.ostrzezenia(stanPozycji),
        ];

        return ListView(
          children: [
            NaglowekWidoku(
              tytul: 'Stan na ${Daty.krotko(_teraz)}',
              opis:
                  'Liczony z zakupów i zużycia. Zużycie dopisuje się samo '
                  'przy wpisie zabiegu — z dawki i powierzchni.',
            ),
            const SizedBox(height: MotywKomputer.odstep),
            for (final ostrzezenie in ostrzezenia) ...[
              OstrzezenieKomputer(
                tresc: ostrzezenie.tresc,
                coZrobic: ostrzezenie.coZrobic,
              ),
              const SizedBox(height: 8),
            ],
            Tabela(
              kolumny: const [
                KolumnaTabeli('Pozycja', udzial: 2),
                KolumnaTabeli('Rodzaj'),
                KolumnaTabeli('Zostało', doPrawej: true),
                KolumnaTabeli('Kupione', doPrawej: true),
                KolumnaTabeli('Zużyte', doPrawej: true),
                KolumnaTabeli('Ostatni zakup'),
              ],
              gdyPusta:
                  'Magazyn jest jeszcze pusty. Dodaj pozycje ze spisu '
                  'nawozów i ze środków, którymi już opryskiwałeś.',
              wiersze: [
                for (final stanPozycji in stany)
                  WierszTabeli(
                    wartosci: [
                      stanPozycji.pozycja.nazwa,
                      stanPozycji.pozycja.rodzaj.dlaRolnika,
                      stanPozycji.iloscOpis,
                      _liczba(stanPozycji.zakupy),
                      _liczba(stanPozycji.zuzycie),
                      stanPozycji.ostatniZakup == null
                          ? 'brak'
                          : Daty.krotko(stanPozycji.ostatniZakup!),
                    ],
                    wyrozniony:
                        stanPozycji.stanUjemny || stanPozycji.terminMinal,
                    onKlik: _pracuje ? null : () => _zakup(stanPozycji),
                    podpis: 'kliknij, żeby dopisać zakup',
                  ),
              ],
            ),
            const SizedBox(height: MotywKomputer.odstep),
            if (_pracuje)
              const Center(child: CircularProgressIndicator())
            else
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _dodajZeSpisow,
                  icon: const Icon(Icons.playlist_add_outlined, size: 20),
                  label: const Text(
                    'Dodaj pozycje ze spisu nawozów i z zabiegów',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _liczba(double wartosc) =>
      wartosc.toStringAsFixed(2).replaceAll('.', ',');
}

/// Ile przyszło. Na komputerze liczbę wpisuje się z klawiatury — to nie
/// telefon w rękawicy.
class _WpisZakupu extends StatefulWidget {
  const _WpisZakupu({required this.nazwa, required this.jednostka});

  final String nazwa;
  final String jednostka;

  @override
  State<_WpisZakupu> createState() => _WpisZakupuState();
}

class _WpisZakupuState extends State<_WpisZakupu> {
  final TextEditingController _ilosc = TextEditingController();
  String? _blad;

  @override
  void dispose() {
    _ilosc.dispose();
    super.dispose();
  }

  void _zapisz() {
    final liczba = double.tryParse(_ilosc.text.trim().replaceAll(',', '.'));
    if (liczba == null || liczba <= 0) {
      setState(() => _blad = 'Wpisz, ile przyszło — liczbę większą od zera.');
      return;
    }
    Navigator.of(context).pop(liczba);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Zakup: ${widget.nazwa}'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ilosc,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Ile kupione (${widget.jednostka})',
              errorText: _blad,
            ),
            onSubmitted: (_) => _zapisz(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Wróć'),
      ),
      FilledButton(onPressed: _zapisz, child: const Text('Zapisz')),
    ],
  );
}
