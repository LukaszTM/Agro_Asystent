import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/biodynamika/biodynamika.dart';
import '../../../funkcje/dzialki/repozytorium_dzialek.dart';
import '../../../funkcje/pogoda/usluga_pogody.dart';
import '../../../funkcje/wiadomosci/usluga_wiadomosci.dart';
import '../../../funkcje/pulpit/zasiewy.dart';
import '../../../funkcje/terminy/kalendarz_terminow.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../../../rdzen/wspolne/mapa_dzialek.dart';
import '../motyw.dart';
import '../widgety/kalendarz_biodynamiczny.dart';
import '../widgety/karta.dart';
import '../widgety/karta_pogody.dart';
import '../widgety/karta_wiadomosci.dart';
import '../widgety/wykres_kolowy.dart';

/// Co pulpit pokazuje po otwarciu programu.
class _DanePulpitu {
  const _DanePulpitu({
    required this.zasiewy,
    required this.dzialki,
    required this.terminy,
    required this.pogoda,
    required this.wiadomosci,
    this.biodynamika,
  });

  final StrukturaZasiewow zasiewy;
  final List<DzialkaEwidencyjna> dzialki;
  final List<PozycjaKalendarza> terminy;

  final StanPogody pogoda;

  final StanWiadomosci wiadomosci;

  /// `null`, gdy słownika kalendarza nie udało się wczytać — pulpit działa
  /// dalej, tylko bez tej karty.
  final _DaneBiodynamiki? biodynamika;
}

class _DaneBiodynamiki {
  const _DaneBiodynamiki({
    required this.tydzien,
    required this.miesiac,
    required this.zastrzezenie,
  });

  final List<DzienBiodynamiczny> tydzien;
  final List<DzienBiodynamiczny> miesiac;
  final String zastrzezenie;
}

/// Pierwszy widok programu na komputer: gospodarstwo na jednym ekranie.
///
/// Na telefonie pierwszy ekran prowadzi do wpisu zabiegu — bo telefon jest
/// w polu. Przy komputerze rolnik siada do przeglądu, więc pulpit odpowiada
/// na trzy pytania naraz: co rośnie, gdzie to leży i co mnie goni.
///
/// Wszystko tutaj liczy się z własnej bazy i działa bez internetu.
class WidokPulpitKomputer extends StatefulWidget {
  const WidokPulpitKomputer({
    super.key,
    required this.uslugi,
    this.teraz,
    this.onPelnyWidok,
  });

  final Uslugi uslugi;
  final DateTime? teraz;

  /// Przejście do pełnej zakładki — pulpit pokazuje skrót, nie wszystko.
  final void Function(String zakladka)? onPelnyWidok;

  @override
  State<WidokPulpitKomputer> createState() => _WidokPulpitKomputerState();
}

class _WidokPulpitKomputerState extends State<WidokPulpitKomputer> {
  late Future<_DanePulpitu> _dane;

  /// Rolnik kliknął „Pobierz na nowo" — wtedy pytamy serwis, nawet jeśli
  /// zapisana prognoza jest jeszcze świeża.
  bool _wymusPogode = false;

  /// To samo dla wiadomości — rolnik może poprosić o świeże nagłówki.
  bool _wymusWiadomosci = false;

