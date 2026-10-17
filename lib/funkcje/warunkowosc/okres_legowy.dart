import '../../rdzen/reguly/regula_prawna.dart';
import '../../rdzen/wspolne/daty.dart';

/// Ostrzeżenie z normy GAEC 8 — przy wpisie pracy przy drzewach, rowach
/// albo oczkach wodnych.
///
/// Treść stoi tutaj, a nie w ekranach, bo oba wyglądy muszą mówić to samo.
/// Ostrzeżenie nie blokuje zapisu: praca mogła być już wykonana, a wpis
/// ma pokazywać prawdę.
class OstrzezenieOElementachKrajobrazu {
  const OstrzezenieOElementachKrajobrazu({
    required this.tresc,
    required this.coZrobic,
  });

  final String tresc;
  final String coZrobic;
}

/// Norma GAEC 8: elementy krajobrazu i okres lęgowy ptaków.
///
/// Okres zakazu, chronione rowy i oczka wodne pochodzą ze słownika reguł.
/// Rodzaj pracy wybiera rolnik z listy — aplikacja nie odgaduje z uwag,
/// co robił na polu.
class OkresLegowy {
  const OkresLegowy({required this.reguly});

  final SlownikRegul reguly;

  NormaGaec? get norma => reguly.warunkowosc.norma('gaec_8');

  PraceKrajobrazowe get prace => reguly.warunkowosc.praceKrajobrazowe;

  /// Praca ze słownika albo `null`, gdy słownik jej nie zna.
  PracaKrajobrazowa? praca(String? id) => prace.praca(id);

  /// Okres, w którym praca jest zabroniona, albo `null`.
  TerminNormy? terminZakazu(PracaKrajobrazowa praca) {
    final idTerminu = praca.idTerminuZakazu;
    if (idTerminu == null || praca.idNormy == null) {
      return null;
    }
    return reguly.warunkowosc.norma(praca.idNormy!)?.termin(idTerminu);
  }

  /// Ostrzeżenie przed zapisem pracy albo `null`, gdy nie ma o czym
  /// ostrzegać: praca nie dotyczy elementów krajobrazu albo dzień zabiegu
  /// wypada poza okresem zakazu.
  OstrzezenieOElementachKrajobrazu? ostrzezeniePrzedZapisem({
    required String? idPracy,
    required DateTime kiedy,
  }) {
    final wybrana = praca(idPracy);
    if (wybrana == null) {
      return null;
    }

    if (wybrana.zawszeOstrzegaj) {
      return OstrzezenieOElementachKrajobrazu(
        tresc: _coChronione,
        coZrobic:
            'Zapisz pracę tak, jak była — wpis ma pokazywać prawdę. Jeśli '
            'element był chroniony, przy kontroli liczy się to jako '
            'złamanie normy GAEC 8.',
      );
    }

    final termin = terminZakazu(wybrana);
    if (termin == null || !termin.obejmuje(kiedy)) {
      return null;
    }
    final od = Daty.dzienIMiesiac(termin.od);
    final doDnia = Daty.dzienIMiesiac(termin.doDnia);
    return OstrzezenieOElementachKrajobrazu(
      tresc:
          'Od $od do $doDnia nie przycina się drzew ani żywopłotów — to '
          'okres lęgowy ptaków (norma GAEC 8).',
      coZrobic:
          'Jeśli to wierzba, drzewo owocowe albo zagajnik o krótkiej '
          'rotacji, zakaz nie obowiązuje — wybierz wtedy tę pracę z listy. '
          'Pracę i tak możesz zapisać: dokumentacja ma być prawdziwa.',
    );
  }

  /// Zdanie o tym, czego norma chroni cały rok — z progów przepisu.
  String get _coChronione {
    final row = norma?.prog('row_chroniony_m')?.wartosc;
    final oczko = norma?.prog('oczko_wodne_m2')?.wartosc;
    final czesci = <String>[
      'drzew będących pomnikami przyrody',
      if (row != null) 'rowów do ${_liczba(row)} m szerokości',
      if (oczko != null) 'oczek wodnych mniejszych niż ${_liczba(oczko)} m²',
    ];
    return 'Norma GAEC 8 zabrania niszczenia ${_wyliczenie(czesci)}.';
  }

  static String _wyliczenie(List<String> czesci) {
    if (czesci.length < 2) {
      return czesci.isEmpty ? '' : czesci.single;
    }
    return '${czesci.sublist(0, czesci.length - 1).join(', ')} '
        'i ${czesci.last}';
  }

  static String _liczba(double wartosc) => wartosc == wartosc.roundToDouble()
      ? wartosc.toStringAsFixed(0)
      : wartosc.toStringAsFixed(1).replaceAll('.', ',');
}
