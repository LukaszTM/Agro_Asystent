import 'package:flutter/material.dart';

import 'app/aplikacja.dart';
import 'app/platforma.dart';

void main() {
  // Telefon dostaje wyglądy „Prosty" i „Nowoczesny", komputer jeden wygląd
  // z ustawieniem wielkości tekstu (plan, pkt 5).
  runApp(AplikacjaAgroAsystent(platforma: Platforma.biezaca()));
}
