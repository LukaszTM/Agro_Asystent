import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/ustawienia/gospodarstwa.dart';
import '../../../funkcje/ustawienia/wybor_wygladu.dart';
import '../../../funkcje/ustawienia/zwierzeta_w_gospodarstwie.dart';
import '../../../rdzen/uslugi/kopia/kopia_danych.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';

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
                  '„agro-asystent-kopia".',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_uslugi.nazwaGospodarstwa, style: teksty.bodyLarge),
                    Text(
                      'Numer producenta: '
                      '${dane.biezace?.numerProducenta ?? 'brak'}',
                      style: teksty.bodyMedium,
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
  });

  final Wyglad wyglad;
  final List<Gospodarstwo> gospodarstwa;
  final Gospodarstwo? biezace;
  final OdpowiedzZwierzeta zwierzeta;
}
