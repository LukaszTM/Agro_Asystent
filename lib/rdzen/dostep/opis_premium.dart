import 'funkcja.dart';

/// Co powiedzieć rolnikowi o funkcji płatnej — jedno miejsce dla obu
/// wyglądów.
///
/// Zasada z planu (pkt 8): wersja darmowa wystarcza do spełnienia
/// obowiązków, premium oszczędza czas. Dlatego każdy opis ma dwa zdania:
/// czego dotyczy dodatek i **jak to samo zrobić bez opłaty**. Nigdzie nie
/// piszemy „kup", bo aplikacja niczego nie sprzedaje w trakcie pracy.
///
/// Decyzja, czy funkcja jest płatna, nie zapada tutaj — to robi
/// [DostepFunkcji]. Tutaj są tylko słowa.
abstract final class OpisPremium {
  /// Zdanie, które musi stać przy każdym wyjaśnieniu: dokumentacji nigdy
  /// nie blokujemy za brak płatności (CLAUDE.md, reguła 4).
  static const String dokumentacjaDarmowa =
      'Wpisy, trzy rejestry, wydruk PDF i eksport CSV/XLSX są darmowe '
      'i zawsze będą.';

  /// Nazwa funkcji w języku rolnika.
  static String nazwa(Funkcja funkcja) => switch (funkcja) {
    Funkcja.importDzialekZWnioskuPdf => 'Wczytanie wniosku z PDF',
    Funkcja.odczytZdjeciaEtykiety => 'Rozpoznawanie etykiety ze zdjęcia',
    Funkcja.odczytZdjeciaOpakowaniaNawozu => 'Odczyt worka ze zdjęcia',
    Funkcja.zabiegNaWieluPolach => 'Jeden wpis na kilku polach',
    Funkcja.karencjaZBazyEtykiet => 'Karencja z bazy etykiet',
    Funkcja.zestawienieDoWniosku => 'Zestawienie do wniosku',
    Funkcja.kompletNaKontrole => 'Komplet na kontrolę',
    Funkcja.ostrzezeniaPrzedBledem => 'Ostrzeżenia przed błędem',
    Funkcja.planNawozeniaAzotem => 'Plan nawożenia azotem',
    Funkcja.programWindows => 'Program na komputer',
    Funkcja.synchronizacja => 'Synchronizacja między urządzeniami',
    Funkcja.wysylkaDoIrzplus => 'Wysyłka zgłoszeń do IRZplus',
    Funkcja.kilkaGospodarstw => 'Kilka gospodarstw',
    Funkcja.magazyn => 'Magazyn',
    Funkcja.kosztyIPrzychody => 'Koszty i przychody',
    _ => 'Ta funkcja',
  };

  /// Co zrobić bez opłaty. Pusty napis znaczy „nie ma zamiennika" — wtedy
  /// zostaje samo zdanie o darmowej dokumentacji.
  static String bezOplaty(Funkcja funkcja) => switch (funkcja) {
    Funkcja.importDzialekZWnioskuPdf =>
      'Działki dodasz po numerze ewidencyjnym, bez limitu, a pola wpiszesz '
          'ręcznie.',
    Funkcja.odczytZdjeciaEtykiety =>
      'Środek wybierzesz z listy dopuszczonych albo znajdziesz po nazwie.',
    Funkcja.odczytZdjeciaOpakowaniaNawozu =>
      'Nawóz wpiszesz ręcznie: nazwa i zawartość azotu z worka.',
    Funkcja.zabiegNaWieluPolach =>
      'Zrób osobny wpis na każdym polu — ewidencja wyjdzie taka sama.',
    Funkcja.karencjaZBazyEtykiet =>
      'Karencję wpiszesz ręcznie z etykiety; aplikacja policzy dzień zbioru.',
    Funkcja.zestawienieDoWniosku => '',
    Funkcja.kompletNaKontrole =>
      'Każdy rejestr wydrukujesz i wyeksportujesz osobno.',
    Funkcja.ostrzezeniaPrzedBledem => '',
    Funkcja.planNawozeniaAzotem =>
      'Ewidencję nawożenia i limit azotu masz w wersji darmowej.',
    Funkcja.programWindows => 'Na telefonie działa wszystko.',
    Funkcja.synchronizacja =>
      'Kopia danych do pliku jest darmowa — przeniesiesz nią dane na inny '
          'telefon.',
    Funkcja.kilkaGospodarstw =>
      'Jedno gospodarstwo działa w całości bez opłaty.',
    Funkcja.magazyn => '',
    Funkcja.kosztyIPrzychody => '',
    _ => '',
  };

  /// Pierwsze zdanie wyjaśnienia na ekranie.
  static String tresc(Funkcja funkcja) =>
      '${nazwa(funkcja)} należy do wersji płatnej.';

  /// Drugie zdanie: co zrobić. Zawsze kończy się obietnicą darmowej
  /// dokumentacji, żeby rolnik nie bał się, że bez opłaty nie udokumentuje
  /// gospodarstwa.
  static String coZrobic(Funkcja funkcja) {
    final zamiennik = bezOplaty(funkcja);
    return zamiennik.isEmpty
        ? dokumentacjaDarmowa
        : '$zamiennik $dokumentacjaDarmowa';
  }
}
