# Program na Windows: skąd wziąć plik .exe

Są dwie drogi. Pierwsza nie wymaga niczego poza przeglądarką i jest ta
właściwa dla rolnika. Druga jest dla pracy nad kodem.

## 1. Gotowy plik do pobrania (zalecane)

Plik `.exe` buduje darmowa maszyna GitHuba. Uruchamia ją **znacznik**
zaczynający się od `pc-`:

```bash
git tag pc-0.1.0
git push origin pc-0.1.0
```

Po kilkunastu minutach w zakładce **Releases** repozytorium staje
wydanie `pc-0.1.0` z plikiem `agro-asystent-windows.zip`. Link do niego
jest stały — można go wysłać dalej, nie wygasa i nie wymaga logowania.

Dalej: rozpakować **cały** folder (obok `agro_asystent.exe` leżą
biblioteki, bez nich program nie wstanie) i uruchomić `agro_asystent.exe`.
Windows pokaże SmartScreen, bo program nie jest podpisany certyfikatem:
**Więcej informacji** → **Uruchom mimo to**.

Przy ręcznym uruchomieniu przepływu (Actions → Run workflow) wydanie nie
powstaje — jest tylko artefakt `agro-asystent-windows` na 14 dni, do
pobrania wyłącznie po zalogowaniu na GitHubie.

> Przycisk **Run workflow** pokazuje się dopiero, gdy plik przepływu leży
> na gałęzi głównej repozytorium. Dopóki praca stoi na gałęzi roboczej,
> program buduje się znacznikiem — i to działa od razu.

## 2. Budowanie u siebie na komputerze

`flutter run -d windows` potrzebuje kompilatora C++ od Microsoftu.
Bez niego Flutter przerywa zdaniem:

```
Error: Unable to find suitable Visual Studio toolchain.
Please run `flutter doctor` for more details.
```

To nie jest błąd aplikacji — to brak narzędzi na komputerze. Czego
trzeba:

| Co | Skąd | Ile waży |
| --- | --- | --- |
| **Visual Studio 2022 Build Tools** (darmowe) | visualstudio.microsoft.com → „Tools for Visual Studio" → Build Tools | ~2 GB |
| Zestaw **„Desktop development with C++"** (polski: „Programowanie aplikacji klasycznych w C++") | zaznacza się w instalatorze | — |
| W tym zestawie: MSVC v143, **Windows 11 SDK**, CMake | zaznaczone domyślnie | — |

Po instalacji trzeba zamknąć i otworzyć okno PowerShella (zmienne
środowiskowe wczytują się przy starcie), a potem sprawdzić:

```bash
flutter doctor -v
```

W wierszu „Visual Studio" ma stać zielony znak. Wtedy:

```bash
flutter run -d windows            # wersja robocza, z podglądem zmian
flutter build windows --release   # gotowy plik w build\windows\x64\runner\Release\
```

Samo Visual Studio Code **nie wystarczy** — to inny program niż Visual
Studio. Flutter szuka kompilatora, nie edytora.

## O czym pamiętać

- Ekrany komputera leżą w `lib/wyglad/komputer/` i są na gałęzi roboczej.
  Jeżeli lokalne repozytorium stoi na gałęzi głównej, program wstanie
  w wyglądzie telefonowym albo wcale — najpierw `git checkout` gałęzi
  z zadania.
- Dane trzyma SQLite w katalogu użytkownika, nie w folderze programu.
  Odinstalowanie przez skasowanie folderu nie kasuje wpisów.
- Dane z telefonu dołącza się w **Ustawieniach** plikiem kopii zapasowej;
  działa to w obie strony („nowszy wpis wygrywa, starszy zostaje
  w dzienniku zmian").
