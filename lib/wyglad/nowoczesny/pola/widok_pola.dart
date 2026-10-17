import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/repozytorium_dzialek.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/dzialki/slownik_upraw.dart';
import '../../../rdzen/dostep/funkcja.dart';
import '../../../rdzen/dostep/opis_premium.dart';
import '../../../rdzen/wspolne/mapa_dzialek.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';
import 'ekran_dzialki.dart';
import 'ekran_import_wniosku.dart';
import 'ekran_pole.dart';
import 'ekran_nowe_pole.dart';
import 'ekran_wybor_uprawy.dart';

/// Zakładka „Pola" wyglądu nowoczesnego: mapa na całą szerokość,
/// wyszukiwarka, filtry upraw i karta wybranego pola (plan, pkt 5).
class WidokPola extends StatefulWidget {
  const WidokPola({super.key, required this.uslugi, this.onZabiegNaPolu});

  final Uslugi uslugi;

  /// Skrót „zapisz zabieg na tym polu" — wpis otwiera się z już wybranym
  /// polem, więc do zapisu zostaje mniej dotknięć.
  final void Function(Pole pole)? onZabiegNaPolu;

  @override
  State<WidokPola> createState() => _WidokPolaState();
}

class _WidokPolaState extends State<WidokPola> {
  late Future<({List<Pole> pola, List<DzialkaEwidencyjna> dzialki})> _dane;
  String _szukane = '';
  String? _uprawa;
  Pole? _wybrane;

  /// Numery działek ewidencyjnych wybranego pola — z nich bierze się
  /// wyróżnienie na mapie.
  Future<List<String>>? _dzialkiPola;

  @override
  void initState() {
    super.initState();
    _dane = _wczytaj();
  }

  Future<({List<Pole> pola, List<DzialkaEwidencyjna> dzialki})>
  _wczytaj() async => (
    pola: await widget.uslugi.pola.wszystkie(widget.uslugi.gospodarstwoId),
    dzialki: await widget.uslugi.dzialki.wszystkie(
      widget.uslugi.gospodarstwoId,
    ),
  );

