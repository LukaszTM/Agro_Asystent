import 'funkcja.dart';

/// Jedyne miejsce w kodzie decydujące o dostępie do funkcji premium
/// (plan, pkt 8). Nigdzie indziej nie wolno pytać „czy użytkownik kupił".
///
/// Zasada: wersja darmowa wystarcza do spełnienia obowiązków wobec ARiMR
/// i inspekcji. Premium oszczędza czas, nigdy nie warunkuje dokumentacji.
class DostepFunkcji {
  const DostepFunkcji({required this.maPremium});

  /// Dostęp bez wykupionego premium — stan domyślny.
  const DostepFunkcji.darmowa() : maPremium = false;

  final bool maPremium;

  /// Funkcje wymagane przepisami — darmowe zawsze i bezwarunkowo.
  /// Zmiana tej listy to zmiana obietnicy danej rolnikowi; nie ruszać bez
  /// decyzji opisanej w planie.
  static const Set<Funkcja> wymaganePrzepisami = {
    Funkcja.dodawanieDzialekPoNumerze,
    Funkcja.wpisZabiegu,
    Funkcja.listaDopuszczonychSrodkow,
    Funkcja.karencjaWpisRecznie,
    Funkcja.trzyRejestryPodgladWydrukEksport,
    Funkcja.kalendarzObowiazkow,
    Funkcja.ewidencjaNawozeniaILimitAzotu,
    Funkcja.kopiaDanychDoPliku,
    Funkcja.rejestrStadaITerminy,
  };

  /// Funkcje oszczędzające czas — dostępne po wykupieniu premium.
  static const Set<Funkcja> _tylkoPremium = {
    Funkcja.importDzialekZWnioskuPdf,
    Funkcja.odczytZdjeciaEtykiety,
    Funkcja.odczytZdjeciaOpakowaniaNawozu,
    Funkcja.zabiegNaWieluPolach,
    Funkcja.karencjaZBazyEtykiet,
    Funkcja.zestawienieDoWniosku,
    Funkcja.kompletNaKontrole,
    Funkcja.ostrzezeniaPrzedBledem,
    Funkcja.planNawozeniaAzotem,
    Funkcja.programWindows,
    Funkcja.synchronizacja,
    Funkcja.wysylkaDoIrzplus,
    Funkcja.kilkaGospodarstw,
    Funkcja.magazyn,
    Funkcja.kosztyIPrzychody,
  };

  bool czyDostepna(Funkcja funkcja) {
    if (wymaganePrzepisami.contains(funkcja)) {
      return true;
    }
    return maPremium || !_tylkoPremium.contains(funkcja);
  }

  /// Czy wolno pokazać zachętę do premium w danym miejscu.
  /// Podczas wpisu zabiegu — nigdy (plan, pkt 8).
  bool czyMoznaZaproponowacPremium({required bool trwaWpisZabiegu}) =>
      !maPremium && !trwaWpisZabiegu;
}
