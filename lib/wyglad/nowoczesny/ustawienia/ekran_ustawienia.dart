import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/ustawienia/gospodarstwa.dart';
import '../../../funkcje/ustawienia/wybor_wygladu.dart';
import '../../../funkcje/ustawienia/zwierzeta_w_gospodarstwie.dart';
import '../../../rdzen/uslugi/kopia/kopia_danych.dart';
import '../../../rdzen/uslugi/kopia/scalanie.dart';
import '../../../rdzen/wspolne/wersja_programu.dart';
import '../magazyn/ekran_magazyn.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';
import 'ekran_dane_gospodarstwa.dart';
import 'ekran_slowniczek.dart';

/// Ustawienia wyglądu nowoczesnego: wygląd, gospodarstwo, zwierzęta i kopia
/// danych.
///
/// Wygląd przełącza się tutaj i działa od razu — rolnik ma zobaczyć różnicę,
/// a nie czytać o niej (plan, pkt 5).
class EkranUstawienia extends StatefulWidget {
  const EkranUstawienia({
    super.key,
    required this.uslugi,
    this.onZmianaWygladu,
    this.onZmianaGospodarstwa,
  });

  final Uslugi uslugi;

  /// Nowy wygląd wraca do startu aplikacji — to on buduje motyw i ekrany.
  final void Function(Wyglad wyglad)? onZmianaWygladu;

  /// Przełączenie gospodarstwa zmienia dane na wszystkich ekranach.
  final void Function(Uslugi noweUslugi)? onZmianaGospodarstwa;

  @override
  State<EkranUstawienia> createState() => _EkranUstawieniaState();
}

class _EkranUstawieniaState extends State<EkranUstawienia> {
  late Uslugi _uslugi;
  late Future<_Dane> _dane;
  bool _pracuje = false;
  String? _wynikKopii;
  ({String tresc, String coZrobic})? _bladKopii;

  @override
  void initState() {
    super.initState();
    _uslugi = widget.uslugi;
    _dane = _wczytaj();
  }

  Future<_Dane> _wczytaj() async => _Dane(
    wyglad: await _uslugi.wyglad.odczytaj(),
    gospodarstwa: await _uslugi.gospodarstwa.wszystkie(),
    biezace: await _uslugi.gospodarstwa.jedno(_uslugi.gospodarstwoId),
    zwierzeta: await _uslugi.zwierzetaWGospodarstwie.odczytaj(),
    konto: await _uslugi.gospodarstwa.konto(),
  );

  void _odswiez() {
    setState(() {
      _dane = _wczytaj();
    });
  }

  Future<void> _ustawWyglad(Wyglad wyglad) async {
    await _uslugi.wyglad.zapisz(wyglad);
    if (!mounted) {
      return;
    }
    _odswiez();
    widget.onZmianaWygladu?.call(wyglad);
  }

  Future<void> _ustawZwierzeta(OdpowiedzZwierzeta odpowiedz) async {
    await _uslugi.zwierzetaWGospodarstwie.zapisz(odpowiedz);
    if (mounted) {
      _odswiez();
    }
  }

  Future<void> _przelacz(Gospodarstwo gospodarstwo) async {
    await _uslugi.gospodarstwa.ustawAktywne(gospodarstwo.id);
    final nowe = _uslugi.dlaGospodarstwa(
      id: gospodarstwo.id,
      nazwa: gospodarstwo.nazwa,
    );
    widget.onZmianaGospodarstwa?.call(nowe);
    if (mounted) {
      setState(() {
        _uslugi = nowe;
        _dane = _wczytaj();
      });
    }
  }

  /// Poprawienie albo usunięcie gospodarstwa — po usunięciu repozytorium
  /// już przełączyło na to, które zostało, więc ekrany muszą dostać nowy
  /// zestaw usług.
  Future<void> _popraw(Gospodarstwo gospodarstwo) async {
    final poprawione = await Navigator.of(context).push<Gospodarstwo>(
      MaterialPageRoute<Gospodarstwo>(
        builder: (_) => EkranDaneGospodarstwaNowoczesny(
          uslugi: _uslugi,
          gospodarstwo: gospodarstwo,
        ),
      ),
    );
    if (poprawione == null || !mounted) {
      return;
    }
    if (poprawione.id.isEmpty) {
      final zostale = await _uslugi.gospodarstwa.aktywne();
      if (zostale != null) {
        final nowe = _uslugi.dlaGospodarstwa(
          id: zostale.id,
          nazwa: zostale.nazwa,
        );
        widget.onZmianaGospodarstwa?.call(nowe);
        _uslugi = nowe;
      }
      if (mounted) {
        _odswiez();
      }
      return;
    }
    if (poprawione.id == _uslugi.gospodarstwoId) {
      final nowe = _uslugi.dlaGospodarstwa(
        id: poprawione.id,
        nazwa: poprawione.nazwa,
      );
      widget.onZmianaGospodarstwa?.call(nowe);
      _uslugi = nowe;
    }
    if (mounted) {
      _odswiez();
    }
  }

