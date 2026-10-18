import 'package:flutter/material.dart';

import '../../app/uslugi.dart';
import '../../funkcje/ustawienia/rozmiar_tekstu.dart';
import '../../rdzen/marka/marka.dart';
import 'motyw.dart';
import 'widoki/widok_dokumenty.dart';
import 'widoki/widok_magazyn.dart';
import 'widoki/widok_pola.dart';
import 'widoki/widok_pulpit.dart';
import 'widoki/widok_rejestr.dart';
import 'widoki/widok_terminy.dart';
import 'widoki/widok_ustawienia.dart';
import 'widoki/widok_warunkowosc.dart';

/// Zakładka programu na komputer.
enum ZakladkaKomputer {
  pulpit('Pulpit', Icons.dashboard_outlined),
  pola('Pola', Icons.map_outlined),
  rejestr('Rejestr zabiegów', Icons.list_alt_outlined),
  terminy('Terminy', Icons.event_outlined),
  warunkowosc('Warunkowość', Icons.rule_outlined),
  dokumenty('Dokumenty', Icons.description_outlined),
  magazyn('Magazyn', Icons.inventory_2_outlined),
  ustawienia('Ustawienia', Icons.settings_outlined);

  const ZakladkaKomputer(this.nazwa, this.ikona);

  final String nazwa;
  final IconData ikona;
}

/// Program na komputer: jeden wygląd dla wszystkich, z ustawieniem
/// wielkości tekstu (plan, pkt 5).
///
/// Układ jest myszowy: stała nawigacja po lewej (bez ukrytego menu, tak jak
/// na telefonie) i szeroki obszar treści z tabelami. Dane, reguły
/// i dokumenty są te same co na telefonie — tu zmienia się tylko warstwa
/// ekranów.
class EkranGlownyKomputer extends StatefulWidget {
  const EkranGlownyKomputer({
    super.key,
    required this.uslugi,
    this.teraz,
    this.onZmianaGospodarstwa,
    this.onZmianaRozmiaruTekstu,
    this.zakladkaNaStart = ZakladkaKomputer.pulpit,
  });

  final Uslugi uslugi;

  /// Dzień, od którego liczymy terminy i sezon. W programie „dzisiaj".
  final DateTime? teraz;

  final void Function(Uslugi noweUslugi)? onZmianaGospodarstwa;

  /// Zmiana wielkości tekstu przebudowuje motyw całego programu.
  final void Function(RozmiarTekstu rozmiar)? onZmianaRozmiaruTekstu;

  final ZakladkaKomputer zakladkaNaStart;

  @override
  State<EkranGlownyKomputer> createState() => _EkranGlownyKomputerState();
}

class _EkranGlownyKomputerState extends State<EkranGlownyKomputer> {
  late ZakladkaKomputer _zakladka = widget.zakladkaNaStart;

  /// Rośnie po każdym zapisie — widoki czytają wtedy dane od nowa.
  int _odswiezenie = 0;

  Uslugi get _uslugi => widget.uslugi;

