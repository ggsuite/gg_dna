# Arbeiten mit GG und Kidney

Kurzanleitung: GG für **einzelne** Repositories, Kidney (`kd`) für **mehrere** Repositories über Tickets hinweg.

## Installation (einmalig)

Beide Tools sind Dart-CLIs und werden global aktiviert:

```bash
dart pub global activate gg
dart pub global activate kd
```

Stelle sicher, dass `~/.pub-cache/bin` (Linux/macOS) bzw. `%LOCALAPPDATA%\Pub\Cache\bin` (Windows) im `PATH` liegt. Test:

```bash
gg -h
kd -h
```

## Was macht was?

| Tool | Wofür | Wo ausführen |
|---|---|---|
| `gg` | Pre-Commit-Checks (Analyze, Format, Tests, Coverage), Commit, Push, Publish, Ticket-Branch in **einem** Repo | Im Repo-Ordner (`P:\grace_cloud\<repo>`) |
| `kd` | Dieselben Aktionen über **alle** Repos eines Tickets, Ticket- und Workspace-Verwaltung | Im Workspace (`P:\workspace_grace_cloud`) bzw. Ticket-Ordner |

Faustregel: **Ein Repo betroffen → `gg`. Mehrere Repos → `kd`.**

---

## Beispiel A — Single-Repo-Ticket mit GG

Du willst einen Bug in `gg_dna` fixen.

```powershell
# 1. Ins Repo, aktuellen Stand holen
cd P:\grace_cloud\gg_dna
git pull

# 2. Ticket-Branch anlegen (legt Branch + .ticket-Datei an)
gg do create ticket -b fix-typo-readme -m "Fix typo in README headline"

# 3. Code ändern, dann committen (gg läuft vorher Analyze + Format + Tests + Coverage)
gg do commit -m "Fix typo in README headline"

# 4. Pushen
gg do push

# 5. Veröffentlichen (nur wenn pubspec-Version erhöht und du publishen willst)
gg do publish
```

**Wichtig:** `gg do commit` schlägt fehl, wenn Tests rot sind oder Coverage < 100 %. Das ist Absicht. Repariere die Ursache, nicht den Check.

Hilfreich:
- `gg can commit` / `gg can push` — prüft, ob alle Bedingungen erfüllt sind, ohne etwas zu tun
- `gg do upgrade` — aktualisiert alle Dependencies
- `gg -h` / `gg do -h` — komplette Befehlsübersicht

---

## Beispiel B — Multi-Repo-Ticket mit Kidney

Du willst ein Feature umsetzen, das `kidney_core` und `kidney_ui` zusammen ändert.

```powershell
# 1. In den Workspace
cd P:\workspace_grace_cloud

# 2. Ticket anlegen (erstellt ./tickets/<id>/ inkl. .ticket-Datei)
kd do create ticket add-export-button -m "Add export button to dashboard"

# 3. In den Ticket-Ordner wechseln
cd .\tickets\add-export-button

# 4. Die benötigten Repos zum Ticket hinzufügen
kd do add kidney_core kidney_ui

# 5. (Optional, empfohlen) Alle Repos im Ticket in VS Code öffnen
kd do code

# 6. (Optional) Claude Code im Ticket-Workspace starten — sieht alle Ticket-Repos
kd do claude

# 7. Code ändern, dann ticket-weit committen + pushen
kd do commit -m "Add export button to dashboard"
kd do push

# 8. Wenn fertig: Review/Publish
kd do review
kd do publish
```

`kd do <action>` führt die Aktion in **jedem** Ticket-Repo aus, das Änderungen hat. Du musst nicht mehr in jedes Repo einzeln wechseln.

Hilfreich:
- `kd ls repos` — zeigt alle Repos im Master-Workspace
- `kd can commit` / `kd can push` — Vorab-Check über alle Ticket-Repos
- `kd do execute "<befehl>"` — führt einen beliebigen Shell-Befehl in jedem Ticket-Repo aus
- `kd one <gg-subcommand>` — gezielt ein einzelnes `gg`-Subkommando in einem Ticket-Repo aufrufen
- `kd -h` / `kd do -h` — komplette Befehlsübersicht

---

## Workflow-Entscheidung in 5 Sekunden

```
Betrifft die Änderung nur 1 Repo?
 ├─ Ja → cd P:\grace_cloud\<repo> → gg do create ticket / commit / push
 └─ Nein → cd P:\workspace_grace_cloud → kd do create ticket → kd do add ... → kd do commit / push
```

Mehr Details: `gg -h`, `kd -h`, oder die READMEs in `P:\grace_cloud\gg` und `P:\grace_cloud\kidney_core`.
