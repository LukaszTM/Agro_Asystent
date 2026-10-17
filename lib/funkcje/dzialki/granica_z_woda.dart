/// Czy pole graniczy z wodą w rozumieniu normy GAEC 4.
///
/// Norma zabrania nawozów i środków ochrony roślin w pasie od brzegu wody,
/// ale nie każda woda się liczy: rowy węższe niż granica z przepisu są
/// wyłączone. Granice działek z ULDK tego nie powiedzą — szerokości rowu
/// nie ma w żadnej warstwie, którą telefon umie pobrać. Dlatego odpowiada
/// rolnik, a [nieznana] znaczy „jeszcze nie odpowiedział", nie „nie".
enum GranicaZWoda {
  tak('tak', 'Tak, graniczy z wodą', 'graniczy z wodą'),
  nie('nie', 'Nie graniczy z wodą', 'nie graniczy z wodą'),

  /// Rolnik jeszcze nie powiedział. Nie zgadujemy i nie ostrzegamy.
  nieznana('', 'Nie wiadomo', 'nieokreślone');

  const GranicaZWoda(this.wBazie, this.dlaRolnika, this.naWydruku);

  final String wBazie;
  final String dlaRolnika;
  final String naWydruku;

  static GranicaZWoda zBazy(String? wartosc) {
    if (wartosc == null || wartosc.isEmpty) {
      return nieznana;
    }
    return GranicaZWoda.values.firstWhere(
      (g) => g.wBazie == wartosc,
      orElse: () => nieznana,
    );
  }

  bool get znana => this != nieznana;

  /// Odpowiedzi do wyboru na ekranie — bez „nie wiadomo", bo to jest stan
  /// przed wyborem, a nie odpowiedź.
  static List<GranicaZWoda> get doWyboru =>
      GranicaZWoda.values.where((g) => g.znana).toList(growable: false);
}
