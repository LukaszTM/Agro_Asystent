import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../rdzen/wspolne/slowniczek_pojec.dart';
import '../motyw.dart';

/// Słowniczek pojęć w wyglądzie Prostym.
///
/// Rolnik dostaje pismo z ARiMR, w którym stoi „TUZ" albo „GAEC 6",
/// i nie ma gdzie sprawdzić, co to znaczy. Hasła są danymi z pliku
/// (`assets/dane/slowniczek.json`) — ekran tylko je pokazuje.
class EkranSlowniczek extends StatelessWidget {
  const EkranSlowniczek({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Słowniczek')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(MotywProsty.odstep),
          children: [ListaSlowniczka(slownik: uslugi.slowniczek)],
        ),
      ),
    );
  }
}
