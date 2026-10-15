import 'package:path/path.dart' as sciezki;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

import '../funkcje/dzialki/repozytorium_pol.dart';
import '../funkcje/zabiegi/repozytorium_zabiegow.dart';
import '../funkcje/zabiegi/slownik_srodkow.dart';
import '../rdzen/baza/baza_gospodarstwa.dart';
import '../rdzen/baza/przygotowanie_slownikow.dart';
import 'uslugi.dart';

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
  final gospodarstwoId = await _zapewnijGospodarstwo(baza, urzadzenie);

  final sciezkaSlownikow = await const PrzygotowanieSlownikow().przygotuj(
    katalog: katalog,
  );
  final slowniki = await fabrykaBazy.openDatabase(
    sciezkaSlownikow,
    options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
  );

  return Uslugi(
    gospodarstwoId: gospodarstwoId,
    urzadzenie: urzadzenie,
    pola: RepozytoriumPol(baza),
    zabiegi: RepozytoriumZabiegow(baza),
    srodki: SlownikSrodkow(slowniki),
  );
}

Future<String> _zapewnijGospodarstwo(Database baza, String urzadzenie) async {
  final istniejace = await baza.query(
    'gospodarstwo',
    where: 'usuniety = 0',
    limit: 1,
  );
  if (istniejace.isNotEmpty) {
    return istniejace.first['id']! as String;
  }

  final czas = DateTime.now().toIso8601String();
  const id = 'gospodarstwo-1';
  await baza.insert('gospodarstwo', {
    'id': id,
    'nazwa': 'Moje gospodarstwo',
    'utworzono': czas,
    'zmieniono': czas,
    'urzadzenie': urzadzenie,
  });
  return id;
}
