import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/nawozenie/nawoz.dart';
import '../../../funkcje/nawozenie/plan_nawozenia.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../../../funkcje/zabiegi/slownik_srodkow.dart';
import '../../../funkcje/zabiegi/zapis_wpisu.dart';
import '../../../rdzen/dostep/funkcja.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../../../rdzen/reguly/regula_prawna.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../../../rdzen/wspolne/wybor_przyorania.dart';
import '../motyw.dart';
import '../widgety/karta.dart';

/// Otwiera okno wpisu zabiegu. Zwraca zapisany zabieg albo `null`, gdy
/// rolnik zrezygnował.
Future<Zabieg?> pokazOknoZabiegu(
  BuildContext context, {
  required Uslugi uslugi,
  DateTime? teraz,
  Pole? pole,
}) {
  return showDialog<Zabieg>(
    context: context,
    builder: (_) =>
        OknoZabiegu(uslugi: uslugi, teraz: teraz, poleNaStart: pole),
  );
}

/// Wpis zabiegu w programie na komputer — jedno okno, klawiatura i mysz.
///
/// Te same dane i ten sam zapis co na telefonie
/// (`funkcje/zabiegi/zapis_wpisu.dart`): oprysk ze środkiem z rejestru,
/// nawożenie z azotem i przyoraniem, pozostałe prace. Różni się tylko
/// sposób wpisywania: liczby z klawiatury, data z kalendarza, bo rolnik
/// przy komputerze często uzupełnia kilka dni naraz.
class OknoZabiegu extends StatefulWidget {
  const OknoZabiegu({
    super.key,
    required this.uslugi,
    this.teraz,
    this.poleNaStart,
  });

  final Uslugi uslugi;

  /// Chwila „teraz" — data i godzina na start; testy podają stałą.
  final DateTime? teraz;

  /// Pole wybrane w zakładce „Pola" — wtedy wpis startuje z gotowym wyborem.
  final Pole? poleNaStart;

  @override
  State<OknoZabiegu> createState() => _OknoZabieguState();
}

class _OknoZabieguState extends State<OknoZabiegu> {
  late final DaneWpisu _dane;
  late final Future<List<Pole>> _pola;
  Future<List<DopuszczonySrodek>>? _srodki;
  Future<List<Nawoz>>? _nawozy;
  Future<List<JednostkaDawkiSrodka>>? _jednostkiDawki;
  Future<List<SkutekDlaMaksymalnejDawki>>? _stanPol;

  final _szukane = TextEditingController();
  final _dawka = TextEditingController();
  final _przyczyna = TextEditingController();
  PracaKrajobrazowa? _praca;
  bool _zapisuje = false;
  String? _blad;

  @override
  void initState() {
    super.initState();
    _dane = DaneWpisu(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      urzadzenie: widget.uslugi.urzadzenie,
      kiedy: widget.teraz,
    );
    if (widget.poleNaStart != null) {
      _dane.pola.add(widget.poleNaStart!);
    }
    _pola = widget.uslugi.pola.wszystkie(widget.uslugi.gospodarstwoId);
    _odswiezStanPol();
  }

  @override
  void dispose() {
    _szukane.dispose();
    _dawka.dispose();
    _przyczyna.dispose();
    super.dispose();
  }

  String get _uprawa => _dane.pola.firstOrNull?.uprawa ?? '';

  bool get _wielePolNaraz =>
      widget.uslugi.dostep.czyDostepna(Funkcja.zabiegNaWieluPolach);

  bool get _pytacOPrace =>
      _dane.rodzaj == RodzajZabiegu.inny &&
      !widget.uslugi.okresLegowy.prace.pusta;

  bool get _gotowy => _dane.gotowyDoZapisu && (!_pytacOPrace || _praca != null);

  static String _liczba(double wartosc) =>
      wartosc.toStringAsFixed(2).replaceAll('.', ',');

  double? get _dawkaZPola {
    final czysty = _dawka.text.trim().replaceAll(',', '.');
    final liczba = double.tryParse(czysty);
    return liczba == null || liczba <= 0 ? null : liczba;
  }

  void _odswiezStanPol() {
    _stanPol = _dane.pola.isEmpty
        ? null
        : widget.uslugi.planNawozenia.skutkiDlaMaksymalnejDawki(
            pola: List.of(_dane.pola),
            azotWpisuKgNaHa: 0,
            kiedy: _dane.kiedy,
          );
  }