  DateTime get _teraz => widget.teraz ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _dane = _wczytaj();
  }

  Future<_DanePulpitu> _wczytaj() async {
    final uslugi = widget.uslugi;
    final pola = await uslugi.pola.wszystkie(uslugi.gospodarstwoId);
    final dzialki = await uslugi.dzialki.wszystkie(uslugi.gospodarstwoId);
    final profil = await uslugi.profil.policz(uslugi.gospodarstwoId);
    final terminy = await uslugi.kalendarz.najblizsze(
      gospodarstwoId: uslugi.gospodarstwoId,
      profil: profil,
      teraz: widget.teraz,
    );
    return _DanePulpitu(
      zasiewy: Zasiewy.policz(pola),
      dzialki: dzialki,
      terminy: terminy,
      pogoda: await uslugi.pogoda.dla(
        uslugi.gospodarstwoId,
        teraz: widget.teraz,
        wymusPobranie: _wymusPogode,
      ),
      wiadomosci: await uslugi.wiadomosci.najnowsze(
        teraz: widget.teraz,
        wymusPobranie: _wymusWiadomosci,
      ),
      biodynamika: _biodynamika(),
    );
  }

  /// Kalendarz jest dodatkiem: gdy słownika nie wczytano przy starcie,
  /// pulpit pokazuje resztę i niczego nie udaje.
  _DaneBiodynamiki? _biodynamika() {
    final slownik = widget.uslugi.biodynamika;
    if (slownik == null) {
      return null;
    }
    final kalendarz = KalendarzBiodynamiczny(slownik);
    final teraz = _teraz;
    return _DaneBiodynamiki(
      tydzien: kalendarz.tydzien(teraz),
      miesiac: kalendarz.miesiac(teraz.year, teraz.month),
      zastrzezenie: slownik.zastrzezenie,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DanePulpitu>(
      future: _dane,
      builder: (context, stan) {
        if (!stan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final dane = stan.data!;
        return LayoutBuilder(
          builder: (context, wymiary) {
            final dwieKolumny =
                wymiary.maxWidth >= MotywKomputer.szerokoscPelnegoUkladu - 160;
            return ListView(
              children: [
                NaglowekWidoku(
                  tytul: widget.uslugi.nazwaGospodarstwa,
                  opis: _zdanieOStanie(dane),
                ),
                const SizedBox(height: MotywKomputer.odstep),
                _Zasiewy(zasiewy: dane.zasiewy),
                const SizedBox(height: MotywKomputer.odstep),
                if (dwieKolumny)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _Mapa(dzialki: dane.dzialki)),
                        const SizedBox(width: MotywKomputer.odstep),
                        Expanded(
                          child: _Terminy(
                            terminy: dane.terminy,
                            teraz: _teraz,
                            onPelnyWidok: widget.onPelnyWidok,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _Mapa(dzialki: dane.dzialki),
                  const SizedBox(height: MotywKomputer.odstep),
                  _Terminy(
                    terminy: dane.terminy,
                    teraz: _teraz,
                    onPelnyWidok: widget.onPelnyWidok,
                  ),
                ],
                const SizedBox(height: MotywKomputer.odstep),
                KartaPogody(
                  stan: dane.pogoda,
                  teraz: _teraz,
                  onOdswiez: () => setState(() {
                    _wymusPogode = true;
                    _dane = _wczytaj();
                  }),
                ),
                const SizedBox(height: MotywKomputer.odstep),
                KartaWiadomosci(
                  stan: dane.wiadomosci,
                  teraz: _teraz,
                  onOdswiez: () => setState(() {
                    _wymusWiadomosci = true;
                    _dane = _wczytaj();
                  }),
                ),
                if (dane.biodynamika case final _DaneBiodynamiki kalendarz) ...[
                  const SizedBox(height: MotywKomputer.odstep),
                  KalendarzBiodynamicznyKarta(
                    tydzien: kalendarz.tydzien,
                    miesiac: kalendarz.miesiac,
                    dzis: _teraz,
                    zastrzezenie: kalendarz.zastrzezenie,
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  String _zdanieOStanie(_DanePulpitu dane) {
    final zasiewy = dane.zasiewy;
    if (zasiewy.pusta) {
      return 'Stan na ${Daty.zRokiem(_teraz)}. Nie ma jeszcze ani jednego '
          'pola — zacznij od zakładki „Pola".';
    }
    final sezon = zasiewy.sezon == null ? '' : ', sezon ${zasiewy.sezon}';
    return 'Stan na ${Daty.zRokiem(_teraz)}$sezon. '
        '${zasiewy.liczbaPol} '
        '${_odmianaPol(zasiewy.liczbaPol)}, razem '
        '${zasiewy.powierzchniaOpis}.';
  }

  static String _odmianaPol(int ile) {
    if (ile == 1) {
      return 'pole';
    }
    final ostatnia = ile % 10;
    final dwieOstatnie = ile % 100;
    final kilka =
        ostatnia >= 2 &&
        ostatnia <= 4 &&
        (dwieOstatnie < 12 || dwieOstatnie > 14);
    return kilka ? 'pola' : 'pól';
  }
}

class _Zasiewy extends StatelessWidget {
  const _Zasiewy({required this.zasiewy});

  final StrukturaZasiewow zasiewy;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    if (zasiewy.pusta) {
      return const KartaKomputer(
        child: OstrzezenieKomputer(
          tresc: 'Nie wiem jeszcze, co rośnie w gospodarstwie.',
          coZrobic:
              'Dodaj pola albo wczytaj je z wniosku — wykres zrobi się sam.',
        ),
      );
    }

    final calosc = zasiewy.powierzchniaAr;
    final widoczne = zasiewy.najwieksze(7);
    return KartaKomputer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Co rośnie', style: teksty.headlineMedium),
          const SizedBox(height: 4),
          Text(
            zasiewy.polaBezUprawy == 0
                ? 'Udział upraw w powierzchni gospodarstwa.'
                : 'Udział upraw w powierzchni gospodarstwa. '
                      '${zasiewy.polaBezUprawy} '
                      '${zasiewy.polaBezUprawy == 1 ? 'pole czeka' : 'pól czeka'} '
                      'na wpisanie uprawy.',
            style: teksty.bodyMedium,
          ),
          const SizedBox(height: MotywKomputer.odstep),
          WykresKolowy(
            wSrodku: zasiewy.powierzchniaOpis,
            podSrodkiem: 'razem',
            czesci: [
              for (final (numer, udzial) in widoczne.indexed)
                CzescWykresu(
                  nazwa: udzial.nazwa,
                  wartosc: udzial.powierzchniaAr.toDouble(),
                  kolor: udzial.nieznana
                      ? MotywKomputer.barwaBezDanych
                      : MotywKomputer.barwaWykresu(numer),
                  opis:
                      '${udzial.powierzchniaOpis} • '
                      '${udzial.udzialOpis(calosc)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mapa extends StatelessWidget {
  const _Mapa({required this.dzialki});

  final List<DzialkaEwidencyjna> dzialki;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final zGranicami = dzialki
        .where((dzialka) => dzialka.obrysy.isNotEmpty)
        .toList();
    return KartaKomputer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gdzie to leży', style: teksty.headlineMedium),
          const SizedBox(height: 4),
          Text(
            zGranicami.isEmpty
                ? 'Granice działek pobiera się raz, przy dodawaniu działki '
                      'po numerze. Potem mapka działa bez internetu.'
                : '${zGranicami.length} '
                      '${zGranicami.length == 1 ? 'działka' : 'działek'} '
                      'z granicami.',
            style: teksty.bodyMedium,
          ),
          const SizedBox(height: MotywKomputer.odstep),
          if (zGranicami.isEmpty)
            const OstrzezenieKomputer(
              tresc: 'Nie ma jeszcze żadnej działki z granicami.',
              coZrobic: 'Dodaj działkę po numerze w zakładce „Pola".',
            )
          else
            MapaDzialek(
              barwy: MotywKomputer.barwyMapy,
              dzialki: zGranicami,
              wysokosc: 260,
            ),
        ],
      ),
    );
  }
}

class _Terminy extends StatelessWidget {
  const _Terminy({
    required this.terminy,
    required this.teraz,
    this.onPelnyWidok,
  });

  final List<PozycjaKalendarza> terminy;
  final DateTime teraz;
  final void Function(String zakladka)? onPelnyWidok;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final najblizsze = terminy.take(4).toList();
    return KartaKomputer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Co mnie goni', style: teksty.headlineMedium),
          const SizedBox(height: 4),
          Text(
            najblizsze.isEmpty
                ? 'Nic nie czeka.'
                : 'Najbliższe terminy i karencje.',
            style: teksty.bodyMedium,
          ),
          const SizedBox(height: MotywKomputer.odstep),
          for (final pozycja in najblizsze)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      Daty.krotko(pozycja.data),
                      style: teksty.labelLarge?.copyWith(
                        color: pozycja.pilnosc(teraz) == PilnoscTerminu.minelo
                            ? MotywKomputer.ostrzezenieObramowanie
                            : MotywKomputer.zielen,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pozycja.nazwa, style: teksty.bodyLarge),
                        Text(pozycja.coZrobic, style: teksty.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (onPelnyWidok != null)
            TextButton(
              onPressed: () => onPelnyWidok!('terminy'),
              child: const Text('Zobacz wszystkie terminy'),
            ),
        ],
      ),
    );
  }
}
