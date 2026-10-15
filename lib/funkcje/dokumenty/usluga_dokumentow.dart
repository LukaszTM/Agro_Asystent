import '../../rdzen/modele/zabieg.dart';
import '../../rdzen/reguly/regula_prawna.dart';
import '../zabiegi/rejestr_zabiegow.dart';
import 'dokument_ewidencji.dart';
import 'eksport_csv.dart';
import 'eksport_xlsx.dart';
import 'wydruk_pdf.dart';
import 'wyjscie_dokumentu.dart';

/// Dokumenty gospodarstwa: podgląd, wydruk PDF i eksport CSV/XLSX.
///
/// Wszystkie trzy są **zawsze darmowe** (plan, pkt 8) — nie ma tu żadnego
/// pytania o wersję płatną; decyzje o premium zapadają wyłącznie
/// w `lib/rdzen/dostep/`.
class UslugaDokumentow {
  const UslugaDokumentow({
    required this.rejestr,
    required this.reguly,
    required this.czcionki,
    required this.wyjscie,
  });

  final RejestrZabiegow rejestr;
  final SlownikRegul reguly;

  /// Czcionki wydruku wczytuje warstwa aplikacji — moduł nie sięga do zasobów.
  final Future<CzcionkiWydruku> Function() czcionki;

  final WyjscieDokumentu wyjscie;

  static const String mimeCsv = 'text/csv';
  static const String mimeXlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const String mimePdf = 'application/pdf';

  /// Rodzaje zabiegów, dla których mamy dokument w słowniku reguł.
  List<RodzajZabiegu> get dostepneRodzaje => [
    for (final wpis in BudowniczyDokumentu.rodzajeDokumentow.entries)
      if (reguly.obowiazek(wpis.value) != null) wpis.key,
  ];

  Obowiazek? obowiazek(RodzajZabiegu rodzaj) =>
      reguly.obowiazek(BudowniczyDokumentu.rodzajeDokumentow[rodzaj] ?? '');

  /// Składa dokument z wpisów rejestru. Zwraca `null`, gdy słownik reguł nie
  /// zna takiego dokumentu — wtedy nic nie udajemy.
  Future<DokumentEwidencji?> zbuduj({
    required String gospodarstwoId,
    required String gospodarstwo,
    required RodzajZabiegu rodzaj,
    String? numerProducenta,
    int? rok,
    DateTime? sporzadzono,
  }) async {
    final obowiazekDokumentu = obowiazek(rodzaj);
    if (obowiazekDokumentu == null) {
      return null;
    }
    final wpisy = await rejestr.wpisy(
      gospodarstwoId,
      filtr: FiltrRejestru(rodzaj: rodzaj, rok: rok),
    );
    return BudowniczyDokumentu.zbuduj(
      obowiazek: obowiazekDokumentu,
      // Na wydruku wpisy idą od najstarszego — tak czyta je kontrola.
      wpisy: wpisy.reversed.toList(growable: false),
      gospodarstwo: gospodarstwo,
      numerProducenta: numerProducenta,
      wersjaRegul: reguly.wersja,
      rok: rok,
      sporzadzono: sporzadzono,
    );
  }

  Future<void> wydrukujPdf(DokumentEwidencji dokument) async {
    final dane = await WydrukPdf.bajty(dokument, czcionki: await czcionki());
    await wyjscie.drukujPdf(dane: dane, nazwa: dokument.nazwaPliku('pdf'));
  }

  Future<void> zapiszPdf(DokumentEwidencji dokument) async {
    final dane = await WydrukPdf.bajty(dokument, czcionki: await czcionki());
    await wyjscie.udostepnij(
      dane: dane,
      nazwa: dokument.nazwaPliku('pdf'),
      typMime: mimePdf,
    );
  }

  Future<void> zapiszCsv(DokumentEwidencji dokument) => wyjscie.udostepnij(
    dane: EksportCsv.bajty(dokument),
    nazwa: dokument.nazwaPliku('csv'),
    typMime: mimeCsv,
  );

  Future<void> zapiszXlsx(DokumentEwidencji dokument) => wyjscie.udostepnij(
    dane: EksportXlsx.bajty(dokument),
    nazwa: dokument.nazwaPliku('xlsx'),
    typMime: mimeXlsx,
  );
}
