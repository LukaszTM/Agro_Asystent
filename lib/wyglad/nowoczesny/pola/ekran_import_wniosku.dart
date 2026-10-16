import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/czytnik_wniosku.dart';
import '../../../funkcje/dzialki/import_wniosku.dart';
import '../../../rdzen/uslugi/pdf/skladnia_pdf.dart';
import '../motyw.dart';
import '../widgety/karta.dart';

/// Wczytanie działek i upraw z wniosku o płatności — wygląd nowoczesny.
///
/// Plik czytamy na urządzeniu i zapisujemy dopiero po potwierdzeniu.
/// Wniosek zawiera dane osobowe i nigdzie go nie wysyłamy (plan, pkt 6.2).
class EkranImportWnioskuNowoczesny extends StatefulWidget {
  const EkranImportWnioskuNowoczesny({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranImportWnioskuNowoczesny> createState() =>
      _EkranImportWnioskuNowoczesnyState();
}

class _EkranImportWnioskuNowoczesnyState
    extends State<EkranImportWnioskuNowoczesny> {
  bool _czytanie = false;
  bool _zapisywanie = false;
  String? _nazwaPliku;
  WniosekZPdf? _wniosek;
  WynikImportu? _zapisane;
  String? _blad;
  String? _coZrobic;

  Future<void> _wybierz() async {
    setState(() {
      _blad = null;
      _coZrobic = null;
    });
    final plik = await widget.uslugi.zrodloPliku.wybierzPdf();
    if (plik == null || !mounted) {
      return;
    }

    setState(() {
      _czytanie = true;
      _nazwaPliku = plik.nazwa;
      _wniosek = null;
      _zapisane = null;
    });

    try {
      // Odczyt w osobnym wątku — wniosek ma kilkadziesiąt stron, a ekran
      // nie może na ten czas zamarzać.
      final wniosek = await compute(CzytnikWniosku.zBajtow, plik.bajty);
      if (!mounted) {
        return;
      }
      setState(() {
        _wniosek = wniosek;
        _czytanie = false;
      });
    } on BladPdf catch (blad) {
      _pokazBlad(
        'Nie udało się odczytać tego pliku (${blad.wiadomosc}).',
        'Sprawdź, czy to wniosek pobrany z eWniosekPlus, a nie zdjęcie '
            'albo skan.',
      );
    } on Exception {
      _pokazBlad(
        'Nie udało się odczytać tego pliku.',
        'Sprawdź, czy to wniosek pobrany z eWniosekPlus, a nie zdjęcie '
            'albo skan.',
      );
    }
  }

  void _pokazBlad(String wiadomosc, String coZrobic) {
    if (!mounted) {
      return;
    }
    setState(() {
      _blad = wiadomosc;
      _coZrobic = coZrobic;
      _czytanie = false;
      _wniosek = null;
    });
  }

  Future<void> _zapisz() async {
    final wniosek = _wniosek;
    if (wniosek == null || _zapisywanie) {
      return;
    }
    setState(() => _zapisywanie = true);
    final wynik = await widget.uslugi.importWniosku.zapisz(
      wniosek: wniosek,
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _zapisane = wynik;
      _zapisywanie = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Wniosek z PDF'),
      leading: BackButton(
        onPressed: () => Navigator.of(context).pop(_zapisane != null),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(MotywNowoczesny.odstep),
        children: [
          if (_zapisane case final WynikImportu wynik)
            ..._poZapisie(context, wynik)
          else if (_wniosek case final WniosekZPdf wniosek)
            ..._podsumowanie(context, wniosek)
          else
            ..._poczatek(context),
        ],
      ),
    ),
  );

  List<Widget> _poczatek(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return [
      Text('Wczytaj działki i uprawy z wniosku', style: teksty.titleLarge),
      const SizedBox(height: 8),
      Text(
        'Wskaż plik wniosku o płatności pobrany z eWniosekPlus. Aplikacja '
        'przepisze z niego działki, pola i powierzchnie.',
        style: teksty.bodyLarge,
      ),
      const SizedBox(height: 8),
      Text(
        'Wniosek zostaje na telefonie — nic nie jest nigdzie wysyłane.',
        style: teksty.bodyMedium,
      ),
      const SizedBox(height: MotywNowoczesny.odstep),
      if (_blad case final String blad) ...[
        OstrzezenieNowoczesne(tresc: blad, coZrobic: _coZrobic),
        const SizedBox(height: MotywNowoczesny.odstep),
      ],
      if (_czytanie)
        Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text('Czytam wniosek…', style: teksty.bodyLarge),
          ],
        )
      else
        FilledButton.icon(
          onPressed: _wybierz,
          icon: const Icon(Icons.upload_file, size: 20),
          label: const Text('Wybierz plik wniosku'),
        ),
    ];
  }

