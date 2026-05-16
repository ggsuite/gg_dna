---
name: new-project
description: Legt ein neues Repository / Package an. Bestätigt Name, Zielordner und Beschreibung mit dem Nutzer und ruft das im Projekt übliche Create-Tool auf. Verwende diesen Skill, wenn der Nutzer sinngemäß sagt "neues Projekt anlegen", "neues Repository erstellen", "neues Package" oder einen GitHub/GitLab-Link für ein noch leeres Repository nennt.
---

# Neues Projekt anlegen

Du legst neue Repositories für den Workspace an. Halte dich strikt an diese Reihenfolge — frage **immer** vor dem tatsächlichen Anlegen nach Bestätigung. Das konkrete Create-Tool (z. B. ein projekt-spezifischer CLI-Wrapper) ist nicht hier festgenagelt; ein Overlay-Repo darf diese Vorlage durch eine engere, projekt-spezifische Version ersetzen.

## 1. Zielordner ermitteln

Repositories eines Teams liegen üblicherweise nebeneinander in einem gemeinsamen Eltern-Ordner. Der Pfad ist von Maschine zu Maschine verschieden — **frage den Nutzer**, in welchem Ordner die Repos liegen, oder finde den Ordner selbst (mit `Glob` nach Geschwister-Verzeichnissen suchen, die die teamtypischen Namens-Konventionen erfüllen).

Sobald der Eltern-Ordner bekannt ist, liste seinen Inhalt mit `Glob`/`ls`, um:

- zu verifizieren, dass der Pfad existiert,
- bestehende Geschwister-Repos zu sehen (Namens-Konventionen, Prefixes).

## 2. Bestätigung beim Nutzer einholen

Bevor irgendetwas erstellt wird, fasse zusammen und lass bestätigen:

- **Zielordner** (`<workspace-root>/<projektname>`).
- **Projektname** — sollte der Team-Konvention folgen (z. B. snake_case oder einem Prefix); im Zweifel den Nutzer fragen.
- **Hosting-Org** (GitHub / GitLab Organization) — explizit nachfragen, falls unklar.
- **Beschreibung** — Mindestlänge richtet sich nach dem Create-Tool; nachfragen, ob das Tool ein Limit hat.
- **Open Source ja/nein** — falls das Create-Tool die Wahl unterstützt.
- **Optionale Flags** — z. B. Sprache (Dart, Flutter, TypeScript, …) je nach Tool.

Erst nach expliziter Bestätigung weitermachen.

## 3. Projekt anlegen

Welches Tool verwendet wird, hängt vom Projekt-Setup ab. Beispiele:

- ein Custom-CLI (`<team>_create_package`, `make-repo`, …),
- `gh repo create` + Template,
- `npm create <template>` / `pnpm create <template>` / `yarn create <template>`,
- `dart create` / `flutter create`,
- `cargo new`.

**Führe immer erst** das Tool mit `-h` / `--help` aus, um die aktuelle Syntax/Flags zu sehen, und konstruiere den Aufruf basierend auf der Hilfe-Ausgabe. Niemals Flags raten.

## 4. GitHub / GitLab-Link bekommen?

Wenn der Nutzer beim Anlegen einen Repo-Link mitliefert, ist das Remote-Repo wahrscheinlich schon angelegt (eventuell mit README/LICENSE/.gitignore vorbefüllt).

- Frage den Nutzer, ob bestehende Dateien im Remote überschrieben werden dürfen.
- **Im Zweifel** vorher kurz prüfen, was schon im Repo liegt (`gh repo view <owner>/<repo> --json …` bzw. `git ls-remote`), und das dem Nutzer melden, falls dort nicht-triviale Inhalte liegen.
- Workflow nach dem Anlegen: lokal commiten → `git push -u origin main`. Falls Remote bereits Commits hat: nur nach Rücksprache mit `--force-with-lease` pushen.

## 5. Nach dem Anlegen

- Kurz bestätigen, was wo angelegt wurde (absoluter Pfad).
- Push-Befehl nennen, aber **nicht ungefragt pushen**.
- Nicht ungefragt zusätzliche Boilerplate, CI-Configs, Lizenzen oder READMEs erzeugen — das Create-Tool liefert die Standard-Struktur.

## Wichtig

- **Niemals** ohne Nutzer-Bestätigung von Pfad, Name, Hosting-Org und Beschreibung etwas erstellen.
- **Niemals** Create-Tool-Flags raten — immer erst `--help` aufrufen.
- Bestehende Ordner unter dem Zielpfad nicht überschreiben, ohne nachzufragen.