  Future<void> _dodajPole() async {
    final dodano = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranNowePoleNowoczesny(uslugi: widget.uslugi),
      ),
    );
    if ((dodano ?? false) && mounted) {
      setState(() {
        _dane = _wczytaj();
      });
    }
  }

  /// Działki ewidencyjne i granice z ULDK — po powrocie mapa musi
  /// policzyć się od nowa.
  Future<void> _dzialkiEwidencyjne() async {
    final zmiana = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranDzialkiNowoczesny(uslugi: widget.uslugi),
      ),
    );
    if ((zmiana ?? false) && mounted) {
      setState(() {
        _dane = _wczytaj();
      });
    }
  }

  Future<void> _importWniosku() async {
    final zapisano = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranImportWnioskuNowoczesny(uslugi: widget.uslugi),
      ),
    );
    if ((zapisano ?? false) && mounted) {
      setState(() {
        _dane = _wczytaj();
        _wybrane = null;
      });
    }
  }

  /// Rodzaj użytku i historia upraw — dane dla normy GAEC 7.
  Future<void> _rodzajIHistoria(Pole pole) async {
    final zmiana = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranPoleNowoczesny(uslugi: widget.uslugi, pole: pole),
      ),
    );
    if ((zmiana ?? false) && mounted) {
      setState(() {
        _dane = _wczytaj();
        _wybrane = null;
      });
    }
  }

  /// Zmiana uprawy wybranego pola — co sezon rośnie tam coś innego.
  Future<void> _zmienUprawe(Pole pole) async {
    final wybrana = await Navigator.of(context).push<UprawaDoWyboru>(
      MaterialPageRoute<UprawaDoWyboru>(
        builder: (_) => EkranWyborUprawyNowoczesny(uslugi: widget.uslugi),
      ),
    );
    if (wybrana == null || !mounted) {
      return;
    }

    // Czwarty rok tej samej uprawy łamie normę GAEC 7 — mówimy o tym
    // przed zapisem, tymi samymi słowami co wygląd prosty.
    final ostrzezenie = await widget.uslugi.zmianowanie.ostrzezeniePrzedZapisem(
      pole: pole,
      uprawa: wybrana.nazwa,
    );
    if (!mounted) {
      return;
    }
    if (ostrzezenie != null) {
      final zapisac = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Czwarty rok tej samej uprawy'),
          content: Text(
            '${ostrzezenie.tresc}\n\n${ostrzezenie.coZrobic}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Wybiorę inną'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Zapisz mimo to'),
            ),
          ],
        ),
      );
      if (!(zapisac ?? false) || !mounted) {
        return;
      }
    }

    await widget.uslugi.pola.zmienUprawe(
      poleId: pole.id,
      uprawa: wybrana.nazwa,
      kodEppo: wybrana.kodEppo,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    final swieze = await widget.uslugi.pola.jedno(pole.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _dane = _wczytaj();
      _wybrane = swieze ?? pole;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Zmieniono uprawę na „${wybrana.nazwa}". Poprzednia została '
          'w dzienniku zmian.',
        ),
      ),
    );
  }

  void _wybierz(Pole? pole) {
    setState(() {
      _wybrane = pole;
      _dzialkiPola = pole == null
          ? null
          : widget.uslugi.pola.dzialkiReferencyjne(pole.id);
    });
  }

  List<Pole> _pasujace(List<Pole> wszystkie) {
    final szukane = _szukane.trim().toLowerCase();
    return wszystkie
        .where(
          (pole) =>
              (_uprawa == null || pole.uprawa == _uprawa) &&
              (szukane.isEmpty ||
                  pole.nazwa.toLowerCase().contains(szukane) ||
                  pole.uprawa.toLowerCase().contains(szukane)),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({List<Pole> pola, List<DzialkaEwidencyjna> dzialki})>(
      future: _dane,
      builder: (context, stan) {
        if (!stan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final wszystkie = stan.data!.pola;
        final dzialki = stan.data!.dzialki;
        final pasujace = _pasujace(wszystkie);
        final uprawy = {
          for (final pole in wszystkie)
            if (pole.uprawa.isNotEmpty) pole.uprawa,
        }.toList(growable: false)..sort();

        return ListView(
          padding: const EdgeInsets.all(MotywNowoczesny.odstep),
          children: [
            if (dzialki.any((d) => d.maGranice))
              FutureBuilder<List<String>>(
                future: _dzialkiPola,
                builder: (context, stanDzialek) => MapaDzialek(
                  dzialki: dzialki,
                  barwy: MotywNowoczesny.barwyMapy,
                  wyrozniona: stanDzialek.data?.firstOrNull,
                  wysokosc: 200,
                ),
              )
            else
              const OstrzezenieNowoczesne(
                tresc: 'Żadna działka nie ma jeszcze granic.',
                coZrobic:
                    'Naciśnij „Działki" i dodaj działkę po numerze '
                    'z wniosku — granice pobierają się raz i zostają '
                    'w telefonie.',
              ),
            const SizedBox(height: MotywNowoczesny.odstep),
            TextField(
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Szukaj pola albo uprawy',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (tekst) => setState(() => _szukane = tekst),
            ),
            if (uprawy.length > 1) ...[
              const SizedBox(height: MotywNowoczesny.odstep),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Wybor(
                    etykieta: 'Wszystkie uprawy',
                    wybrany: _uprawa == null,
                    onTap: () => setState(() => _uprawa = null),
                  ),
                  for (final uprawa in uprawy)
                    Wybor(
                      etykieta: uprawa,
                      wybrany: _uprawa == uprawa,
                      onTap: () => setState(() => _uprawa = uprawa),
                    ),
                ],
              ),
            ],
            const SizedBox(height: MotywNowoczesny.odstep),
            if (_wybrane != null) ...[
              _KartaPola(
                pole: _wybrane!,
                dzialki: _dzialkiPola,
                onZamknij: () => _wybierz(null),
                onZmianaUprawy: () => _zmienUprawe(_wybrane!),
                onHistoria: () => _rodzajIHistoria(_wybrane!),
                onZabieg: widget.onZabiegNaPolu == null
                    ? null
                    : () => widget.onZabiegNaPolu!(_wybrane!),
              ),
              const SizedBox(height: MotywNowoczesny.odstep),
            ],
            FilledButton.icon(
              onPressed: _dodajPole,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Dodaj pole'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _dzialkiEwidencyjne,
                    icon: const Icon(Icons.map_outlined, size: 20),
                    label: const Text('Działki'),
                  ),
                ),
                // Wczytanie wniosku to dodatek płatny (plan, pkt 8).
                if (widget.uslugi.dostep.czyDostepna(
                  Funkcja.importDzialekZWnioskuPdf,
                )) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _importWniosku,
                      icon: const Icon(Icons.upload_file, size: 20),
                      label: const Text('Z wniosku'),
                    ),
                  ),
                ],
              ],
            ),
            // Jedno zdanie pod przyciskami — lista pól ma zostać na
            // pierwszym ekranie, a nie zjechać pod wyjaśnienie.
            if (!widget.uslugi.dostep.czyDostepna(
              Funkcja.importDzialekZWnioskuPdf,
            )) ...[
              const SizedBox(height: 8),
              Text(
                OpisPremium.tresc(Funkcja.importDzialekZWnioskuPdf),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: MotywNowoczesny.odstep),
            if (wszystkie.isEmpty)
              const OstrzezenieNowoczesne(
                tresc: 'Nie masz jeszcze żadnego pola.',
                coZrobic:
                    'Naciśnij „Dodaj pole" — wystarczy nazwa, powierzchnia '
                    'i uprawa z listy.',
              )
            else if (pasujace.isEmpty)
              const OstrzezenieNowoczesne(
                tresc: 'Żadne pole nie pasuje do tego, czego szukasz.',
                coZrobic: 'Zmień wpisane słowo albo wybierz inną uprawę.',
              )
            else
              for (final pole in pasujace) ...[
                Karta(
                  onTap: () => _wybierz(pole),
                  wyrozniona: pole.id == _wybrane?.id,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pole.nazwa,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: pole.id == _wybrane?.id
                                        ? MotywNowoczesny.karta
                                        : MotywNowoczesny.tekst,
                                  ),
                            ),
                            Text(
                              '${pole.uprawa} • ${pole.powierzchniaOpis}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: pole.id == _wybrane?.id
                                        ? MotywNowoczesny.karta
                                        : MotywNowoczesny.tekstPomocniczy,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }
}

