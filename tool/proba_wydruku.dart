// Narzędzie dewelopera: wytwarza przykładowy wydruk i eksport do obejrzenia.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:agro_asystent/funkcje/dokumenty/dokument_ewidencji.dart';
import 'package:agro_asystent/funkcje/dokumenty/eksport_csv.dart';
import 'package:agro_asystent/funkcje/dokumenty/eksport_xlsx.dart';
import 'package:agro_asystent/funkcje/dokumenty/wydruk_pdf.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/rdzen/uslugi/pdf/tekst_pdf.dart';

/// Użycie: `dart run tool/proba_wydruku.dart <katalog wyjściowy>`
Future<void> main(List<String> argv) async {
  final katalog = Directory(argv.isEmpty ? 'dane/wynik' : argv.first)
    ..createSync(recursive: true);
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );
  final obowiazek = reguly.obowiazek('ewidencja_sor')!;

  final dokument = BudowniczyDokumentu.zbuduj(
    obowiazek: obowiazek,
    wpisy: const [],
    gospodarstwo: 'Gospodarstwo Łąki Górne',
    wersjaRegul: reguly.wersja,
    rok: 2026,
    sporzadzono: DateTime(2026, 10, 15),
  );
  final zWierszami = DokumentEwidencji(
    tytul: dokument.tytul,
    podstawa: dokument.podstawa,
    wersjaRegul: dokument.wersjaRegul,
    gospodarstwo: dokument.gospodarstwo,
    rok: dokument.rok,
    kolumny: dokument.kolumny,
    sporzadzono: dokument.sporzadzono,
    wiersze: [
      for (var i = 1; i <= 3; i++)
        WierszDokumentu(
          wartosci: [
            'Abydos 750 EC',
            'R-14/2025 h.r.',
            '1$i.05.2026',
            '08:30',
            '0,75 l/ha',
            '2,50 ha',
            'pszenica zwyczajna ozima',
            'TRZAW',
            'BBCH 29–59',
            'mączniak prawdziwy zbóż i traw',
            'opryskiwanie',
            '061506_2.0007.138',
          ],
          braki: const [],
        ),
    ],
  );

  final pdf = await WydrukPdf.bajty(
    zWierszami,
    czcionki: CzcionkiWydruku(
      zwykla: File('assets/czcionki/dejavu_sans_pl.ttf').readAsBytesSync(),
      pogrubiona: File('assets/czcionki/dejavu_sans_pl_bold.ttf')
          .readAsBytesSync(),
    ),
  );
  File('${katalog.path}/ewidencja.pdf').writeAsBytesSync(pdf);
  File('${katalog.path}/ewidencja.csv')
      .writeAsBytesSync(EksportCsv.bajty(zWierszami));
  File('${katalog.path}/ewidencja.xlsx')
      .writeAsBytesSync(EksportXlsx.bajty(zWierszami));

  for (final strona in OdczytTekstuPdf.strony(pdf)) {
    for (final wiersz in strona.wiersze()) {
      print(wiersz.map((s) => s.tekst).join(' | '));
    }
  }
  print('Pliki w ${katalog.path}');
}
