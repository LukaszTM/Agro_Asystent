import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/dzialki/slownik_upraw.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';
import 'ekran_wybor_uprawy.dart';

/// Nowe pole w wyglądzie nowoczesnym: nazwa, powierzchnia przyciskami
/// i uprawa z listy słownika.
///
/// Kod EPPO bierzemy ze słownika upraw — jeśli go tam nie ma, zostaje puste
/// i wyjdzie w ewidencji jako brak. Nie wymyślamy go (CLAUDE.md, reguła 5).
class EkranNowePoleNowoczesny extends StatefulWidget {
  const EkranNowePoleNowoczesny({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranNowePoleNowoczesny> createState() =>
      _EkranNowePoleNowoczesnyState();
}

class _EkranNowePoleNowoczesnyState extends State<EkranNowePoleNowoczesny> {
  final TextEditingController _nazwa = TextEditingController();
  UprawaDoWyboru? _uprawa;
  double _hektary = 1;
  bool _zapisuje = false;

  @override
  void dispose() {
    _nazwa.dispose();
    super.dispose();
  }

  Future<void> _wybierzUprawe() async {
    final wybrana = await Navigator.of(context).push<UprawaDoWyboru>(
      MaterialPageRoute<UprawaDoWyboru>(
        builder: (_) => EkranWyborUprawyNowoczesny(uslugi: widget.uslugi),
      ),
    );
    if (wybrana != null && mounted) {
      setState(() => _uprawa = wybrana);
    }
  }

  Future<void> _zapisz() async {
    final uprawa = _uprawa;
    if (uprawa == null || _zapisuje) {
      return;
    }
    setState(() => _zapisuje = true);
    await widget.uslugi.pola.dodaj(
      pole: Pole(
        id: 'pole-${DateTime.now().microsecondsSinceEpoch}',
        gospodarstwoId: widget.uslugi.gospodarstwoId,
        nazwa: _nazwa.text.trim().isEmpty ? 'Nowe pole' : _nazwa.text.trim(),
        uprawa: uprawa.nazwa,
        // Kod EPPO z wyboru rolnika; przy własnej nazwie zostaje pusty
        // i w ewidencji wyjdzie jako brak (CLAUDE.md, reguła 5).
        kodEppo: uprawa.kodEppo,
        powierzchniaAr: (_hektary * 100).round(),
      ),
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nowe pole')),
      body: ListView(
        padding: const EdgeInsets.all(MotywNowoczesny.odstep),
        children: [
          Text('Nazwa pola', style: teksty.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _nazwa,
            style: teksty.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'np. Za stodołą',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: MotywNowoczesny.odstep),
          Text('Powierzchnia', style: teksty.titleLarge),
          const SizedBox(height: 8),
          WyborLiczbyNowoczesny(
            wartosc: _hektary,
            jednostka: 'ha',
            krok: 0.1,
            onZmiana: (nowa) => setState(() => _hektary = nowa),
          ),
          const SizedBox(height: MotywNowoczesny.odstep),
          Text('Uprawa', style: teksty.titleLarge),
          const SizedBox(height: 8),
          Karta(
            onTap: _wybierzUprawe,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _uprawa?.nazwa ?? 'Wybierz uprawę',
                        style: teksty.bodyLarge,
                      ),
                      Text(
                        _uprawa == null
                            ? 'z listy; jeśli Twojej uprawy nie ma — '
                                  'wpiszesz sam'
                            : (_uprawa!.maKod
                                  ? 'kod EPPO: ${_uprawa!.kodEppo}'
                                  : 'bez kodu EPPO — na wydruku będzie '
                                        '„brak"'),
                        style: teksty.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: MotywNowoczesny.tekstPomocniczy,
                ),
              ],
            ),
          ),
          const SizedBox(height: MotywNowoczesny.odstep * 2),
          if (_zapisuje)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(
              onPressed: _uprawa == null ? null : _zapisz,
              child: const Text('Zapisz pole'),
            ),
          if (_uprawa == null) ...[
            const SizedBox(height: 8),
            Text(
              'Uprawa jest potrzebna: od niej zależy lista dopuszczonych '
              'środków i kod EPPO w ewidencji.',
              style: teksty.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
