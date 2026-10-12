import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../rdzen/dostep/dostep_funkcji.dart';
import '../wyglad/prosty/ekran_glowny.dart';
import '../wyglad/prosty/motyw.dart';

/// Start aplikacji. Wybór wyglądu („Prosty" / „Nowoczesny") dojdzie w
/// ustawieniach, gdy powstanie drugi wygląd; na razie zawsze „Prosty".
class AplikacjaAgroAsystent extends StatelessWidget {
  const AplikacjaAgroAsystent({
    super.key,
    this.dostep = const DostepFunkcji.darmowa(),
  });

  final DostepFunkcji dostep;

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
      home: EkranGlownyProsty(dostep: dostep),
    );
  }
}
