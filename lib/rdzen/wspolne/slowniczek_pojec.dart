import 'package:flutter/material.dart';

import '../../funkcje/slowniczek/slowniczek.dart';

/// Słowniczek pojęć — ten sam we wszystkich trzech wyglądach.
///
/// Rolnik czyta w piśmie z ARiMR „TUZ" albo „GAEC 6" i nie ma gdzie
/// sprawdzić, co to znaczy. Hasła stoją w pliku danych z numerem wersji
/// (`assets/dane/slowniczek.json`), więc nowe słowo dopisuje się bez
/// zmiany kodu.
///
/// Widget bierze kolory i kroje z `Theme` ekranu, w którym stoi, więc
/// w wyglądzie Prostym jest duży, a na komputerze gęstszy — bez osobnych
/// kopii kodu.
class ListaSlowniczka extends StatefulWidget {
  const ListaSlowniczka({
    super.key,
    required this.slownik,
    this.odSzukania = 8,
    this.szukanieWidoczne = true,
  });

  /// `null`, gdy pliku nie wczytano — wtedy ekran mówi o tym wprost
  /// zamiast pokazywać pustą listę.
  final SlownikPojec? slownik;

  /// Od ilu haseł pokazujemy pole szukania. Przy kilku hasłach szukanie
  /// tylko przeszkadza.
  final int odSzukania;

  /// Można je wyłączyć tam, gdzie słowniczek jest tylko kartą na innym
  /// ekranie.
  final bool szukanieWidoczne;

  @override
  State<ListaSlowniczka> createState() => _ListaSlowniczkaState();
}

class _ListaSlowniczkaState extends State<ListaSlowniczka> {
  final _szukane = TextEditingController();

  @override
  void dispose() {
    _szukane.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final slownik = widget.slownik;
    if (slownik == null) {
      return Text(
        'Słowniczka nie udało się wczytać. Reszta aplikacji działa '
        'normalnie — wyjaśnienia pojęć wrócą po aktualizacji.',
        style: teksty.bodyLarge,
      );
    }

    final zSzukaniem =
        widget.szukanieWidoczne && slownik.hasla.length >= widget.odSzukania;
    final znalezione = zSzukaniem
        ? slownik.szukaj(_szukane.text)
        : slownik.hasla;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(slownik.poCo, style: teksty.bodyMedium),
        if (zSzukaniem) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _szukane,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Szukaj pojęcia',
              hintText: 'na przykład: tuz',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 12),
        if (znalezione.isEmpty)
          Text(
            'Nie mamy jeszcze takiego hasła. Napisz, czego brakuje — '
            'dopiszemy je do słowniczka.',
            style: teksty.bodyLarge,
          )
        else
          for (final haslo in znalezione) _Haslo(haslo: haslo),
        const SizedBox(height: 12),
        Text(
          '${slownik.zastrzezenie} Słowniczek ${slownik.wersja}.',
          style: teksty.bodyMedium,
        ),
      ],
    );
  }
}

/// Jedno hasło: skrót widoczny od razu, wyjaśnienie po dotknięciu.
class _Haslo extends StatelessWidget {
  const _Haslo({required this.haslo});

  final HasloSlownika haslo;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return ExpansionTile(
      // Cały wiersz jest celem dotyku, a nie sama strzałka.
      tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      title: Text(haslo.skrot, style: teksty.titleLarge),
      subtitle: Text(haslo.nazwa, style: teksty.bodyMedium),
      childrenPadding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(haslo.wyjasnienie, style: teksty.bodyLarge),
        const SizedBox(height: 8),
        Text('Gdzie to spotkasz: ${haslo.gdzie}', style: teksty.bodyMedium),
        if (haslo.doWeryfikacji) ...[
          const SizedBox(height: 8),
          Text(
            'To hasło jest jeszcze do sprawdzenia w przepisie — traktuj je '
            'jako podpowiedź, nie jako wykładnię.',
            style: teksty.bodyMedium,
          ),
        ],
      ],
    );
  }
}
