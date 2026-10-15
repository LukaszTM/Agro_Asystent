import '../funkcje/dokumenty/usluga_dokumentow.dart';
import '../funkcje/dzialki/import_wniosku.dart';
import '../funkcje/dzialki/klient_uldk.dart';
import '../funkcje/dzialki/repozytorium_dzialek.dart';
import '../funkcje/dzialki/repozytorium_pol.dart';
import '../funkcje/dzialki/zrodlo_pliku.dart';
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

  /// Granice działek pobieramy tylko przy dodawaniu działki; potem wszystko
  /// działa bez internetu.
  final KlientUldk uldk;

  final DostepFunkcji dostep;
}
