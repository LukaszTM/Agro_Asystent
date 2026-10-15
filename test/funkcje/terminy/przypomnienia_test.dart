import 'package:agro_asystent/funkcje/terminy/kalendarz_terminow.dart';
import 'package:agro_asystent/funkcje/terminy/przypomnienia.dart';
import 'package:agro_asystent/funkcje/terminy/ustawienia_przypomnien.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Układanie przypomnień jest osobno od systemu powiadomień, więc da się
/// je sprawdzić bez telefonu.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  PozycjaKalendarza termin(String id, DateTime data) => PozycjaKalendarza(
    id: id,
    nazwa: 'Termin $id',
    coZrobic: 'Zrób to na czas.',
    zrodlo: ZrodloTerminu.przepis,
    data: data,
  );

  final teraz = DateTime(2026, 10, 15, 12);

  test('dla terminu planujemy przypomnienie w dniu i trzy dni wcześniej', () {
    final plan = PlanPrzypomnien.uloz([
      termin('a', DateTime(2026, 10, 25)),
    ], teraz: teraz);
    expect(plan, hasLength(2));
    expect(plan.first.kiedy, DateTime(2026, 10, 22, PlanPrzypomnien.godzina));
    expect(plan.first.tytul, contains('3 dni do terminu'));
    expect(plan.last.kiedy, DateTime(2026, 10, 25, PlanPrzypomnien.godzina));
    expect(plan.last.tresc, 'Zrób to na czas.');
  });

  test('nie planujemy przypomnień na przeszłość', () {
    final plan = PlanPrzypomnien.uloz([
      termin('wczoraj', DateTime(2026, 10, 14)),
      // Termin pojutrze: uprzedzenie wypadałoby wczoraj, zostaje sam dzień.
      termin('pojutrze', DateTime(2026, 10, 17)),
    ], teraz: teraz);
    expect(
      [for (final p in plan) p.kiedy],
      [DateTime(2026, 10, 17, PlanPrzypomnien.godzina)],
    );
  });

  test('terminy dalsze niż miesiąc czekają na swoją kolej', () {
    final plan = PlanPrzypomnien.uloz([
      termin('daleki', DateTime(2027, 4, 15)),
    ], teraz: teraz);
    expect(plan, isEmpty);
  });

  test('ten sam termin dostaje ten sam numer, więc plan się nie dubluje', () {
    final pierwszy = PlanPrzypomnien.uloz([
      termin('a', DateTime(2026, 10, 25)),
    ], teraz: teraz);
    final drugi = PlanPrzypomnien.uloz([
      termin('a', DateTime(2026, 10, 25)),
    ], teraz: teraz.add(const Duration(hours: 1)));
    expect([for (final p in pierwszy) p.id], [for (final p in drugi) p.id]);
    expect(pierwszy.first.id, isNot(pierwszy.last.id));
  });

  test('plan jest ułożony po czasie i ucięty do granicy systemu', () {
    final pozycje = [
      for (var i = 1; i <= 30; i++)
        termin('t$i', DateTime(2026, 10, 15).add(Duration(days: i))),
    ];
    final plan = PlanPrzypomnien.uloz(pozycje, teraz: teraz);

    expect(plan.length, PlanPrzypomnien.najwiecej);
    for (var i = 1; i < plan.length; i++) {
      expect(plan[i].kiedy.isBefore(plan[i - 1].kiedy), isFalse);
    }
  });

  test('ustawienie przypomnień przeżywa zamknięcie aplikacji', () async {
    final baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    addTearDown(baza.close);

    final ustawienia = UstawieniaPrzypomnien(baza);
    expect(await ustawienia.czyWlaczone(), isFalse);

    await ustawienia.zapisz(wlaczone: true);
    expect(await ustawienia.czyWlaczone(), isTrue);

    await ustawienia.zapisz(wlaczone: false);
    expect(await ustawienia.czyWlaczone(), isFalse);
  });
}
