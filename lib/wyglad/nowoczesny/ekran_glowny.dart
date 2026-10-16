import 'package:flutter/material.dart';

import '../../app/uslugi.dart';
import '../../funkcje/dzialki/repozytorium_pol.dart';
import '../../funkcje/ustawienia/wybor_wygladu.dart';
import '../../rdzen/marka/marka.dart';
import 'dokumenty/widok_dokumenty.dart';
import 'motyw.dart';
import 'pola/widok_pola.dart';
import 'nawozenie/ekran_nawozenie.dart';
import 'rejestr/ekran_rejestr.dart';
import 'start/widok_start.dart';
import 'terminy/widok_terminy.dart';
import 'ustawienia/ekran_ustawienia.dart';
import 'widgety/pasek_nawigacji.dart';
import 'wpis/ekran_wpis.dart';

/// Ekran główny wyglądu „Nowoczesny": cztery zakładki i dolny pasek
/// nawigacji z przyciskiem „+" (plan, pkt 5).
///
/// Zakładki pokazują te same dane co wygląd prosty — liczy je
/// `lib/funkcje/`, nie ekrany.
class EkranGlownyNowoczesny extends StatefulWidget {
  const EkranGlownyNowoczesny({
    super.key,
    required this.uslugi,
    this.onZmianaGospodarstwa,
    this.onZmianaWygladu,
    this.teraz,
  });

  final Uslugi uslugi;

  final void Function(Uslugi noweUslugi)? onZmianaGospodarstwa;
  final void Function(Wyglad wyglad)? onZmianaWygladu;

  /// Dzień, od którego liczymy terminy; w aplikacji „dzisiaj".
  final DateTime? teraz;

  @override
  State<EkranGlownyNowoczesny> createState() => _EkranGlownyNowoczesnyState();
}

class _EkranGlownyNowoczesnyState extends State<EkranGlownyNowoczesny> {
  int _zakladka = 0;

  /// Rośnie po każdym zapisie — zakładki czytają wtedy dane od nowa.
  /// Bez tego podsumowanie sezonu pokazywałoby stan z chwili otwarcia.
  int _odswiezenie = 0;

  static const List<ZakladkaPaska> _zakladki = [
    ZakladkaPaska(etykieta: 'Start', ikona: Icons.home_outlined),
    ZakladkaPaska(etykieta: 'Pola', ikona: Icons.map_outlined),
    ZakladkaPaska(etykieta: 'Terminy', ikona: Icons.event_outlined),
    ZakladkaPaska(etykieta: 'Dokumenty', ikona: Icons.description_outlined),
  ];

  static const List<String> _tytuly = [
    Marka.nazwa,
    'Pola',
    'Terminy',
    'Dokumenty',
  ];

  Future<void> _dodajZabieg({Pole? pole}) async {
    final zapisano = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranWpisu(
          uslugi: widget.uslugi,
          poleNaStart: pole,
          teraz: widget.teraz,
        ),
      ),
    );
    if ((zapisano ?? false) && mounted) {
      setState(() {
        _odswiezenie++;
        _zakladka = 0;
      });
    }
  }

  /// Rejestr wpisów: podgląd, poprawka i cofnięcie. Po zmianie zakładki
  /// muszą przeliczyć dane — podsumowanie sezonu też się zmienia.
  Future<void> _rejestr() async {
    final zmienione = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            EkranRejestrNowoczesny(uslugi: widget.uslugi, teraz: widget.teraz),
      ),
    );
    if ((zmienione ?? false) && mounted) {
      setState(() => _odswiezenie++);
    }
  }

  Future<void> _nawozenie() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EkranNawozenieNowoczesny(uslugi: widget.uslugi),
      ),
    );
    if (mounted) {
      setState(() => _odswiezenie++);
    }
  }

  Future<void> _ustawienia() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EkranUstawienia(
          uslugi: widget.uslugi,
          onZmianaWygladu: widget.onZmianaWygladu,
          onZmianaGospodarstwa: widget.onZmianaGospodarstwa,
        ),
      ),
    );
    if (mounted) {
      setState(() => _odswiezenie++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: MotywNowoczesny.odstep,
        title: Row(
          children: [
            if (_zakladka == 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Image.asset(
                  Marka.logo,
                  height: 28,
                  // Logo jest znakiem aplikacji, nie treścią ekranu.
                  excludeFromSemantics: true,
                ),
              ),
            // Nazwa musi zmieścić się obok logo i przycisku ustawień —
            // na wąskim telefonie pasek nie może się rozjechać.
            Flexible(
              child: Text(_tytuly[_zakladka], overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ustawienia',
            onPressed: _ustawienia,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _zakladka,
          children: [
            WidokStart(
              key: ValueKey('start-$_odswiezenie'),
              uslugi: widget.uslugi,
              teraz: widget.teraz,
              onTerminy: () => setState(() => _zakladka = 2),
              onDokumenty: () => setState(() => _zakladka = 3),
              onRejestr: _rejestr,
              onNawozenie: _nawozenie,
            ),
            WidokPola(
              key: ValueKey('pola-$_odswiezenie'),
              uslugi: widget.uslugi,
              onZabiegNaPolu: (pole) => _dodajZabieg(pole: pole),
            ),
            WidokTerminy(
              key: ValueKey('terminy-$_odswiezenie'),
              uslugi: widget.uslugi,
              teraz: widget.teraz,
            ),
            WidokDokumenty(
              key: ValueKey('dokumenty-$_odswiezenie'),
              uslugi: widget.uslugi,
              onRejestr: _rejestr,
            ),
          ],
        ),
      ),
      bottomNavigationBar: PasekNawigacji(
        zakladki: _zakladki,
        wybrana: _zakladka,
        onZakladka: (numer) => setState(() => _zakladka = numer),
        onDodaj: _dodajZabieg,
      ),
    );
  }
}
