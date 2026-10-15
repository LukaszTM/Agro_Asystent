import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/nawozenie/nawoz.dart';
import '../../../funkcje/odczyt/czytnik_zdjecia.dart';
import '../../../funkcje/odczyt/odczyt_nawozu.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import '../widgety/wybor_liczby.dart';

/// Spis nawozów gospodarstwa: nazwa, zawartość azotu i to, czy nawóz jest
/// naturalny — od tego zależy limit azotu (plan, pkt 3).
class EkranNawozy extends StatefulWidget {
  const EkranNawozy({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranNawozy> createState() => _EkranNawozyState();
}

class _EkranNawozyState extends State<EkranNawozy> {
  late Future<List<Nawoz>> _nawozy;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _nawozy = widget.uslugi.nawozy.wszystkie(widget.uslugi.gospodarstwoId);
  }

  Future<void> _dodaj() async {
    final dodano = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranNowyNawoz(uslugi: widget.uslugi),
      ),
    );
    if (dodano ?? false) {
      setState(_odswiez);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nawozy')),
      body: FutureBuilder<List<Nawoz>>(
        future: _nawozy,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final nawozy = stan.data!;
          return ListView(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            children: [
              if (nawozy.isEmpty)
                const Ostrzezenie(
                  tresc: 'Nie masz jeszcze żadnego nawozu w spisie.',
                  coZrobic:
                      'Dodaj nawóz i przepisz zawartość azotu z worka '
                      'albo z analizy — niczego nie zgadujemy za Ciebie.',
                ),
              for (final nawoz in nawozy) ...[
                DuzyPrzycisk(
                  etykieta: nawoz.nazwa,
                  opis: [
                    nawoz.naturalny ? 'naturalny' : 'mineralny',
                    nawoz.skladOpis,
                  ].join(' • '),
                  ikona: nawoz.naturalny
                      ? Icons.compost_outlined
                      : Icons.science_outlined,
                  onTap: null,
                ),
                const SizedBox(height: MotywProsty.odstep),
              ],
              const SizedBox(height: MotywProsty.odstep),
              FilledButton(onPressed: _dodaj, child: const Text('Dodaj nawóz')),
            ],
          );
        },
      ),
    );
  }
}

