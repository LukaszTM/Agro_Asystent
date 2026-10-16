import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/slownik_upraw.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';

/// Wybór uprawy pola z listy (reguły interfejsu: wybór z listy zamiast
/// pisania).
///
/// Lista idzie od upraw najczęstszych w rejestrze, więc pszenica i rzepak są
/// na górze. Gdy nazwa z rejestru nie mówi, o jaki gatunek chodzi („łubin"),
/// ekran pyta o gatunek — dzięki temu na wydruku stoi kod gatunku, a nie kod
/// rodzaju. Gdy uprawy nie ma w słowniku, rolnik wpisuje własną nazwę; wtedy
/// kodu EPPO nie wymyślamy i pole zostaje puste.
class EkranWyborUprawy extends StatefulWidget {
  const EkranWyborUprawy({
    super.key,
    required this.uslugi,
    this.tytul = 'Jaka uprawa?',
    this.gatunkiDo,
  });

  final Uslugi uslugi;

  final String tytul;

  /// Gdy podane — ekran pokazuje gatunki tej nazwy rodzajowej, nie cały
  /// słownik.
  final UprawaDoWyboru? gatunkiDo;

  @override
  State<EkranWyborUprawy> createState() => _EkranWyborUprawyState();
}

class _EkranWyborUprawyState extends State<EkranWyborUprawy> {
  /// Ile upraw pokazujemy naraz. Słownik ma ich ponad 600, więc liczy się
  /// wyszukiwarka, a nie długość listy.
  static const int _ileNaraz = 60;

