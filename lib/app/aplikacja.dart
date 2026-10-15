import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../rdzen/dostep/dostep_funkcji.dart';
import '../wyglad/prosty/ekran_glowny.dart';
import '../wyglad/prosty/motyw.dart';
import 'start.dart';
import 'uslugi.dart';

/// Start aplikacji. Wybór wyglądu („Prosty" / „Nowoczesny") dojdzie w
/// ustawieniach, gdy powstanie drugi wygląd; na razie zawsze „Prosty".
class AplikacjaAgroAsystent extends StatelessWidget {
  const AplikacjaAgroAsystent({
    super.key,
    this.dostep = const DostepFunkcji.darmowa(),
    this.uslugi,
    this.wlasneUruchomienie,
  });

  final DostepFunkcji dostep;

  /// Gotowe usługi — podstawiane w testach zamiast otwierania prawdziwej bazy.
  final Uslugi? uslugi;

  /// Sposób złożenia usług przy starcie; domyślnie otwiera bazę na urządzeniu.
  final Future<Uslugi> Function()? wlasneUruchomienie;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agro Asystent',
      debugShowCheckedModeBanner: false,
      theme: MotywProsty.zbuduj(),
      locale: const Locale('pl'),
      supportedLocales: const [Locale('pl')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _Start(
        dostep: dostep,
        gotowe: uslugi,
        uruchomienie: wlasneUruchomienie,
      ),
    );
  }
}

/// Czeka na otwarcie bazy i przygotowanie słowników, a potem pokazuje ekran
/// główny. Bez internetu, więc trwa to chwilę tylko przy pierwszym starcie.
class _Start extends StatefulWidget {
  const _Start({required this.dostep, this.gotowe, this.uruchomienie});

  final DostepFunkcji dostep;
  final Uslugi? gotowe;
  final Future<Uslugi> Function()? uruchomienie;

  @override
  State<_Start> createState() => _StartState();
}

class _StartState extends State<_Start> {
  Future<Uslugi>? _uslugi;

  /// Usługi po przełączeniu gospodarstwa — baza i słowniki zostają otwarte,
  /// zmienia się tylko gospodarstwo, nad którym pracujemy.
  Uslugi? _wybrane;

  @override
  void initState() {
    super.initState();
    final gotowe = widget.gotowe;
    _uslugi = gotowe != null
        ? Future<Uslugi>.value(gotowe)
        : (widget.uruchomienie ?? () => uruchom(dostep: widget.dostep))();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uslugi>(
      future: _uslugi,
      builder: (context, stan) {
        if (stan.hasError) {
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(MotywProsty.odstep * 2),
              child: Center(
                child: Text(
                  'Nie udało się otworzyć danych aplikacji.\n'
                  'Uruchom ją ponownie; jeśli to nie pomoże, zgłoś błąd.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }
        return EkranGlownyProsty(
          dostep: widget.dostep,
          uslugi: _wybrane ?? stan.data,
          onZmianaGospodarstwa: (nowe) => setState(() => _wybrane = nowe),
        );
      },
    );
  }
}