/// Dodanie nawozu: nazwa, rodzaj i zawartość składników z opakowania.
class EkranNowyNawoz extends StatefulWidget {
  const EkranNowyNawoz({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranNowyNawoz> createState() => _EkranNowyNawozState();
}

class _EkranNowyNawozState extends State<EkranNowyNawoz> {
  final TextEditingController _nazwa = TextEditingController();
  bool _naturalny = false;
  double _azot = 0;
  bool _zapisuje = false;
  bool _czyta = false;

  /// Co wyszło z odczytu worka — pokazujemy do potwierdzenia, nie zapisujemy
  /// po cichu (CLAUDE.md, reguła 5).
  OdczytNawozu? _odczyt;
  String? _bladOdczytu;

  Future<void> _odczytajZWorka() async {
    if (_czyta) {
      return;
    }
    setState(() {
      _czyta = true;
      _bladOdczytu = null;
    });
    try {
      final tekst = await widget.uslugi.czytnikZdjecia.tekst(
        ZrodloZdjecia.aparat,
      );
      if (tekst == null || !mounted) {
        return;
      }
      final odczyt = CzytnikNawozu.zTekstu(tekst);
      setState(() {
        _odczyt = odczyt;
        if (odczyt.nazwa != null) {
          _nazwa.text = odczyt.nazwa!;
        }
        if (odczyt.azotProcent != null) {
          _azot = odczyt.azotProcent!;
        }
        if (odczyt.naturalny ?? false) {
          _naturalny = true;
        }
      });
    } on BladOdczytuZdjecia catch (blad) {
      if (mounted) {
        setState(
          () => _bladOdczytu = [
            blad.wiadomosc,
            if (blad.coZrobic != null) blad.coZrobic!,
          ].join(' '),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _czyta = false);
      }
    }
  }

  @override
  void dispose() {
    _nazwa.dispose();
    super.dispose();
  }

  Future<void> _zapisz() async {
    if (_zapisuje) {
      return;
    }
    setState(() => _zapisuje = true);
    final nazwa = _nazwa.text.trim();
    await widget.uslugi.nawozy.zapisz(
      nawoz: Nawoz(
        id: 'nawoz-${DateTime.now().microsecondsSinceEpoch}',
        gospodarstwoId: widget.uslugi.gospodarstwoId,
        nazwa: nazwa.isEmpty ? 'Nawóz bez nazwy' : nazwa,
        naturalny: _naturalny,
        // Zero znaczy „nie wiem" — wtedy azot zostaje nieznany i nie liczymy
        // go do limitu, zamiast wpisywać wartość z sufitu.
        azotProcent: _azot > 0 ? _azot : null,
        zrodlo: _odczyt?.cokolwiekZnaleziono ?? false
            ? 'zdjęcie worka'
            : (_naturalny ? 'analiza' : 'worek'),
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
      appBar: AppBar(title: const Text('Nowy nawóz')),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          if (_czyta)
            const Center(child: CircularProgressIndicator())
          else
            DuzyPrzycisk(
              etykieta: 'Odczytaj z worka',
              opis: 'zrób zdjęcie napisu na opakowaniu',
              ikona: Icons.photo_camera_outlined,
              onTap: _odczytajZWorka,
            ),
          if (_bladOdczytu != null) ...[
            const SizedBox(height: MotywProsty.odstep),
            Ostrzezenie(tresc: _bladOdczytu!),
          ],
          if (_odczyt != null) ...[
            const SizedBox(height: MotywProsty.odstep),
            Ostrzezenie(
              tresc: _odczyt!.cokolwiekZnaleziono
                  ? 'Odczytano ze zdjęcia — sprawdź i popraw, jeśli trzeba.'
                  : 'Ze zdjęcia nic nie dało się odczytać.',
              coZrobic: _odczyt!.cokolwiekZnaleziono
                  ? null
                  : 'Wpisz nazwę i zawartość azotu ręcznie albo zrób zdjęcie '
                        'z bliska, w świetle.',
            ),
          ],
          const SizedBox(height: MotywProsty.odstep),
          Text('Nazwa nawozu', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _nazwa,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'np. Saletra amonowa z worka',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text('Rodzaj', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Wybor(
                  etykieta: 'Mineralny',
                  opis: 'z worka',
                  wybrany: !_naturalny,
                  onTap: () => setState(() => _naturalny = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Wybor(
                  etykieta: 'Naturalny',
                  opis: 'obornik, gnojowica',
                  wybrany: _naturalny,
                  onTap: () => setState(() => _naturalny = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text(
            'Zawartość azotu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          WyborLiczby(
            wartosc: _azot,
            jednostka: '% N',
            krok: _naturalny ? 0.1 : 1,
            minimum: 0,
            maksimum: 100,
            onZmiana: (nowa) => setState(() => _azot = nowa),
          ),
          const SizedBox(height: 8),
          Text(
            _azot > 0
                ? 'Przepisz z worka albo z analizy nawozu naturalnego.'
                : 'Zostaw zero, jeśli nie znasz zawartości — wtedy ten nawóz '
                      'nie będzie liczony do limitu azotu i powiemy o tym '
                      'wprost.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: MotywProsty.odstep * 2),
          FilledButton(
            onPressed: _zapisuje ? null : _zapisz,
            child: const Text('Zapisz nawóz'),
          ),
        ],
      ),
    );
  }
}

class _Wybor extends StatelessWidget {
  const _Wybor({
    required this.etykieta,
    required this.opis,
    required this.wybrany,
    required this.onTap,
  });

  final String etykieta;
  final String opis;
  final bool wybrany;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: wybrany,
      child: Material(
        color: wybrany
            ? MotywProsty.zielenAkcji
            : MotywProsty.powierzchniaDruga,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: MotywProsty.minCelDotyku + 12,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  etykieta,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: wybrany
                        ? MotywProsty.powierzchnia
                        : MotywProsty.tekst,
                  ),
                ),
                Text(
                  opis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: wybrany
                        ? MotywProsty.powierzchnia
                        : MotywProsty.tekst,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
