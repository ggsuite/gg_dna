# Grace Cloud — Documentation Conventions

Dokumentation in Grace-Cloud-Paketen ist **funktional**, nicht "schön". Jedes Stück Doku hat ein klares Ziel: API-Verständnis, Reproduzierbarkeit, Änderungs-Nachvollziehbarkeit.

## 1. Doc-Comments im Code (`///`)

Siehe `code-conventions.md` §7. Ergänzend:

- **Was, nicht wie.** "Returns the list value at index `[i]`" — nicht "Loops through internal data and returns the i-th".
- **Konsistente Tempora**: 3rd-Person-Indikativ ("Updates the state.", "Throws when ..."), kein "Will update", kein imperatives "Update the state.".
- **Parameter-Doku als Aufzählung** mit `- [name]`-Syntax:
  ```dart
  /// Run the operation and display the status.
  ///
  /// - [task] to be executed.
  ///   - If the task throws, an error state will be printed.
  ///   - If the task completes successfully, a success state will be printed.
  ```
- **Beispiele** im Doc-Comment nur, wenn der Aufruf nicht offensichtlich aus Signatur + Beschreibung folgt. Dann als ` ```dart ` Block.
- **Throw-Verhalten** explizit machen, wenn relevant: `Throws a [StateError] when ...`.

## 2. README.md

Pflicht-Aufbau (Reihenfolge):

```markdown
# <PaketName>

<1–3 Sätze: Was macht dieses Paket? Welches Problem löst es?>

## Features (oder: ## Description / ## Classes je nach Paket)

- **<Feature>**: <Kurze Erklärung>
- ...

## Usage / Example Usage

```dart
import 'package:<pkg>/<pkg>.dart';

void main() async {
  // Minimal-Beispiel, das ohne Anpassung lauffähig ist
}
```

## Features and bugs

Please file feature requests and bugs at [GitHub](https://github.com/<org>/<pkg>).
```

Optional und üblich:
- **`## State`** mit CI-Badge: `[![Dart Script Execution](https://github.com/<org>/<pkg>/actions/workflows/check.yaml/badge.svg)](...)`.
- **`## Classes`** als Tabelle bei Mehr-Klassen-Paketen (siehe `gg_list/README.md`):
  ```markdown
  | Class            | Description                          |
  | :--------------- | :----------------------------------- |
  | `GgList`         | Create lists of ordinary value types |
  ```
- **`## How It Works`** für nicht-triviale Mechaniken.
- **TOC** bei langen Readmes (manuell gepflegt).

Tonfall: knapp, technisch, Englisch. Keine Marketing-Sätze.

## 3. CHANGELOG.md

[Keep a Changelog](https://keepachangelog.com)-Style mit Grace-Cloud-Anpassungen:

```markdown
# Changelog

## [1.2.0] - 2026-04-29

### Added
- New `Foo.bar` factory.

### Changed
- Default of `useCarriageReturn` is now `!isGitHub`.

### Fixed
- Race condition in `dispose`.

### Removed
- Deprecated `legacyMethod`.

## [1.1.5] - 2026-04-12
...

[1.2.0]: https://github.com/<org>/<pkg>/compare/1.1.5...1.2.0
[1.1.5]: https://github.com/<org>/<pkg>/compare/1.1.4...1.1.5
```

Regeln:
- **Reverse chronological** (neueste oben).
- **Sektionen** nur wenn relevant: `Added`, `Changed`, `Fixed`, `Removed` (manchmal `Deprecated`, `Security`).
- **Versions-Header**: `## [<semver>] - <YYYY-MM-DD>`. Eckige Klammern bei verlinkten Versionen.
- **Compare-Links** am Datei-Ende; pflegen oder mit `gg do commit` automatisch generieren lassen.
- **Bullet-Items** sind kurz und imperativ ("Add X", "Fix Y").
- **`gg do commit -m "..."`** schreibt die Commit-Message automatisch in den Changelog. Manuell editieren ist erlaubt, sollte aber selten nötig sein.

## 4. example/

- **Dart-Pakete**: `example/<pkg>_example.dart` — eine Datei, lauffähig per `dart run example/<pkg>_example.dart`. Optional Shebang `#!/usr/bin/env dart`.
- **Flutter-Pakete**: `example/` ist ein eigenes Flutter-Subprojekt (`example/lib/main.dart`, `example/pubspec.yaml`, `example/test/`).
- **Lizenz-Header** auch in Beispielen.
- **Funktional vollständig**: das Beispiel zeigt den Happy Path inklusive Setup. Kein "TODO: implement".

## 5. Workflow-Dateien (.github/workflows/)

`pipeline.yaml` (Standard, von `gg_create_package` erzeugt):

- Trigger: `push` auf `main`.
- Steps: Git-User → SSH-Key → Checkout → Flutter/Dart-Detection → SDK-Setup → `pub get` → `dart pub global activate gg` → `gg info last-changes-hash` → `gg info modified-files --force` → `gg did commit` → `gg did push` → `gg can commit --force`.
- **Nicht eigenmächtig anpassen.** Wenn Pipeline-Änderungen nötig sind, `gg`-Tooling oder Team-Konvention abstimmen.

`check.yaml` (lokaler `gg`-Check-Schalter):

```yaml
needsInternet: false
analyze:
  execute: true
format:
  execute: true
tests:
  execute: true
pana:
  execute: false   # true für Flutter-Pakete oder vor Publish
```

## 6. CLAUDE.md

Die `CLAUDE.md` im Repo-Root wird von Claude Code automatisch geladen. Pflicht-Inhalt:

- **`@`-Imports zu den Konventions-Dokumenten** in `.gg/claude/`. Diese werden vom `apply-conventions`-Kommando automatisch eingefügt und in einem Marker-Block gehalten:
  ```markdown
  <!-- gg_dna:conventions:start v=YYYY-MM-DD -->
  @.gg/claude/code-conventions.md
  @.gg/claude/test-conventions.md
  @.gg/claude/documentation-conventions.md
  <!-- gg_dna:conventions:end -->
  ```
- **Repo-spezifische Hinweise** außerhalb des Marker-Blocks (oben oder unten): Architekturskizze, Domain-Begriffe, projektspezifische Workflows.

Nicht in CLAUDE.md gehören: Onboarding-Prosa, Marketing, etwas, das in README oder Code-Doc besser aufgehoben ist.

## 7. Was nicht zu dokumentieren ist

- **Trivialitäten**: ein Getter `length` braucht keinen Doc-Comment, der "Returns the length" sagt — der Lint zwingt zwar dazu, dann reicht aber die schlichte Variante.
- **"Wie der Code es tut"**: das steht im Code. Doc-Comments erklären *was* und *warum*, nicht *wie*.
- **Persönliche Notizen**, "Vielleicht später"-Pläne, "FIXME: ich verstehe das nicht" — solche Kommentare gehören nicht in das Repo.
