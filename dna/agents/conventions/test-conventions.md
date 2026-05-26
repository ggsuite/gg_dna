# Test Conventions (Dart / Flutter)

Tests sind Pflicht, nicht Empfehlung. Dieses Dokument ist die generische Basis — projektspezifische Tooling-Aufrufe (Pre-Commit-Hooks, CI-Pipelines) gehören in einen Overlay.

## 1. Datei-Struktur

- **1:1-Spiegelung** von `lib/src/` zu `test/`:
  - `lib/src/foo.dart` → `test/foo_test.dart`
  - `lib/src/sub/bar.dart` → `test/sub/bar_test.dart`
- **Eine Test-Datei pro Source-Datei.**
- Test-Dateien beginnen mit dem **Lizenz-Header** (siehe `code-conventions.md`, §2).
- Top-Level-`main()`-Funktion, kein expliziter Rückgabetyp.

## 2. Imports im Test

```dart
import 'package:test/test.dart';                     // Dart-Pakete
// oder:
import 'package:flutter_test/flutter_test.dart';     // Flutter-Pakete

import 'package:<pkg>/<pkg>.dart';                   // eigenes Paket über Public API
```

Nur in Ausnahmefällen `package:<pkg>/src/...` importieren — üblich, wenn ein interner Helfer getestet werden muss, der absichtlich nicht exportiert ist.

## 3. Verschachtelung mit `group` / `test`

Drei-Ebenen-Hierarchie ist Default:

```dart
void main() {
  group('FooBar', () {                    // Klassenname
    group('run()', () {                   // Methode mit (args)
      group('Should print running and', () {
        test('success messages', () { ... });
        test('error messages', () { ... });
      });
    });
    group('logTask(...)', () {
      test('with success should print success status', () { ... });
    });
  });
}
```

- **Outer group** = Klassen- oder Top-Level-Funktions-Name.
- **Innere group** = Methoden-Signatur (`run()`, `logTask(...)`, `copyWithValue(i, value)`).
- **Test-Name** beginnt mit "should" oder beschreibt das beobachtete Verhalten.

## 4. Setup, Teardown, Helpers

- `setUp` zum Resetten von gemeinsamem State (Listen leeren, Test-Singletons zurücksetzen).
- `tearDown` zum Aufräumen externer Ressourcen (temporäre Verzeichnisse, fakes auf null setzen).
- **Local helper closures** in `main()` für Setup-Logik, die in mehreren Tests verwendet wird (kein magisches Helper-Modul, keine Vererbung).

```dart
void main() {
  late Directory tmp;
  final messages = <String>[];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('foo_test_');
    messages.clear();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Directory makeFixture(String name) => Directory(p.join(tmp.path, name))..createSync();

  group('Foo', () { ... });
}
```

## 5. Combinatorial Tests

Wenn dieselbe Logik mit mehreren Eingaben getestet werden soll, **for-loop um `test(...)`**, nicht parametrisierte Frameworks:

```dart
for (final cr in [null, false]) {
  test('with carriage return = $cr', () async { ... });
}
```

## 6. Mocking-Politik

- **Echte Typen bevorzugen.** Konstruktoren erlauben über Optionalparameter (z. B. `ggLog`, `promptUser`, `homeOverride`) Dependency-Injection — dann sind Tests ohne Mocks möglich.
- **Funktionen statt Mocks**: ein Callback (`String? Function(String)`) ist einfacher zu testen als eine gemockte `Stdin`-Klasse.
- **Test-Singletons**: für globale Flags gibt es projektweite Test-Overrides (`testIsCi`, `testHomeDir`, …); setze sie in `setUp` und reset sie in `tearDown` auf `null`.
- **`mockito`/`mocktail`**: nur einsetzen, wenn ohne Mock keine vernünftige Test-Strategie möglich ist.

## 7. Test-Inhalt

- Ein `test(...)` testet **eine** Verhaltensweise. Mehrere `expect`s sind erlaubt, solange sie zusammen genau diese Verhaltensweise belegen.
- Bevorzuge **strukturelle Vergleiche** (`expect(messages, equals([...]))`) gegenüber Einzel-Asserts für Listen.
- Für Exceptions: `expectLater(future, throwsA(isA<XyzError>().having((e) => e.message, 'message', contains('...'))))`.
- Für Future-Erfolge: `final result = await ...; expect(result, ...);`.
- **Keine `print`** in Tests. Wenn Output abgefangen werden muss, einen Capture-Helfer benutzen.

## 8. Coverage

- **100 % erforderlich** als Default-Anspruch. Projektspezifische Pre-Commit-/CI-Checks blocken sonst.
- **Unerreichbare oder irrelevante Codepfade** mit Kommentaren markieren:
  ```dart
  // coverage:ignore-line
  // coverage:ignore-start
  ...
  // coverage:ignore-end
  ```
- Beispiele für legitime Ignores:
  - Sichtbar-machen einer `UnsupportedError`-Variante in einer Container-Implementierung.
  - Einzeln nicht testbare `dart:io`-Aufrufe (z. B. `stdin.readLineSync()`-Wrapper im Default-Fallback).
- **Ignores sind nicht zum Verstecken von Faulheit.** Wenn ein Pfad theoretisch testbar ist (auch über Dependency-Injection), dann teste ihn statt zu ignorieren.

## 9. Stil-Konsistenz

- **Sektions-Trenner** auch in Tests:
  ```dart
  // #########################################################################
  group('subList(start, end)', () { ... });
  ```
- Test-Code ist auch Code: Lizenz-Header, single quotes, trailing commas, 80-Zeichen-Regel (in Dart-Paketen).

## 10. Lokale Validierung vor Commit

Vor jedem Commit sollten laufen:
- `dart analyze` (sauber)
- `dart format` (sauber)
- `dart test` (alle grün, gewünschte Coverage)

Welches Tool das automatisiert (Git-Hook, CLI-Wrapper, CI-Job), ist projektspezifisch.
