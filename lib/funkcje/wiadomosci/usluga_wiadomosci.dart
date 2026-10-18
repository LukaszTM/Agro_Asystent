import 'klient_wiadomosci.dart';
import 'wiadomosci.dart';

/// Co pokazać na karcie wiadomości.
class StanWiadomosci {
  const StanWiadomosci({
    this.wiadomosci = const [],
    this.pobrano,
    this.brakZrodel = false,
    this.nicNieOdpowiedzialo = false,
  });

  final List<Wiadomosc> wiadomosci;

  /// Kiedy pobrano to, co widać.
  final DateTime? pobrano;

  /// W pliku danych nie ma ani jednego kanału.
  final bool brakZrodel;

  /// Kanały są, ale żaden nie odpowiedział — zwykle brak internetu albo
  /// zmieniony adres kanału.
  final bool nicNieOdpowiedzialo;

  bool get pusty => wiadomosci.isEmpty;
}

/// Wiadomości rolnicze z kanałów RSS.
///
/// Dodatek, nie dokumentacja: gdy nie ma internetu, pokazujemy ostatnio
/// pobrane nagłówki z datą. Kanał, który nie odpowiada, pomijamy — jeden
/// zepsuty adres nie może zabrać reszty.
class UslugaWiadomosci {
  const UslugaWiadomosci({
    required this.zapis,
    required this.kanaly,
    this.klient = const KlientWiadomosci(),
    this.odstepMiedzyPobraniami = const Duration(hours: 6),
    this.ileNaEkranie = 8,
  });

  final RepozytoriumWiadomosci zapis;

  /// Lista kanałów ze słownika. `null`, gdy pliku nie wczytano.
  final SlownikKanalow? kanaly;

  final KlientWiadomosci klient;
  final Duration odstepMiedzyPobraniami;
  final int ileNaEkranie;

  Future<StanWiadomosci> najnowsze({
    DateTime? teraz,
    bool wymusPobranie = false,
  }) async {
    final chwila = teraz ?? DateTime.now();
    final lista = kanaly?.kanaly ?? const <KanalWiadomosci>[];
    final zapisane = await zapis.ostatnie();

    if (lista.isEmpty) {
      return StanWiadomosci(
        wiadomosci: zapisane?.wiadomosci ?? const [],
        pobrano: zapisane?.pobrano,
        brakZrodel: true,
      );
    }
    if (!wymusPobranie &&
        zapisane != null &&
        chwila.difference(zapisane.pobrano) < odstepMiedzyPobraniami) {
      return StanWiadomosci(
        wiadomosci: zapisane.wiadomosci,
        pobrano: zapisane.pobrano,
      );
    }

    final zebrane = <Wiadomosc>[];
    for (final kanal in lista) {
      zebrane.addAll(await klient.zKanalu(kanal));
    }

    if (zebrane.isEmpty) {
      return StanWiadomosci(
        wiadomosci: zapisane?.wiadomosci ?? const [],
        pobrano: zapisane?.pobrano,
        nicNieOdpowiedzialo: true,
      );
    }

    // Najnowsze na górze; wiadomości bez daty idą na koniec, bo nie
    // wiemy, kiedy powstały.
    zebrane.sort((a, b) {
      if (a.data == null && b.data == null) {
        return 0;
      }
      if (a.data == null) {
        return 1;
      }
      if (b.data == null) {
        return -1;
      }
      return b.data!.compareTo(a.data!);
    });

    final wybrane = zebrane.take(ileNaEkranie).toList();
    await zapis.zapisz(wiadomosci: wybrane, pobrano: chwila);
    return StanWiadomosci(wiadomosci: wybrane, pobrano: chwila);
  }
}
