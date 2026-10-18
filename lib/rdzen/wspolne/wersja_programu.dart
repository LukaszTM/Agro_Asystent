import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Która wersja programu stoi na urządzeniu.
///
/// Przy testach z rolnikami to nie ozdoba: bez numeru nie wiadomo, czy
/// zgłoszona usterka jest jeszcze aktualna, czy dotyczy pliku sprzed
/// trzech poprawek.
class WersjaProgramu {
  const WersjaProgramu({required this.wersja, required this.numerBudowy});

  final String wersja;
  final String numerBudowy;

  String get opis => numerBudowy.isEmpty
      ? 'Wersja $wersja'
      : 'Wersja $wersja (budowa $numerBudowy)';

  /// Odczyt z paczki aplikacji. `null`, gdy się nie udał — na przykład
  /// w testach widgetów albo gdy wtyczka nie odpowiada. Brak numeru nie
  /// może przewrócić ekranu ustawień.
  static Future<WersjaProgramu?> zPaczki() async {
    try {
      final paczka = await PackageInfo.fromPlatform();
      return WersjaProgramu(
        wersja: paczka.version,
        numerBudowy: paczka.buildNumber,
      );
    } on Object {
      return null;
    }
  }
}

/// Wiersz z numerem wersji na ekranie ustawień — ten sam we wszystkich
/// trzech wyglądach.
class WierszWersji extends StatefulWidget {
  const WierszWersji({super.key, this.styl, this.przed = ''});

  final TextStyle? styl;

  /// Co napisać przed numerem, np. „Agro Asystent • ".
  final String przed;

  @override
  State<WierszWersji> createState() => _WierszWersjiState();
}

class _WierszWersjiState extends State<WierszWersji> {
  late final Future<WersjaProgramu?> _wersja = WersjaProgramu.zPaczki();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WersjaProgramu?>(
      future: _wersja,
      builder: (context, stan) {
        final wersja = stan.data;
        if (wersja == null) {
          return const SizedBox.shrink();
        }
        return Text(
          '${widget.przed}${wersja.opis}',
          style: widget.styl ?? Theme.of(context).textTheme.bodyMedium,
        );
      },
    );
  }
}
