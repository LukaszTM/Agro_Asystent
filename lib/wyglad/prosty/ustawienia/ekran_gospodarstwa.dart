import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/ustawienia/gospodarstwa.dart';
import '../../../funkcje/ustawienia/wybor_wygladu.dart';
import '../../../funkcje/ustawienia/zwierzeta_w_gospodarstwie.dart';
import '../magazyn/ekran_magazyn.dart';
import '../../../rdzen/wspolne/wersja_programu.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_kopia.dart';

/// Gospodarstwo i konto (krok 10 etapu 1): dane na wydruki, przełączanie
/// między gospodarstwami i nazwa konta.
///
/// Dokumentacja bieżącego gospodarstwa jest darmowa zawsze. Premium otwiera
/// tylko *dodanie kolejnego* gospodarstwa — a gospodarstwa już założone
/// zostają w pełni dostępne, także gdy premium się skończy.
class EkranGospodarstwa extends StatefulWidget {
  const EkranGospodarstwa({
    super.key,
    required this.uslugi,
    this.onZmiana,
    this.onZmianaWygladu,
  });

  final Uslugi uslugi;

  /// Przełączenie gospodarstwa zmienia wszystkie ekrany, więc o nowym
  /// wyborze musi dowiedzieć się start aplikacji.
  final void Function(Uslugi noweUslugi)? onZmiana;

  /// Zmiana wyglądu przebudowuje całą aplikację — motyw jest nad ekranami.
  final void Function(Wyglad wyglad)? onZmianaWygladu;

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
      zwierzeta: await _uslugi.zwierzetaWGospodarstwie.odczytaj(),
      wyglad: await _uslugi.wyglad.odczytaj(),
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
    if (poprawione.id.isEmpty) {
      // Gospodarstwo usunięte — repozytorium już przełączyło na to, które
      // zostało; ekrany muszą dostać nowy zestaw usług.
      final zostale = await _uslugi.gospodarstwa.aktywne();
      if (zostale != null) {
        final nowe = _uslugi.dlaGospodarstwa(
          id: zostale.id,
          nazwa: zostale.nazwa,
        );
        widget.onZmiana?.call(nowe);
        _uslugi = nowe;
      }
      if (mounted) {
        setState(_odswiez);
      }
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

  Future<void> _zapiszZwierzeta(OdpowiedzZwierzeta odpowiedz) async {
    await _uslugi.zwierzetaWGospodarstwie.zapisz(odpowiedz);
    if (mounted) {
      setState(_odswiez);
    }
  }

  Future<void> _zapiszWyglad(Wyglad wyglad) async {
    await _uslugi.wyglad.zapisz(wyglad);
    if (mounted) {
      setState(_odswiez);
    }
    widget.onZmianaWygladu?.call(wyglad);
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
              const SizedBox(height: MotywProsty.odstep),
              // Numer wersji przyda się przy zgłaszaniu usterek w czasie
              // testów — inaczej nie wiadomo, którego pliku dotyczy uwaga.
              const WierszWersji(przed: 'Agro Asystent • '),
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
              _Zwierzeta(odpowiedz: dane.zwierzeta, onZmiana: _zapiszZwierzeta),
              const SizedBox(height: MotywProsty.odstep * 2),
              _WyborWygladuProsty(
                wybrany: dane.wyglad,
                onZmiana: _zapiszWyglad,
              ),
              const SizedBox(height: MotywProsty.odstep),
              DuzyPrzycisk(
                etykieta: 'Magazyn',
                opis: 'ile środków i nawozów zostało',
                ikona: Icons.inventory_2_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EkranMagazyn(uslugi: _uslugi),
                  ),
                ),
              ),
              const SizedBox(height: MotywProsty.odstep),
              DuzyPrzycisk(
                etykieta: 'Kopia danych',
                opis: 'zapisz wszystko do jednego pliku',
                ikona: Icons.save_outlined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EkranKopia(
                      uslugi: _uslugi,
                      onWczytano: () {
                        widget.onZmiana?.call(_uslugi);
                        if (mounted) {
                          setState(_odswiez);
                        }
                      },
                    ),
                  ),
                ),
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
    required this.zwierzeta,
    required this.wyglad,
  });

  final List<Gospodarstwo> lista;
  final Gospodarstwo? biezace;
  final Konto? konto;
  final bool moznaDodac;
  final OdpowiedzZwierzeta zwierzeta;
  final Wyglad wyglad;
}