  void _odswiezSrodki() {
    if (_dane.rodzaj == RodzajZabiegu.oprysk && _uprawa.isNotEmpty) {
      final fragment = _szukane.text.trim();
      _srodki = fragment.isEmpty
          ? widget.uslugi.srodki.dlaUprawy(_uprawa)
          : widget.uslugi.srodki.szukaj(_uprawa, fragment);
    }
    if (_dane.rodzaj == RodzajZabiegu.nawozenie) {
      _nawozy ??= widget.uslugi.nawozy.wszystkie(widget.uslugi.gospodarstwoId);
    }
  }

  void _ustawRodzaj(RodzajZabiegu rodzaj) {
    setState(() {
      _dane
        ..rodzaj = rodzaj
        ..srodek = null
        ..nawoz = null
        ..dawka = null
        ..przyczyna = null
        ..dataPrzyorania = null;
      _dawka.clear();
      _przyczyna.clear();
      _praca = null;
      _blad = null;
      _odswiezSrodki();
    });
  }

  void _przelaczPole(Pole pole) {
    setState(() {
      final juzJest = _dane.pola.indexWhere((p) => p.id == pole.id);
      if (juzJest >= 0) {
        _dane.pola.removeAt(juzJest);
      } else {
        // Zabieg na kilku polach naraz to dodatek płatny (plan, pkt 8).
        // Bez niego wybór pola zamienia poprzedni.
        if (!_wielePolNaraz) {
          _dane.pola.clear();
        }
        _dane.pola.add(pole);
      }
      _dane
        ..srodek = null
        ..dawka = null;
      _dawka.clear();
      _odswiezSrodki();
      _odswiezStanPol();
    });
  }

  Future<void> _zmienDate() async {
    final dzien = await showDatePicker(
      context: context,
      initialDate: _dane.kiedy,
      firstDate: DateTime(_dane.kiedy.year - 3),
      lastDate: widget.teraz ?? DateTime.now(),
      helpText: 'Dzień zabiegu',
      confirmText: 'Wybierz',
      cancelText: 'Anuluj',
    );
    if (dzien == null || !mounted) {
      return;
    }
    setState(() {
      _dane.kiedy = DateTime(
        dzien.year,
        dzien.month,
        dzien.day,
        _dane.kiedy.hour,
        _dane.kiedy.minute,
      );
      _odswiezStanPol();
    });
  }