  late Future<WynikSzukaniaUpraw> _uprawy;
  String _szukane = '';

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    final rodzajowa = widget.gatunkiDo;
    _uprawy = rodzajowa != null
        ? widget.uslugi.uprawy
              .gatunki(rodzajowa)
              .then(
                (gatunki) =>
                    WynikSzukaniaUpraw(uprawy: gatunki, razem: gatunki.length),
              )
        : widget.uslugi.uprawy.doWyboru(szukane: _szukane, limit: _ileNaraz);
  }

  Future<void> _wybierz(UprawaDoWyboru uprawa) async {
    if (uprawa.wymagaGatunku) {
      final gatunek = await Navigator.of(context).push<UprawaDoWyboru>(
        MaterialPageRoute<UprawaDoWyboru>(
          builder: (_) => EkranWyborUprawy(
            uslugi: widget.uslugi,
            tytul: uprawa.pytanie ?? 'Jaki gatunek?',
            gatunkiDo: uprawa,
          ),
        ),
      );
      if (gatunek != null && mounted) {
        Navigator.of(context).pop(gatunek);
      }
      return;
    }
    Navigator.of(context).pop(uprawa);
  }

  Future<void> _wlasnaNazwa() async {
    final nazwa = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const EkranWlasnaUprawa()),
    );
    if (nazwa != null && nazwa.trim().isNotEmpty && mounted) {
      Navigator.of(context).pop(UprawaDoWyboru.wlasnaNazwa(nazwa));
    }
  }

  String _naglowekListy(WynikSzukaniaUpraw wynik) {
    if (_szukane.isEmpty) {
      return 'Pisz nazwę uprawy — ogonki i wielkie litery nie mają '
          'znaczenia. Niżej są najczęstsze uprawy, jeśli wolisz przewijać.';
    }
    return wynik.razem == 1
        ? 'Znaleziono 1 uprawę.'
        : 'Znaleziono ${wynik.razem} upraw.';
  }

  static String _opis(UprawaDoWyboru uprawa) {
    if (uprawa.wymagaGatunku) {
      return 'naciśnij i wybierz gatunek';
    }
    if (uprawa.maKod) {
      return 'kod EPPO: ${uprawa.kodEppo}';
    }
    return 'bez kodu EPPO — na wydruku będzie „brak"';
  }

  @override
  Widget build(BuildContext context) {
    final gatunki = widget.gatunkiDo != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.tytul)),
      body: Column(
        children: [
          if (!gatunki)
            Padding(
              padding: const EdgeInsets.all(MotywProsty.odstep),
              child: TextField(
                // Klawiatura wychodzi od razu: przy 600 uprawach szukanie
                // jest szybsze niż przewijanie, a listę i tak widać niżej.
                autofocus: true,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Szukaj uprawy',
                  prefixIcon: Icon(Icons.search, size: 28),
                  border: OutlineInputBorder(),
                ),
                onChanged: (tekst) => setState(() {
                  _szukane = tekst.trim();
                  _odswiez();
                }),
              ),
            ),
          Expanded(
            child: FutureBuilder<WynikSzukaniaUpraw>(
              future: _uprawy,
              builder: (context, stan) {
                if (!stan.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final wynik = stan.data!;
                return ListView(
                  padding: const EdgeInsets.all(MotywProsty.odstep),
                  children: [
                    if (!gatunki) ...[
                      Text(
                        _naglowekListy(wynik),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (wynik.pusty)
                      Ostrzezenie(
                        tresc: _szukane.isEmpty
                            ? 'Słownik nie ma tu żadnej uprawy.'
                            : 'Żadna uprawa nie pasuje do „$_szukane".',
                        coZrobic:
                            'Wpisz inną część nazwy albo naciśnij '
                            '„Nie ma mojej uprawy".',
                      ),
                    for (final uprawa in wynik.uprawy) ...[
                      DuzyPrzycisk(
                        etykieta: uprawa.nazwa,
                        opis: _opis(uprawa),
                        ikona: uprawa.maKod
                            ? Icons.check_circle_outline
                            : Icons.help_outline,
                        onTap: () => _wybierz(uprawa),
                      ),
                      const SizedBox(height: MotywProsty.odstep),
                    ],
                    if (wynik.jestWiecej)
                      Ostrzezenie(
                        tresc:
                            'To nie wszystkie: pasuje ${wynik.razem} upraw, '
                            'pokazujemy ${wynik.uprawy.length}.',
                        coZrobic:
                            'Wpisz w okienku u góry więcej liter — '
                            'np. „psz ozim" zamiast „psz".',
                      ),
                    if (!gatunki) ...[
                      const SizedBox(height: MotywProsty.odstep),
                      DuzyPrzycisk(
                        etykieta: 'Nie ma mojej uprawy',
                        opis: 'wpisz nazwę sam',
                        ikona: Icons.edit_outlined,
                        onTap: _wlasnaNazwa,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Własna nazwa uprawy — wyjście awaryjne, gdy słownik jej nie ma.
class EkranWlasnaUprawa extends StatefulWidget {
  const EkranWlasnaUprawa({super.key});

  @override
  State<EkranWlasnaUprawa> createState() => _EkranWlasnaUprawaState();
}

class _EkranWlasnaUprawaState extends State<EkranWlasnaUprawa> {
  final TextEditingController _nazwa = TextEditingController();

  @override
  void dispose() {
    _nazwa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Własna uprawa')),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          Text('Nazwa uprawy', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _nazwa,
            autofocus: true,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'np. gryka na nasiona',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: MotywProsty.odstep),
          const Ostrzezenie(
            tresc:
                'Dla własnej nazwy nie podpowiemy środków z rejestru ani '
                'kodu EPPO.',
            coZrobic:
                'W ewidencji zostanie „brak" w kolumnie kodu — uzupełnisz '
                'go przed kontrolą. Jeśli Twoja uprawa jest na liście, '
                'wybierz ją z listy.',
          ),
          const SizedBox(height: MotywProsty.odstep * 2),
          FilledButton(
            onPressed: _nazwa.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_nazwa.text.trim()),
            child: const Text('Zapisz nazwę'),
          ),
        ],
      ),
    );
  }
}
