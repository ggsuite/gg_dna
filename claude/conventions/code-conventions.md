# Grace Cloud — Code Conventions (Dart / Flutter)

Diese Regeln gelten für alle Grace-Cloud-Pakete (`gg_*`, `kidney_*`, `ds_*`). Sie wurden aus den Referenz-Repos `gg_status_printer`, `gg_typedefs`, `gg_router`, `gg_list` extrahiert. Wenn du Code für ein solches Paket schreibst oder ein neues Paket anlegst, halte dich strikt an diese Regeln.

## 1. Paket- & Datei-Layout

- **Paketname = Repo-Name = Klassen-Prefix.** `gg_status_printer` exportiert `GgStatusPrinter`. Niemals zwei Top-Level-Konzepte in einem Paket.
- **Public API liegt in `lib/<package>.dart`** und ist eine reine Barrel-Datei: License-Header, `library;`, dann ausschließlich `export 'src/...';`-Zeilen. Keine Implementierung.
- **Implementierung liegt in `lib/src/<file>.dart`.** Externe Konsumenten importieren niemals `package:<pkg>/src/...`.
- **Datei-Namen sind snake_case** und spiegeln den Haupt-Typ darin (`gg_status_printer.dart` enthält `class GgStatusPrinter`). Eng verwandte kleine Helfer (Enums, Typedefs, kurze Datenklassen) dürfen mit in derselben Datei liegen.
- **Tests spiegeln `lib/src/` 1:1**: `lib/src/foo.dart` → `test/foo_test.dart`. Siehe `test-conventions.md`.

## 2. Lizenz-Header

**Jede `.dart`-Datei** beginnt mit exakt diesem Block (Jahr aktualisieren):

```dart
// @license
// Copyright (c) 2019 - <YYYY> Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.
```

Danach: Leerzeile, dann `library;` (nur in der Barrel-Datei) oder Imports.

## 3. Imports

- **Reihenfolge:** `dart:` zuerst, dann `package:`, dann relative Imports — jeweils alphabetisch, durch Leerzeilen getrennt.
- **Innerhalb des Pakets**: relative Imports (`import '../gg_router.dart';`) bevorzugen — der Lint `prefer_relative_imports` ist in den meisten Repos aktiv.
- **In Tests** das eigene Paket über `package:<pkg>/<pkg>.dart` importieren, nicht über `src/`.

## 4. Klassen-Aufbau

Reihenfolge der Mitglieder:
1. **Konstruktor(en)** zuerst, mit `///`-Doc.
2. **Factory-Konstruktoren** danach (`Foo.generate(...)`, `Foo.fromList(...)`).
3. **Public Methods** geordnet nach logischer Verwandtschaft, nicht alphabetisch.
4. **Public Felder / Getter** (alle `final`).
5. **Static-Konstanten und -Methoden**.
6. **Private Felder & Methoden** am Ende mit `_`-Prefix.

Felder sind grundsätzlich `final`. Mutability wird vermieden; "ändern" geschieht über Copy-with-Methoden (`copyWithValue`, `transform`).

## 5. Konstruktoren & API

- **Named parameters mit `required`** sind Default. Positionale Parameter nur bei trivialen 1-Argument-Konstruktoren.
- Sinnvolle Defaults im Constructor (`ggLog = print`, `useCarriageReturn = !isGitHub`).
- **Generische Typ-Parameter** wo es um wiederverwendbare Container/Workflows geht (`GgStatusPrinter<T>`, `GgList<T>`).
- **Factory-Konstruktoren** für alternative Erzeugung (`.generate`, `.fromList`, `.fromX`).
- Async-Code: `Future<T>` zurückgeben, Fehler mit `try / catch / rethrow` behandeln (kein Schlucken).
- `unawaited_futures` ist Lint-aktiv — alle `Future` entweder awaiten oder explizit mit `unawaited(...)` kennzeichnen.

## 6. Sektions-Kommentare (visuelle Landmarken)

Diese Marker sind **Konvention im ganzen Codebase** — sie helfen beim Scannen und sind keine Doc-Comments:

- **`// #############################################################################`** — vor Klassen, Enums oder anderen Top-Level-Konstrukten.
- **`// ...........................................................................`** — vor jeder Methode, jedem Getter, jedem Feld-Block, der ein Doc-Kommentar trägt.
- **`// .............................................................................`** (länger) — am Datei-Anfang oder bei größeren Sektions-Trennern.
- **`// ######################\n// Section Name\n// ######################`** — innerhalb großer Klassen, um logische Sektionen zu markieren (z. B. `Constructors`, `Data access`, `List methods`, `Private`).

Der Stil ist konsistent in allen Repos — **nicht weglassen**, nicht durch eigene Varianten ersetzen.

## 7. Dokumentation in Code

- **Jeder Public Member** hat einen `///`-Doc-Comment (Lint `public_member_api_docs` ist aktiv).
- **Erste Zeile**: kurze, vollständige Aussage in 3rd-Person-Indikativ ("Run the operation and display the status").
- **Parameter** dokumentieren mit `- [name] <Beschreibung>`-Syntax in Folgezeilen.
- **Aufzählungen** mit `-` einrücken; verschachtelte Aufzählungen mit `  -`.
- Beispiele als ` ```dart ` Block in Doc-Comment möglich, wenn nicht-trivial.

## 8. Linter-Regeln (Pflicht-Set)

`analysis_options.yaml` enthält:

```yaml
include: package:lints/recommended.yaml

linter:
  rules:
    - camel_case_types
    - prefer_relative_imports        # in Flutter-Paketen mit example/ ggf. aus
    - lines_longer_than_80_chars     # in Flutter-Paketen häufig deaktiviert
    - prefer_single_quotes
    - void_checks
    - require_trailing_commas
    - prefer_const_constructors
    - always_declare_return_types
    - prefer_const_constructors_in_immutables
    - prefer_const_declarations
    - prefer_const_literals_to_create_immutables
    - prefer_constructors_over_static_methods
    - package_api_docs
    - public_member_api_docs
    - missing_whitespace_between_adjacent_strings
    - unawaited_futures

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    always_declare_return_types: true
```

Flutter-Pakete dürfen `lines_longer_than_80_chars` und `strict-*` deaktivieren, **wenn nötig** — aber nur dort.

## 9. Naming-Quickref

| Konstrukt | Stil | Beispiel |
|---|---|---|
| Klasse | `Gg<X>` PascalCase | `GgRouterDelegate` |
| Datei | snake_case mit `gg_`-Prefix | `gg_router_delegate.dart` |
| Test-Datei | `<filename>_test.dart` | `gg_router_delegate_test.dart` |
| Privates Member | `_camelCase` | `_updateState` |
| Konstante | `lowerCamelCase` (kein SCREAMING_SNAKE) | `carriageReturn` |
| Enum-Wert | `lowerCamelCase` | `GgStatusPrinterStatus.success` |

## 10. Was nicht zu tun ist

- **Keine** `dynamic`-Rückgabetypen (Lint `always_declare_return_types` als Error).
- **Keine** Doppelten Quotes (Lint `prefer_single_quotes`).
- **Keine** unawaited Futures ohne `unawaited(...)`.
- **Keine** Mutationen von Public Feldern; Setter nur mit klarer Begründung.
- **Keine** TODO-Kommentare ohne Issue/Ticket-Referenz.
- **Keine** auskommentierten Codeblöcke "für später" — Git ist die History.
- **Kein** Co-Authored-By-Trailer in Commits (gilt repository-weit).
