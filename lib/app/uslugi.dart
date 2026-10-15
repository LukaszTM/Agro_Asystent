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
    required this.zabiegi,
    required this.srodki,
    this.dostep = const DostepFunkcji.darmowa(),
  });

  final String gospodarstwoId;
  final String urzadzenie;
  final RepozytoriumPol pola;
  final RepozytoriumZabiegow zabiegi;
  final SlownikSrodkow srodki;
  final DostepFunkcji dostep;
}
