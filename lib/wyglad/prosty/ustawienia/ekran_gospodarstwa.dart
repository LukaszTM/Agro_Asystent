import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/ustawienia/gospodarstwa.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';

/// Gospodarstwo i konto (krok 10 etapu 1): dane na wydruki, przełączanie
/// między gospodarstwami i nazwa konta.
///
/// Dokumentacja bieżącego gospodarstwa jest darmowa zawsze. Premium otwiera
/// tylko *dodanie kolejnego* gospodarstwa — a gospodarstwa już założone
/// zostają w pełni dostępne, także gdy premium się skończy.
class EkranGospodarstwa extends StatefulWidget {
  const EkranGospodarstwa({super.key, required this.uslugi, this.onZmiana});

  final Uslugi uslugi;

  /// Przełączenie gospodarstwa zmienia wszystkie ekrany, więc o nowym
  /// wyborze musi dowiedzieć się start aplikacji.
  final void Function(Uslugi noweUslugi)? onZmiana;

  @override
  State<EkranGospodarstwa> createState() => _EkranGospodarstwaState();
}

class _EkranGospodarstwaState extends State<EkranGospodarstwa> {
  late Uslugi _uslugi;
  late Future<_Dane> _dane;

  @override
  void initState() {
    super.initState();
    _uslugi = widget.uslugi;
    _odswiez();
  }

  void _odswiez() {
    _dane = _policz();
  }

  Future<_Dane> _policz() async {
    final repozytorium = _uslugi.gospodarstwa;
    return _Dane(
      lista: await repozytorium.wszystkie(),
      biezace: await repozytorium.jedno(_uslugi.gospodarstwoId),
      konto: await repozytorium.konto(),
      moznaDodac: await repozytorium.czyMoznaDodac(),
    );
  }

  Future<void> _przelacz(Gospodarstwo gospodarstwo) async {
    await _uslugi.gospodarstwa.ustawAktywne(gospodarstwo.id);
    final nowe = _uslugi.dlaGospodarstwa(
      id: gospodarstwo.id,
      nazwa: gospodarstwo.nazwa,
    );
    widget.onZmiana?.call(nowe);
    if (mounted) {
      setState(() {
        _uslugi = nowe;
        _odswiez();
      });
    }
  }

  Future<void> _popraw(Gospodarstwo gospodarstwo) async {
    final poprawione = await Navigator.of(context).push<Gospodarstwo>(
      MaterialPageRoute<Gospodarstwo>(
        builder: (_) =>
            EkranDaneGospodarstwa(uslugi: _uslugi, gospodarstwo: gospodarstwo),
      ),
    );
    if (poprawione == null) {
      return;
    }
    if (poprawione.id == _uslugi.gospodarstwoId) {
      final nowe = _uslugi.dlaGospodarstwa(
        id: poprawione.id,
        nazwa: poprawione.nazwa,
      );
      widget.onZmiana?.call(nowe);
      _uslugi = nowe;
    }
    if (mounted) {
      setState(_odswiez);
    }
  }

  Future<void> _dodaj() async {
    final dodane = await Navigator.of(context).push<Gospodarstwo>(
      MaterialPageRoute<Gospodarstwo>(
        builder: (_) => EkranDaneGospodarstwa(uslugi: _uslugi),
      ),
    );
    if (dodane != null) {
      await _przelacz(dodane);
    }
  }

  Future<void> _zapiszKonto(String nazwa) async {
    await _uslugi.gospodarstwa.zapiszKonto(
      nazwa: nazwa,
      urzadzenie: _uslugi.urzadzenie,
    );
    if (mounted) {
      setState(_odswiez);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gospodarstwo')),
      body: FutureBuilder<_Dane>(
        future: _dane,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dane = stan.data!;
          final biezace = dane.biezace;

          return ListView(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            children: [
              Text(
                'Dane na wydruki',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (biezace != null)
                DuzyPrzycisk(
                  etykieta: biezace.nazwa,
                  opis: biezace.numerProducenta == null
                      ? 'numer producenta: brak • naciśnij, aby poprawić'
                      : 'numer producenta: ${biezace.numerProducenta}',
                  ikona: Icons.agriculture_outlined,
                  onTap: () => _popraw(biezace),
                ),
              const SizedBox(height: MotywProsty.odstep),
              Text(
                'Nazwa i numer producenta stoją na każdym wydruku dla ARiMR '
                'i inspekcji. Poprawisz je zawsze, bez żadnej opłaty.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (dane.lista.length > 1) ...[
                const SizedBox(height: MotywProsty.odstep),
                Text(
                  'Moje gospodarstwa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final gospodarstwo in dane.lista) ...[
                  DuzyPrzycisk(
                    etykieta: gospodarstwo.nazwa,
                    opis: gospodarstwo.id == _uslugi.gospodarstwoId
                        ? 'pracujesz tu teraz'
                        : 'naciśnij, aby przejść',
                    ikona: gospodarstwo.id == _uslugi.gospodarstwoId
                        ? Icons.check_circle_outline
                        : Icons.swap_horiz,
                    wyrozniony: gospodarstwo.id == _uslugi.gospodarstwoId,
                    onTap: gospodarstwo.id == _uslugi.gospodarstwoId
                        ? null
                        : () => _przelacz(gospodarstwo),
                  ),
                  const SizedBox(height: MotywProsty.odstep),
                ],
              ],
              const SizedBox(height: MotywProsty.odstep),
              if (dane.moznaDodac)
                DuzyPrzycisk(
                  etykieta: 'Dodaj gospodarstwo',
                  opis: 'osobne pola, zabiegi i dokumenty',
                  ikona: Icons.add_circle_outline,
                  onTap: _dodaj,
                )
              else
                const Ostrzezenie(
                  tresc:
                      'Kilka gospodarstw w jednej aplikacji to dodatek '
                      'premium.',
                  coZrobic:
                      'Gospodarstwo, które prowadzisz, działa w całości bez '
                      'opłaty — wpisy, rejestry, wydruk i eksport.',
                ),
              const SizedBox(height: MotywProsty.odstep * 2),
              _Konto(konto: dane.konto, onZapisz: _zapiszKonto),
            ],
          );
        },
      ),
    );
  }
}

