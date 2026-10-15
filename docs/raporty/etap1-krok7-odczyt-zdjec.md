# Raport etap 1, krok 7 — odczyt zdjęć

15 października 2026 r. Zadanie z planu (pkt 4, krok 7):
„Odczyt zdjęć: etykieta środka (rozpoznanie), opakowanie nawozu (nazwa, NPK)".

## Co rolnik może zrobić

| Gdzie | Co robi przycisk |
| --- | --- |
| **Dodaj zabieg → Oprysk → „Rozpoznaj etykietę"** | zdjęcie etykiety zawęża listę środków do tego, co widać na opakowaniu |
| **Nawozy → Dodaj nawóz → „Odczytaj z worka"** | zdjęcie worka wypełnia nazwę i zawartość azotu do potwierdzenia |

Rozpoznawanie pisma działa **na urządzeniu i bez internetu** — zdjęcie
etykiety ani worka nigdzie nie wyjeżdża, tak jak cała reszta danych.

## Co rozpoznajemy, a czego nie

| Źródło | Rozpoznajemy | Nie rozpoznajemy |
| --- | --- | --- |
| Etykieta środka | nazwa handlowa („Abydos 750 EC"), numer zezwolenia („R-14/2025 h.r.") | dawki ani karencji — te biorą się ze sprawdzonej bazy z zadania P2 |
| Worek nawozu | nazwa, zapis „NPK 6-20-30", „azot całkowity (N) 34,0 %", „N 46%", rozpoznanie nawozu naturalnego po nazwie | nic poza tym; czego nie widać, zostaje puste |

Zasada jest ta sama co w całej aplikacji: **odczyt jest propozycją**. Nazwa
ze zdjęcia trafia do pola, które rolnik widzi i może poprawić; nic nie
zapisuje się po cichu. Gdy nic nie dało się odczytać, mówimy to wprost
i podpowiadamy, co zrobić („zrób zdjęcie z bliska, w świetle").

Numer zezwolenia rozstrzyga, gdy po nazwie pasuje kilka środków — to
najpewniejszy ślad na etykiecie. Środka, którego nie ma w rejestrze dla
danej uprawy, **nie dopisujemy**: pokazujemy, co odczytaliśmy, i zostawiamy
wybór z listy.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/funkcje/odczyt/czytnik_zdjecia.dart` | granica: aparat i rozpoznawanie pisma |
| `lib/funkcje/odczyt/odczyt_nawozu.dart` | czytanie składu z worka (NPK, zapis słowny, skrót) |
| `lib/funkcje/odczyt/odczyt_etykiety.dart` | nazwa handlowa, numer zezwolenia, dopasowanie do rejestru |
| `lib/app/czytnik_zdjecia_urzadzenia.dart` | aparat (`image_picker`) i rozpoznawanie pisma (ML Kit, model w aplikacji) |

Zmiany w ekranach: „Odczytaj z worka" w dodawaniu nawozu i „Rozpoznaj
etykietę" przy wyborze środka.

## Liczby

| Miara | Wartość |
| --- | --- |
| Nowe pliki kodu | 4 |
| Nowe pliki testów | 2 |
| Testy dodane w tym kroku | 16 |
| Testy w całym projekcie | 216 (było 200) |
| Nowe zależności | `google_mlkit_text_recognition` (MIT + model Google), `image_picker` (BSD) |
| `flutter analyze` | bez ostrzeżeń |

## Czego pilnują testy

Testy nie robią zdjęć — podstawiamy czytnik i sprawdzamy, co aplikacja robi
z odczytanym tekstem. Teksty w testach wyglądają jak prawdziwy wynik
rozpoznawania: krzywe wiersze, rozstrzelone znaki, urwane zdania.

- Trzy zapisy składu z worka: `NPK 6-20-30`, `azot całkowity (N) 34,0 %`,
  `N 46%`.
- Zdanie z instrukcji („Stosować zgodnie z zaleceniami") **nie** zostaje
  wzięte za nazwę nawozu.
- Nieczytelne zdjęcie nie daje fałszywego rozpoznania — nazwa i azot zostają
  puste, a rolnik dostaje zdanie, co zrobić.
- Numer zezwolenia rozstrzyga między dwoma środkami o podobnej nazwie.
- Rozpoznana etykieta zawęża listę do jednego środka; środka spoza rejestru
  nie dopisujemy.
- Odczyt z worka zapisuje nawóz ze źródłem „zdjęcie worka" — widać, skąd
  wzięła się zawartość azotu.

## Rzeczy świadomie odłożone

- **Odczyt karencji z etykiety ze zdjęcia** — karencja pochodzi z bazy
  etykiet z zadania P2, bo tam jest sprawdzona i ma datę etykiety. To temat
  kroku 8.
- **Rozpoznawanie etykiet pisanych nietypowym krojem** (ozdobne logo
  producenta) — model radzi sobie z tekstem drukowanym, nie z grafiką.
- **Windows**: rozpoznawanie pisma działa na Androidzie; w programie na PC
  przycisk zdjęcia się nie pojawi.
