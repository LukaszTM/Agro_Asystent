import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/ustawienia/gospodarstwa.dart';
import '../../../funkcje/ustawienia/zwierzeta_w_gospodarstwie.dart';
import '../motyw.dart';
import '../widgety/karta.dart';

/// Co okno oddaje po zapisaniu — nazwa bywa inna niż przed zmianą, a stoi
/// w nagłówku programu i na każdym wydruku.
class ZapisaneGospodarstwo {
  const ZapisaneGospodarstwo({required this.id, required this.nazwa});

  final String id;
  final String nazwa;
}

/// Dane gospodarstwa: nazwa, numer producenta, powierzchnia użytków
/// i odpowiedź o zwierzętach.
///
/// Przy komputerze wypełnia się to raz, z klawiatury i z dokumentów
/// leżących obok — dlatego cały profil mieści się w jednym oknie zamiast
/// pięciu ekranów jak na telefonie.
class OknoGospodarstwa extends StatefulWidget {
  const OknoGospodarstwa({
    super.key,
    required this.uslugi,
    this.gospodarstwo,
    this.nowe = false,
  });

  final Uslugi uslugi;

  /// Gospodarstwo do poprawienia. Przy zakładaniu nowego — `null`.
  final Gospodarstwo? gospodarstwo;

  final bool nowe;

  @override
  State<OknoGospodarstwa> createState() => _OknoGospodarstwaState();
}

class _OknoGospodarstwaState extends State<OknoGospodarstwa> {
  late final TextEditingController _nazwa = TextEditingController(
    text: widget.gospodarstwo?.nazwa ?? '',
  );
  late final TextEditingController _numer = TextEditingController(
    text: widget.gospodarstwo?.numerProducenta ?? '',
  );
  late final TextEditingController _powierzchnia = TextEditingController(
    text: widget.nowe || (widget.gospodarstwo?.powierzchniaUrHa ?? 0) <= 0
        ? ''
        : widget.gospodarstwo!.powierzchniaUrHa
              .toStringAsFixed(2)
              .replaceAll('.', ','),
  );

  OdpowiedzZwierzeta _zwierzeta = OdpowiedzZwierzeta.nieWiem;
  bool _wczytane = false;
  bool _pracuje = false;
  String? _blad;

  @override
  void initState() {
    super.initState();
    _wczytajZwierzeta();
  }

  Future<void> _wczytajZwierzeta() async {
    if (widget.nowe) {
      setState(() => _wczytane = true);
      return;
    }
    final odpowiedz = await widget.uslugi.zwierzetaWGospodarstwie.odczytaj();
    if (mounted) {
      setState(() {
        _zwierzeta = odpowiedz;
        _wczytane = true;
      });
    }
  }

  @override
  void dispose() {
    _nazwa.dispose();
    _numer.dispose();
    _powierzchnia.dispose();
    super.dispose();
  }

  /// Powierzchnia użytków rolnych w hektarach. `null` znaczy „nie podano" —
  /// i tak zostaje, bo zgadywanie powierzchni zmieniłoby obowiązki
  /// gospodarstwa (CLAUDE.md, reguła 5).
  double? get _hektary {
    final tekst = _powierzchnia.text.trim().replaceAll(',', '.');
    if (tekst.isEmpty) {
      return null;
    }
    return double.tryParse(tekst);
  }

