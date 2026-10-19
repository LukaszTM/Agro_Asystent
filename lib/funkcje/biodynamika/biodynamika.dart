import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'astronomia.dart';

/// Żywioł i praca, którą tradycja wiąże z dniem.
class ZywiolBiodynamiczny {
  const ZywiolBiodynamiczny({
    required this.id,
    required this.nazwa,
    required this.praca,
    required this.opis,
  });

  factory ZywiolBiodynamiczny.zJson(Map<String, dynamic> json) =>
      ZywiolBiodynamiczny(
        id: json['id'] as String,
        nazwa: json['nazwa'] as String,
        praca: json['praca'] as String,
        opis: json['opis'] as String,
      );

  final String id;
  final String nazwa;

  /// Co tradycja radzi robić: „korzeń", „liść", „kwiat", „owoc".
  final String praca;

  final String opis;
}

/// Gwiazdozbiór, w którym stoi Księżyc.
class ZnakZodiaku {
  const ZnakZodiaku({
    required this.nazwa,
    required this.odStopni,
    required this.zywiol,
  });

  final String nazwa;

  /// Początek odcinka na ekliptyce gwiazdowej.
  final double odStopni;

  final ZywiolBiodynamiczny zywiol;
}

/// Nazwa fazy Księżyca dla danej elongacji.
class FazaKsiezyca {
  const FazaKsiezyca({
    required this.nazwa,
    required this.odStopni,
    required this.rosnie,
  });

  final String nazwa;
  final double odStopni;

  /// Czy Księżyca przybywa.
  final bool rosnie;
}

/// Jedna z czterech faz głównych: nów, pierwsza kwadra, pełnia, ostatnia
/// kwadra — elongacja, przy której wypada.
class FazaGlowna {
  const FazaGlowna({required this.nazwa, required this.stopnie});

  final String nazwa;
  final double stopnie;
}

/// Ćwiartka obiegu Księżyca między dwiema fazami głównymi i to, co tradycja
/// radzi w niej siać. `praca == null` znaczy: czas na pracę w glebie,
/// nie na siew.
class KwadraSiewu {
  const KwadraSiewu({
    required this.nr,
    required this.od,
    required this.do_,
    required this.praca,
    required this.opis,
  });

  final int nr;
  final String od;
  final String do_;

  /// „liść", „owoc", „korzeń" — albo `null`, gdy kwadra jest bez siewu.
  final String? praca;

  final String opis;

  bool get bezSiewu => praca == null;
}

/// Zasady oznaczeń siewnych — dane z pliku, tak jak reszta kalendarza.
///
/// Oznaczenia są takie, jak w drukowanych kalendarzach rolników: rączka
/// siewna (dobry dzień), dwie rączki (bardzo dobry), przekreślona rączka
/// (zły). To umowa tradycji, nie przepis.
class SiewBiodynamiczny {
  const SiewBiodynamiczny({
    required this.opis,
    required this.kwadry,
    required this.fazyGlowne,
  });

  factory SiewBiodynamiczny.zJson(Map<String, dynamic> json) =>
      SiewBiodynamiczny(
        opis: json['opis'] as String,
        kwadry: [
          for (final wpis in json['kwadry'] as List<dynamic>)
            KwadraSiewu(
              nr: (wpis as Map<String, dynamic>)['nr'] as int,
              od: wpis['od'] as String,
              do_: wpis['do'] as String,
              praca: wpis['praca'] as String?,
              opis: wpis['opis'] as String,
            ),
        ],
        fazyGlowne: [
          for (final wpis in json['fazy_glowne'] as List<dynamic>)
            FazaGlowna(
              nazwa: (wpis as Map<String, dynamic>)['nazwa'] as String,
              stopnie: (wpis['stopnie'] as num).toDouble(),
            ),
        ],
      );

  final String opis;

  /// Cztery kwadry w kolejności od nowiu.
  final List<KwadraSiewu> kwadry;

  /// Fazy główne uporządkowane rosnąco po elongacji.
  final List<FazaGlowna> fazyGlowne;

  /// Kwadra dla elongacji 0–360: pierwsza od nowiu do pierwszej kwadry itd.
  KwadraSiewu kwadraDla(double elongacja) {
    final ile = kwadry.length;
    final numer = ((elongacja % 360) / (360 / ile)).floor().clamp(0, ile - 1);
    return kwadry[numer];
  }
}

/// Faza główna, która wypada danego dnia — z godziną.
class ZmianaFazy {
  const ZmianaFazy({required this.faza, required this.okolo});

  final FazaGlowna faza;