  Future<void> _zmienGodzine() async {
    final godzina = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dane.kiedy),
      helpText: 'Godzina zabiegu',
      confirmText: 'Wybierz',
      cancelText: 'Anuluj',
    );
    if (godzina == null || !mounted) {
      return;
    }
    setState(() {
      _dane.kiedy = DateTime(
        _dane.kiedy.year,
        _dane.kiedy.month,
        _dane.kiedy.day,
        godzina.hour,
        godzina.minute,
      );
    });
  }

  void _wybierzSrodek(DopuszczonySrodek srodek) {
    setState(() {
      _dane
        ..srodek = srodek
        // Dawkę podpowiadamy tylko wtedy, gdy rejestr podaje ją
        // jednoznacznie; inaczej rolnik przepisuje ją z etykiety
        // (CLAUDE.md, reguła 5).
        ..dawka = srodek.dawkaZnana ? srodek.dawka : null
        ..jednostkaZEtykiety = null
        ..przyczyna = srodek.agrofag;
      _dawka.text = srodek.dawkaZnana ? _liczba(srodek.dawka!) : '';
      _przyczyna.text = srodek.agrofag ?? '';
      if (!srodek.dawkaZnana) {
        _jednostkiDawki ??= widget.uslugi.srodki.jednostkiDawki();
      }
    });
  }

  void _wybierzNawoz(Nawoz nawoz) {
    setState(() {
      _dane.nawoz = nawoz;
      _dane.dawka ??= ZapisWpisu.domyslnaDawkaNawozu(_dane.jednostkaDawki);
      _dawka.text = _liczba(_dane.dawka!);
    });
  }

  void _ustawJednostkeNawozu(JednostkaDawki jednostka) {
    setState(() {
      _dane
        ..jednostkaDawki = jednostka
        ..dawka = ZapisWpisu.domyslnaDawkaNawozu(jednostka);
      _dawka.text = _liczba(_dane.dawka!);
    });
  }

  Future<void> _zapisz() async {
    if (_zapisuje) {
      return;
    }
    if (!_gotowy) {
      setState(() => _blad = _czegoBrakuje());
      return;
    }
    setState(() {
      _zapisuje = true;
      _blad = null;
    });
    final zabieg = await ZapisWpisu(
      zabiegi: widget.uslugi.zabiegi,
      nawozenie: widget.uslugi.nawozenie,
      magazyn: widget.uslugi.magazyn,
      dostep: widget.uslugi.dostep,
    ).zapisz(_dane, praca: _praca);
    if (mounted) {
      Navigator.of(context).pop(zabieg);
    }
  }

  String _czegoBrakuje() {
    if (_dane.rodzaj == null) {
      return 'Wybierz, co robisz: oprysk, nawożenie albo inną pracę.';
    }
    if (_dane.pola.isEmpty) {
      return 'Wybierz pole, na którym był zabieg.';
    }
    if (_dane.rodzaj == RodzajZabiegu.oprysk && _dane.srodek == null) {
      return 'Wybierz środek z listy — ewidencja wymaga jego nazwy.';
    }
    if (_dane.rodzaj == RodzajZabiegu.nawozenie && _dane.nawoz == null) {
      return 'Wybierz nawóz ze spisu (spis uzupełnisz w zakładce Magazyn '
          'albo w telefonie).';
    }
    return 'Powiedz, co dokładnie robisz — od tego zależy ostrzeżenie '
        'o okresie lęgowym.';
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Nowy zabieg'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _naglowek('Kiedy'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _zmienDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(Daty.krotko(_dane.kiedy)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _zmienGodzine,
                    icon: const Icon(Icons.schedule_outlined, size: 18),
                    label: Text(
                      '${_dane.kiedy.hour.toString().padLeft(2, '0')}:'
                      '${_dane.kiedy.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ],
              ),
              _naglowek('Co robisz?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final rodzaj in RodzajZabiegu.values)
                    _Przelacznik(
                      etykieta: rodzaj.dlaRolnika,
                      wybrany: _dane.rodzaj == rodzaj,
                      onKlik: () => _ustawRodzaj(rodzaj),
                    ),
                ],
              ),
              _naglowek(
                _wielePolNaraz ? 'Na których polach?' : 'Na którym polu?',
              ),
              FutureBuilder<List<Pole>>(
                future: _pola,
                builder: (context, stan) {
                  if (!stan.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final pola = stan.data!;
                  if (pola.isEmpty) {
                    return const OstrzezenieKomputer(
                      tresc: 'Nie ma jeszcze żadnego pola.',
                      coZrobic: 'Dodaj pole w zakładce „Pola" i wróć tutaj.',
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final pole in pola)
                        _Przelacznik(
                          etykieta: '${pole.nazwa} • ${pole.uprawa}',
                          wybrany: _dane.pola.any((p) => p.id == pole.id),
                          onKlik: () => _przelaczPole(pole),
                        ),
                    ],
                  );
                },
              ),
              if (_dane.pola.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Powierzchnia zabiegu: ${_dane.powierzchniaOpis}'
                  '${_dane.pola.length > 1 ? ' (${_dane.pola.length} pola)' : ''}.',
                  style: teksty.bodyMedium,
                ),
              ],
              ..._praceKrajobrazowe(teksty),
              ..._pasOdWody(),
              if (_dane.rodzaj == RodzajZabiegu.oprysk) ..._oprysk(teksty),
              if (_dane.rodzaj == RodzajZabiegu.nawozenie)
                ..._nawozenie(teksty),
              if (_blad != null) ...[
                const SizedBox(height: MotywKomputer.odstep),
                OstrzezenieKomputer(tresc: _blad!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _zapisuje ? null : () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: _zapisuje ? null : _zapisz,
          child: Text(_zapisuje ? 'Zapisuję…' : 'Zapisz zabieg'),
        ),
      ],
    );
  }

  Widget _naglowek(String tekst) => Padding(
    padding: const EdgeInsets.only(top: MotywKomputer.odstep, bottom: 6),
    child: Text(tekst, style: Theme.of(context).textTheme.titleLarge),
  );

  List<Widget> _praceKrajobrazowe(TextTheme teksty) {
    if (!_pytacOPrace) {
      return const [];
    }
    final okresLegowy = widget.uslugi.okresLegowy;
    final ostrzezenie = okresLegowy.ostrzezeniePrzedZapisem(
      idPracy: _praca?.id,
      kiedy: _dane.kiedy,
    );
    return [
      _naglowek('Co robisz dokładnie?'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final praca in okresLegowy.prace.prace)
            _Przelacznik(
              etykieta: praca.nazwa,
              wybrany: praca.id == _praca?.id,
              onKlik: () => setState(() => _praca = praca),
            ),
        ],
      ),
      if (_praca != null) ...[
        const SizedBox(height: 4),
        Text(_praca!.opis, style: teksty.bodyMedium),
      ],
      if (ostrzezenie != null) ...[
        const SizedBox(height: 8),
        OstrzezenieKomputer(
          tresc: ostrzezenie.tresc,
          coZrobic: ostrzezenie.coZrobic,
        ),
      ],
    ];
  }

  /// Ostrzeżenie z normy GAEC 4 — pas od brzegu wody bez nawozów
  /// i środków ochrony roślin. Nie blokuje zapisu: dokumentacja ma być
  /// prawdziwa, a zabieg mógł być wykonany poza pasem.
  List<Widget> _pasOdWody() {
    final ostrzezenie = widget.uslugi.pasOdWody.ostrzezeniePrzedZapisem(
      pola: _dane.pola,
      rodzaj: _dane.rodzaj,
    );
    if (ostrzezenie == null) {
      return const [];
    }
    return [
      const SizedBox(height: 8),
      OstrzezenieKomputer(
        tresc: ostrzezenie.tresc,
        coZrobic: ostrzezenie.coZrobic,
      ),
    ];
  }

  List<Widget> _oprysk(TextTheme teksty) {
    final srodek = _dane.srodek;
    return [
      _naglowek('Czym opryskujesz?'),
      if (_dane.pola.isEmpty)
        Text(
          'Najpierw wybierz pole — lista środków zależy od uprawy.',
          style: teksty.bodyMedium,
        )
      else ...[
        TextField(
          controller: _szukane,
          decoration: const InputDecoration(
            labelText: 'Szukaj po nazwie środka',
            prefixIcon: Icon(Icons.search, size: 20),
          ),
          onChanged: (_) => setState(_odswiezSrodki),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<DopuszczonySrodek>>(
          future: _srodki,
          builder: (context, stan) {
            if (!stan.hasData) {
              return const LinearProgressIndicator();
            }
            final srodki = stan.data!;
            if (srodki.isEmpty) {
              return OstrzezenieKomputer(
                tresc:
                    'Rejestr nie przewiduje tu żadnego środka dla uprawy '
                    '„$_uprawa".',
                coZrobic: _szukane.text.trim().isEmpty
                    ? 'Sprawdź, czy uprawa pola jest wpisana poprawnie.'
                    : 'Spróbuj wpisać inną część nazwy.',
              );
            }
            // Kilka pozycji naraz — cały rejestr ma ich tysiące,
            // a wyszukiwarka jest wyżej.
            final widoczne = srodki.take(8).toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final pozycja in widoczne)
                  _Pozycja(
                    nazwa: pozycja.nazwa,
                    opis: [
                      if (pozycja.agrofag != null) pozycja.agrofag!,
                      pozycja.dawkaOpis,
                    ].join(' • '),
                    wybrana: pozycja.zastosowanieId == srodek?.zastosowanieId,
                    onKlik: () => _wybierzSrodek(pozycja),
                  ),
                if (srodki.length > widoczne.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Dopuszczonych środków: ${srodki.length}. '
                      'Wpisz nazwę, żeby zawęzić listę.',
                      style: teksty.bodyMedium,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
      if (srodek != null) ...[
        _naglowek('Dawka'),
        if (!srodek.dawkaZnana) ...[
          OstrzezenieKomputer(
            tresc: 'Rejestr nie podaje tu dawki w jednoznacznej postaci.',
            coZrobic:
                srodek.dawkaTekst ??
                'Odczytaj dawkę z etykiety i wpisz ją niżej.',
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _dawka,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Dawka',
                  helperMaxLines: 2,
                  suffixText: srodek.dawkaZnana
                      ? '${srodek.dawkaJednostka}/${srodek.dawkaOdniesienie}'
                      : _dane.jednostkaZEtykiety?.opis,
                  helperText: srodek.dawkaZnana
                      ? 'największa dopuszczalna: ${srodek.dawkaOpis}'
                      : 'z etykiety; puste = bez dawki',
                ),
                onChanged: (_) => setState(() => _dane.dawka = _dawkaZPola),
              ),
            ),
            if (!srodek.dawkaZnana) ...[
              const SizedBox(width: MotywKomputer.odstep),
              Expanded(child: _jednostkiZEtykiety(teksty)),
            ],
          ],
        ),
        if (srodek.dawka != null &&
            (_dane.dawka ?? 0) > srodek.dawka! + 1e-9) ...[
          const SizedBox(height: 8),
          const OstrzezenieKomputer(
            tresc: 'Ta dawka przekracza dopuszczalną z rejestru.',
            coZrobic: 'Zmniejsz dawkę albo sprawdź etykietę.',
          ),
        ],
        if (_dane.dawka != null &&
            !srodek.dawkaZnana &&
            _dane.jednostkaZEtykiety == null) ...[
          const SizedBox(height: 8),
          const OstrzezenieKomputer(
            tresc: 'Nie wiadomo, w czym podana jest ta dawka.',
            coZrobic:
                'Wybierz jednostkę obok — bez niej liczba w ewidencji '
                'nic nie znaczy.',
          ),
        ],
        if (_dane.iloscSrodkaRazem case final double razem) ...[
          const SizedBox(height: 6),
          Text(
            'Na ${_dane.powierzchniaOpis} potrzeba ${_liczba(razem)} '
            '${_dane.dawkaJednostka ?? ''}.',
            style: teksty.bodyMedium,
          ),
        ],
        _naglowek('Powód zabiegu'),
        TextField(
          controller: _przyczyna,
          decoration: const InputDecoration(labelText: 'Agrofag albo powód'),
          onChanged: (tekst) =>
              _dane.przyczyna = tekst.trim().isEmpty ? null : tekst.trim(),
        ),
      ],
    ];
  }

  Widget _jednostkiZEtykiety(TextTheme teksty) =>
      FutureBuilder<List<JednostkaDawkiSrodka>>(
        future: _jednostkiDawki,
        builder: (context, stan) {
          if (!stan.hasData) {
            return Text(
              'Czytam jednostki z rejestru…',
              style: teksty.bodyMedium,
            );
          }
          final lista = stan.data!;
          if (lista.isEmpty) {
            return Text(
              'Rejestr nie podaje tu żadnej jednostki. Zapisz zabieg bez '
              'dawki i dopisz ją na wydruku.',
              style: teksty.bodyMedium,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('W czym podana jest dawka?', style: teksty.bodyMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final jednostka in lista)
                    _Przelacznik(
                      etykieta: jednostka.opis,
                      wybrany: jednostka == _dane.jednostkaZEtykiety,
                      onKlik: () =>
                          setState(() => _dane.jednostkaZEtykiety = jednostka),
                    ),
                ],
              ),
            ],
          );
        },
      );

  List<Widget> _nawozenie(TextTheme teksty) {
    final nawoz = _dane.nawoz;
    return [
      _naglowek('Czym nawozisz?'),
      FutureBuilder<List<Nawoz>>(
        future: _nawozy,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const LinearProgressIndicator();
          }
          final nawozy = stan.data!;
          if (nawozy.isEmpty) {
            return const OstrzezenieKomputer(
              tresc: 'Spis nawozów jest pusty.',
              coZrobic:
                  'Dopisz nawóz w telefonie (Dodaj zabieg → Nawożenie → '
                  'Nowy nawóz) — wtedy pojawi się tutaj.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final pozycja in nawozy)
                _Pozycja(
                  nazwa: pozycja.nazwa,
                  opis: pozycja.skladOpis,
                  wybrana: pozycja.id == nawoz?.id,
                  onKlik: () => _wybierzNawoz(pozycja),
                ),
            ],
          );
        },
      ),
      if (nawoz != null) ...[
        _naglowek('Dawka'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                controller: _dawka,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Dawka',
                  suffixText: _dane.jednostkaDawki.opis,
                ),
                onChanged: (_) => setState(() => _dane.dawka = _dawkaZPola),
              ),
            ),
            const SizedBox(width: MotywKomputer.odstep),
            for (final jednostka in JednostkaDawki.values) ...[
              _Przelacznik(
                etykieta: jednostka.opis,
                wybrany: _dane.jednostkaDawki == jednostka,
                onKlik: () => _ustawJednostkeNawozu(jednostka),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (_dane.azotKgNaHa case final double azot) ...[
          Text(
            'To ${azot.toStringAsFixed(1).replaceAll('.', ',')} kg azotu na '
            'hektar, czyli ${(azot * _dane.powierzchniaAr / 100).toStringAsFixed(0)} '
            'kg na ${_dane.powierzchniaOpis}.',
            style: teksty.bodyMedium,
          ),
          if (_stanPol case final Future<List<SkutekDlaMaksymalnejDawki>> stan)
            _MaksymalnaDawka(stanPol: stan, azotWpisu: azot),
        ] else
          const OstrzezenieKomputer(
            tresc: 'Nie znamy zawartości azotu w tym nawozie.',
            coZrobic:
                'Azotu nie policzymy do limitu — dopisz zawartość z worka '
                'albo z analizy gnojowicy.',
          ),
        if (nawoz.naturalny) ...[
          _naglowek('Przyoranie'),
          WyborPrzyorania(
            dzienZabiegu: _dane.kiedy,
            wybrana: _dane.dataPrzyorania,
            onZmiana: (dzien) => setState(() => _dane.dataPrzyorania = dzien),
          ),
        ],
      ],
    ];
  }
}