  Future<void> _zapisz() async {
    final nazwa = _nazwa.text.trim();
    if (nazwa.isEmpty) {
      setState(() => _blad = 'Wpisz nazwę gospodarstwa — stoi na wydrukach.');
      return;
    }
    if (_powierzchnia.text.trim().isNotEmpty && _hektary == null) {
      setState(() => _blad = 'Powierzchnię wpisz liczbą, na przykład 18,40.');
      return;
    }
    setState(() {
      _pracuje = true;
      _blad = null;
    });

    final uslugi = widget.uslugi;
    String gospodarstwoId;
    if (widget.nowe) {
      final wynik = await uslugi.gospodarstwa.dodaj(
        nazwa: nazwa,
        numerProducenta: _numer.text,
        urzadzenie: uslugi.urzadzenie,
      );
      if (wynik.wynik != WynikDodania.dodane || wynik.id == null) {
        if (mounted) {
          setState(() {
            _pracuje = false;
            _blad = switch (wynik.wynik) {
              WynikDodania.potrzebnePremium =>
                'Drugie gospodarstwo należy do dodatków płatnych. '
                    'Pierwsze działa w całości bez opłaty.',
              WynikDodania.brakNazwy => 'Wpisz nazwę gospodarstwa.',
              WynikDodania.dodane => null,
            };
          });
        }
        return;
      }
      gospodarstwoId = wynik.id!;
    } else {
      gospodarstwoId = widget.gospodarstwo!.id;
    }

    await uslugi.gospodarstwa.popraw(
      gospodarstwoId: gospodarstwoId,
      nazwa: nazwa,
      numerProducenta: _numer.text,
      powierzchniaUrHa: _hektary,
    );
    await uslugi.zwierzetaWGospodarstwie.zapisz(_zwierzeta);

    if (mounted) {
      Navigator.of(context)
          .pop(ZapisaneGospodarstwo(id: gospodarstwoId, nazwa: nazwa));
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(widget.nowe ? 'Nowe gospodarstwo' : 'Dane gospodarstwa'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nazwa gospodarstwa', style: teksty.titleLarge),
              const SizedBox(height: 6),
              TextField(
                controller: _nazwa,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Tak, jak ma stać na wydruku',
                ),
              ),
              const SizedBox(height: MotywKomputer.odstep),
              Text('Numer producenta', style: teksty.titleLarge),
              const SizedBox(height: 6),
              TextField(
                controller: _numer,
                decoration: const InputDecoration(
                  hintText: 'z wniosku ARiMR; zostaw puste, jeśli nie masz',
                ),
              ),
              const SizedBox(height: MotywKomputer.odstep),
              Text(
                'Powierzchnia użytków rolnych (ha)',
                style: teksty.titleLarge,
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _powierzchnia,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(hintText: 'np. 18,40'),
              ),
              const SizedBox(height: 6),
              Text(
                'Od powierzchni zależy, które obowiązki włącza aplikacja. '
                'Puste pole zostaje puste — nie dopisujemy tu nic z pól, '
                'bo wniosek i rzeczywistość bywają różne.',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: MotywKomputer.odstep),
              Text('Zwierzęta w gospodarstwie', style: teksty.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Bez tej odpowiedzi obowiązki liczone od DJP zostają '
                '„do sprawdzenia".',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: 8),
              if (!_wczytane)
                const LinearProgressIndicator()
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final odpowiedz in OdpowiedzZwierzeta.values)
                      odpowiedz == _zwierzeta
                          ? FilledButton(
                              onPressed: () =>
                                  setState(() => _zwierzeta = odpowiedz),
                              child: Text(_opis(odpowiedz)),
                            )
                          : OutlinedButton(
                              onPressed: () =>
                                  setState(() => _zwierzeta = odpowiedz),
                              child: Text(_opis(odpowiedz)),
                            ),
                  ],
                ),
              if (_blad case final String wiadomosc) ...[
                const SizedBox(height: MotywKomputer.odstep),
                OstrzezenieKomputer(tresc: wiadomosc),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _pracuje ? null : () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: _pracuje ? null : _zapisz,
          child: Text(widget.nowe ? 'Załóż gospodarstwo' : 'Zapisz dane'),
        ),
      ],
    );
  }

  static String _opis(OdpowiedzZwierzeta odpowiedz) => switch (odpowiedz) {
    OdpowiedzZwierzeta.tak => 'Mam zwierzęta',
    OdpowiedzZwierzeta.nie => 'Nie mam zwierząt',
    OdpowiedzZwierzeta.nieWiem => 'Nie odpowiadam teraz',
  };
}