class _Dane {
  const _Dane({
    required this.lista,
    required this.biezace,
    required this.konto,
    required this.moznaDodac,
  });

  final List<Gospodarstwo> lista;
  final Gospodarstwo? biezace;
  final Konto? konto;
  final bool moznaDodac;
}

/// Nazwa konta — po nic więcej nie służy. Aplikacja nie ma serwera i nie
/// wymaga logowania; nazwa przyda się przy kopii i synchronizacji, żeby
/// wiedzieć, czyje dane są w paczce.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Konto', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Twoje imię i nazwisko albo nazwa firmy. Nie ma logowania ani '
          'hasła — nazwa zostaje w telefonie i trafia do kopii danych.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nazwa,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'np. Jan Kowalski',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: MotywProsty.odstep),
        FilledButton(
          onPressed: () => widget.onZapisz(_nazwa.text),
          child: const Text('Zapisz konto'),
        ),
      ],
    );
  }
}

/// Dane jednego gospodarstwa: nazwa, numer producenta. Ten sam ekran służy
/// do poprawy istniejącego i do założenia nowego.
class EkranDaneGospodarstwa extends StatefulWidget {
  const EkranDaneGospodarstwa({
    super.key,
    required this.uslugi,
    this.gospodarstwo,
  });

  final Uslugi uslugi;

  /// `null` znaczy „nowe gospodarstwo".
  final Gospodarstwo? gospodarstwo;

  @override
  State<EkranDaneGospodarstwa> createState() => _EkranDaneGospodarstwaState();
}

class _EkranDaneGospodarstwaState extends State<EkranDaneGospodarstwa> {
  late final TextEditingController _nazwa = TextEditingController(
    text: widget.gospodarstwo?.nazwa ?? '',
  );
  late final TextEditingController _numer = TextEditingController(
    text: widget.gospodarstwo?.numerProducenta ?? '',
  );
  ({String tresc, String coZrobic})? _blad;
  bool _zapisuje = false;

  bool get _nowe => widget.gospodarstwo == null;

  @override
  void dispose() {
    _nazwa.dispose();
    _numer.dispose();
    super.dispose();
  }

  Future<void> _zapisz() async {
    if (_zapisuje) {
      return;
    }
    setState(() {
      _zapisuje = true;
      _blad = null;
    });

    final nazwa = _nazwa.text.trim();
    final numer = _numer.text.trim();

    if (_nowe) {
      final wynik = await widget.uslugi.gospodarstwa.dodaj(
        nazwa: nazwa,
        numerProducenta: numer,
        urzadzenie: widget.uslugi.urzadzenie,
      );
      if (!mounted) {
        return;
      }
      switch (wynik.wynik) {
        case WynikDodania.dodane:
          Navigator.of(context).pop(
            Gospodarstwo(
              id: wynik.id!,
              nazwa: nazwa,
              numerProducenta: numer.isEmpty ? null : numer,
            ),
          );
        case WynikDodania.brakNazwy:
          setState(() {
            _zapisuje = false;
            _blad = (
              tresc: 'Gospodarstwo nie ma nazwy.',
              coZrobic: 'Wpisz nazwę — będzie na wydrukach.',
            );
          });
        case WynikDodania.potrzebnePremium:
          setState(() {
            _zapisuje = false;
            _blad = (
              tresc: 'Kolejne gospodarstwo to dodatek premium.',
              coZrobic:
                  'Gospodarstwo, które prowadzisz, działa dalej bez opłaty '
                  '— wpisy, rejestry, wydruk i eksport.',
            );
          });
      }
      return;
    }

    if (nazwa.isEmpty) {
      setState(() {
        _zapisuje = false;
        _blad = (
          tresc: 'Gospodarstwo nie ma nazwy.',
          coZrobic: 'Wpisz nazwę — będzie na wydrukach.',
        );
      });
      return;
    }

    await widget.uslugi.gospodarstwa.popraw(
      gospodarstwoId: widget.gospodarstwo!.id,
      nazwa: nazwa,
      numerProducenta: numer,
    );
    if (mounted) {
      Navigator.of(context).pop(
        Gospodarstwo(
          id: widget.gospodarstwo!.id,
          nazwa: nazwa,
          numerProducenta: numer.isEmpty ? null : numer,
          powierzchniaUrHa: widget.gospodarstwo!.powierzchniaUrHa,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_nowe ? 'Nowe gospodarstwo' : 'Dane gospodarstwa'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          Text('Nazwa', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _nazwa,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'np. Gospodarstwo w Dąbrowie',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text(
            'Numer producenta',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _numer,
            style: Theme.of(context).textTheme.bodyLarge,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'z pisma z ARiMR',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jeśli nie masz go pod ręką, zostaw puste — na wydruku będzie '
            '„brak". Nie zgadujemy numeru.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_blad != null) ...[
            const SizedBox(height: MotywProsty.odstep),
            Ostrzezenie(tresc: _blad!.tresc, coZrobic: _blad!.coZrobic),
          ],
          const SizedBox(height: MotywProsty.odstep),
          FilledButton(
            onPressed: _zapisuje ? null : _zapisz,
            child: Text(_nowe ? 'Dodaj gospodarstwo' : 'Zapisz dane'),
          ),
        ],
      ),
    );
  }
}
