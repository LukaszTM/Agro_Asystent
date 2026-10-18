import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/czytnik_wniosku.dart';
import '../../../funkcje/dzialki/import_wniosku.dart';
import '../../../funkcje/dzialki/klient_uldk.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/dzialki/slownik_upraw.dart';
import '../../../funkcje/dzialki/szukanie_dzialki.dart';
import '../../../rdzen/wspolne/szukanie_dzialki.dart';
import '../motyw.dart';
import '../widgety/karta.dart';

/// Okna dodawania danych w programie na komputer.
///
/// Na telefonie każdy krok ma osobny ekran i duże przyciski — palcem
/// inaczej się nie da. Przy komputerze rolnik ma klawiaturę i mysz, więc
/// całość mieści się w jednym oknie: pisze, zatwierdza Enterem, wraca do
/// tabeli. Zapis idzie do tej samej bazy i przez te same repozytoria co
/// na telefonie.

/// Nowe pole: nazwa, uprawa ze słownika i powierzchnia.
class OknoNowePole extends StatefulWidget {
  const OknoNowePole({super.key, required this.uslugi, required this.sezon});

  final Uslugi uslugi;

  /// Sezon, do którego dopisujemy pole.
  final int sezon;

  @override
  State<OknoNowePole> createState() => _OknoNowePoleState();
}

class _OknoNowePoleState extends State<OknoNowePole> {
  final _nazwa = TextEditingController();
  final _powierzchnia = TextEditingController();
  UprawaDoWyboru? _uprawa;
  String _wpisanaUprawa = '';
  bool _zapisywanie = false;
  String? _blad;

  @override
  void dispose() {
    _nazwa.dispose();
    _powierzchnia.dispose();
    super.dispose();
  }

  /// Powierzchnia w arach albo `null`, gdy wpisu nie da się odczytać.
  int? get _ar {
    final tekst = _powierzchnia.text.trim().replaceAll(',', '.');
    final hektary = double.tryParse(tekst);
    if (hektary == null || hektary <= 0) {
      return null;
    }
    return (hektary * 100).round();
  }

  Future<void> _zapisz() async {
    final ar = _ar;
    if (_nazwa.text.trim().isEmpty) {
      setState(() => _blad = 'Wpisz nazwę pola — po niej je rozpoznasz.');
      return;
    }
    if (ar == null) {
      setState(
        () => _blad = 'Wpisz powierzchnię w hektarach, na przykład 2,35.',
      );
      return;
    }
    final uprawa = _uprawa;
    final nazwaUprawy = uprawa?.nazwa ?? _wpisanaUprawa.trim();
    if (nazwaUprawy.isEmpty) {
      setState(() => _blad = 'Wybierz uprawę z listy albo wpisz własną.');
      return;
    }

    setState(() {
      _zapisywanie = true;
      _blad = null;
    });
    await widget.uslugi.pola.dodaj(
      pole: Pole(
        id: 'pole-${DateTime.now().microsecondsSinceEpoch}',
        gospodarstwoId: widget.uslugi.gospodarstwoId,
        nazwa: _nazwa.text.trim(),
        uprawa: nazwaUprawy,
        // Kod EPPO tylko z wyboru ze słownika. Przy własnej nazwie zostaje
        // pusty i w ewidencji wyjdzie jako brak — nie zgadujemy go
        // (CLAUDE.md, reguła 5).
        kodEppo: uprawa?.kodEppo,
        powierzchniaAr: ar,
        sezon: widget.sezon,
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
    return AlertDialog(
      title: const Text('Nowe pole'),
      content: SizedBox(
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nazwa pola', style: teksty.titleLarge),
            const SizedBox(height: 6),
            TextField(
              controller: _nazwa,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Za stodołą, Przy drodze…',
              ),
              onSubmitted: (_) => _zapisz(),
            ),
            const SizedBox(height: MotywKomputer.odstep),
            Text('Uprawa', style: teksty.titleLarge),
            const SizedBox(height: 6),
            _WyborUprawy(
              uprawy: widget.uslugi.uprawy,
              onWybor: (uprawa, wpisane) {
                _uprawa = uprawa;
                _wpisanaUprawa = wpisane;
              },
            ),
            const SizedBox(height: MotywKomputer.odstep),
            Text('Powierzchnia w hektarach', style: teksty.titleLarge),
            const SizedBox(height: 6),
            TextField(
              controller: _powierzchnia,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: 'np. 2,35'),
              onSubmitted: (_) => _zapisz(),
            ),
            const SizedBox(height: 6),
            Text(
              'Pole trafi do sezonu ${widget.sezon}.',
              style: teksty.bodyMedium,
            ),
            if (_blad case final String wiadomosc) ...[
              const SizedBox(height: MotywKomputer.odstep),
              OstrzezenieKomputer(tresc: wiadomosc),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _zapisywanie
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: _zapisywanie ? null : _zapisz,
          child: const Text('Zapisz pole'),
        ),
      ],
    );
  }
}

