# dostep
Jedyne miejsce decydujące o dostępie do funkcji premium (plan, pkt 8).
Funkcje wymagane przepisami są darmowe zawsze — patrz `DostepFunkcji.wymaganePrzepisami`.

Ekrany **nie pytają** „czy rolnik kupił" — pytają
`DostepFunkcji.czyDostepna(Funkcja...)`. Pilnuje tego test architektury:
słowa `maPremium` i `_tylkoPremium` nie mogą wystąpić poza tym katalogiem.

Słowa, którymi aplikacja mówi o funkcji płatnej, stoją w `opis_premium.dart` —
jedno miejsce dla obu wyglądów. Każde wyjaśnienie ma dwa zdania: czego dotyczy
dodatek i jak zrobić to samo bez opłaty; kończy się obietnicą, że dokumentacja
jest darmowa. Nigdzie nie namawiamy do zakupu.

Dwie zasady dla ekranów:

- **podczas wpisu zabiegu** funkcji płatnej po prostu nie ma — bez przycisku
  i bez wzmianki o wersji płatnej (plan, pkt 8);
- **poza wpisem** zostaje jedno zdanie zamiast przycisku, żeby rolnik wiedział,
  że funkcja istnieje, i co zrobić bez niej.
