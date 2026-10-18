import 'package:flutter/material.dart';

import '../../funkcje/dzialki/klient_uldk.dart';
import '../../funkcje/dzialki/wybor_jednostek.dart';

/// Wybór obrębu krok po kroku — ten sam we wszystkich trzech wyglądach.
///
/// Rolnik dodaje też działki spoza wniosku: dzierżawione, kupione po
/// złożeniu wniosku, przejęte po sąsiedzie. Pełnego identyfikatora
/// (`061506_2.0007.138`) nie zna, ale zna swoją gminę i obręb, a numer
/// działki ma na umowie. Dlatego prowadzimy go listami, a identyfikator
/// składamy sami.
///
/// Widget bierze kolory i kroje z `Theme` ekranu, w którym stoi, więc
/// w wyglądzie Prostym jest duży, a na komputerze gęstszy — bez osobnych
/// kopii kodu.
class WyborObrebu extends StatefulWidget {
  const WyborObrebu({
    super.key,
    required this.wybor,
    required this.onZmiana,
    this.odSzukania = 12,
  });

  final WyborJednostek wybor;

  /// Wywoływane po każdym wyborze — ekran odświeża przycisk „dalej".
  final VoidCallback onZmiana;

  /// Od ilu pozycji pokazujemy pole szukania. Województw jest szesnaście
  /// i szukanie tylko przeszkadza; obrębów bywa kilkadziesiąt.
  final int odSzukania;

  @override
  State<WyborObrebu> createState() => _WyborObrebuState();
}

class _WyborObrebuState extends State<WyborObrebu> {
  late Future<List<JednostkaTerytorialna>> _lista;
  final _szukane = TextEditingController();
  String? _blad;
  String? _coZrobic;

  @override
  void initState() {
    super.initState();
    _wczytaj();
  }

  @override
  void dispose() {
    _szukane.dispose();
    super.dispose();
  }

  void _wczytaj() {
    _lista = widget.wybor.lista(widget.wybor.biezacy).catchError((Object blad) {
      if (mounted && blad is BladUldk) {
        setState(() {
          _blad = blad.wiadomosc;
          _coZrobic = blad.coZrobic;
        });
      }
      return <JednostkaTerytorialna>[];
    });
  }

  void _wybierz(JednostkaTerytorialna jednostka) {
    setState(() {
      widget.wybor.wybierz(widget.wybor.biezacy, jednostka);
      _szukane.clear();
      _blad = null;
      _wczytaj();
    });
    widget.onZmiana();
  }

  void _cofnij(PoziomPodzialu poziom) {
    setState(() {
      widget.wybor.cofnij(poziom);
      _szukane.clear();
      _blad = null;
      _wczytaj();
    });
    widget.onZmiana();
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final poziom = widget.wybor.biezacy;
    final gotowy = widget.wybor.gotowy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ścieżka wyboru: każdy szczebel da się cofnąć jednym dotknięciem.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final szczebel in PoziomPodzialu.values)
              if (widget.wybor.wybrana(szczebel)
                  case final JednostkaTerytorialna jednostka)
                InputChip(
                  label: Text('${szczebel.dlaRolnika}: ${jednostka.nazwa}'),
                  onDeleted: () => _cofnij(szczebel),
                  onPressed: () => _cofnij(szczebel),
                ),
          ],
        ),
        if (!gotowy) ...[
          const SizedBox(height: 12),
          Text('Wybierz ${poziom.dlaRolnika}', style: teksty.titleLarge),
          const SizedBox(height: 8),
          if (_blad case final String wiadomosc)
            _Blad(tresc: wiadomosc, coZrobic: _coZrobic)
          else
            FutureBuilder<List<JednostkaTerytorialna>>(
              future: _lista,
              builder: (context, stan) {
                if (stan.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final wszystkie = stan.data ?? const <JednostkaTerytorialna>[];
                if (wszystkie.isEmpty && _blad == null) {
                  return Text(
                    'Usługa nie podała żadnej pozycji.',
                    style: teksty.bodyLarge,
                  );
                }
                final szukane = _szukane.text.trim().toLowerCase();
                final widoczne = szukane.isEmpty
                    ? wszystkie
                    : wszystkie
                          .where((j) => j.nazwa.toLowerCase().contains(szukane))
                          .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wszystkie.length >= widget.odSzukania) ...[
                      TextField(
                        controller: _szukane,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Szukaj: ${poziom.dlaRolnika}',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: widoczne.length,
                        itemBuilder: (context, numer) {
                          final jednostka = widoczne[numer];
                          return ListTile(
                            title: Text(
                              jednostka.nazwa,
                              style: teksty.bodyLarge,
                            ),
                            onTap: () => _wybierz(jednostka),
                          );
                        },
                      ),
                    ),
                    if (widoczne.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Nic nie pasuje do tego, co wpisałeś.',
                          style: teksty.bodyLarge,
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ],
    );
  }
}

class _Blad extends StatelessWidget {
  const _Blad({required this.tresc, this.coZrobic});

  final String tresc;
  final String? coZrobic;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tresc, style: teksty.bodyLarge),
        if (coZrobic case final String rada) ...[
          const SizedBox(height: 4),
          Text(rada, style: teksty.bodyMedium),
        ],
      ],
    );
  }
}