  List<Widget> _podsumowanie(BuildContext context, WniosekZPdf wniosek) {
    final teksty = Theme.of(context).textTheme;
    final kontrola = wniosek.kontrola;
    return [
      Text(_nazwaPliku ?? 'Wniosek', style: teksty.titleLarge),
      const SizedBox(height: 8),
      Karta(
        child: Column(
          children: [
            _Liczba(
              etykieta: 'Działki w ewidencji',
              wartosc: '${wniosek.dzialki.length}',
              opis: '${_ha(wniosek.powierzchniaDzialekHa)} ha razem',
            ),
            _Liczba(
              etykieta: 'Pola (uprawy)',
              wartosc: '${wniosek.pola.length}',
              opis: '${_ha(wniosek.powierzchniaPolAr / 100)} ha zadeklarowane',
            ),
            _Liczba(
              etykieta: 'Różnych upraw',
              wartosc: '${wniosek.uprawy.length}',
              opis: wniosek.rok == null
                  ? 'rok nieznany'
                  : 'wniosek na ${wniosek.rok}',
              ostatnia: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: MotywNowoczesny.odstep),
      if (!kontrola.wynikPewny)
        OstrzezenieNowoczesne(
          tresc: 'Odczyt nie jest pewny: ${kontrola.ostrzezenia.first}',
          coZrobic:
              'Możesz zapisać i poprawić ręcznie albo wczytać wniosek '
              'jeszcze raz.',
        )
      else if (kontrola.wierszePominiete > 0)
        OstrzezenieNowoczesne(
          tresc: 'Pominięto ${kontrola.wierszePominiete} wierszy wniosku.',
          coZrobic: 'Po zapisie sprawdź, czy wszystkie pola są na liście.',
        )
      else
        Text(
          'Powierzchnie się zgadzają: każde pole sumuje się do powierzchni '
          'swoich działek.',
          style: teksty.bodyMedium,
        ),
      const SizedBox(height: MotywNowoczesny.odstep),
      if (_zapisywanie)
        const Center(child: CircularProgressIndicator())
      else ...[
        FilledButton(
          onPressed: _zapisz,
          child: const Text('Zapisz do gospodarstwa'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _wybierz,
          child: const Text('Wybierz inny plik'),
        ),
      ],
    ];
  }

  List<Widget> _poZapisie(BuildContext context, WynikImportu wynik) {
    final teksty = Theme.of(context).textTheme;
    return [
      Text('Zapisane', style: teksty.titleLarge),
      const SizedBox(height: 8),
      Karta(
        child: Column(
          children: [
            _Liczba(
              etykieta: 'Działki',
              wartosc: '${wynik.dzialkiRazem}',
              opis:
                  '${wynik.dzialkiDodane} nowych, '
                  '${wynik.dzialkiUzupelnione} uzupełnionych',
            ),
            _Liczba(
              etykieta: 'Pola',
              wartosc: '${wynik.polaRazem}',
              opis: 'sezon ${wynik.sezon}',
              ostatnia: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: MotywNowoczesny.odstep),
      if (wynik.uprawyBezKodu.isNotEmpty) ...[
        OstrzezenieNowoczesne(
          tresc:
              '${wynik.uprawyBezKodu.length} upraw nie ma w słowniku '
              '(${wynik.uprawyBezKodu.take(2).join(', ')}).',
          coZrobic:
              'Przy wpisie zabiegu wybierz dla nich uprawę z listy — '
              'nie wpisujemy niczego na domysł.',
        ),
        const SizedBox(height: MotywNowoczesny.odstep),
      ],
      if (wynik.dzialkiBezPelnegoNumeru.isNotEmpty) ...[
        OstrzezenieNowoczesne(
          tresc:
              '${wynik.dzialkiBezPelnegoNumeru.length} działek bez pełnego '
              'numeru.',
          coZrobic:
              'Dla nich granic nie pobierzemy — numer trzeba dopisać '
              'ręcznie na ekranie działek.',
        ),
        const SizedBox(height: MotywNowoczesny.odstep),
      ],
      Text(
        'Granice działek pobierzesz na ekranie „Działki" — wniosek podaje '
        'numery i powierzchnie, granice są z ULDK.',
        style: teksty.bodyMedium,
      ),
      const SizedBox(height: MotywNowoczesny.odstep),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Gotowe'),
      ),
    ];
  }

  static String _ha(double wartosc) =>
      wartosc.toStringAsFixed(2).replaceAll('.', ',');
}

/// Jedna liczba z opisem.
class _Liczba extends StatelessWidget {
  const _Liczba({
    required this.etykieta,
    required this.wartosc,
    required this.opis,
    this.ostatnia = false,
  });

  final String etykieta;
  final String wartosc;
  final String opis;
  final bool ostatnia;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: ostatnia ? 0 : 12),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(wartosc, style: teksty.headlineMedium),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etykieta, style: teksty.bodyLarge),
                Text(opis, style: teksty.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
