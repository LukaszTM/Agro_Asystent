import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../rdzen/uslugi/kopia/kopia_danych.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';

/// Kopia danych do pliku — zawsze darmowa (plan, pkt 8).
///
/// Aplikacja nie ma serwera, więc kopia to jedyny sposób, żeby rolnik nie
/// stracił dokumentacji razem z telefonem. Plik zapisuje się tam, gdzie
/// rolnik wskaże: na dysku w chmurze, na karcie, w mailu do siebie.
class EkranKopia extends StatefulWidget {
  const EkranKopia({super.key, required this.uslugi, this.onWczytano});

  final Uslugi uslugi;

  /// Po wczytaniu kopii wszystkie ekrany mają inne dane — start aplikacji
  /// musi się o tym dowiedzieć.
  final VoidCallback? onWczytano;

  @override
  State<EkranKopia> createState() => _EkranKopiaState();
}

class _EkranKopiaState extends State<EkranKopia> {
  bool _pracuje = false;
  String? _wynik;
  ({String tresc, String coZrobic})? _ostrzezenie;

  Future<void> _zrobKopie() async {
    if (_pracuje) {
      return;
    }
    setState(() {
      _pracuje = true;
      _wynik = null;
      _ostrzezenie = null;
    });
    try {
      final teraz = DateTime.now();
      final bajty = await widget.uslugi.kopia.zrob(teraz: teraz);
      await widget.uslugi.dokumenty.wyjscie.udostepnij(
        dane: bajty,
        nazwa: KopiaDanych.nazwaPliku(teraz),
        typMime: 'application/zip',
      );
      if (mounted) {
        setState(() {
          _wynik =
              'Kopia gotowa: ${KopiaDanych.nazwaPliku(teraz)}. '
              'Zapisz ją tam, gdzie znajdziesz po zgubieniu telefonu.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ostrzezenie = (
            tresc: 'Nie udało się zapisać kopii.',
            coZrobic: 'Sprawdź miejsce na dane i spróbuj jeszcze raz.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _pracuje = false);
      }
    }
  }

  Future<void> _wczytajKopie() async {
    if (_pracuje) {
      return;
    }
    final plik = await widget.uslugi.zrodloPliku.wybierzKopie();
    if (plik == null) {
      return;
    }
    setState(() {
      _pracuje = true;
      _wynik = null;
      _ostrzezenie = null;
    });

    final wynik = await widget.uslugi.kopia.wczytaj(plik.bajty);
    if (!mounted) {
      return;
    }
    setState(() {
      _pracuje = false;
      switch (wynik) {
        case KopiaWczytana(:final opis):
          _wynik =
              'Wczytano kopię z ${_dzien(opis.zrobiona)}: '
              '${opis.liczbaPol} pól, ${opis.liczbaZabiegow} zabiegów, '
              '${opis.liczbaZwierzat} zwierząt.';
        case KopiaOdrzucona(:final blad):
          _ostrzezenie = switch (blad) {
            BladKopii.nieNaszPlik => (
              tresc: 'To nie jest kopia z tej aplikacji.',
              coZrobic:
                  'Wybierz plik o nazwie zaczynającej się od '
                  '„agro-asystent-kopia".',
            ),
            BladKopii.nowszaWersja => (
              tresc: 'Kopia pochodzi z nowszej wersji aplikacji.',
              coZrobic: 'Zaktualizuj aplikację i wczytaj kopię jeszcze raz.',
            ),
            BladKopii.saJuzDane => (
              tresc: 'W telefonie są już wpisy.',
              coZrobic:
                  'Kopię wczytujemy do pustej aplikacji, żeby nie zdublować '
                  'dokumentacji. Odinstaluj aplikację i zainstaluj ją na nowo, '
                  'albo wczytaj kopię na innym telefonie.',
            ),
          };
      }
    });
    if (wynik is KopiaWczytana) {
      widget.onWczytano?.call();
    }
  }

  static String _dzien(DateTime kiedy) =>
      '${kiedy.day.toString().padLeft(2, '0')}.'
      '${kiedy.month.toString().padLeft(2, '0')}.${kiedy.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kopia danych')),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          Text(
            'Aplikacja trzyma dane tylko w tym telefonie. Kopia to jeden '
            'plik — zapisz go na dysku w chmurze albo wyślij sobie mailem.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: MotywProsty.odstep),
          DuzyPrzycisk(
            etykieta: 'Zrób kopię',
            opis: 'wszystkie gospodarstwa, pola, zabiegi i zwierzęta',
            ikona: Icons.save_outlined,
            wyrozniony: true,
            onTap: _pracuje ? null : _zrobKopie,
          ),
          const SizedBox(height: MotywProsty.odstep),
          DuzyPrzycisk(
            etykieta: 'Wczytaj kopię',
            opis: 'na nowym telefonie, do pustej aplikacji',
            ikona: Icons.restore_outlined,
            onTap: _pracuje ? null : _wczytajKopie,
          ),
          if (_pracuje) ...[
            const SizedBox(height: MotywProsty.odstep),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_wynik != null) ...[
            const SizedBox(height: MotywProsty.odstep),
            Text(_wynik!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          if (_ostrzezenie != null) ...[
            const SizedBox(height: MotywProsty.odstep),
            Ostrzezenie(
              tresc: _ostrzezenie!.tresc,
              coZrobic: _ostrzezenie!.coZrobic,
            ),
          ],
          const SizedBox(height: MotywProsty.odstep * 2),
          Text(
            'Kopia jest darmowa i zawsze będzie — dokumentacji nie zamykamy '
            'za opłatą. W pliku jest zwykły zapis danych, który otworzysz '
            'też na komputerze.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
