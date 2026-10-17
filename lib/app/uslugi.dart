import '../funkcje/dokumenty/usluga_dokumentow.dart';
import '../funkcje/dzialki/import_wniosku.dart';
import '../funkcje/dzialki/klient_uldk.dart';
import '../funkcje/dzialki/repozytorium_dzialek.dart';
import '../funkcje/dzialki/repozytorium_pol.dart';
import '../funkcje/dzialki/historia_upraw.dart';
import '../funkcje/dzialki/uprawy_pola.dart';
import '../funkcje/warunkowosc/zmianowanie.dart';
import '../funkcje/dzialki/slownik_upraw.dart';
import '../funkcje/dzialki/zrodlo_pliku.dart';
import '../funkcje/nawozenie/ewidencja_nawozenia.dart';
import '../funkcje/nawozenie/nawoz.dart';
import '../funkcje/nawozenie/plan_nawozenia.dart';
import '../funkcje/nawozenie/terminy_azotowe.dart';
import '../funkcje/odczyt/czytnik_zdjecia.dart';
import '../funkcje/odczyt/odczyt_etykiety.dart';
import '../funkcje/terminy/kalendarz_terminow.dart';
import '../funkcje/terminy/przypomnienia.dart';
import '../funkcje/terminy/ustawienia_przypomnien.dart';
import '../funkcje/ustawienia/gospodarstwa.dart';
import '../funkcje/ustawienia/wybor_wygladu.dart';
import '../funkcje/ustawienia/zwierzeta_w_gospodarstwie.dart';
import '../funkcje/zwierzeta/stado.dart';
import '../funkcje/zabiegi/rejestr_zabiegow.dart';
import '../funkcje/zabiegi/repozytorium_zabiegow.dart';
import '../funkcje/zabiegi/slownik_srodkow.dart';
import '../rdzen/dostep/dostep_funkcji.dart';
import '../rdzen/reguly/regula_prawna.dart';
import '../rdzen/uslugi/kopia/kopia_danych.dart';
import '../rdzen/uslugi/kopia/scalanie.dart';

/// To, czego ekrany potrzebują do pracy. Składane raz, przy starcie aplikacji,
/// i podawane dalej w konstruktorach — bez globalnych zmiennych, żeby testy
/// mogły podstawić własną bazę.
class Uslugi {
  const Uslugi({
    required this.gospodarstwoId,
    required this.nazwaGospodarstwa,
    required this.urzadzenie,
    required this.pola,
    required this.dzialki,
    required this.zabiegi,
    required this.rejestr,
    required this.srodki,
    required this.uprawy,
    required this.reguly,
    required this.importWniosku,
    required this.zrodloPliku,
    required this.dokumenty,
    required this.czytnikZdjecia,
    required this.czytnikEtykiety,
    required this.nawozy,
    required this.nawozenie,
    required this.planNawozenia,
    required this.terminyAzotowe,
    required this.stado,
    required this.gospodarstwa,
    required this.kopia,
    required this.zwierzetaWGospodarstwie,
    required this.wyglad,
    required this.kalendarz,
    required this.profil,
    required this.przypomnienia,
    required this.ustawieniaPrzypomnien,
    this.uldk = const KlientUldk(),
    this.dostep = const DostepFunkcji.darmowa(),
  });

  final String gospodarstwoId;

  /// Nazwa gospodarstwa — stoi na każdym wydruku i w eksporcie.
  final String nazwaGospodarstwa;

  final String urzadzenie;
  final RepozytoriumPol pola;
  final RepozytoriumDzialek dzialki;
  final RepozytoriumZabiegow zabiegi;

  /// Odczyt wpisów do podglądu, wydruku i eksportu.
  final RejestrZabiegow rejestr;

  final SlownikSrodkow srodki;

  /// Uprawy do wyboru przy zakładaniu pola — z kodem EPPO i z gatunkami
  /// do wyboru przy nazwie rodzajowej.
  final SlownikUpraw uprawy;

  /// Słownik reguł prawnych — stąd bierzemy listę pól wymaganych w ewidencji.
  final SlownikRegul reguly;

  /// Zapis odczytanego wniosku do bazy gospodarstwa.
  final ImportWniosku importWniosku;

  /// Wybór pliku wniosku — w aplikacji okno systemowe, w testach plik z dysku.
  final ZrodloPliku zrodloPliku;

  /// Podgląd, wydruk PDF i eksport CSV/XLSX — zawsze darmowe (plan, pkt 8).
  final UslugaDokumentow dokumenty;

  /// Odczyt tekstu ze zdjęcia — etykieta środka, worek nawozu.
  final CzytnikZdjecia czytnikZdjecia;

  /// Rozpoznanie etykiety w słowniku środków.
  final CzytnikEtykiety czytnikEtykiety;

  /// Spis nawozów gospodarstwa.
  final RepozytoriumNawozow nawozy;