  Future<void> _dodajGospodarstwo() async {
    final dodane = await Navigator.of(context).push<Gospodarstwo>(
      MaterialPageRoute<Gospodarstwo>(
        builder: (_) => EkranDaneGospodarstwaNowoczesny(uslugi: _uslugi),
      ),
    );
    if (dodane != null && mounted) {
      await _przelacz(dodane);
    }
  }

  Future<void> _zapiszKonto(String nazwa) async {
    await _uslugi.gospodarstwa.zapiszKonto(
      nazwa: nazwa,
      urzadzenie: _uslugi.urzadzenie,
    );
    if (mounted) {
      _odswiez();
    }
  }

  Future<void> _zrobKopie() async {
    if (_pracuje) {
      return;
    }
    setState(() {
      _pracuje = true;
      _wynikKopii = null;
      _bladKopii = null;
    });
    try {
      final teraz = DateTime.now();
      final bajty = await _uslugi.kopia.zrob(teraz: teraz);
      await _uslugi.dokumenty.wyjscie.udostepnij(
        dane: bajty,
        nazwa: KopiaDanych.nazwaPliku(teraz),
        typMime: 'application/zip',
      );
      if (mounted) {
        setState(
          () => _wynikKopii =
              'Kopia gotowa: ${KopiaDanych.nazwaPliku(teraz)}. '
              'Zapisz ją tam, gdzie znajdziesz po zgubieniu telefonu.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _bladKopii = (
            tresc: 'Nie udało się zapisać kopii.',
            coZrobic: 'Sprawdź miejsce na dane i spróbuj jeszcze raz.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pracuje = false);
      }
    }
  }

  Future<void> _wczytajKopie() async {
    if (_pracuje) {
      return;
    }
    final plik = await _uslugi.zrodloPliku.wybierzKopie();
    if (plik == null) {
      return;
    }
    setState(() {
      _pracuje = true;
      _wynikKopii = null;
      _bladKopii = null;
    });
    final wynik = await _uslugi.kopia.wczytaj(plik.bajty);
    if (!mounted) {
      return;
    }
    setState(() {
      _pracuje = false;
      switch (wynik) {
        case KopiaWczytana(:final opis):
          _wynikKopii =
              'Wczytano kopię: ${opis.liczbaPol} pól, '
              '${opis.liczbaZabiegow} zabiegów.';
        case KopiaOdrzucona(:final blad):
          _bladKopii = switch (blad) {
            BladKopii.nieNaszPlik => (
              tresc: 'To nie jest kopia z tej aplikacji.',
              coZrobic:
                  'Wybierz plik o nazwie zaczynającej się od '
                  '„moj-lan-kopia".',
            ),
            BladKopii.nowszaWersja => (
              tresc: 'Kopia pochodzi z nowszej wersji aplikacji.',
              coZrobic: 'Zaktualizuj aplikację i wczytaj kopię jeszcze raz.',
            ),
            BladKopii.saJuzDane => (
              tresc: 'W telefonie są już wpisy.',
              coZrobic:
                  'Kopię wczytujemy do pustej aplikacji, żeby nie zdublować '
                  'dokumentacji.',
            ),
          };
      }
    });
    if (wynik is KopiaWczytana) {
      _odswiez();
    }
  }

  /// Dołączenie danych z kopii zrobionej na drugim urządzeniu —
  /// synchronizacja przez dysk użytkownika, bez serwera (plan, pkt 2).
  Future<void> _dolaczDane() async {
    if (_pracuje) {
      return;
    }
    final plik = await _uslugi.zrodloPliku.wybierzKopie();
    if (plik == null) {
      return;
    }
    setState(() {
      _pracuje = true;
      _wynikKopii = null;
      _bladKopii = null;
    });
    final wynik = await _uslugi.scalanie.scal(plik.bajty);
    if (!mounted) {
      return;
    }
    setState(() {
      _pracuje = false;
      switch (wynik) {
        case ScalenieZrobione(:final raport):
          _wynikKopii = _opisScalenia(raport);
        case ScalenieOdrzucone(:final blad):
          _bladKopii = switch (blad) {
            BladKopii.nieNaszPlik => (
              tresc: 'To nie jest kopia z tej aplikacji.',
              coZrobic:
                  'Wybierz plik o nazwie zaczynającej się od '
                  '„moj-lan-kopia".',
            ),
            BladKopii.nowszaWersja => (
              tresc: 'Plik pochodzi z nowszej wersji aplikacji.',
              coZrobic: 'Zaktualizuj aplikację i spróbuj jeszcze raz.',
            ),
            BladKopii.saJuzDane => (
              tresc: 'Tego pliku nie da się dołączyć.',
              coZrobic: 'Zrób nową kopię na drugim urządzeniu.',
            ),
          };
      }
    });
    if (wynik is ScalenieZrobione) {
      _odswiez();
    }
  }

  /// Treść jest ta sama co w wyglądzie prostym — scalanie znaczy to samo.
  static String _opisScalenia(RaportScalenia raport) {
    if (!raport.cokolwiekSieZmienilo) {
      return 'Plik nie wnosi nic nowego — wszystko z niego już tu jest.';
    }
    final czesci = <String>[
      if (raport.zabiegiDodane > 0) '${raport.zabiegiDodane} zabiegów',
      if (raport.polaDodane > 0) '${raport.polaDodane} pól',
      if (raport.zwierzetaDodane > 0) '${raport.zwierzetaDodane} zwierząt',
    ];
    return [
      'Dołączono dane z drugiego urządzenia.',
      if (czesci.isNotEmpty) 'Doszło: ${czesci.join(', ')}.',
      if (raport.zastapioneRazem > 0)
        '${raport.zastapioneRazem} wpisów było w pliku nowszych — '
            'poprzednie wersje zostały w dzienniku zmian.',
      if (raport.pominieteRazem > 0)
        '${raport.pominieteRazem} wpisów z pliku było starszych — '
            'zostawiliśmy nowsze, a starsze zapisaliśmy w dzienniku.',
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: FutureBuilder<_Dane>(
        future: _dane,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dane = stan.data!;

          return ListView(
            padding: const EdgeInsets.all(MotywNowoczesny.odstep),
            children: [
              Text('Wygląd', style: teksty.titleLarge),
              const SizedBox(height: 8),
              for (final wyglad in Wyglad.values) ...[
                Karta(
                  onTap: () => _ustawWyglad(wyglad),
                  wyrozniona: wyglad == dane.wyglad,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wyglad.nazwa,
                              style: teksty.bodyLarge?.copyWith(
                                color: wyglad == dane.wyglad
                                    ? MotywNowoczesny.karta
                                    : null,
                              ),
                            ),
                            Text(
                              wyglad.opis,
                              style: teksty.bodyMedium?.copyWith(
                                color: wyglad == dane.wyglad
                                    ? MotywNowoczesny.karta
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (wyglad == dane.wyglad)
                        const Icon(
                          Icons.check,
                          color: MotywNowoczesny.karta,
                          size: 20,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: MotywNowoczesny.odstep),
              Text('Gospodarstwo', style: teksty.titleLarge),
              const SizedBox(height: 8),
              Karta(
                onTap: dane.biezace == null
                    ? null
                    : () => _popraw(dane.biezace!),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _uslugi.nazwaGospodarstwa,
                            style: teksty.bodyLarge,
                          ),
                          Text(
                            'Numer producenta: '
                            '${dane.biezace?.numerProducenta ?? 'brak'}',
                            style: teksty.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: MotywNowoczesny.tekstPomocniczy,
                    ),
                  ],
                ),
              ),
              if (dane.gospodarstwa.length > 1) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final gospodarstwo in dane.gospodarstwa)
                      Wybor(
                        etykieta: gospodarstwo.nazwa,
                        wybrany: gospodarstwo.id == _uslugi.gospodarstwoId,
                        onTap: () => _przelacz(gospodarstwo),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _dodajGospodarstwo,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Dodaj gospodarstwo'),
              ),
              const SizedBox(height: MotywNowoczesny.odstep),
              _Konto(konto: dane.konto, onZapisz: _zapiszKonto),
              const SizedBox(height: MotywNowoczesny.odstep),
              Text('Zwierzęta w gospodarstwie', style: teksty.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Ta wersja nie prowadzi rejestru stada, ale od zwierząt '
                'zależą obowiązki z programu azotanowego.',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (odpowiedz, etykieta) in const [
                    (OdpowiedzZwierzeta.tak, 'Mam zwierzęta'),
                    (OdpowiedzZwierzeta.nie, 'Nie mam zwierząt'),
                    (OdpowiedzZwierzeta.nieWiem, 'Nie wiem'),
                  ])
                    Wybor(
                      etykieta: etykieta,
                      wybrany: dane.zwierzeta == odpowiedz,
                      onTap: () => _ustawZwierzeta(odpowiedz),
                    ),
                ],
              ),
              const SizedBox(height: MotywNowoczesny.odstep),
              Text('Magazyn', style: teksty.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Ile środków i nawozów zostało. Zużycie dopisuje się samo '
                'przy wpisie zabiegu.',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: 8),
              Karta(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EkranMagazynNowoczesny(uslugi: _uslugi),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: MotywNowoczesny.tekstPomocniczy,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Otwórz magazyn', style: teksty.bodyLarge),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MotywNowoczesny.odstep),
              Text('Kopia danych', style: teksty.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Aplikacja trzyma dane tylko w tym telefonie. Kopia jest '
                'darmowa i zawsze będzie.',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: 8),
              if (_pracuje)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _zrobKopie,
                        child: const Text('Zrób kopię'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _wczytajKopie,
                        child: const Text('Wczytaj kopię'),
                      ),
                    ),
                  ],
                ),
              if (!_pracuje) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _dolaczDane,
                  icon: const Icon(Icons.merge_outlined, size: 20),
                  label: const Text('Dołącz dane z drugiego urządzenia'),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zrób kopię na jednym telefonie i dołącz ją na drugim. '
                  'Gdy ten sam wpis poprawiono po obu stronach, zostaje '
                  'nowszy — starszy jest widoczny w dzienniku zmian.',
                  style: teksty.bodyMedium,
                ),
              ],
              if (_wynikKopii != null) ...[
                const SizedBox(height: 8),
                Text(_wynikKopii!, style: teksty.bodyLarge),
              ],
              if (_bladKopii != null) ...[
                const SizedBox(height: 8),
                OstrzezenieNowoczesne(
                  tresc: _bladKopii!.tresc,
                  coZrobic: _bladKopii!.coZrobic,
                ),
              ],
              const SizedBox(height: MotywNowoczesny.odstep),
              Text('Słowniczek', style: teksty.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Co znaczą skróty z wniosku i pism z ARiMR: TUZ, GAEC, DJP.',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: 8),
              Karta(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EkranSlowniczekNowoczesny(uslugi: _uslugi),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_outlined,
                      size: 20,
                      color: MotywNowoczesny.tekstPomocniczy,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Otwórz słowniczek', style: teksty.bodyLarge),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MotywNowoczesny.odstep),
              // Numer wersji przyda się przy zgłaszaniu usterek w czasie
              // testów — inaczej nie wiadomo, którego pliku dotyczy uwaga.
              const WierszWersji(przed: 'Mój Łan • '),
            ],
          );
        },
      ),
    );
  }
}

