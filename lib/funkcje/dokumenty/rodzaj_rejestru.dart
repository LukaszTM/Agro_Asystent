import '../../rdzen/modele/zabieg.dart';

/// Rejestr, który aplikacja drukuje i eksportuje.
///
/// Plan (pkt 8) obiecuje **trzy rejestry**: ewidencję zabiegów środkami
/// ochrony roślin, ewidencję nawożenia azotem i rejestr ekoschematów.
/// Dwa ostatnie powstają z tych samych wpisów nawożenia, ale mają różne
/// kolumny i różną podstawę prawną — dlatego dokument wybiera się po
/// rejestrze, a nie po rodzaju zabiegu.
///
/// Kolumny każdego rejestru biorą się ze słownika reguł (`wymagane_pola`),
/// nie z tego pliku (CLAUDE.md, reguła 1).
enum RodzajRejestru {
  ewidencjaSor(
    idObowiazku: 'ewidencja_sor',
    zabiegi: RodzajZabiegu.oprysk,
    dlaRolnika: 'Opryski',
  ),
  nawozenieAzotem(
    idObowiazku: 'program_azotanowy_ewidencja',
    zabiegi: RodzajZabiegu.nawozenie,
    dlaRolnika: 'Nawożenie azotem',
  ),
  ekoschematy(
    idObowiazku: 'ekoschematy_rejestr',
    zabiegi: RodzajZabiegu.nawozenie,
    dlaRolnika: 'Ekoschematy',
  );

  const RodzajRejestru({
    required this.idObowiazku,
    required this.zabiegi,
    required this.dlaRolnika,
  });

  /// Obowiązek w słowniku reguł, z którego biorą się kolumny.
  final String idObowiazku;

  /// Rodzaj zabiegów, z których powstaje ten rejestr.
  final RodzajZabiegu zabiegi;

  /// Krótka nazwa na przycisk wyboru.
  final String dlaRolnika;
}