/// Przycisk wyboru: wypełniony, gdy wybrany; obrysowany, gdy nie.
class _Przelacznik extends StatelessWidget {
  const _Przelacznik({
    required this.etykieta,
    required this.wybrany,
    required this.onKlik,
  });

  final String etykieta;
  final bool wybrany;
  final VoidCallback onKlik;

  @override
  Widget build(BuildContext context) => wybrany
      ? FilledButton(onPressed: onKlik, child: Text(etykieta))
      : OutlinedButton(onPressed: onKlik, child: Text(etykieta));
}

/// Pozycja listy środków albo nawozów — nazwa i opis, klik wybiera.
class _Pozycja extends StatelessWidget {
  const _Pozycja({
    required this.nazwa,
    required this.opis,
    required this.wybrana,
    required this.onKlik,
  });

  final String nazwa;
  final String opis;
  final bool wybrana;
  final VoidCallback onKlik;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final zaokraglenie = BorderRadius.circular(MotywKomputer.zaokraglenieMale);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: wybrana ? MotywKomputer.powierzchniaDruga : MotywKomputer.karta,
        shape: RoundedRectangleBorder(
          borderRadius: zaokraglenie,
          side: BorderSide(
            color: wybrana ? MotywKomputer.zielen : MotywKomputer.obramowanie,
            width: wybrana ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: zaokraglenie,
          onTap: onKlik,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  wybrana
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: wybrana
                      ? MotywKomputer.zielen
                      : MotywKomputer.tekstPomocniczy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nazwa, style: teksty.bodyLarge),
                      if (opis.isNotEmpty) Text(opis, style: teksty.bodyMedium),
                    ],
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

/// Maksymalna dawka azotu dla uprawy (tabela 14 programu azotanowego).
/// Nie blokuje zapisu — rolnik mógł już wysiać i musi móc to zapisać.
class _MaksymalnaDawka extends StatelessWidget {
  const _MaksymalnaDawka({required this.stanPol, required this.azotWpisu});

  final Future<List<SkutekDlaMaksymalnejDawki>> stanPol;
  final double azotWpisu;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<SkutekDlaMaksymalnejDawki>>(
        future: stanPol,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const SizedBox.shrink();
          }
          final pola = [for (final pole in stan.data!) pole.zDawka(azotWpisu)];
          final ostrzezenia = pola
              .where((pole) => pole.ostrzezenie != null)
              .toList(growable: false);
          if (ostrzezenia.isEmpty) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final pole in ostrzezenia)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OstrzezenieKomputer(
                    tresc: pole.ostrzezenie!,
                    coZrobic: pole.coZrobic,
                  ),
                ),
            ],
          );
        },
      );
}
