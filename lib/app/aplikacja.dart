import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../funkcje/ustawienia/wybor_wygladu.dart';
import '../rdzen/dostep/dostep_funkcji.dart';
import '../wyglad/nowoczesny/ekran_glowny.dart';
import '../wyglad/nowoczesny/motyw.dart';
import '../wyglad/prosty/ekran_glowny.dart';
import '../wyglad/prosty/motyw.dart';
import 'start.dart';
import 'uslugi.dart';

/// Start aplikacji. Wygląd („Prosty" / „Nowoczesny") bierzemy z ustawień
/// gospodarstwa; domyślnie „Prosty", bo aplikacja jest przede wszystkim dla
/// rolników 60+ (plan, pkt 5).
class AplikacjaAgroAsystent extends StatefulWidget {
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
  State<AplikacjaAgroAsystent> createState() => _AplikacjaState();
}

class _AplikacjaState extends State<AplikacjaAgroAsystent> {
  Future<Uslugi>? _uslugi;

  /// Usługi po przełączeniu gospodarstwa — baza i słowniki zostają otwarte,
  /// zmienia się tylko gospodarstwo, nad którym pracujemy.
  Uslugi? _wybrane;

  Wyglad _wyglad = Wyglad.prosty;

  /// Dopóki nie odczytamy wyboru z bazy, nie pokazujemy żadnego z wyglądów —
  /// inaczej na chwilę mignąłby ten niewybrany.
  bool _wygladOdczytany = false;

  @override
  void initState() {
    super.initState();
    final gotowe = widget.uslugi;
    final uslugi = gotowe != null
        ? Future<Uslugi>.value(gotowe)
        : (widget.wlasneUruchomienie ?? () => uruchom(dostep: widget.dostep))();
    _uslugi = uslugi;
    uslugi.then(_odczytajWyglad).onError<Object>((_, _) {
      // Błąd startu obsługuje FutureBuilder niżej — tu nie ma czego czytać.
    });
  }

  Future<void> _odczytajWyglad(Uslugi uslugi) async {
    final wyglad = await uslugi.wyglad.odczytaj();
    if (mounted) {
      setState(() {
        _wyglad = wyglad;
        _wygladOdczytany = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agro Asystent',
      debugShowCheckedModeBanner: false,
      theme: _wyglad == Wyglad.nowoczesny
          ? MotywNowoczesny.zbuduj()
          : MotywProsty.zbuduj(),
      locale: const Locale('pl'),
      supportedLocales: const [Locale('pl')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FutureBuilder<Uslugi>(
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

          final uslugi = _wybrane ?? stan.data;
          if (uslugi == null) {
            // Baza jeszcze się otwiera: ekran główny prostego wyglądu działa
            // i bez usług — pokazuje kafelki z opisem, co będzie.
            return EkranGlownyProsty(dostep: widget.dostep);
          }
          if (!_wygladOdczytany) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (_wyglad == Wyglad.nowoczesny) {
            return EkranGlownyNowoczesny(
              uslugi: uslugi,
              onZmianaGospodarstwa: _zmienGospodarstwo,
              onZmianaWygladu: _zmienWyglad,
            );
          }
          return EkranGlownyProsty(
            dostep: widget.dostep,
            uslugi: uslugi,
            onZmianaGospodarstwa: _zmienGospodarstwo,
            onZmianaWygladu: _zmienWyglad,
          );
        },
      ),
    );
  }

  void _zmienGospodarstwo(Uslugi nowe) => setState(() => _wybrane = nowe);

  void _zmienWyglad(Wyglad wyglad) => setState(() => _wyglad = wyglad);
}
