import 'package:flutter/material.dart';

import '../../app/uslugi.dart';
import '../../funkcje/dzialki/repozytorium_pol.dart';
import 'motyw.dart';
import 'widgety/duzy_przycisk.dart';
import 'widgety/wybor_liczby.dart';

/// Lista pól gospodarstwa wraz z dodawaniem nowego.
///
/// Mapa i import z wniosku dojdą w kolejnych krokach etapu 1; tu chodzi o to,
/// żeby rolnik miał na czym zapisać pierwszy zabieg.
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
  late Future<List<String>> _uprawy;
  String? _uprawa;
  double _hektary = 1;

  @override
  void initState() {
    super.initState();
    _uprawy = widget.uslugi.srodki.uprawy();
  }

  @override
  void dispose() {
    _nazwa.dispose();
    super.dispose();
  }

  Future<void> _zapisz() async {
    final uprawa = _uprawa;
    if (uprawa == null) {
      return;
    }
    final kod = await widget.uslugi.srodki.kodEppo(uprawa);
    if (!mounted) {
      return;
    }
    await widget.uslugi.pola.dodaj(
      pole: Pole(
        id: 'pole-${DateTime.now().microsecondsSinceEpoch}',
        gospodarstwoId: widget.uslugi.gospodarstwoId,
        nazwa: _nazwa.text.trim().isEmpty ? 'Nowe pole' : _nazwa.text.trim(),
        uprawa: uprawa,
        kodEppo: kod,
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
          FutureBuilder<List<String>>(
            future: _uprawy,
            builder: (context, stan) {
              if (!stan.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return DropdownButtonFormField<String>(
                initialValue: _uprawa,
                isExpanded: true,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('wybierz z listy'),
                items: [
                  for (final uprawa in stan.data!)
                    DropdownMenuItem(value: uprawa, child: Text(uprawa)),
                ],
                onChanged: (wybrana) => setState(() => _uprawa = wybrana),
              );
            },
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
