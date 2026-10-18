import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../rdzen/wspolne/slowniczek_pojec.dart';
import '../motyw.dart';

/// Słowniczek pojęć w wyglądzie Nowoczesnym. Te same hasła co w wyglądzie
/// Prostym i w programie na komputer — jeden plik danych, trzy ekrany.
class EkranSlowniczekNowoczesny extends StatelessWidget {
  const EkranSlowniczekNowoczesny({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Słowniczek')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(MotywNowoczesny.odstep),
          children: [ListaSlowniczka(slownik: uslugi.slowniczek)],
        ),
      ),
    );
  }
}