  /// Ewidencja nawożenia i limit azotu z nawozów naturalnych.
  final EwidencjaNawozenia nawozenie;

  /// Zestawienie azotu i sprawdzenie, czy przepis wymaga planu nawożenia.
  final PlanNawozenia planNawozenia;

  /// Graniczne terminy stosowania nawozów azotowych — z wykazem gmin.
  final TerminyAzotowe terminyAzotowe;

  /// Rejestr stada: zwierzęta, zdarzenia i DJP.
  final RepozytoriumStada stado;

  /// Lista gospodarstw, wybór aktywnego i konto (plan, pkt 7).
  final RepozytoriumGospodarstw gospodarstwa;

  /// Uprawy pola po sezonach — z nich liczy się zmianowanie (GAEC 7).
  /// Pracują na tej samej bazie co repozytorium pól, więc biorą ją stąd.
  RepozytoriumUprawPola get uprawyPola => RepozytoriumUprawPola(kopia.baza);

  /// Norma GAEC 7: zmianowanie i dywersyfikacja upraw.
  Zmianowanie get zmianowanie =>
      Zmianowanie(pola: pola, uprawy: uprawyPola, reguly: reguly);

  /// Historia upraw pola razem z zakresem lat z przepisu.
  UslugaHistoriiUpraw get historiaUpraw =>
      UslugaHistoriiUpraw(pola: pola, uprawy: uprawyPola, reguly: reguly);

  /// Kopia danych do pliku — zawsze darmowa (plan, pkt 8).
  final KopiaDanych kopia;

  /// Dołączenie danych z kopii zrobionej na **drugim** urządzeniu —
  /// synchronizacja przez dysk użytkownika (plan, pkt 2). Pracuje na tej
  /// samej bazie i w tym samym formacie pliku co kopia, więc bierze je
  /// od niej, a nie z osobnego wstrzyknięcia.
  Scalanie get scalanie => Scalanie(
    baza: kopia.baza,
    wersjaSchematu: kopia.wersjaSchematu,
    urzadzenie: urzadzenie,
  );

  /// Czy gospodarstwo ma zwierzęta. Aplikacja nie prowadzi rejestru stada
  /// (produkcja zwierzęca poza zakresem), więc pyta o to raz — od tego
  /// zależy, czy obowiązki od DJP są „do sprawdzenia".
  final ZwierzetaWGospodarstwie zwierzetaWGospodarstwie;

  /// Wybrany wygląd telefonu („Prosty" / „Nowoczesny"). Oba pokazują te same
  /// dane — różni się tylko warstwa ekranów (plan, pkt 5).
  final WyborWygladu wyglad;

  /// Kalendarz obowiązków: terminy z przepisów i karencje z własnych zabiegów.
  final KalendarzTerminow kalendarz;

  /// Powierzchnia, DJP i deklaracje — od nich zależy, które obowiązki
  /// się włączają (plan, pkt 3).
  final ProfilZBazy profil;

  /// Powiadomienia w telefonie.
  final UslugaPrzypomnien przypomnienia;

  /// Czy rolnik chce przypomnień.
  final UstawieniaPrzypomnien ustawieniaPrzypomnien;

  /// Granice działek pobieramy tylko przy dodawaniu działki; potem wszystko
  /// działa bez internetu.
  final KlientUldk uldk;

  final DostepFunkcji dostep;

  /// Te same usługi, ale dla innego gospodarstwa. Wszystkie repozytoria
  /// pracują na jednej bazie i same filtrują po gospodarstwie, więc
  /// przełączenie to zmiana identyfikatora i nazwy — bez ponownego
  /// otwierania bazy i rozpakowywania słowników.
  Uslugi dlaGospodarstwa({required String id, required String nazwa}) => Uslugi(
    gospodarstwoId: id,
    nazwaGospodarstwa: nazwa,
    urzadzenie: urzadzenie,
    pola: pola,
    dzialki: dzialki,
    zabiegi: zabiegi,
    rejestr: rejestr,
    srodki: srodki,
    uprawy: uprawy,
    reguly: reguly,
    importWniosku: importWniosku,
    zrodloPliku: zrodloPliku,
    dokumenty: dokumenty,
    czytnikZdjecia: czytnikZdjecia,
    czytnikEtykiety: czytnikEtykiety,
    nawozy: nawozy,
    nawozenie: nawozenie,
    planNawozenia: planNawozenia,
    terminyAzotowe: terminyAzotowe,
    stado: stado,
    gospodarstwa: gospodarstwa,
    kopia: kopia,
    zwierzetaWGospodarstwie: zwierzetaWGospodarstwie,
    wyglad: wyglad,
    kalendarz: kalendarz,
    profil: profil,
    przypomnienia: przypomnienia,
    ustawieniaPrzypomnien: ustawieniaPrzypomnien,
    uldk: uldk,
    dostep: dostep,
  );
}
