import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/ustawienia/gospodarstwa.dart';
import '../motyw.dart';
import '../widgety/karta.dart';

/// Dane gospodarstwa w wyglądzie nowoczesnym: nazwa i numer producenta,
/// dodanie kolejnego gospodarstwa i usunięcie.
///
/// Numeru producenta nie zgadujemy — puste pole wychodzi na wydruku jako
/// „brak" (CLAUDE.md, reguła 5).
class EkranDaneGospodarstwaNowoczesny extends StatefulWidget {
  const EkranDaneGospodarstwaNowoczesny({
    super.key,
    required this.uslugi,
    this.gospodarstwo,
  });

  final Uslugi uslugi;

  /// `null` znaczy „nowe gospodarstwo".
  final Gospodarstwo? gospodarstwo;

  @override
  State<EkranDaneGospodarstwaNowoczesny> createState() =>
      _EkranDaneGospodarstwaNowoczesnyState();
}

class _EkranDaneGospodarstwaNowoczesnyState
    extends State<EkranDaneGospodarstwaNowoczesny> {
  late final TextEditingController _nazwa = TextEditingController(
    text: widget.gospodarstwo?.nazwa ?? '',
  );
  late final TextEditingController _numer = TextEditingController(
    text: widget.gospodarstwo?.numerProducenta ?? '',
  );
  ({String tresc, String coZrobic})? _blad;
  bool _zapisuje = false;

  bool get _nowe => widget.gospodarstwo == null;

  /// Zwracane po usunięciu — ekran ustawień pozna je po pustym numerze.
  static const Gospodarstwo _usuniete = Gospodarstwo(id: '', nazwa: '');

  @override
  void dispose() {
    _nazwa.dispose();
    _numer.dispose();
    super.dispose();
  }

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
              'Nie można go usunąć — zostałbyś bez miejsca na '
              'dokumentację. Najpierw dodaj drugie.',
        );
      });
      return;
    }
    Navigator.of(context).pop(_usuniete);
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
                  'Gospodarstwo, które prowadzisz, działa dalej bez '
                  'opłaty — wpisy, rejestry, wydruk i eksport.',
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
    final teksty = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_nowe ? 'Nowe gospodarstwo' : 'Dane gospodarstwa'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MotywNowoczesny.odstep),
        children: [
          Text('Nazwa', style: teksty.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _nazwa,
            style: teksty.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'np. Gospodarstwo w Dąbrowie',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: MotywNowoczesny.odstep),
          Text('Numer producenta', style: teksty.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _numer,
            style: teksty.bodyLarge,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'z pisma z ARiMR',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jeśli nie masz go pod ręką, zostaw puste — na wydruku będzie '
            '„brak". Nie zgadujemy numeru.',
            style: teksty.bodyMedium,
          ),
          if (_blad case final ({String tresc, String coZrobic}) blad) ...[
            const SizedBox(height: MotywNowoczesny.odstep),
            OstrzezenieNowoczesne(tresc: blad.tresc, coZrobic: blad.coZrobic),
          ],
          const SizedBox(height: MotywNowoczesny.odstep),
          FilledButton(
            onPressed: _zapisuje ? null : _zapisz,
            child: Text(_nowe ? 'Dodaj gospodarstwo' : 'Zapisz dane'),
          ),
          if (!_nowe) ...[
            const SizedBox(height: MotywNowoczesny.odstep * 2),
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