  /// Przybliżona godzina (czas lokalny urządzenia).
  final DateTime okolo;

  String get godzinaOpis =>
      '${okolo.hour}:${okolo.minute.toString().padLeft(2, '0')}';
}

/// Jak tradycja ocenia dzień pod siew.
enum OcenaSiewu {
  /// Dzień fazy głównej — przekreślona rączka.
  zly,

  /// Kwadra sprzyja siewowi — jedna rączka.
  dobry,

  /// Kwadra i gwiazdozbiór mówią to samo — dwie rączki.
  bardzoDobry,

  /// Czwarta kwadra: praca w glebie, nie siew — bez rączki.
  bezSiewu;

  String get dlaRolnika => switch (this) {
    OcenaSiewu.zly => 'dzień zły do siewu',
    OcenaSiewu.dobry => 'dobry dzień do siewu',
    OcenaSiewu.bardzoDobry => 'bardzo dobry dzień do siewu',
    OcenaSiewu.bezSiewu => 'prace w glebie, nie siew',
  };
}

/// Słownik kalendarza biodynamicznego — dane z pliku, nie z kodu.
///
/// Granice gwiazdozbiorów, przypisanie żywiołów i nazwy faz to **umowa
/// tradycji**, nie przepis prawa. Trzymamy je tak samo jak reguły prawne:
/// w pliku z numerem wersji, żeby dało się je poprawić bez ruszania kodu.
class SlownikBiodynamiczny {
  const SlownikBiodynamiczny({
    required this.wersja,
    required this.zastrzezenie,
    required this.dokladnosc,
    required this.ayanamsaJ2000,
    required this.ayanamsaNaRok,
    required this.znaki,
    required this.fazy,
    required this.siew,
  });

  factory SlownikBiodynamiczny.zTekstuJson(String tekst) {
    final json = jsonDecode(tekst) as Map<String, dynamic>;
    final zywioly = <String, ZywiolBiodynamiczny>{
      for (final wpis in json['zywioly'] as List<dynamic>)
        (wpis as Map<String, dynamic>)['id'] as String:
            ZywiolBiodynamiczny.zJson(wpis),
    };
    final ayanamsa = json['ayanamsa'] as Map<String, dynamic>;
    return SlownikBiodynamiczny(
      wersja: json['wersja'] as String,
      zastrzezenie: json['zastrzezenie'] as String,
      dokladnosc: json['dokladnosc'] as String,
      ayanamsaJ2000: (ayanamsa['stopnieJ2000'] as num).toDouble(),
      ayanamsaNaRok: (ayanamsa['przyrostNaRok'] as num).toDouble(),
      znaki: [
        for (final wpis in json['znaki'] as List<dynamic>)
          ZnakZodiaku(
            nazwa: (wpis as Map<String, dynamic>)['nazwa'] as String,
            odStopni: (wpis['odStopni'] as num).toDouble(),
            zywiol: zywioly[wpis['zywiol'] as String]!,
          ),
      ],
      fazy: [
        for (final wpis in json['fazy'] as List<dynamic>)
          FazaKsiezyca(
            nazwa: (wpis as Map<String, dynamic>)['nazwa'] as String,
            odStopni: (wpis['odStopni'] as num).toDouble(),
            rosnie: wpis['rosnie'] as bool,
          ),
      ],
      siew: SiewBiodynamiczny.zJson(json['siew'] as Map<String, dynamic>),
    );
  }

  final String wersja;

  /// Zdanie, które musi stać przy każdym pokazaniu kalendarza.
  final String zastrzezenie;

  /// Czego ten rachunek nie obiecuje.
  final String dokladnosc;

  /// Przesunięcie zodiaku zwrotnikowego względem gwiazdowego w J2000.
  final double ayanamsaJ2000;

  /// Przyrost tego przesunięcia na rok (precesja).
  final double ayanamsaNaRok;

  final List<ZnakZodiaku> znaki;
  final List<FazaKsiezyca> fazy;

  /// Oznaczenia siewne: kwadry i fazy główne.
  final SiewBiodynamiczny siew;

  /// Przesunięcie zodiaków na daną chwilę.
  double ayanamsa(DateTime chwila) {
    final lata =
        chwila.toUtc().difference(DateTime.utc(2000, 1, 1, 12)).inDays / 365.25;
    return ayanamsaJ2000 + ayanamsaNaRok * lata;
  }

  /// Długość gwiazdowa — od niej zależy gwiazdozbiór.
  double gwiazdowa(double zwrotnikowa, DateTime chwila) {
    final przesunieta = (zwrotnikowa - ayanamsa(chwila)) % 360;
    return przesunieta < 0 ? przesunieta + 360 : przesunieta;
  }