class _Dane {
  const _Dane({
    required this.wyglad,
    required this.gospodarstwa,
    required this.biezace,
    required this.zwierzeta,
    required this.konto,
  });

  final Wyglad wyglad;
  final List<Gospodarstwo> gospodarstwa;
  final Gospodarstwo? biezace;
  final OdpowiedzZwierzeta zwierzeta;
  final Konto? konto;
}

/// Konto — imię i nazwisko albo nazwa firmy. Bez logowania i bez hasła;
/// nazwa zostaje w telefonie i trafia do kopii danych.
class _Konto extends StatefulWidget {
  const _Konto({required this.konto, required this.onZapisz});

  final Konto? konto;
  final Future<void> Function(String nazwa) onZapisz;

  @override
  State<_Konto> createState() => _KontoState();
}

class _KontoState extends State<_Konto> {
  late final TextEditingController _nazwa = TextEditingController(
    text: widget.konto?.nazwa ?? '',
  );

  @override
  void dispose() {
    _nazwa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Konto', style: teksty.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Twoje imię i nazwisko albo nazwa firmy. Nie ma logowania ani '
          'hasła — nazwa zostaje w telefonie i trafia do kopii danych.',
          style: teksty.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nazwa,
          style: teksty.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'np. Jan Kowalski',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => widget.onZapisz(_nazwa.text),
          child: const Text('Zapisz konto'),
        ),
      ],
    );
  }
}