/// Karta wybranego pola: dane z wniosku i skrót do wpisu zabiegu.
class _KartaPola extends StatelessWidget {
  const _KartaPola({
    required this.pole,
    required this.dzialki,
    required this.onZamknij,
    required this.onZmianaUprawy,
    required this.onHistoria,
    this.onZabieg,
  });

  final Pole pole;
  final Future<List<String>>? dzialki;
  final VoidCallback onZamknij;
  final VoidCallback onZmianaUprawy;

  /// Rodzaj użytku i uprawy z poprzednich lat — osobny ekran, bo to dane
  /// do wypełnienia raz, a nie przy każdym zabiegu.
  final VoidCallback onHistoria;

  final VoidCallback? onZabieg;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Karta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(pole.nazwa, style: teksty.headlineMedium)),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Zamknij kartę pola',
                onPressed: onZamknij,
              ),
            ],
          ),
          Text(
            '${pole.uprawa} • ${pole.powierzchniaOpis}'
            '${pole.sezon == null ? '' : ' • sezon ${pole.sezon}'}',
            style: teksty.bodyLarge,
          ),
          if (pole.oznaczenieZWniosku != null) ...[
            const SizedBox(height: 4),
            Text(
              'We wniosku: ${pole.oznaczenieZWniosku}',
              style: teksty.bodyMedium,
            ),
          ],
          FutureBuilder<List<String>>(
            future: dzialki,
            builder: (context, stan) {
              final numery = stan.data ?? const <String>[];
              if (numery.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Działki: ${numery.join(', ')}',
                  style: teksty.bodyMedium,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            pole.kodEppo == null
                ? 'Kod EPPO: brak — w ewidencji wyjdzie „brak"'
                : 'Kod EPPO: ${pole.kodEppo}',
            style: teksty.bodyMedium,
          ),
          const SizedBox(height: MotywNowoczesny.odstep),
          Row(
            children: [
              if (onZabieg != null)
                Expanded(
                  child: FilledButton(
                    onPressed: onZabieg,
                    child: const Text('Zapisz zabieg'),
                  ),
                ),
              if (onZabieg != null) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onZmianaUprawy,
                  child: const Text('Zmień uprawę'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onHistoria,
            icon: Icon(
              pole.rodzajUzytku.znany
                  ? Icons.history_outlined
                  : Icons.help_outline,
              size: 20,
            ),
            label: Text(
              pole.rodzajUzytku.znany
                  ? 'Rodzaj użytku i uprawy w latach'
                  : 'Podaj rodzaj użytku (GAEC 7)',
            ),
          ),
        ],
      ),
    );
  }
}