  ZnakZodiaku znakDla(double dlugoscGwiazdowa) {
    var wybrany = znaki.last;
    for (final znak in znaki) {
      if (dlugoscGwiazdowa >= znak.odStopni) {
        wybrany = znak;
      }
    }
    return wybrany;
  }

  FazaKsiezyca fazaDla(double elongacja) {
    // Pierwszy wpis („nów") leży na przejściu przez zero, więc obejmuje
    // i koniec, i początek koła.
    if (elongacja >= fazy.first.odStopni) {
      return fazy.first;
    }
    var wybrana = fazy.first;
    for (final faza in fazy.skip(1)) {
      if (elongacja >= faza.odStopni) {
        wybrana = faza;
      }
    }
    return wybrana;
  }
}

/// Zmiana gwiazdozbioru w ciągu dnia — wtedy zmienia się też rodzaj pracy.
class ZmianaZnaku {
  const ZmianaZnaku({required this.okolo, required this.z, required this.na});

  /// Przybliżona godzina zmiany (czas lokalny urządzenia).
  final DateTime okolo;

  /// Gwiazdozbiór od północy do tej godziny.
  final ZnakZodiaku z;

  /// Gwiazdozbiór od tej godziny do końca dnia.
  final ZnakZodiaku na;

  String get godzinaOpis =>
      '${okolo.hour.toString().padLeft(2, '0')}:'
      '${okolo.minute.toString().padLeft(2, '0')}';
}

/// Jeden dzień kalendarza.
class DzienBiodynamiczny {
  const DzienBiodynamiczny({
    required this.data,
    required this.znak,
    required this.faza,
    required this.elongacja,
    required this.oswietlenie,
    required this.kwadra,
    this.zmiana,
    this.zmianaFazy,
  });

  final DateTime data;
  final ZnakZodiaku znak;
  final FazaKsiezyca faza;

  /// Ćwiartka obiegu i to, co tradycja radzi w niej siać.
  final KwadraSiewu kwadra;

  /// Faza główna wypadająca tego dnia — `null` w zwykły dzień.
  final ZmianaFazy? zmianaFazy;

  /// Odległość kątowa od Słońca w południe (0–360 stopni).
  final double elongacja;

  /// Jaka część tarczy jest oświetlona (0–1).
  final double oswietlenie;

  /// `null`, gdy Księżyc stoi w jednym gwiazdozbiorze przez cały dzień.
  final ZmianaZnaku? zmiana;

  ZywiolBiodynamiczny get zywiol => znak.zywiol;

  /// „korzeń", „liść", „kwiat" albo „owoc".
  String get praca => znak.zywiol.praca;

  /// Czy Księżyca przybywa. Liczymy to z elongacji, a nie z nazwy fazy —
  /// „nów" obejmuje koniec i początek obiegu.
  bool get rosnie => elongacja < 180;

  String get oswietlenieOpis => '${(oswietlenie * 100).round()} %';

  /// Rączki siewne: zły w dzień fazy głównej, bez rączki w kwadrze bez
  /// siewu, dwie rączki, gdy gwiazdozbiór mówi to samo, co kwadra.
  OcenaSiewu get ocenaSiewu {
    if (zmianaFazy != null) {
      return OcenaSiewu.zly;
    }
    if (kwadra.bezSiewu) {
      return OcenaSiewu.bezSiewu;
    }
    return kwadra.praca == praca ? OcenaSiewu.bardzoDobry : OcenaSiewu.dobry;
  }
}

/// Kalendarz biodynamiczny liczony na urządzeniu.
///
/// **To tradycja, nie przepis.** Terminy zabiegów, karencje i obowiązki
/// biorą się z rozporządzeń i etykiet — nigdy stąd (CLAUDE.md, reguła 1
/// i 5). Kalendarz jest dodatkiem informacyjnym i tak ma być podpisany na
/// każdym ekranie.
class KalendarzBiodynamiczny {
  const KalendarzBiodynamiczny(this.slownik);

  final SlownikBiodynamiczny slownik;

  DzienBiodynamiczny dzien(DateTime dzien) {
    final poczatek = DateTime(dzien.year, dzien.month, dzien.day);
    final poludnie = poczatek.add(const Duration(hours: 12));
    final jd = Astronomia.dzienJulianski(poludnie);
    final znak = _znakO(poludnie);
    final elongacja = Astronomia.elongacja(jd);

    return DzienBiodynamiczny(
      data: poczatek,
      znak: znak,
      faza: slownik.fazaDla(elongacja),
      elongacja: elongacja,
      oswietlenie: Astronomia.oswietlenie(jd),
      kwadra: slownik.siew.kwadraDla(elongacja),
      zmiana: _zmiana(poczatek),
      zmianaFazy: _zmianaFazy(poczatek),
    );
  }

