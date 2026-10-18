import '../../rdzen/uslugi/geometria.dart';
import '../dzialki/repozytorium_dzialek.dart';
import 'klient_pogody.dart';
import 'pogoda.dart';

/// Co pokazać na ekranie pogody — razem z tym, czego nie wiemy.
class StanPogody {
  const StanPogody({
    this.prognoza,
    this.blad,
    this.coZrobic,
    this.brakPolozenia = false,
  });

  /// Ostatnia znana prognoza: świeżo pobrana albo zapisana wcześniej.
  final Prognoza? prognoza;

  /// Dlaczego nie udało się pobrać nowej. Prognoza może przy tym być —
  /// wtedy pokazujemy starą z datą.
  final String? blad;

  final String? coZrobic;

  /// Nie wiemy, gdzie leży gospodarstwo — nie ma ani jednej działki
  /// z granicami.
  final bool brakPolozenia;

  bool get pusty => prognoza == null;
}

/// Pogoda dla gospodarstwa: położenie z działek, pobranie z sieci,
/// zapis na później.
///
/// Zasada offline-first: sieć jest dodatkiem. Gdy jej nie ma, pokazujemy
/// ostatni zapisany odczyt **z datą**, a nie pustkę i nie zgadywankę.
class UslugaPogody {
  const UslugaPogody({
    required this.zapis,
    required this.dzialki,
    this.klient = const KlientPogody(),
    this.odstepMiedzyPobraniami = const Duration(hours: 3),
  });

  final RepozytoriumPogody zapis;
  final RepozytoriumDzialek dzialki;
  final KlientPogody klient;

  /// Jak często wolno odpytywać serwis. Prognoza godzinowa nie zmienia się
  /// częściej, a regulamin usługi prosi o oszczędność.
  final Duration odstepMiedzyPobraniami;

  Future<StanPogody> dla(
    String gospodarstwoId, {
    DateTime? teraz,
    bool wymusPobranie = false,
  }) async {
    final chwila = teraz ?? DateTime.now();
    final polozenie = PolozenieGospodarstwa.zDzialek(
      await dzialki.wszystkie(gospodarstwoId),
    );
    final zapisana = await zapis.ostatnia(gospodarstwoId);

    if (polozenie == null) {
      return StanPogody(prognoza: zapisana, brakPolozenia: true);
    }
    if (!wymusPobranie &&
        zapisana != null &&
        !zapisana.starsza(chwila, niz: odstepMiedzyPobraniami) &&
        _toSamoMiejsce(zapisana, polozenie)) {
      return StanPogody(prognoza: zapisana);
    }

    try {
      final swieza = await klient.pobierz(
        szerokosc: polozenie.szerokosc,
        dlugosc: polozenie.dlugosc,
        teraz: chwila,
      );
      await zapis.zapisz(gospodarstwoId: gospodarstwoId, prognoza: swieza);
      return StanPogody(prognoza: swieza);
    } on BladPogody catch (blad) {
      return StanPogody(
        prognoza: zapisana,
        blad: blad.wiadomosc,
        coZrobic: blad.coZrobic,
      );
    }
  }

  /// Czy zapisana prognoza dotyczy tego samego miejsca. Setna część
  /// stopnia to mniej więcej kilometr — dla pogody bez znaczenia.
  static bool _toSamoMiejsce(Prognoza prognoza, Punkt polozenie) =>
      (prognoza.szerokosc - polozenie.szerokosc).abs() < 0.01 &&
      (prognoza.dlugosc - polozenie.dlugosc).abs() < 0.01;
}
