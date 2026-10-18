import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/ustawienia/gospodarstwa.dart';
import '../../../funkcje/ustawienia/rozmiar_tekstu.dart';
import '../../../funkcje/ustawienia/zwierzeta_w_gospodarstwie.dart';
import '../../../rdzen/uslugi/kopia/kopia_danych.dart';
import '../../../rdzen/wspolne/slowniczek_pojec.dart';
import '../../../rdzen/wspolne/wersja_programu.dart';
import '../../../rdzen/uslugi/kopia/scalanie.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import 'okno_gospodarstwa.dart';

/// Ustawienia programu na komputer: wielkość tekstu, dane gospodarstwa
/// i kopia danych.
///
/// Wielkość tekstu jest tu najważniejsza — program ma jeden wygląd dla
/// wszystkich, a monitory stoją różnie (plan, pkt 5).
class WidokUstawieniaKomputer extends StatefulWidget {
  const WidokUstawieniaKomputer({
    super.key,
    required this.uslugi,
    this.onZmianaGospodarstwa,
    this.onZmianaRozmiaruTekstu,
  });

  final Uslugi uslugi;
  final void Function(Uslugi noweUslugi)? onZmianaGospodarstwa;
  final void Function(RozmiarTekstu rozmiar)? onZmianaRozmiaruTekstu;

  @override
  State<WidokUstawieniaKomputer> createState() =>
      _WidokUstawieniaKomputerState();
}

class _WidokUstawieniaKomputerState extends State<WidokUstawieniaKomputer> {
  late Future<_Dane> _dane;
  bool _pracuje = false;
  String? _wynik;
  ({String tresc, String coZrobic})? _blad;

