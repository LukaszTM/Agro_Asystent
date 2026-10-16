import 'package:flutter/material.dart';

import '../../app/uslugi.dart';
import '../../funkcje/dzialki/repozytorium_pol.dart';
import '../../funkcje/dzialki/slownik_upraw.dart';
import 'dzialki/ekran_dzialki.dart';
import 'dzialki/ekran_wybor_uprawy.dart';
import 'dzialki/ekran_import_wniosku.dart';
import 'nawozenie/ekran_nawozenie.dart';
import 'motyw.dart';
import 'widgety/duzy_przycisk.dart';
import 'widgety/wybor_liczby.dart';

/// Lista pól gospodarstwa wraz z dodawaniem nowego oraz wejściem do działek
/// ewidencyjnych i mapy.
///
/// Import z wniosku dojdzie w kolejnym kroku etapu 1; tu chodzi o to, żeby
/// rolnik miał na czym zapisać pierwszy zabieg.
class EkranPola extends StatefulWidget {
  const EkranPola({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranPola> createState() => _EkranPolaState();
}

class _EkranPolaState extends State<EkranPola> {
  late Future<List<Pole>> _pola;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _pola = widget.uslugi.pola.wszystkie(widget.uslugi.gospodarstwoId);
  }

  Future<void> _wczytajWniosek() async {
    final zapisano = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranImportWniosku(uslugi: widget.uslugi),
      ),
    );
    if (zapisano ?? false) {
      setState(_odswiez);
    }
  }

  Future<void> _dodaj() async {
    final dodano = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranNowePole(uslugi: widget.uslugi),
      ),
    );
    if (dodano ?? false) {
      setState(_odswiez);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pola')),
      body: FutureBuilder<List<Pole>>(
        future: _pola,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pola = stan.data!;
          return ListView(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            children: [
              if (pola.isEmpty)
                const Ostrzezenie(
                  tresc: 'Nie masz jeszcze żadnego pola.',
                  coZrobic:
                      'Naciśnij „Dodaj pole" — wystarczy nazwa, uprawa '
                      'i powierzchnia.',
                ),
              for (final pole in pola) ...[
                DuzyPrzycisk(
                  etykieta: pole.nazwa,
                  opis: '${pole.uprawa} • ${pole.powierzchniaOpis}',
                  ikona: Icons.crop_square,
                  onTap: null,
                ),
                const SizedBox(height: MotywProsty.odstep),
              ],
              const SizedBox(height: MotywProsty.odstep),
              FilledButton(onPressed: _dodaj, child: const Text('Dodaj pole')),
              const SizedBox(height: MotywProsty.odstep),
              DuzyPrzycisk(
                etykieta: 'Działki i mapa',
                opis: 'Granice działek z numeru ewidencyjnego',
                ikona: Icons.map_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EkranDzialki(uslugi: widget.uslugi),
                  ),
                ),
              ),
              const SizedBox(height: MotywProsty.odstep),
              DuzyPrzycisk(
                etykieta: 'Nawożenie',
                opis: 'azot na polach i limit z przepisu',
                ikona: Icons.compost_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EkranNawozenie(uslugi: widget.uslugi),
                  ),
                ),
              ),
              const SizedBox(height: MotywProsty.odstep),
              DuzyPrzycisk(
                etykieta: 'Wczytaj wniosek z PDF',
                opis: 'Działki i uprawy z eWniosekPlus',
                ikona: Icons.upload_file_outlined,
                onTap: _wczytajWniosek,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Dodawanie pola: nazwa, uprawa z listy i powierzchnia przyciskami.
class EkranNowePole extends StatefulWidget {
  const EkranNowePole({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranNowePole> createState() => _EkranNowePoleState();
}

class _EkranNowePoleState extends State<EkranNowePole> {
  final TextEditingController _nazwa = TextEditingController();
  UprawaDoWyboru? _uprawa;
  double _hektary = 1;

  @override
  void dispose() {
    _nazwa.dispose();
    super.dispose();
  }

  Future<void> _wybierzUprawe() async {
    final wybrana = await Navigator.of(context).push<UprawaDoWyboru>(
      MaterialPageRoute<UprawaDoWyboru>(
        builder: (_) => EkranWyborUprawy(uslugi: widget.uslugi),
      ),
    );
    if (wybrana != null && mounted) {
      setState(() => _uprawa = wybrana);
    }
  }

  Future<void> _zapisz() async {
    final uprawa = _uprawa;
    if (uprawa == null) {
      return;
    }
    await widget.uslugi.pola.dodaj(
      pole: Pole(
        id: 'pole-${DateTime.now().microsecondsSinceEpoch}',
        gospodarstwoId: widget.uslugi.gospodarstwoId,
        nazwa: _nazwa.text.trim().isEmpty ? 'Nowe pole' : _nazwa.text.trim(),
        uprawa: uprawa.nazwa,
        // Kod EPPO bierzemy z wyboru rolnika; przy własnej nazwie zostaje
        // pusty i w ewidencji wyjdzie jako brak (CLAUDE.md, reguła 5).
        kodEppo: uprawa.kodEppo,
        powierzchniaAr: (_hektary * 100).round(),
      ),
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nowe pole')),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          Text('Nazwa pola', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _nazwa,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'np. Za stodołą',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text('Powierzchnia', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          WyborLiczby(
            wartosc: _hektary,
            jednostka: 'ha',
            krok: 0.1,
            minimum: 0.1,
            onZmiana: (nowa) => setState(() => _hektary = nowa),
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text('Uprawa', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          DuzyPrzycisk(
            etykieta: _uprawa?.nazwa ?? 'Wybierz uprawę',
            opis: _uprawa == null
                ? 'z listy; jeśli Twojej uprawy nie ma — wpiszesz sam'
                : (_uprawa!.maKod
                      ? 'kod EPPO: ${_uprawa!.kodEppo}'
                      : 'bez kodu EPPO — na wydruku będzie „brak"'),
            ikona: Icons.grass_outlined,
            onTap: _wybierzUprawe,
          ),
          const SizedBox(height: MotywProsty.odstep * 2),
          FilledButton(
            onPressed: _uprawa == null ? null : _zapisz,
            child: const Text('Zapisz pole'),
          ),
        ],
      ),
    );
  }
}