  double _elongacjaO(DateTime chwila) =>
      Astronomia.elongacja(Astronomia.dzienJulianski(chwila));

  /// Faza główna, jeśli wypada tego dnia. Elongacja rośnie około 12 stopni
  /// na dobę, więc między północami przechodzi najwyżej przez jeden
  /// z czterech progów.
  ZmianaFazy? _zmianaFazy(DateTime poczatekDnia) {
    final koniecDnia = poczatekDnia.add(const Duration(days: 1));
    final przed = _elongacjaO(poczatekDnia);
    final po = _elongacjaO(koniecDnia);
    final przebyte = (po - przed + 360) % 360;
    for (final faza in slownik.siew.fazyGlowne) {
      final doProgu = (faza.stopnie - przed + 360) % 360;
      if (doProgu >= przebyte) {
        continue;
      }
      // Połowienie przedziału do minuty — próg przechodzi się raz.
      var wczesniej = poczatekDnia;
      var pozniej = koniecDnia;
      while (pozniej.difference(wczesniej).inMinutes > 1) {
        final srodek = wczesniej.add(
          Duration(minutes: pozniej.difference(wczesniej).inMinutes ~/ 2),
        );
        final odPrzed = (_elongacjaO(srodek) - przed + 360) % 360;
        if (odPrzed < doProgu) {
          wczesniej = srodek;
        } else {
          pozniej = srodek;
        }
      }
      return ZmianaFazy(faza: faza, okolo: pozniej);
    }
    return null;
  }

  /// Siedem dni od podanego dnia włącznie.
  List<DzienBiodynamiczny> tydzien(DateTime od) => [
    for (var numer = 0; numer < 7; numer++)
      dzien(DateTime(od.year, od.month, od.day).add(Duration(days: numer))),
  ];

  /// Cały miesiąc kalendarzowy.
  List<DzienBiodynamiczny> miesiac(int rok, int miesiac) {
    final dni = DateTime(rok, miesiac + 1, 0).day;
    return [
      for (var numer = 1; numer <= dni; numer++)
        dzien(DateTime(rok, miesiac, numer)),
    ];
  }

  ZnakZodiaku _znakO(DateTime chwila) {
    final jd = Astronomia.dzienJulianski(chwila);
    return slownik.znakDla(
      slownik.gwiazdowa(Astronomia.dlugoscKsiezyca(jd), chwila),
    );
  }

  /// Godzina, o której Księżyc wchodzi w następny gwiazdozbiór — jeśli
  /// wypada tego dnia. Księżyc zmienia znak co mniej więcej dwa i pół
  /// dnia, więc zmiana jest najwyżej jedna.
  ZmianaZnaku? _zmiana(DateTime poczatekDnia) {
    final koniecDnia = poczatekDnia.add(const Duration(days: 1));
    final przed = _znakO(poczatekDnia);
    final po = _znakO(koniecDnia);
    if (przed.nazwa == po.nazwa) {
      return null;
    }

    var wczesniej = poczatekDnia;
    var pozniej = koniecDnia;
    // Połowienie przedziału do minuty — dokładniej i tak nie warto, bo
    // granice gwiazdozbiorów są umowne.
    while (pozniej.difference(wczesniej).inMinutes > 1) {
      final srodek = wczesniej.add(
        Duration(minutes: pozniej.difference(wczesniej).inMinutes ~/ 2),
      );
      if (_znakO(srodek).nazwa == przed.nazwa) {
        wczesniej = srodek;
      } else {
        pozniej = srodek;
      }
    }
    return ZmianaZnaku(okolo: pozniej, z: przed, na: po);
  }
}

/// Wczytuje słownik kalendarza z pliku dołączonego do aplikacji.
class ZrodloBiodynamiki {
  ZrodloBiodynamiki({AssetBundle? paczka}) : _paczka = paczka ?? rootBundle;

  static const String sciezka = 'assets/dane/kalendarz_biodynamiczny.json';

  final AssetBundle _paczka;
  SlownikBiodynamiczny? _wPamieci;

  Future<SlownikBiodynamiczny> wczytaj() async {
    final juz = _wPamieci;
    if (juz != null) {
      return juz;
    }
    final slownik = SlownikBiodynamiczny.zTekstuJson(
      await _paczka.loadString(sciezka),
    );
    _wPamieci = slownik;
    return slownik;
  }
}