  Uslugi get _uslugi => widget.uslugi;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _dane = _wczytaj();
  }

  Future<_Dane> _wczytaj() async => _Dane(
    gospodarstwo: await _uslugi.gospodarstwa.jedno(_uslugi.gospodarstwoId),
    rozmiar: await _uslugi.rozmiarTekstu.odczytaj(),
    zwierzeta: await _uslugi.zwierzetaWGospodarstwie.odczytaj(),
    moznaDodac: await _uslugi.gospodarstwa.czyMoznaDodac(),
  );

  /// Poprawa danych gospodarstwa albo założenie kolejnego.
  Future<void> _daneGospodarstwa(
    Gospodarstwo? gospodarstwo, {
    bool nowe = false,
  }) async {
    final zapisane = await showDialog<ZapisaneGospodarstwo>(
      context: context,
      builder: (_) => OknoGospodarstwa(
        uslugi: _uslugi,
        gospodarstwo: gospodarstwo,
        nowe: nowe,
      ),
    );
    if (zapisane == null || !mounted) {
      return;
    }
    setState(_odswiez);
    // Nazwa stoi w nagłówku programu i na każdym wydruku, więc reszta
    // programu musi zobaczyć ją od razu.
    widget.onZmianaGospodarstwa?.call(
      _uslugi.dlaGospodarstwa(id: zapisane.id, nazwa: zapisane.nazwa),
    );
  }

  Future<void> _ustawRozmiar(RozmiarTekstu rozmiar) async {
    await _uslugi.rozmiarTekstu.zapisz(rozmiar);
    if (!mounted) {
      return;
    }
    setState(_odswiez);
    widget.onZmianaRozmiaruTekstu?.call(rozmiar);
  }

  Future<void> _zrobKopie() async {
    if (_pracuje) {
      return;
    }
    setState(() {
      _pracuje = true;
      _wynik = null;
      _blad = null;
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
          () => _wynik =
              'Kopia gotowa: ${KopiaDanych.nazwaPliku(teraz)}. Zapisz ją '
              'tam, gdzie znajdziesz po awarii komputera.',
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _blad = (
            tresc: 'Nie udało się zapisać kopii.',
            coZrobic: 'Sprawdź miejsce na dysku i spróbuj jeszcze raz.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pracuje = false);
      }
    }
  }

  /// Dołączenie danych z telefonu: ten sam plik kopii, to samo scalanie
  /// („nowszy wpis wygrywa, starszy zostaje w dzienniku zmian").
  Future<void> _dolaczZTelefonu() async {
    if (_pracuje) {
      return;
    }
    final plik = await _uslugi.zrodloPliku.wybierzKopie();
    if (plik == null) {
      return;
    }
    setState(() {
      _pracuje = true;
      _wynik = null;
      _blad = null;
    });
    final wynik = await _uslugi.scalanie.scal(plik.bajty);
    if (!mounted) {
      return;
    }
    setState(() {
      _pracuje = false;
      switch (wynik) {
        case ScalenieZrobione(:final raport):
          _wynik = _opisScalenia(raport);
          _odswiez();
        case ScalenieOdrzucone(:final blad):
          _blad = switch (blad) {
            BladKopii.nieNaszPlik => (
              tresc: 'To nie jest kopia z tej aplikacji.',
              coZrobic:
                  'Wybierz plik o nazwie zaczynającej się od '
                  '„agro-asystent-kopia".',
            ),
            BladKopii.nowszaWersja => (
              tresc: 'Plik pochodzi z nowszej wersji aplikacji.',
              coZrobic: 'Zaktualizuj program i spróbuj jeszcze raz.',
            ),
            // Scalanie radzi sobie z danymi po obu stronach, więc ten
            // błąd tu nie wypada — zostaje dla kompletności.
            BladKopii.saJuzDane => (
              tresc: 'Nie udało się dołączyć pliku.',
              coZrobic: 'Zrób nową kopię na telefonie i spróbuj z nią.',
            ),
          };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return FutureBuilder<_Dane>(
      future: _dane,
      builder: (context, stan) {
        if (!stan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final dane = stan.data!;
        return ListView(
          children: [
            const NaglowekWidoku(
              tytul: 'Ustawienia programu',
              opis:
                  'Program na komputer ma jeden wygląd dla wszystkich — '
                  'dobierasz tylko wielkość tekstu.',
            ),
            const SizedBox(height: MotywKomputer.odstep),
            KartaKomputer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wielkość tekstu', style: teksty.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Zmiana działa od razu, w całym programie.',
                    style: teksty.bodyMedium,
                  ),
                  const SizedBox(height: MotywKomputer.odstep),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final rozmiar in RozmiarTekstu.values)
                        rozmiar == dane.rozmiar
                            ? FilledButton(
                                onPressed: () => _ustawRozmiar(rozmiar),
                                child: Text(rozmiar.nazwa),
                              )
                            : OutlinedButton(
                                onPressed: () => _ustawRozmiar(rozmiar),
                                child: Text(rozmiar.nazwa),
                              ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(dane.rozmiar.opis, style: teksty.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: MotywKomputer.odstep),
            KartaKomputer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gospodarstwo', style: teksty.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    dane.gospodarstwo?.nazwa ?? _uslugi.nazwaGospodarstwa,
                    style: teksty.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Właściciel: '
                    '${dane.gospodarstwo?.wlasciciel ?? 'nie podano'} • '
                    'numer producenta: '
                    '${dane.gospodarstwo?.numerProducenta ?? 'brak'} • '
                    'użytki rolne: ${_powierzchnia(dane.gospodarstwo)} • '
                    'zwierzęta: ${_zwierzeta(dane.zwierzeta)}',
                    style: teksty.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Te dane stoją na każdym wydruku i od nich zależy, '
                    'które obowiązki aplikacja włącza.',
                    style: teksty.bodyMedium,
                  ),
                  const SizedBox(height: MotywKomputer.odstep),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _daneGospodarstwa(dane.gospodarstwo),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: const Text('Popraw dane gospodarstwa'),
                      ),
                      if (dane.moznaDodac)
                        OutlinedButton.icon(
                          onPressed: () => _daneGospodarstwa(null, nowe: true),
                          icon: const Icon(Icons.add_home_outlined, size: 20),
                          label: const Text('Dodaj gospodarstwo'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MotywKomputer.odstep),
            KartaKomputer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kopia i dane z telefonu', style: teksty.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Program trzyma dane na tym komputerze. Kopia jest '
                    'darmowa i zawsze będzie; dołączenie pliku z telefonu '
                    'nic nie usuwa — nowszy wpis wygrywa, a starszy zostaje '
                    'w dzienniku zmian.',
                    style: teksty.bodyMedium,
                  ),
                  const SizedBox(height: MotywKomputer.odstep),
                  if (_pracuje)
                    const Center(child: CircularProgressIndicator())
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _zrobKopie,
                          icon: const Icon(Icons.save_outlined, size: 20),
                          label: const Text('Zrób kopię'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _dolaczZTelefonu,
                          icon: const Icon(Icons.phonelink_outlined, size: 20),
                          label: const Text('Dołącz dane z telefonu'),
                        ),
                      ],
                    ),
                  if (_wynik case final String tekst) ...[
                    const SizedBox(height: MotywKomputer.odstep),
                    Text(tekst, style: teksty.bodyLarge),
                  ],
                  if (_blad
                      case final ({String tresc, String coZrobic}) blad) ...[
                    const SizedBox(height: MotywKomputer.odstep),
                    OstrzezenieKomputer(
                      tresc: blad.tresc,
                      coZrobic: blad.coZrobic,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MotywKomputer.odstep),
            KartaKomputer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Słowniczek pojęć', style: teksty.titleLarge),
                  const SizedBox(height: 4),
                  ListaSlowniczka(slownik: _uslugi.slowniczek),
                ],
              ),
            ),
            const SizedBox(height: MotywKomputer.odstep),
            KartaKomputer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('O programie', style: teksty.titleLarge),
                  const SizedBox(height: 4),
                  const WierszWersji(przed: 'Agro Asystent • '),
                  Text(
                    'Urządzenie: ${_uslugi.urzadzenie} • słownik reguł '
                    '${_uslugi.reguly.wersja} (obowiązuje od '
                    '${_uslugi.reguly.obowiazujeOd.year}-'
                    '${_uslugi.reguly.obowiazujeOd.month.toString().padLeft(2, '0')}-'
                    '${_uslugi.reguly.obowiazujeOd.day.toString().padLeft(2, '0')})',
                    style: teksty.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Zestawienie nie jest poradą prawną. Progi i terminy '
                    'pochodzą ze słownika reguł, nie z kodu programu.',
                    style: teksty.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _powierzchnia(Gospodarstwo? gospodarstwo) {
    final hektary = gospodarstwo?.powierzchniaUrHa ?? 0;
    return hektary <= 0
        ? 'nie podano'
        : '${hektary.toStringAsFixed(2).replaceAll('.', ',')} ha';
  }

  static String _zwierzeta(OdpowiedzZwierzeta odpowiedz) => switch (odpowiedz) {
    OdpowiedzZwierzeta.tak => 'są',
    OdpowiedzZwierzeta.nie => 'nie ma',
    OdpowiedzZwierzeta.nieWiem => 'bez odpowiedzi',
  };

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
      'Dołączono dane z telefonu.',
      if (czesci.isNotEmpty) 'Doszło: ${czesci.join(', ')}.',
      if (raport.zastapioneRazem > 0)
        '${raport.zastapioneRazem} wpisów z pliku było nowszych — '
            'poprzednie wersje zostały w dzienniku zmian.',
      if (raport.pominieteRazem > 0)
        '${raport.pominieteRazem} wpisów z pliku było starszych — '
            'zostawiliśmy nowsze, a starsze zapisaliśmy w dzienniku.',
    ].join(' ');
  }
}

class _Dane {
  const _Dane({
    required this.gospodarstwo,
    required this.rozmiar,
    required this.zwierzeta,
    required this.moznaDodac,
  });

  final Gospodarstwo? gospodarstwo;
  final RozmiarTekstu rozmiar;
  final OdpowiedzZwierzeta zwierzeta;

  /// Czy wolno założyć kolejne gospodarstwo (drugie to dodatek płatny).
  final bool moznaDodac;
}