  void _przelacz(ZakladkaKomputer zakladka) {
    setState(() {
      _zakladka = zakladka;
      _odswiezenie++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, wymiary) {
            final pelnyUklad =
                wymiary.maxWidth >= MotywKomputer.szerokoscPelnegoUkladu;
            return Row(
              children: [
                _Nawigacja(
                  wybrana: _zakladka,
                  zNazwami: pelnyUklad,
                  nazwaGospodarstwa: _uslugi.nazwaGospodarstwa,
                  onWybor: _przelacz,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(MotywKomputer.odstep * 1.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _zakladka.nazwa,
                                style: teksty.displayLarge,
                              ),
                            ),
                            Text(
                              _uslugi.nazwaGospodarstwa,
                              style: teksty.bodyLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: MotywKomputer.odstep),
                        Expanded(child: _widok()),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Przejście z pulpitu do pełnej zakładki.
  void _przelaczPoNazwie(String nazwa) {
    for (final zakladka in ZakladkaKomputer.values) {
      if (zakladka.name == nazwa) {
        _przelacz(zakladka);
        return;
      }
    }
  }

  Widget _widok() => switch (_zakladka) {
    // Klucz z licznikiem przebudowuje widok po powrocie na zakładkę —
    // dane czyta wtedy od nowa. Widok, który sam coś zapisał, odświeża się
    // u siebie; przebudowa z zewnątrz zgubiłaby mu wybrane pole.
    ZakladkaKomputer.pulpit => WidokPulpitKomputer(
      key: ValueKey('pulpit-$_odswiezenie'),
      uslugi: _uslugi,
      teraz: widget.teraz,
      onPelnyWidok: _przelaczPoNazwie,
    ),
    ZakladkaKomputer.pola => WidokPolaKomputer(
      key: ValueKey('pola-$_odswiezenie'),
      uslugi: _uslugi,
      teraz: widget.teraz,
    ),
    ZakladkaKomputer.rejestr => WidokRejestrKomputer(
      key: ValueKey('rejestr-$_odswiezenie'),
      uslugi: _uslugi,
      teraz: widget.teraz,
    ),
    ZakladkaKomputer.terminy => WidokTerminyKomputer(
      key: ValueKey('terminy-$_odswiezenie'),
      uslugi: _uslugi,
      teraz: widget.teraz,
    ),
    ZakladkaKomputer.warunkowosc => WidokWarunkowoscKomputer(
      key: ValueKey('warunkowosc-$_odswiezenie'),
      uslugi: _uslugi,
      teraz: widget.teraz,
    ),
    ZakladkaKomputer.dokumenty => WidokDokumentyKomputer(
      key: ValueKey('dokumenty-$_odswiezenie'),
      uslugi: _uslugi,
      teraz: widget.teraz,
    ),
    ZakladkaKomputer.magazyn => WidokMagazynKomputer(
      key: ValueKey('magazyn-$_odswiezenie'),
      uslugi: _uslugi,
      teraz: widget.teraz,
    ),
    ZakladkaKomputer.ustawienia => WidokUstawieniaKomputer(
      key: ValueKey('ustawienia-$_odswiezenie'),
      uslugi: _uslugi,
      onZmianaGospodarstwa: widget.onZmianaGospodarstwa,
      onZmianaRozmiaruTekstu: widget.onZmianaRozmiaruTekstu,
    ),
  };
}

/// Stała nawigacja po lewej. Bez ukrytego menu — wszystkie zakładki widać
/// naraz, tak jak cztery kafelki na telefonie.
class _Nawigacja extends StatelessWidget {
  const _Nawigacja({
    required this.wybrana,
    required this.zNazwami,
    required this.nazwaGospodarstwa,
    required this.onWybor,
  });

  final ZakladkaKomputer wybrana;

  /// Na wąskim oknie zostają same ikony z podpowiedzią.
  final bool zNazwami;

  final String nazwaGospodarstwa;
  final void Function(ZakladkaKomputer zakladka) onWybor;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Container(
      width: zNazwami ? MotywKomputer.szerokoscNawigacji : 72,
      color: MotywKomputer.karta,
      padding: const EdgeInsets.symmetric(vertical: MotywKomputer.odstep),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MotywKomputer.odstep,
            ),
            child: Row(
              children: [
                Image.asset(
                  Marka.logo,
                  height: 32,
                  // Logo jest znakiem programu, nie treścią ekranu.
                  excludeFromSemantics: true,
                ),
                if (zNazwami) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      Marka.nazwa,
                      overflow: TextOverflow.ellipsis,
                      style: teksty.titleLarge,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: MotywKomputer.odstep),
          for (final zakladka in ZakladkaKomputer.values)
            _PrzyciskZakladki(
              zakladka: zakladka,
              wybrana: zakladka == wybrana,
              zNazwa: zNazwami,
              onKlik: () => onWybor(zakladka),
            ),
          const Spacer(),
          if (zNazwami)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MotywKomputer.odstep,
              ),
              child: Text(
                'Dane leżą na tym komputerze. Program działa bez '
                'internetu.',
                style: teksty.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _PrzyciskZakladki extends StatelessWidget {
  const _PrzyciskZakladki({
    required this.zakladka,
    required this.wybrana,
    required this.zNazwa,
    required this.onKlik,
  });

  final ZakladkaKomputer zakladka;
  final bool wybrana;
  final bool zNazwa;
  final VoidCallback onKlik;

  @override
  Widget build(BuildContext context) {
    final kolor = wybrana ? MotywKomputer.zielen : MotywKomputer.tekst;
    return Semantics(
      button: true,
      selected: wybrana,
      label: zakladka.nazwa,
      child: Material(
        color: wybrana ? MotywKomputer.powierzchniaDruga : MotywKomputer.karta,
        child: InkWell(
          onTap: onKlik,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: MotywKomputer.minCelKlikniecia,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: MotywKomputer.odstep,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(zakladka.ikona, size: 20, color: kolor),
                if (zNazwa) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      zakladka.nazwa,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: kolor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
