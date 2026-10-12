/// Funkcje aplikacji, których dostępność zależy od wersji (darmowa / premium).
///
/// Lista odpowiada tabeli z planu (pkt 8). Nowa funkcja płatna musi tu trafić —
/// to jedyne miejsce, w którym kod wie o podziale na wersje.
enum Funkcja {
  // Pola i mapa
  dodawanieDzialekPoNumerze,
  importDzialekZWnioskuPdf,

  // Wpis zabiegu
  wpisZabiegu,
  listaDopuszczonychSrodkow,
  odczytZdjeciaEtykiety,
  odczytZdjeciaOpakowaniaNawozu,
  zabiegNaWieluPolach,

  // Karencja
  karencjaWpisRecznie,
  karencjaZBazyEtykiet,

  // Dokumenty
  trzyRejestryPodgladWydrukEksport,
  zestawienieDoWniosku,
  kompletNaKontrole,

  // Terminy
  kalendarzObowiazkow,
  ostrzezeniaPrzedBledem,

  // Nawożenie
  ewidencjaNawozeniaILimitAzotu,
  planNawozeniaAzotem,

  // Urządzenia
  kopiaDanychDoPliku,
  programWindows,
  synchronizacja,

  // Zwierzęta
  rejestrStadaITerminy,
  wysylkaDoIrzplus,

  // Dodatki
  kilkaGospodarstw,
  magazyn,
  kosztyIPrzychody,
}
