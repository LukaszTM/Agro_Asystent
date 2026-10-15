import '../funkcje/dzialki/klient_uldk.dart';
import '../funkcje/dzialki/repozytorium_dzialek.dart';
import '../funkcje/dzialki/repozytorium_pol.dart';
import '../funkcje/zabiegi/repozytorium_zabiegow.dart';
import '../funkcje/zabiegi/slownik_srodkow.dart';
import '../rdzen/dostep/dostep_funkcji.dart';

/// To, czego ekrany potrzebują do pracy. Składane raz, przy starcie aplikacji,
/// i podawane dalej w konstruktorach — bez globalnych zmiennych, żeby testy
/// mogły podstawić własną bazę.
class Uslugi {
  const Uslugi({
    required this.gospodarstwoId,
    required this.urzadzenie,
    required this.pola,
    required this.dzialki,
    required this.zabiegi,
    required this.srodki,
    this.uldk = const KlientUldk(),
    this.dostep = const DostepFunkcji.darmowa(),
  });

  final String gospodarstwoId;
  final String urzadzenie;
  final RepozytoriumPol pola;
  final RepozytoriumDzialek dzialki;
  final RepozytoriumZabiegow zabiegi;
  final SlownikSrodkow srodki;

  /// Granice działek pobieramy tylko przy dodawaniu działki; potem wszystko
  /// działa bez internetu.
  final KlientUldk uldk;

  final DostepFunkcji dostep;
}