/// Wybór uprawy ze słownika, z pisaniem jako wyjściem awaryjnym.
class _WyborUprawy extends StatelessWidget {
  const _WyborUprawy({required this.uprawy, required this.onWybor});

  final SlownikUpraw uprawy;

  /// Wybrana uprawa ze słownika (z kodem EPPO) albo sama nazwa wpisana
  /// z klawiatury.
  final void Function(UprawaDoWyboru? zeSlownika, String wpisana) onWybor;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<UprawaDoWyboru>(
      displayStringForOption: (uprawa) => uprawa.nazwa,
      optionsBuilder: (wartosc) async {
        onWybor(null, wartosc.text);
        if (wartosc.text.trim().length < 2) {
          return const Iterable<UprawaDoWyboru>.empty();
        }
        final wynik = await uprawy.doWyboru(szukane: wartosc.text, limit: 10);
        return wynik.uprawy;
      },
      onSelected: (uprawa) => onWybor(uprawa, uprawa.nazwa),
      fieldViewBuilder: (context, kontroler, ognisko, _) => TextField(
        controller: kontroler,
        focusNode: ognisko,
        decoration: const InputDecoration(
          hintText: 'Zacznij pisać: pszenica, rzepak…',
        ),
      ),
      optionsViewBuilder: (context, wybierz, opcje) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final uprawa in opcje)
                  ListTile(
                    title: Text(uprawa.nazwa),
                    subtitle: uprawa.kodEppo == null
                        ? const Text('bez kodu EPPO')
                        : Text('kod ${uprawa.kodEppo}'),
                    onTap: () => wybierz(uprawa),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Działka ewidencyjna po numerze — granice pobiera ULDK.
class OknoDzialkaPoNumerze extends StatefulWidget {
  const OknoDzialkaPoNumerze({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<OknoDzialkaPoNumerze> createState() => _OknoDzialkaPoNumerzeState();
}

class _OknoDzialkaPoNumerzeState extends State<OknoDzialkaPoNumerze> {
  final _numer = TextEditingController();

  /// Szukanie po województwie, miejscowości i numerze — dla działek spoza
  /// wniosku, których pełnego numeru nikt nie pamięta.
  late final SzukanieDzialkiPoNazwie _poNazwie = SzukanieDzialkiPoNazwie(
    klient: widget.uslugi.uldk,
    wojewodztwa: widget.uslugi.wojewodztwa,
  );

  /// `true` — szukamy po miejscowości, `false` — rolnik wpisuje pełny
  /// numer z wypisu.
  bool _zList = true;

  bool _pobieranie = false;
  DzialkaZUldk? _pobrana;
  bool _jestJuz = false;
  String? _blad;
  String? _coZrobic;

  @override
  void dispose() {
    _numer.dispose();
    super.dispose();
  }

  bool get _moznaSzukac =>
      _zList ? _poNazwie.moznaSzukac : _numer.text.trim().isNotEmpty;

  /// Szukanie po nazwie: jedna znaleziona działka — od razu granice;
  /// kilka — rolnik wybiera z listy, bo obręby o tej nazwie są w wielu
  /// gminach.
  Future<void> _szukaj() async {
    if (!_moznaSzukac) {
      setState(
        () => _blad = _zList
            ? 'Wpisz nazwę miejscowości (obrębu) i numer działki z umowy.'
            : 'Wpisz numer działki z wypisu albo z wniosku.',
      );
      return;
    }
    if (!_zList) {
      return _pobierz(_numer.text.trim());
    }
    setState(() {
      _pobieranie = true;
      _blad = null;
      _coZrobic = null;
      _pobrana = null;
    });
    try {
      final znalezione = await _poNazwie.szukaj();
      if (!mounted) {
        return;
      }
      if (znalezione.length == 1) {
        await _pobierz(znalezione.single.teryt);
        return;
      }
      setState(() => _pobieranie = false);
    } on BladUldk catch (blad) {
      if (!mounted) {
        return;
      }
      setState(() {
        _blad = blad.wiadomosc;
        _coZrobic = blad.coZrobic;
        _pobieranie = false;
      });
    }
  }

  Future<void> _pobierz(String numer) async {
    setState(() {
      _pobieranie = true;
      _blad = null;
      _coZrobic = null;
      _pobrana = null;
    });
    try {
      final dzialka = await widget.uslugi.uldk.pobierz(numer);
      final jestJuz = await widget.uslugi.dzialki.czyJuzJest(
        widget.uslugi.gospodarstwoId,
        dzialka.identyfikator,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pobrana = dzialka;
        _jestJuz = jestJuz;
        _pobieranie = false;
      });
    } on BladUldk catch (blad) {
      if (!mounted) {
        return;
      }
      setState(() {
        _blad = blad.wiadomosc;
        _coZrobic = blad.coZrobic;
        _pobieranie = false;
      });
    }
  }

  Future<void> _zapisz() async {
    final dzialka = _pobrana;
    if (dzialka == null) {
      return;
    }
    await widget.uslugi.dzialki.zapisz(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      zUldk: dzialka,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final pobrana = _pobrana;
    return AlertDialog(
      title: const Text('Działka po numerze'),
      content: SizedBox(
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Granice pobieramy raz, z państwowej usługi ULDK. Do tego '
              'jednego kroku potrzebny jest internet — potem mapka działa '
              'bez niego.',
              style: teksty.bodyMedium,
            ),
            const SizedBox(height: MotywKomputer.odstep),
            // Działka z wniosku ma pełny numer w dokumencie; dzierżawiona
            // zwykle nie — wtedy szukamy po miejscowości i numerze z umowy.
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.list_alt_outlined, size: 20),
                  label: Text('Po miejscowości'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.keyboard_outlined, size: 20),
                  label: Text('Wpisz pełny numer'),
                ),
              ],
              selected: {_zList},
              onSelectionChanged: (wybrane) => setState(() {
                _zList = wybrane.first;
                _blad = null;
                _pobrana = null;
              }),
            ),
            const SizedBox(height: MotywKomputer.odstep),
            if (_zList)
              SzukanieDzialki(
                szukanie: _poNazwie,
                onZmiana: () => setState(() => _blad = null),
                onWybor: (dzialka) => _pobierz(dzialka.teryt),
                onSzukaj: _szukaj,
              )
            else
              TextField(
                controller: _numer,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Numer działki',
                  hintText: 'np. 141201_2.0012.123/4',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _szukaj(),
              ),
            if (_blad case final String wiadomosc) ...[
              const SizedBox(height: MotywKomputer.odstep),
              OstrzezenieKomputer(tresc: wiadomosc, coZrobic: _coZrobic),
            ],
            if (pobrana != null) ...[
              const SizedBox(height: MotywKomputer.odstep),
              KartaKomputer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pobrana.identyfikator, style: teksty.titleLarge),
                    Text(
                      [
                        pobrana.wojewodztwo,
                        pobrana.powiat,
                        pobrana.gmina,
                        pobrana.obreb,
                      ].whereType<String>().join(' • '),
                      style: teksty.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (_jestJuz) ...[
                const SizedBox(height: 8),
                const OstrzezenieKomputer(
                  tresc: 'Tę działkę masz już w gospodarstwie.',
                  coZrobic: 'Zapis odświeży jej granice i dane z rejestru.',
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Anuluj'),
        ),
        if (pobrana == null)
          FilledButton(
            onPressed: _pobieranie ? null : _szukaj,
            child: Text(_pobieranie ? 'Szukam…' : 'Znajdź działkę'),
          )
        else
          FilledButton(onPressed: _zapisz, child: const Text('Zapisz działkę')),
      ],
    );
  }
}

/// Wczytanie wniosku z eWniosekPlus (PDF).
class OknoWniosek extends StatefulWidget {
  const OknoWniosek({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<OknoWniosek> createState() => _OknoWniosekState();
}

class _OknoWniosekState extends State<OknoWniosek> {
  bool _pracuje = false;
  String? _nazwaPliku;
  WniosekZPdf? _wniosek;
  WynikImportu? _zapisane;
  String? _blad;
  String? _coZrobic;

  Future<void> _wybierz() async {
    final plik = await widget.uslugi.zrodloPliku.wybierzPdf();
    if (plik == null || !mounted) {
      return;
    }
    setState(() {
      _pracuje = true;
      _nazwaPliku = plik.nazwa;
      _blad = null;
      _coZrobic = null;
    });
    try {
      // Wniosek ma kilkadziesiąt stron — odczyt idzie do osobnego wątku,
      // żeby okno nie zamarzło.
      final wniosek = await compute(CzytnikWniosku.zBajtow, plik.bajty);
      if (!mounted) {
        return;
      }
      setState(() {
        _wniosek = wniosek;
        _pracuje = false;
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _blad = 'Nie udało się odczytać tego pliku.';
        _coZrobic =
            'Sprawdź, czy to wniosek pobrany z eWniosekPlus, a nie zdjęcie '
            'albo skan.';
        _pracuje = false;
        _wniosek = null;
      });
    }
  }

  Future<void> _zapisz() async {
    final wniosek = _wniosek;
    if (wniosek == null) {
      return;
    }
    setState(() => _pracuje = true);
    final wynik = await widget.uslugi.importWniosku.zapisz(
      wniosek: wniosek,
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _zapisane = wynik;
      _pracuje = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final zapisane = _zapisane;
    final wniosek = _wniosek;
    return AlertDialog(
      title: const Text('Wniosek z PDF'),
      content: SizedBox(
        width: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (zapisane != null) ...[
              Text(
                'Wczytane do sezonu ${zapisane.sezon}',
                style: teksty.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '${zapisane.dzialkiRazem} działek ewidencyjnych, '
                '${zapisane.polaRazem} pól.',
                style: teksty.bodyLarge,
              ),
              if (zapisane.uprawyBezKodu.isNotEmpty) ...[
                const SizedBox(height: MotywKomputer.odstep),
                OstrzezenieKomputer(
                  tresc:
                      '${zapisane.uprawyBezKodu.length} upraw bez kodu EPPO: '
                      '${zapisane.uprawyBezKodu.take(5).join(', ')}'
                      '${zapisane.uprawyBezKodu.length > 5 ? '…' : ''}.',
                  coZrobic:
                      'Kodu nie zgadujemy. Popraw uprawę przy polu, a kod '
                      'dojdzie ze słownika.',
                ),
              ],
              if (zapisane.dzialkiBezPelnegoNumeru.isNotEmpty) ...[
                const SizedBox(height: 8),
                OstrzezenieKomputer(
                  tresc:
                      '${zapisane.dzialkiBezPelnegoNumeru.length} działek bez '
                      'pełnego numeru.',
                  coZrobic:
                      'Bez niego nie pobierzemy granic — numer znajdziesz '
                      'w wypisie z ewidencji gruntów.',
                ),
              ],
            ] else if (wniosek != null) ...[
              Text(_nazwaPliku ?? 'wniosek.pdf', style: teksty.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Odczytano ${wniosek.dzialki.length} działek i '
                '${wniosek.pola.length} pól'
                '${wniosek.rok == null ? '' : ', rok ${wniosek.rok}'}.',
                style: teksty.bodyLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Zapis nie rusza granic działek już pobranych z ULDK '
                'ani wpisów w rejestrze zabiegów.',
                style: teksty.bodyMedium,
              ),
            ] else ...[
              Text(
                'Wybierz plik wniosku pobrany z eWniosekPlus. Program czyta '
                'go na tym komputerze — nic nie wychodzi do sieci.',
                style: teksty.bodyMedium,
              ),
              if (_blad case final String wiadomosc) ...[
                const SizedBox(height: MotywKomputer.odstep),
                OstrzezenieKomputer(tresc: wiadomosc, coZrobic: _coZrobic),
              ],
            ],
            if (_pracuje) ...[
              const SizedBox(height: MotywKomputer.odstep),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(zapisane != null),
          child: Text(zapisane == null ? 'Anuluj' : 'Zamknij'),
        ),
        if (zapisane == null)
          FilledButton(
            onPressed: _pracuje ? null : (wniosek == null ? _wybierz : _zapisz),
            child: Text(wniosek == null ? 'Wybierz plik' : 'Zapisz do bazy'),
          ),
      ],
    );
  }
}
