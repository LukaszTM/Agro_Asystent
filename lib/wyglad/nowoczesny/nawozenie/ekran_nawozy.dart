import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/nawozenie/nawoz.dart';
import '../../../funkcje/odczyt/czytnik_zdjecia.dart';
import '../../../funkcje/odczyt/odczyt_nawozu.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';

/// Spis nawozów gospodarstwa — wygląd nowoczesny.
///
/// Zawartość azotu przepisuje rolnik z worka albo z analizy. Zero znaczy
/// „nie wiem" i taki nawóz nie liczy się do limitu; nie zgadujemy składu
/// (CLAUDE.md, reguła 5).
class EkranNawozyNowoczesny extends StatefulWidget {
  const EkranNawozyNowoczesny({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranNawozyNowoczesny> createState() => _EkranNawozyNowoczesnyState();
}

class _EkranNawozyNowoczesnyState extends State<EkranNawozyNowoczesny> {
  late Future<List<Nawoz>> _nawozy;
  bool _cosDodano = false;

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
        builder: (_) => EkranNowyNawozNowoczesny(uslugi: widget.uslugi),
      ),
    );
    if ((dodano ?? false) && mounted) {
      setState(() {
        _cosDodano = true;
        _odswiez();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nawozy'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(_cosDodano),
        ),
      ),
      body: FutureBuilder<List<Nawoz>>(
        future: _nawozy,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final nawozy = stan.data!;
          return ListView(
            padding: const EdgeInsets.all(MotywNowoczesny.odstep),
            children: [
              if (nawozy.isEmpty)
                const OstrzezenieNowoczesne(
                  tresc: 'Nie masz jeszcze żadnego nawozu w spisie.',
                  coZrobic:
                      'Dodaj nawóz i przepisz zawartość azotu z worka albo '
                      'z analizy — niczego nie zgadujemy za Ciebie.',
                )
              else
                for (final nawoz in nawozy) ...[
                  Karta(
                    child: Row(
                      children: [
                        Icon(
                          nawoz.naturalny
                              ? Icons.compost_outlined
                              : Icons.science_outlined,
                          size: 20,
                          color: MotywNowoczesny.tekstPomocniczy,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nawoz.nazwa, style: teksty.bodyLarge),
                              Text(
                                [
                                  nawoz.naturalny ? 'naturalny' : 'mineralny',
                                  nawoz.skladOpis,
                                ].join(' • '),
                                style: teksty.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: MotywNowoczesny.odstep),
              FilledButton.icon(
                onPressed: _dodaj,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Dodaj nawóz'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Nowy nawóz: nazwa, rodzaj i zawartość azotu z opakowania albo ze
/// zdjęcia worka (odczyt zawsze do potwierdzenia).
class EkranNowyNawozNowoczesny extends StatefulWidget {
  const EkranNowyNawozNowoczesny({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranNowyNawozNowoczesny> createState() =>
      _EkranNowyNawozNowoczesnyState();
}

class _EkranNowyNawozNowoczesnyState extends State<EkranNowyNawozNowoczesny> {
  final TextEditingController _nazwa = TextEditingController();
  bool _naturalny = false;
  double _azot = 0;
  bool _zapisuje = false;
  bool _czyta = false;

  /// Co wyszło z odczytu worka — do potwierdzenia, nie do cichego zapisu
  /// (CLAUDE.md, reguła 5).
  OdczytNawozu? _odczyt;
  String? _bladOdczytu;

  @override
  void dispose() {
    _nazwa.dispose();
    super.dispose();
  }

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
        // Zero znaczy „nie wiem": azot zostaje nieznany i nie liczy się
        // do limitu, zamiast wartości z sufitu.
        azotProcent: _azot > 0 ? _azot : null,
        zrodlo: (_odczyt?.cokolwiekZnaleziono ?? false)
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
    final teksty = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nowy nawóz')),
      body: ListView(
        padding: const EdgeInsets.all(MotywNowoczesny.odstep),
        children: [
          if (_czyta)
            const Center(child: CircularProgressIndicator())
          else
            Karta(
              onTap: _odczytajZWorka,
              child: Row(
                children: [
                  const Icon(
                    Icons.photo_camera_outlined,
                    size: 20,
                    color: MotywNowoczesny.tekstPomocniczy,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Odczytaj z worka', style: teksty.bodyLarge),
                        Text(
                          'zrób zdjęcie napisu na opakowaniu',
                          style: teksty.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_bladOdczytu case final String blad) ...[
            const SizedBox(height: MotywNowoczesny.odstep),
            OstrzezenieNowoczesne(tresc: blad),
          ],
          if (_odczyt case final OdczytNawozu odczyt) ...[
            const SizedBox(height: MotywNowoczesny.odstep),
            OstrzezenieNowoczesne(
              tresc: odczyt.cokolwiekZnaleziono
                  ? 'Odczytano ze zdjęcia — sprawdź i popraw, jeśli trzeba.'
                  : 'Ze zdjęcia nic nie dało się odczytać.',
              coZrobic: odczyt.cokolwiekZnaleziono
                  ? null
                  : 'Wpisz nazwę i zawartość azotu ręcznie albo zrób '
                        'zdjęcie z bliska, w świetle.',
            ),
          ],
          const SizedBox(height: MotywNowoczesny.odstep),
          Text('Nazwa nawozu', style: teksty.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _nazwa,
            style: teksty.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'np. Saletra amonowa z worka',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: MotywNowoczesny.odstep),
          Text('Rodzaj', style: teksty.titleLarge),
          const SizedBox(height: 8),
          // Etykiety krótkie, bo dłuższe nie mieszczą się w jednym
          // rzędzie na telefonie 420 px; objaśnienie stoi pod nimi.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Wybor(
                etykieta: 'Mineralny',
                wybrany: !_naturalny,
                onTap: () => setState(() => _naturalny = false),
              ),
              Wybor(
                etykieta: 'Naturalny',
                wybrany: _naturalny,
                onTap: () => setState(() => _naturalny = true),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _naturalny
                ? 'Naturalny: obornik, gnojowica, gnojówka.'
                : 'Mineralny: nawóz z worka.',
            style: teksty.bodyMedium,
          ),
          const SizedBox(height: MotywNowoczesny.odstep),
          Text('Zawartość azotu', style: teksty.titleLarge),
          const SizedBox(height: 8),
          WyborLiczbyNowoczesny(
            wartosc: _azot,
            jednostka: '% N',
            krok: _naturalny ? 0.1 : 1,
            onZmiana: (nowa) => setState(() => _azot = nowa.clamp(0, 100)),
          ),
          const SizedBox(height: 8),
          Text(
            _azot > 0
                ? 'Przepisz z worka albo z analizy nawozu naturalnego.'
                : 'Zostaw zero, jeśli nie znasz zawartości — wtedy ten '
                      'nawóz nie będzie liczony do limitu azotu i powiemy '
                      'o tym wprost.',
            style: teksty.bodyMedium,
          ),
          const SizedBox(height: MotywNowoczesny.odstep * 2),
          if (_zapisuje)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(onPressed: _zapisz, child: const Text('Zapisz nawóz')),
        ],
      ),
    );
  }
}
