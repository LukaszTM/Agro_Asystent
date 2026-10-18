import '../dzialki/repozytorium_pol.dart';

/// Udział jednej uprawy w strukturze zasiewów gospodarstwa.
class UdzialUprawy {
  const UdzialUprawy({
    required this.uprawa,
    required this.powierzchniaAr,
    required this.liczbaPol,
  });

  /// Pusta nazwa znaczy „pole bez wpisanej uprawy". Nie zgadujemy, co tam
  /// rośnie — pokazujemy to jako osobną część wykresu (plan, pkt 11).
  final String uprawa;

  final int powierzchniaAr;
  final int liczbaPol;

  bool get nieznana => uprawa.trim().isEmpty;

  String get nazwa => nieznana ? 'Bez wpisanej uprawy' : uprawa;

  double get powierzchniaHa => powierzchniaAr / 100;

  String get powierzchniaOpis =>
      '${powierzchniaHa.toStringAsFixed(2).replaceAll('.', ',')} ha';

  /// Udział w całości jako ułamek (0–1).
  double udzial(int calosc) => calosc <= 0 ? 0 : powierzchniaAr / calosc;

  String udzialOpis(int calosc) {
    final procent = udzial(calosc) * 100;
    final zaokraglony = procent >= 10
        ? procent.toStringAsFixed(0)
        : procent.toStringAsFixed(1).replaceAll('.', ',');
    return '$zaokraglony %';
  }

  UdzialUprawy _zSuma(UdzialUprawy inna) => UdzialUprawy(
    uprawa: uprawa,
    powierzchniaAr: powierzchniaAr + inna.powierzchniaAr,
    liczbaPol: liczbaPol + inna.liczbaPol,
  );
}

/// Struktura zasiewów jednego sezonu: co i na ilu hektarach.
class StrukturaZasiewow {
  const StrukturaZasiewow({
    required this.sezon,
    required this.uprawy,
    required this.liczbaPol,
  });

  /// Sezon, z którego liczymy. `null`, gdy nie ma ani jednego pola.
  final int? sezon;

  /// Uprawy malejąco po powierzchni.
  final List<UdzialUprawy> uprawy;

  final int liczbaPol;

  bool get pusta => uprawy.isEmpty;

  int get powierzchniaAr =>
      uprawy.fold(0, (suma, udzial) => suma + udzial.powierzchniaAr);

  double get powierzchniaHa => powierzchniaAr / 100;

  String get powierzchniaOpis =>
      '${powierzchniaHa.toStringAsFixed(2).replaceAll('.', ',')} ha';

  /// Ile pól czeka na wpisanie uprawy.
  int get polaBezUprawy => uprawy
      .where((udzial) => udzial.nieznana)
      .fold(0, (suma, udzial) => suma + udzial.liczbaPol);

  /// Największe [ile] upraw; reszta schodzi do jednej pozycji „Pozostałe".
  ///
  /// Wykres z dwudziestoma kawałkami nie mówi nic — a rolnik i tak patrzy
  /// na to, co zajmuje najwięcej.
  List<UdzialUprawy> najwieksze(int ile) {
    if (ile < 1 || uprawy.length <= ile) {
      return uprawy;
    }
    final wiodace = uprawy.take(ile - 1).toList();
    final reszta = uprawy.skip(ile - 1).toList();
    return [
      ...wiodace,
      UdzialUprawy(
        uprawa: 'Pozostałe (${reszta.length})',
        powierzchniaAr: reszta.fold(0, (s, u) => s + u.powierzchniaAr),
        liczbaPol: reszta.fold(0, (s, u) => s + u.liczbaPol),
      ),
    ];
  }
}

/// Struktura zasiewów liczona z pól gospodarstwa.
///
/// Liczymy jeden sezon naraz — pola z różnych lat zsumowane dałyby
/// powierzchnię większą niż gospodarstwo.
abstract final class Zasiewy {
  /// Najnowszy sezon, w którym cokolwiek zapisano.
  ///
  /// Nie bierzemy bieżącego roku z zegara: w styczniu nowego sezonu
  /// jeszcze nie ma w bazie, a pulpit nie może przez to pokazać pustki.
  static int? ostatniSezon(List<Pole> pola) {
    int? ostatni;
    for (final pole in pola) {
      final sezon = pole.sezon;
      if (sezon != null && (ostatni == null || sezon > ostatni)) {
        ostatni = sezon;
      }
    }
    return ostatni;
  }

  static StrukturaZasiewow policz(List<Pole> pola, {int? sezon}) {
    final wybranySezon = sezon ?? ostatniSezon(pola);
    final zSezonu = wybranySezon == null
        ? pola
        : pola.where((pole) => (pole.sezon ?? wybranySezon) == wybranySezon);

    final poUprawie = <String, UdzialUprawy>{};
    var liczbaPol = 0;
    for (final pole in zSezonu) {
      liczbaPol++;
      final klucz = pole.uprawa.trim();
      final dopisek = UdzialUprawy(
        uprawa: klucz,
        powierzchniaAr: pole.powierzchniaAr,
        liczbaPol: 1,
      );
      final dotychczas = poUprawie[klucz];
      poUprawie[klucz] = dotychczas == null
          ? dopisek
          : dotychczas._zSuma(dopisek);
    }

    final uprawy = poUprawie.values.toList()
      ..sort((a, b) {
        // Pola bez uprawy zawsze na końcu — to brak danych, nie uprawa.
        if (a.nieznana != b.nieznana) {
          return a.nieznana ? 1 : -1;
        }
        final poPowierzchni = b.powierzchniaAr.compareTo(a.powierzchniaAr);
        return poPowierzchni != 0
            ? poPowierzchni
            : a.uprawa.compareTo(b.uprawa);
      });

    return StrukturaZasiewow(
      sezon: wybranySezon,
      uprawy: uprawy,
      liczbaPol: liczbaPol,
    );
  }
}
