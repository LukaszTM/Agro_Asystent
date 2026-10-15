import 'package:path/path.dart' as sciezki;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

import '../funkcje/dokumenty/usluga_dokumentow.dart';
import '../funkcje/dokumenty/wydruk_pdf.dart';
import '../funkcje/dzialki/import_wniosku.dart';
import '../funkcje/dzialki/repozytorium_dzialek.dart';
import '../funkcje/dzialki/repozytorium_pol.dart';
import '../funkcje/nawozenie/ewidencja_nawozenia.dart';
import '../funkcje/nawozenie/nawoz.dart';
import '../funkcje/nawozenie/plan_nawozenia.dart';
import '../funkcje/odczyt/odczyt_etykiety.dart';
import '../funkcje/terminy/kalendarz_terminow.dart';
import '../funkcje/terminy/ustawienia_przypomnien.dart';
import '../funkcje/zabiegi/rejestr_zabiegow.dart';
import '../funkcje/zabiegi/repozytorium_zabiegow.dart';
import '../funkcje/zabiegi/slownik_srodkow.dart';
import '../rdzen/baza/baza_gospodarstwa.dart';
import '../rdzen/baza/przygotowanie_slownikow.dart';
import '../rdzen/reguly/zrodlo_regul.dart';
import 'uslugi.dart';
import 'czytnik_zdjecia_urzadzenia.dart';
import 'przypomnienia_urzadzenia.dart';
import 'wyjscie_dokumentu_urzadzenia.dart';
import 'zrodlo_pliku_urzadzenia.dart';

/// Składa usługi przy starcie aplikacji: otwiera bazę gospodarstwa,
/// rozpakowuje słowniki i zakłada gospodarstwo, jeśli go jeszcze nie ma.
///
/// Wszystko dzieje się lokalnie — aplikacja nie potrzebuje internetu, żeby
/// ruszyć (plan, pkt 2).
Future<Uslugi> uruchom({
  DatabaseFactory? fabryka,
  String? katalogDanych,
  String urzadzenie = 'telefon',
}) async {
  final fabrykaBazy = fabryka ?? sqflite.databaseFactory;
  final katalog =
      katalogDanych ?? (await getApplicationDocumentsDirectory()).path;

  final baza = await BazaGospodarstwa.otworz(
    fabryka: fabrykaBazy,
    sciezka: sciezki.join(katalog, BazaGospodarstwa.nazwaPliku),
  );
  final gospodarstwo = await _zapewnijGospodarstwo(baza, urzadzenie);

  final sciezkaSlownikow = await const PrzygotowanieSlownikow().przygotuj(
    katalog: katalog,
  );
  final slowniki = await fabrykaBazy.openDatabase(
    sciezkaSlownikow,
    options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
  );

  final reguly = await ZrodloRegul().wczytaj();

  return Uslugi(
    gospodarstwoId: gospodarstwo.id,
    nazwaGospodarstwa: gospodarstwo.nazwa,
    urzadzenie: urzadzenie,
    pola: RepozytoriumPol(baza),
    dzialki: RepozytoriumDzialek(baza),
    zabiegi: RepozytoriumZabiegow(baza),
    rejestr: RejestrZabiegow(baza),
    srodki: SlownikSrodkow(slowniki),
    reguly: reguly,
    importWniosku: ImportWniosku(baza: baza, srodki: SlownikSrodkow(slowniki)),
    zrodloPliku: const ZrodloPlikuUrzadzenia(),
    dokumenty: UslugaDokumentow(
      rejestr: RejestrZabiegow(baza),
      reguly: reguly,
      czcionki: wczytajCzcionkiWydruku,
      wyjscie: const WyjscieDokumentuUrzadzenia(),
    ),
    czytnikZdjecia: CzytnikZdjeciaUrzadzenia(),
    czytnikEtykiety: CzytnikEtykiety(SlownikSrodkow(slowniki)),
    nawozy: RepozytoriumNawozow(baza),
    nawozenie: EwidencjaNawozenia(
      baza: baza,
      zabiegi: RepozytoriumZabiegow(baza),
      reguly: reguly,
    ),
    planNawozenia: PlanNawozenia(baza: baza, reguly: reguly),
    kalendarz: KalendarzTerminow(
      reguly: reguly,
      rejestr: RejestrZabiegow(baza),
    ),
    profil: ProfilZBazy(baza),
    przypomnienia: PrzypomnieniaUrzadzenia(),
    ustawieniaPrzypomnien: UstawieniaPrzypomnien(baza),
  );
}

/// Czcionki wydruku z zasobów aplikacji. Wczytujemy je dopiero przy pierwszym
/// wydruku — przy starcie nie są potrzebne.
Future<CzcionkiWydruku> wczytajCzcionkiWydruku() async {
  final zwykla = await rootBundle.load('assets/czcionki/dejavu_sans_pl.ttf');
  final pogrubiona = await rootBundle.load(
    'assets/czcionki/dejavu_sans_pl_bold.ttf',
  );
  return CzcionkiWydruku(
    zwykla: zwykla.buffer.asUint8List(),
    pogrubiona: pogrubiona.buffer.asUint8List(),
  );
}

typedef _Gospodarstwo = ({String id, String nazwa});

Future<_Gospodarstwo> _zapewnijGospodarstwo(
  Database baza,
  String urzadzenie,
) async {
  final istniejace = await baza.query(
    'gospodarstwo',
    where: 'usuniety = 0',
    limit: 1,
  );
  if (istniejace.isNotEmpty) {
    return (
      id: istniejace.first['id']! as String,
      nazwa: (istniejace.first['nazwa'] as String?) ?? 'Moje gospodarstwo',
    );
  }

  final czas = DateTime.now().toIso8601String();
  const id = 'gospodarstwo-1';
  const nazwa = 'Moje gospodarstwo';
  await baza.insert('gospodarstwo', {
    'id': id,
    'nazwa': nazwa,
    'utworzono': czas,
    'zmieniono': czas,
    'urzadzenie': urzadzenie,
  });
  return (id: id, nazwa: nazwa);
}
