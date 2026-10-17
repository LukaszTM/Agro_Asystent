import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/magazyn/magazyn.dart';
import '../../../funkcje/nawozenie/nawoz.dart';
import '../../../rdzen/dostep/funkcja.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import '../widgety/wybor_liczby.dart';

/// Magazyn: ile środków i nawozów zostało, co kupione i co zużyte.
///
/// Stan liczy się z ruchów, więc każdą liczbę da się wytłumaczyć. Zużycie
/// przy zabiegu dopisuje się samo — tu rolnik wpisuje zakupy i poprawki.
///
/// Magazyn to funkcja premium (plan, pkt 8): oszczędza czas, ale żadna
/// dokumentacja od niego nie zależy. Bez premium ekran mówi o tym wprost
/// i niczego nie blokuje w rejestrach.
class EkranMagazyn extends StatefulWidget {
  const EkranMagazyn({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;

  /// Dzień, na który liczymy stan. W aplikacji „dzisiaj".
  final DateTime? teraz;

  @override
  State<EkranMagazyn> createState() => _EkranMagazynState();
}

class _EkranMagazynState extends State<EkranMagazyn> {
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

  Future<void> _dodajZNawozow() async {
    final nawozy = await widget.uslugi.nawozy.wszystkie(
      widget.uslugi.gospodarstwoId,
    );
    if (!mounted) {
      return;
    }
    final wybrany = await showDialog<Nawoz>(
      context: context,
      builder: (context) => _ListaWyboru<Nawoz>(
        tytul: 'Który nawóz?',
        pozycje: nawozy,
        etykieta: (nawoz) => nawoz.nazwa,
      ),
    );
    if (wybrany == null) {
      return;
    }
    await widget.uslugi.magazyn.zapiszPozycje(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      rodzaj: RodzajPozycji.nawoz,
      nazwa: wybrany.nazwa,
      // Nawozy liczymy w tonach i kilogramach; magazyn trzyma kilogramy,
      // bo tak stoi na worku.
      jednostka: 'kg',
      nawozId: wybrany.id,
      urzadzenie: widget.uslugi.urzadzenie,
      teraz: _teraz,
    );
    if (mounted) {
      setState(_odswiez);
    }
  }

  Future<void> _dodajZeSrodkow() async {
    final propozycje = await widget.uslugi.magazyn.srodkiZZabiegow(
      widget.uslugi.gospodarstwoId,
    );
    if (!mounted) {
      return;
    }
    final wybrana = await showDialog<PropozycjaPozycji>(
      context: context,
      builder: (context) => _ListaWyboru<PropozycjaPozycji>(
        tytul: 'Który środek?',
        pozycje: propozycje,
        etykieta: (p) => p.nazwa,
      ),
    );
    if (wybrana == null) {
      return;
    }
    await widget.uslugi.magazyn.zapiszPozycje(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      rodzaj: RodzajPozycji.srodek,
      nazwa: wybrana.nazwa,
      jednostka: wybrana.jednostka,
      nrZezwolenia: wybrana.nrZezwolenia,
      // Termin stosowania bierzemy z rejestru — stąd ostrzeżenie
      // o zapasie środka, którego nie wolno już wylać na pole.
      terminDoStosowania: await widget.uslugi.srodki.terminDoStosowania(
        wybrana.nazwa,
      ),
      urzadzenie: widget.uslugi.urzadzenie,
      teraz: _teraz,
    );
    if (mounted) {
      setState(_odswiez);
    }
  }

  Future<void> _ruch(StanPozycji stanPozycji, {required bool zakup}) async {
    final ilosc = await showDialog<double>(
      context: context,
      builder: (context) => _WpisIlosci(
        tytul: zakup ? 'Ile kupione?' : 'Ile jest naprawdę?',
        jednostka: stanPozycji.pozycja.jednostka,
        startowa: zakup ? 0 : stanPozycji.ilosc,
      ),
    );
    if (ilosc == null || _pracuje) {
      return;
    }
    setState(() => _pracuje = true);
    try {
      final magazyn = widget.uslugi.magazyn;
      if (zakup) {
        await magazyn.zapiszZakup(
          pozycjaId: stanPozycji.pozycja.id,
          ilosc: ilosc,
          kiedy: _teraz,
          urzadzenie: widget.uslugi.urzadzenie,
          teraz: _teraz,
        );
      } else {
        await magazyn.zapiszPoprawke(
          pozycjaId: stanPozycji.pozycja.id,
          roznica: ilosc - stanPozycji.ilosc,
          kiedy: _teraz,
          urzadzenie: widget.uslugi.urzadzenie,
          uwagi: 'przeliczone w magazynie',
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
            padding: const EdgeInsets.all(MotywProsty.odstep),
            children: [
              if (!_dostepny)
                const Ostrzezenie(
                  tresc: 'Magazyn należy do wersji płatnej.',
                  coZrobic:
                      'Wpisy, rejestry, wydruk i eksport działają bez '
                      'opłaty — magazyn tylko oszczędza czas przy '
                      'liczeniu, ile czego zostało.',
                ),
              if (_dostepny) ...[
                Text(
                  'Stan na ${Daty.krotko(_teraz)}',
                  style: teksty.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Liczony z zakupów i zużycia. Zużycie dopisuje się samo '
                  'przy wpisie zabiegu — z dawki i powierzchni.',
                  style: teksty.bodyMedium,
                ),
                const SizedBox(height: MotywProsty.odstep),
                if (stany.isEmpty)
                  const Ostrzezenie(
                    tresc: 'Magazyn jest jeszcze pusty.',
                    coZrobic:
                        'Dodaj nawóz ze swojego spisu albo środek, którym '
                        'już opryskiwałeś — potem wpisz zakup.',
                  ),
                for (final stanPozycji in stany) ...[
                  _KartaPozycji(
                    stanPozycji: stanPozycji,
                    ostrzezenia: widget.uslugi.magazyn.ostrzezenia(stanPozycji),
                    pracuje: _pracuje,
                    onZakup: () => _ruch(stanPozycji, zakup: true),
                    onPoprawka: () => _ruch(stanPozycji, zakup: false),
                  ),
                  const SizedBox(height: MotywProsty.odstep),
                ],
                const SizedBox(height: MotywProsty.odstep),
                DuzyPrzycisk(
                  etykieta: 'Dodaj nawóz',
                  opis: 'ze spisu nawozów gospodarstwa',
                  ikona: Icons.grass_outlined,
                  onTap: _dodajZNawozow,
                ),
                const SizedBox(height: 10),
                DuzyPrzycisk(
                  etykieta: 'Dodaj środek',
                  opis: 'z tych, którymi już opryskiwałeś',
                  ikona: Icons.water_drop_outlined,
                  onTap: _dodajZeSrodkow,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Jedna pozycja: ile zostało, co kupione, co zużyte.
class _KartaPozycji extends StatelessWidget {
  const _KartaPozycji({
    required this.stanPozycji,
    required this.ostrzezenia,
    required this.pracuje,
    required this.onZakup,
    required this.onPoprawka,
  });

  final StanPozycji stanPozycji;
  final List<OstrzezenieMagazynu> ostrzezenia;
  final bool pracuje;
  final VoidCallback onZakup;
  final VoidCallback onPoprawka;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final pozycja = stanPozycji.pozycja;
    return Container(
      padding: const EdgeInsets.all(MotywProsty.odstep),
      decoration: BoxDecoration(
        color: MotywProsty.powierzchniaDruga,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieDuze),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pozycja.nazwa, style: teksty.titleLarge),
          const SizedBox(height: 4),
          Text(pozycja.rodzaj.dlaRolnika, style: teksty.bodyMedium),
          const SizedBox(height: 8),
          Text(stanPozycji.iloscOpis, style: teksty.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Kupione: ${_liczba(stanPozycji.zakupy)} ${pozycja.jednostka} • '
            'zużyte: ${_liczba(stanPozycji.zuzycie)} ${pozycja.jednostka}',
            style: teksty.bodyLarge,
          ),
          if (stanPozycji.ostatniZakup case final DateTime dzien) ...[
            const SizedBox(height: 4),
            Text(
              'Ostatni zakup: ${Daty.krotko(dzien)}',
              style: teksty.bodyMedium,
            ),
          ],
          for (final ostrzezenie in ostrzezenia) ...[
            const SizedBox(height: 8),
            Ostrzezenie(
              tresc: ostrzezenie.tresc,
              coZrobic: ostrzezenie.coZrobic,
            ),
          ],
          const SizedBox(height: MotywProsty.odstep),
          DuzyPrzycisk(
            etykieta: 'Zakup',
            opis: 'dopisz, ile przyszło',
            ikona: Icons.add_shopping_cart_outlined,
            onTap: pracuje ? null : onZakup,
          ),
          const SizedBox(height: 10),
          DuzyPrzycisk(
            etykieta: 'Policz stan',
            opis: 'popraw, gdy w magazynie jest inaczej',
            ikona: Icons.balance_outlined,
            onTap: pracuje ? null : onPoprawka,
          ),
        ],
      ),
    );
  }

  static String _liczba(double wartosc) =>
      wartosc.toStringAsFixed(2).replaceAll('.', ',');
}

/// Wybór z listy — zamiast pisania (reguły interfejsu).
class _ListaWyboru<T> extends StatelessWidget {
  const _ListaWyboru({
    required this.tytul,
    required this.pozycje,
    required this.etykieta,
  });

  final String tytul;
  final List<T> pozycje;
  final String Function(T) etykieta;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tytul),
    content: pozycje.isEmpty
        ? Text(
            'Nie ma z czego wybrać. Dopisz nawóz w spisie nawozów albo '
            'zrób pierwszy wpis oprysku.',
            style: Theme.of(context).textTheme.bodyLarge,
          )
        : SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final pozycja in pozycje)
                  DuzyPrzycisk(
                    etykieta: etykieta(pozycja),
                    ikona: Icons.inventory_2_outlined,
                    onTap: () => Navigator.of(context).pop(pozycja),
                  ),
              ],
            ),
          ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Wróć'),
      ),
    ],
  );
}

/// Ilość przyciskami „+" i „−" — bez klawiatury (reguły interfejsu).
class _WpisIlosci extends StatefulWidget {
  const _WpisIlosci({
    required this.tytul,
    required this.jednostka,
    required this.startowa,
  });

  final String tytul;
  final String jednostka;
  final double startowa;

  @override
  State<_WpisIlosci> createState() => _WpisIlosciState();
}

class _WpisIlosciState extends State<_WpisIlosci> {
  late double _ilosc = widget.startowa < 0 ? 0 : widget.startowa;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.tytul),
    content: SizedBox(
      width: 320,
      child: WyborLiczby(
        wartosc: _ilosc,
        jednostka: widget.jednostka,
        krok: 1,
        onZmiana: (nowa) => setState(() => _ilosc = nowa),
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
