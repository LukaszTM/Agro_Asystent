import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/czytnik_wniosku.dart';
import '../../../funkcje/dzialki/import_wniosku.dart';
import '../../../rdzen/uslugi/pdf/skladnia_pdf.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';

/// Wczytanie działek i upraw z wniosku o płatności (krok 2 etapu 1).
///
/// Rolnik wskazuje plik PDF pobrany z eWniosekPlus; aplikacja czyta go
/// na urządzeniu, pokazuje, co znalazła, i zapisuje dopiero po
/// potwierdzeniu. Nic nie jest nigdzie wysyłane — wniosek zawiera dane
/// osobowe i zostaje na telefonie (plan, pkt 6.2).
class EkranImportWniosku extends StatefulWidget {
  const EkranImportWniosku({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranImportWniosku> createState() => _EkranImportWnioskuState();
}

class _EkranImportWnioskuState extends State<EkranImportWniosku> {
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
      // Odczyt idzie do osobnego wątku — wniosek ma kilkadziesiąt stron
      // i ekran nie może na ten czas zamarzać.
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
    if (wniosek == null) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wniosek z PDF')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(MotywProsty.odstep),
          children: [
            if (_zapisane != null)
              ..._poZapisie(context, _zapisane!)
            else if (_wniosek != null)
              ..._podsumowanie(context, _wniosek!)
            else
              ..._poczatek(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _poczatek(BuildContext context) => [
    Text(
      'Wczytaj działki i uprawy z wniosku',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    const SizedBox(height: 8),
    Text(
      'Wskaż plik wniosku o płatności, pobrany z eWniosekPlus. '
      'Aplikacja przepisze z niego działki, pola i powierzchnie, '
      'żebyś nie musiał wpisywać ich ręcznie.',
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    const SizedBox(height: MotywProsty.odstep),
    Text(
      'Wniosek zostaje na telefonie — nic nie jest nigdzie wysyłane.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    const SizedBox(height: MotywProsty.odstep),
    if (_blad != null) ...[
      Ostrzezenie(tresc: _blad!, coZrobic: _coZrobic),
      const SizedBox(height: MotywProsty.odstep),
    ],
    if (_czytanie)
      Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: MotywProsty.odstep),
          Text('Czytam wniosek…', style: Theme.of(context).textTheme.bodyLarge),
        ],
      )
    else
      FilledButton(
        onPressed: _wybierz,
        child: const Text('Wybierz plik wniosku'),
      ),
  ];

  List<Widget> _podsumowanie(BuildContext context, WniosekZPdf wniosek) {
    final kontrola = wniosek.kontrola;
    return [
      Text(
        _nazwaPliku ?? 'Wniosek',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: MotywProsty.odstep),
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
      ),
      const SizedBox(height: MotywProsty.odstep),
      if (!kontrola.wynikPewny)
        Ostrzezenie(
          tresc: 'Odczyt nie jest pewny: ${kontrola.ostrzezenia.first}',
          coZrobic:
              'Możesz zapisać i poprawić ręcznie albo wczytać '
              'wniosek jeszcze raz.',
        )
      else if (kontrola.wierszePominiete > 0)
        Ostrzezenie(
          tresc: 'Pominięto ${kontrola.wierszePominiete} wierszy wniosku.',
          coZrobic: 'Po zapisie sprawdź, czy wszystkie pola są na liście.',
        )
      else
        Text(
          'Powierzchnie się zgadzają: każde pole sumuje się do powierzchni '
          'swoich działek.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      const SizedBox(height: MotywProsty.odstep),
      if (_zapisywanie)
        const Center(child: CircularProgressIndicator())
      else ...[
        FilledButton(
          onPressed: _zapisz,
          child: const Text('Zapisz do gospodarstwa'),
        ),
        const SizedBox(height: MotywProsty.odstep),
        OutlinedButton(
          onPressed: _wybierz,
          style: _obramowany(context),
          child: const Text('Wybierz inny plik'),
        ),
      ],
    ];
  }

  List<Widget> _poZapisie(BuildContext context, WynikImportu wynik) => [
    Text('Zapisane', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: MotywProsty.odstep),
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
    ),
    const SizedBox(height: MotywProsty.odstep),
    if (wynik.uprawyBezKodu.isNotEmpty)
      Ostrzezenie(
        tresc:
            '${wynik.uprawyBezKodu.length} upraw nie ma w słowniku '
            '(${wynik.uprawyBezKodu.take(2).join(', ')}).',
        coZrobic:
            'Przy wpisie zabiegu wybierz dla nich uprawę z listy — '
            'nie wpisujemy niczego na domysł.',
      ),
    if (wynik.dzialkiBezPelnegoNumeru.isNotEmpty) ...[
      const SizedBox(height: MotywProsty.odstep),
      Ostrzezenie(
        tresc:
            '${wynik.dzialkiBezPelnegoNumeru.length} działek '
            'bez pełnego numeru.',
        coZrobic:
            'Dla nich granic nie pobierzemy — numer trzeba dopisać '
            'ręcznie na ekranie działek.',
      ),
    ],
    const SizedBox(height: MotywProsty.odstep),
    Text(
      'Granice działek pobierzesz na ekranie „Działki i mapa" — '
      'wniosek podaje numery i powierzchnie, granice są z ULDK.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    const SizedBox(height: MotywProsty.odstep),
    FilledButton(
      onPressed: () => Navigator.of(context).pop(true),
      child: const Text('Gotowe'),
    ),
  ];

  ButtonStyle _obramowany(BuildContext context) => OutlinedButton.styleFrom(
    minimumSize: const Size(
      MotywProsty.minCelDotyku * 2,
      MotywProsty.minCelDotyku + 8,
    ),
    textStyle: Theme.of(context).textTheme.labelLarge,
  );

  static String _ha(double wartosc) =>
      wartosc.toStringAsFixed(2).replaceAll('.', ',');
}

/// Jedna liczba z opisem — duża, żeby dała się przeczytać bez okularów.
class _Liczba extends StatelessWidget {
  const _Liczba({
    required this.etykieta,
    required this.wartosc,
    required this.opis,
  });

  final String etykieta;
  final String wartosc;
  final String opis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              wartosc,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etykieta, style: Theme.of(context).textTheme.bodyLarge),
                Text(opis, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
