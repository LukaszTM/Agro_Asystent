import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/slownik_upraw.dart';
import '../motyw.dart';
import '../widgety/karta.dart';

/// Wybór uprawy pola z listy — wygląd nowoczesny.
///
/// Te same zasady co w wyglądzie prostym: lista od upraw najczęstszych,
/// przy nazwie rodzajowej („łubin") pytanie o gatunek, a gdy uprawy nie ma
/// w słowniku — własna nazwa bez wymyślonego kodu EPPO.
class EkranWyborUprawyNowoczesny extends StatefulWidget {
  const EkranWyborUprawyNowoczesny({
    super.key,
    required this.uslugi,
    this.tytul = 'Jaka uprawa?',
    this.gatunkiDo,
  });

  final Uslugi uslugi;
  final String tytul;

  /// Gdy podane — pokazujemy gatunki tej nazwy rodzajowej.
  final UprawaDoWyboru? gatunkiDo;

  @override
  State<EkranWyborUprawyNowoczesny> createState() =>
      _EkranWyborUprawyNowoczesnyState();
}

class _EkranWyborUprawyNowoczesnyState
    extends State<EkranWyborUprawyNowoczesny> {
  /// Ile upraw pokazujemy naraz — słownik ma ich ponad 600.
  static const int _ileNaraz = 60;

  late Future<WynikSzukaniaUpraw> _uprawy;
  final TextEditingController _wlasna = TextEditingController();
  String _szukane = '';
  bool _wpisujeWlasna = false;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  @override
  void dispose() {
    _wlasna.dispose();
    super.dispose();
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
          builder: (_) => EkranWyborUprawyNowoczesny(
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

  static String _opis(UprawaDoWyboru uprawa) {
    if (uprawa.wymagaGatunku) {
      return 'wybierz gatunek';
    }
    if (uprawa.maKod) {
      return 'kod EPPO: ${uprawa.kodEppo}';
    }
    return 'bez kodu EPPO — na wydruku będzie „brak"';
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final gatunki = widget.gatunkiDo != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.tytul)),
      body: ListView(
        padding: const EdgeInsets.all(MotywNowoczesny.odstep),
        children: [
          if (!gatunki)
            TextField(
              style: teksty.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Szukaj uprawy',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (tekst) => setState(() {
                _szukane = tekst.trim();
                _odswiez();
              }),
            ),
          const SizedBox(height: MotywNowoczesny.odstep),
          FutureBuilder<WynikSzukaniaUpraw>(
            future: _uprawy,
            builder: (context, stan) {
              if (!stan.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final wynik = stan.data!;
              final uprawy = wynik.uprawy;
              if (wynik.pusty) {
                return OstrzezenieNowoczesne(
                  tresc: _szukane.isEmpty
                      ? 'Słownik nie ma tu żadnej uprawy.'
                      : 'Żadna uprawa nie pasuje do „$_szukane".',
                  coZrobic:
                      'Wpisz inną część nazwy albo wpisz własną uprawę '
                      'niżej.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!gatunki) ...[
                    Text(
                      _szukane.isEmpty
                          ? 'Najczęstsze uprawy — szukaj bez ogonków, '
                                'np. „lubin"'
                          : (wynik.razem == 1
                                ? 'Znaleziono 1 uprawę'
                                : 'Znaleziono ${wynik.razem} upraw'),
                      style: teksty.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                  ],
                  for (final uprawa in uprawy) ...[
                    Karta(
                      onTap: () => _wybierz(uprawa),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(uprawa.nazwa, style: teksty.bodyLarge),
                                Text(_opis(uprawa), style: teksty.bodyMedium),
                              ],
                            ),
                          ),
                          Icon(
                            uprawa.wymagaGatunku
                                ? Icons.chevron_right
                                : (uprawa.maKod
                                      ? Icons.check_circle_outline
                                      : Icons.help_outline),
                            size: 20,
                            color: MotywNowoczesny.tekstPomocniczy,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (wynik.jestWiecej)
                    OstrzezenieNowoczesne(
                      tresc:
                          'Pasuje ${wynik.razem} upraw, pokazujemy '
                          '${uprawy.length}.',
                      coZrobic: 'Wpisz więcej liter, żeby zawęzić listę.',
                    ),
                ],
              );
            },
          ),
          if (!gatunki) ...[
            const SizedBox(height: MotywNowoczesny.odstep),
            if (!_wpisujeWlasna)
              OutlinedButton.icon(
                onPressed: () => setState(() => _wpisujeWlasna = true),
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Nie ma mojej uprawy'),
              )
            else
              Karta(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Własna nazwa uprawy', style: teksty.titleLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _wlasna,
                      autofocus: true,
                      style: teksty.bodyLarge,
                      decoration: const InputDecoration(
                        hintText: 'np. gryka na nasiona',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    const OstrzezenieNowoczesne(
                      tresc:
                          'Dla własnej nazwy nie podpowiemy środków '
                          'z rejestru ani kodu EPPO.',
                      coZrobic:
                          'W ewidencji zostanie „brak" w kolumnie kodu — '
                          'uzupełnisz go przed kontrolą.',
                    ),
                    const SizedBox(height: MotywNowoczesny.odstep),
                    FilledButton(
                      onPressed: _wlasna.text.trim().isEmpty
                          ? null
                          : () => Navigator.of(context)
                                .pop(UprawaDoWyboru.wlasnaNazwa(_wlasna.text)),
                      child: const Text('Zapisz nazwę'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
