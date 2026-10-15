import '../funkcje/dokumenty/usluga_dokumentow.dart';
import '../funkcje/dzialki/import_wniosku.dart';
import '../funkcje/dzialki/klient_uldk.dart';
import '../funkcje/dzialki/repozytorium_dzialek.dart';
import '../funkcje/dzialki/repozytorium_pol.dart';
import '../funkcje/dzialki/zrodlo_pliku.dart';
import '../funkcje/nawozenie/ewidencja_nawozenia.dart';
import '../funkcje/nawozenie/nawoz.dart';
import '../funkcje/nawozenie/plan_nawozenia.dart';
import '../funkcje/odczyt/czytnik_zdjecia.dart';
import '../funkcje/odczyt/odczyt_etykiety.dart';
import '../funkcje/terminy/kalendarz_terminow.dart';
import '../funkcje/terminy/przypomnienia.dart';
import '../funkcje/terminy/ustawienia_przypomnien.dart';
import '../funkcje/zabiegi/rejestr_zabiegow.dart';
import '../funkcje/zabiegi/repozytorium_zabiegow.dart';
import '../funkcje/zabiegi/slownik_srodkow.dart';
import '../rdzen/dostep/dostep_funkcji.dart';
import '../rdzen/reguly/regula_prawna.dart';

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
    required this.reguly,
    required this.importWniosku,
    required this.zrodloPliku,
    required this.dokumenty,
    required this.czytnikZdjecia,
    required this.czytnikEtykiety,
    required this.nawozy,
    required this.nawozenie,
    required this.planNawozenia,
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
}
