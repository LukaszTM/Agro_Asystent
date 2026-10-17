import '../../rdzen/reguly/regula_prawna.dart';
import 'repozytorium_pol.dart';
import 'rodzaj_uzytku.dart';
import 'uprawy_pola.dart';

/// Co aplikacja wie o uprawach jednego pola w kolejnych latach.
///
/// Zakres lat nie jest liczbą w kodzie: norma GAEC 7 każe brać pod uwagę
/// uprawę „nie wcześniej niż w 2023 r.", a rok ten stoi w słowniku reguł
/// przy progu `ta_sama_uprawa_lata`.
class HistoriaUprawPola {
  const HistoriaUprawPola({
    required this.pole,
    required this.wpisy,
    required this.propozycje,
    required this.odRoku,
    required this.doRoku,
    required this.podpowiedzRodzajuUzytku,
  });

  final Pole pole;

  /// Uprawy w plonie głównym, od najnowszego sezonu.
  final List<UprawaSezonu> wpisy;

  /// Uprawy tego samego oznaczenia z wniosków z wcześniejszych lat —
  /// do potwierdzenia przez rolnika, nie dopisane same.
  final List<UprawaSezonu> propozycje;

  /// Pierwszy rok, który liczy się do zmianowania (z przepisu).
  final int odRoku;

  /// Ostatni rok, o który pytamy — sezon pola albo rok bieżący.
  final int doRoku;

  /// Co aplikacja podpowiada jako rodzaj użytku dla tego pola.
  final RodzajUzytku podpowiedzRodzajuUzytku;

  /// Lata z przedziału, dla których nie ma jeszcze wpisu.
  List<int> get brakujaceLata {
    final znane = wpisy.map((w) => w.sezon).toSet();
    return [
      for (var rok = doRoku; rok >= odRoku; rok--)
        if (!znane.contains(rok)) rok,
    ];
  }

  bool get kompletna => brakujaceLata.isEmpty;

  /// Czy pole czeka na decyzję rolnika o rodzaju użytku.
  bool get rodzajUzytkuDoPodania => !pole.rodzajUzytku.znany;

  UprawaSezonu? wRoku(int rok) =>
      wpisy.where((w) => w.sezon == rok).firstOrNull;
}

/// Składa historię upraw pola z bazy i ze słownika reguł.
class UslugaHistoriiUpraw {
  const UslugaHistoriiUpraw({
    required this.pola,
    required this.uprawy,
    required this.reguly,
  });

  final RepozytoriumPol pola;
  final RepozytoriumUprawPola uprawy;
  final SlownikRegul reguly;

  /// Rok, od którego przepis każe liczyć zmianowanie. `null`, gdy słownik
  /// tego nie podaje — wtedy nie wymyślamy własnej granicy.
  int? get odRokuZPrzepisu => reguly.warunkowosc
      .norma('gaec_7')
      ?.prog('ta_sama_uprawa_lata')
      ?.liczOdRoku;

  Future<HistoriaUprawPola> dla(Pole pole, {DateTime? teraz}) async {
    final biezacyRok = (teraz ?? DateTime.now()).year;
    final doRoku = pole.sezon == null
        ? biezacyRok
        : (pole.sezon! > biezacyRok ? pole.sezon! : biezacyRok);
    return HistoriaUprawPola(
      pole: pole,
      wpisy: (await uprawy.historia(pole.id))
          .where((u) => u.plonGlowny)
          .toList(growable: false),
      propozycje: await uprawy.propozycjeZWnioskow(pole.id),
      odRoku: odRokuZPrzepisu ?? doRoku,
      doRoku: doRoku,
      podpowiedzRodzajuUzytku: RodzajUzytku.podpowiedz(
        uprawa: pole.uprawa,
        podpowiedzi: reguly.warunkowosc.rodzajeUzytku,
      ),
    );
  }
}