/// Wybór wyglądu telefonu. Oba pokazują te same dane i te same dokumenty —
/// różni się tylko warstwa ekranów (plan, pkt 5).
class _WyborWygladuProsty extends StatelessWidget {
  const _WyborWygladuProsty({required this.wybrany, required this.onZmiana});

  final Wyglad wybrany;
  final Future<void> Function(Wyglad wyglad) onZmiana;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wygląd aplikacji', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Oba wyglądy mają te same wpisy, rejestry i wydruki. '
          'Zmienisz go kiedy chcesz.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        for (final wyglad in Wyglad.values) ...[
          DuzyPrzycisk(
            etykieta: wyglad.nazwa,
            opis: wyglad == wybrany
                ? '${wyglad.opis} • tak teraz wygląda'
                : wyglad.opis,
            ikona: wyglad == wybrany
                ? Icons.check_circle_outline
                : Icons.phone_android_outlined,
            wyrozniony: wyglad == wybrany,
            onTap: wyglad == wybrany ? null : () => onZmiana(wyglad),
          ),
          const SizedBox(height: MotywProsty.odstep),
        ],
      ],
    );
  }
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

  Future<void> _usun() async {
    final gospodarstwo = widget.gospodarstwo!;
    final potwierdzone = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Usunąć „${gospodarstwo.nazwa}"?'),
        content: Text(
          'Wpisy zostają w bazie, ale gospodarstwo zniknie z listy. '
          'Zrób najpierw kopię danych do pliku.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zostaw'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (!(potwierdzone ?? false)) {
      return;
    }

    final usuniete = await widget.uslugi.gospodarstwa.usun(
      gospodarstwoId: gospodarstwo.id,
    );
    if (!mounted) {
      return;
    }
    if (!usuniete) {
      setState(() {
        _blad = (
          tresc: 'To jedyne gospodarstwo w aplikacji.',
          coZrobic:
              'Nie można go usunąć — zostałbyś bez miejsca na dokumentację. '
              'Najpierw dodaj drugie.',
        );
      });
      return;
    }
    Navigator.of(context).pop(_usunieteGospodarstwo);
  }

  /// Zwracane po usunięciu — ekran listy pozna je po pustej nazwie.
  static const Gospodarstwo _usunieteGospodarstwo = Gospodarstwo(
    id: '',
    nazwa: '',
  );

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
          if (!_nowe) ...[
            const SizedBox(height: MotywProsty.odstep * 2),
            OutlinedButton(
              onPressed: _zapisuje ? null : _usun,
              child: const Text('Usuń gospodarstwo'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pytanie o zwierzęta gospodarskie.
///
/// Ta wersja aplikacji nie prowadzi rejestru stada — produkcja zwierzęca
/// jest ścieżką rozwoju (plan, pkt 2). Ale od liczby DJP zależą obowiązki
/// z programu azotanowego, więc nie wolno zakładać, że zwierząt nie ma:
/// dopóki rolnik nie odpowie, obowiązki od DJP są „do sprawdzenia".
class _Zwierzeta extends StatelessWidget {
  const _Zwierzeta({required this.odpowiedz, required this.onZmiana});

  final OdpowiedzZwierzeta odpowiedz;
  final void Function(OdpowiedzZwierzeta) onZmiana;

  static const Map<OdpowiedzZwierzeta, String> _etykiety = {
    OdpowiedzZwierzeta.nie: 'Nie mam zwierząt',
    OdpowiedzZwierzeta.tak: 'Mam zwierzęta',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zwierzęta gospodarskie',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Od liczby zwierząt zależy, czy musisz prowadzić ewidencję '
          'nawożenia. Ta wersja aplikacji nie prowadzi rejestru stada, '
          'więc pytamy raz.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final wpis in _etykiety.entries)
              ChoiceChip(
                label: Text(
                  wpis.value,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                selected: odpowiedz == wpis.key,
                onSelected: (_) => onZmiana(wpis.key),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (odpowiedz == OdpowiedzZwierzeta.nieWiem)
          const Ostrzezenie(
            tresc: 'Nie wiemy, czy masz zwierzęta.',
            coZrobic:
                'Odpowiedz powyżej — inaczej obowiązki zależne od liczby '
                'zwierząt zostają oznaczone jako do sprawdzenia.',
          )
        else if (odpowiedz == OdpowiedzZwierzeta.tak)
          const Ostrzezenie(
            tresc: 'Liczby DJP aplikacja nie policzy.',
            coZrobic:
                'Rejestr stada dojdzie w przyszłej wersji. Do tego czasu '
                'sprawdź u doradcy, czy przekraczasz 10 DJP — od tego '
                'zależy ewidencja nawożenia.',
          ),
      ],
    );
  }
}
