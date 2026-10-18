import 'package:flutter/material.dart';

import '../../funkcje/dzialki/klient_uldk.dart';
import '../../funkcje/dzialki/szukanie_dzialki.dart';

/// Szukanie działki spoza wniosku — to samo we wszystkich trzech wyglądach.
///
/// Rolnik wybiera województwo, wpisuje nazwę miejscowości (obrębu) z umowy
/// i numer działki. Gdy usługa znajdzie kilka działek o tej nazwie (obręby
/// się powtarzają), pokazujemy listę z gminą i powiatem — rolnik wskazuje
/// swoją. Samo zapytanie wysyła przycisk ekranu, żeby był jeden, na dole.
///
/// Widget bierze kolory i kroje z `Theme` ekranu, w którym stoi, więc
/// w wyglądzie Prostym jest duży, a na komputerze gęstszy — bez osobnych
/// kopii kodu.
class SzukanieDzialki extends StatefulWidget {
  const SzukanieDzialki({
    super.key,
    required this.szukanie,
    required this.onZmiana,
    required this.onWybor,
    this.onSzukaj,
  });

  final SzukanieDzialkiPoNazwie szukanie;

  /// Rolnik zmienił województwo, nazwę albo numer — ekran odświeża
  /// przycisk szukania.
  final VoidCallback onZmiana;

  /// Rolnik wskazał działkę z listy znalezionych.
  final void Function(DzialkaZnaleziona dzialka) onWybor;

  /// Zatwierdzenie klawiaturą w polu numeru — to samo co przycisk ekranu.
  final VoidCallback? onSzukaj;

  @override
  State<SzukanieDzialki> createState() => _SzukanieDzialkiState();
}

class _SzukanieDzialkiState extends State<SzukanieDzialki> {
  late final TextEditingController _obreb = TextEditingController(
    text: widget.szukanie.obreb,
  );
  late final TextEditingController _numer = TextEditingController(
    text: widget.szukanie.numer,
  );

  @override
  void dispose() {
    _obreb.dispose();
    _numer.dispose();
    super.dispose();
  }

  void _zmiana() {
    widget.szukanie
      ..obreb = _obreb.text
      ..numer = _numer.text
      ..wyczyscWynik();
    setState(() {});
    widget.onZmiana();
  }

  void _wojewodztwo(Wojewodztwo? wybrane) {
    widget.szukanie
      ..wojewodztwo = wybrane
      ..wyczyscWynik();
    setState(() {});
    widget.onZmiana();
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final szukanie = widget.szukanie;
    final wybrane = szukanie.wojewodztwo;
    final lista = szukanie.wojewodztwa.wojewodztwa;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lista.isNotEmpty) ...[
          Text('Województwo', style: teksty.titleLarge),
          const SizedBox(height: 8),
          if (wybrane != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InputChip(
                  label: Text(wybrane.nazwa),
                  selected: true,
                  onDeleted: () => _wojewodztwo(null),
                  onPressed: () => _wojewodztwo(null),
                ),
              ],
            )
          else ...[
            Text(
              'Zawęża szukanie — nazwy wsi powtarzają się w całym kraju.',
              style: teksty.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final wojewodztwo in lista)
                  ChoiceChip(
                    label: Text(wojewodztwo.nazwa),
                    selected: false,
                    onSelected: (_) => _wojewodztwo(wojewodztwo),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
        ],
        Text('Miejscowość (obręb)', style: teksty.titleLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _obreb,
          style: teksty.bodyLarge,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'np. Brzeziny — jak na umowie albo w wypisie',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _zmiana(),
        ),
        const SizedBox(height: 12),
        Text('Numer działki', style: teksty.titleLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _numer,
          style: teksty.bodyLarge,
          // Numer bywa z ułamkiem („138/4"), więc nie klawiatura liczbowa.
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'np. 138 albo 138/4 — z umowy dzierżawy',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _zmiana(),
          onSubmitted: (_) => widget.onSzukaj?.call(),
        ),
        if (szukanie.znalezione.length > 1) ...[
          const SizedBox(height: 12),
          Text(
            'Jest ${szukanie.znalezione.length} takich działek — która '
            'jest Twoja?',
            style: teksty.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            szukanie.znalezioneWKraju > szukanie.znalezione.length
                ? 'Obręb „${szukanie.obreb.trim()}" jest w kraju '
                      '${szukanie.znalezioneWKraju} razy; pokazujemy te '
                      'z wybranego województwa. Dotknij swojej gminy.'
                : 'Obręb o tej nazwie jest w kilku gminach. Dotknij '
                      'swojej.',
            style: teksty.bodyMedium,
          ),
          const SizedBox(height: 8),
          for (final dzialka in szukanie.znalezione)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('gmina ${dzialka.gmina}', style: teksty.bodyLarge),
              subtitle: Text(
                '${dzialka.powiat}, ${dzialka.wojewodztwo}',
                style: teksty.bodyMedium,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onWybor(dzialka),
            ),
        ],
      ],
    );
  }
}
