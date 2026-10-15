import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zwierzeta/stado.dart';
import '../../../rdzen/reguly/regula_prawna.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_zwierzeta.dart';

/// Dodanie zwierzęcia: numer kolczyka, grupa i to, skąd się wzięło.
/// Od zdarzenia liczy się termin zgłoszenia do IRZplus.
class EkranNoweZwierze extends StatefulWidget {
  const EkranNoweZwierze({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranNoweZwierze> createState() => _EkranNoweZwierzeState();
}

class _EkranNoweZwierzeState extends State<EkranNoweZwierze> {
  final TextEditingController _numer = TextEditingController();
  RodzajZdarzenia _zdarzenie = RodzajZdarzenia.urodzenie;
  GrupaDjp? _grupa;
  bool _zapisuje = false;

  @override
  void dispose() {
    _numer.dispose();
    super.dispose();
  }

  Future<void> _zapisz() async {
    if (_zapisuje) {
      return;
    }
    setState(() => _zapisuje = true);

    final gatunek = _grupa?.gatunek ?? 'bydło';
    final stada = await widget.uslugi.stado.stada(widget.uslugi.gospodarstwoId);
    final istniejace = stada.where((s) => s.gatunek == gatunek);
    final stadoId = istniejace.isNotEmpty
        ? istniejace.first.id
        : await widget.uslugi.stado.dodajStado(
            gospodarstwoId: widget.uslugi.gospodarstwoId,
            nazwa: gatunek,
            gatunek: gatunek,
            urzadzenie: widget.uslugi.urzadzenie,
          );

    final teraz = DateTime.now();
    await widget.uslugi.stado.dodajZwierze(
      stadoId: stadoId,
      zdarzenie: _zdarzenie,
      urzadzenie: widget.uslugi.urzadzenie,
      numer: _numer.text.trim().isEmpty ? null : _numer.text.trim(),
      grupaDjp: _grupa?.id,
      dataUrodzenia: _zdarzenie == RodzajZdarzenia.urodzenie ? teraz : null,
      dataZdarzenia: teraz,
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wspolczynniki = widget.uslugi.reguly.wspolczynnikiDjp;

    return Scaffold(
      appBar: AppBar(title: const Text('Nowe zwierzę')),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          Text('Skąd zwierzę', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final rodzaj in [
                RodzajZdarzenia.urodzenie,
                RodzajZdarzenia.kupno,
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(
                        rodzaj.dlaRolnika,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      selected: _zdarzenie == rodzaj,
                      onSelected: (_) => setState(() => _zdarzenie = rodzaj),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text('Numer kolczyka', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _numer,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'np. PL005123456789',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text('Grupa', style: Theme.of(context).textTheme.titleLarge),
          if (wspolczynniki.grupy.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Ostrzezenie(
                tresc: 'Słownik reguł nie podaje grup zwierząt.',
                coZrobic:
                    'Zaktualizuj dane aplikacji — bez grupy nie '
                    'policzymy DJP.',
              ),
            )
          else
            WyborGrupyDjp(
              wspolczynniki: wspolczynniki,
              wybrana: _grupa,
              onZmiana: (grupa) => setState(() => _grupa = grupa),
            ),
          const SizedBox(height: MotywProsty.odstep),
          if (_grupa == null)
            Text(
              'Bez grupy zapiszemy zwierzę, ale nie policzymy go do DJP.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: MotywProsty.odstep),
          FilledButton(
            onPressed: _zapisuje ? null : _zapisz,
            child: const Text('Zapisz zwierzę'),
          ),
        ],
      ),
    );
  }
}
