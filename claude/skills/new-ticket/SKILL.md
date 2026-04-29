---
name: new-ticket
description: Legt ein neues Grace-Cloud-Ticket an. Zwei Modi - (A) Multi-Repo-Ticket im Kidney-Workspace via `kd do create ticket` + `kd do add`, (B) Single-Repo-Ticket direkt im Repo via `gg do create ticket`. Verwende diesen Skill automatisch, wenn der Nutzer sinngemäß sagt "neues Ticket anlegen/erstellen", "Bug fixen", "Feature umsetzen/einführen" — insbesondere wenn es um Grace Cloud, GG, `gg_*`, `kidney_*` oder `ds_*` geht. Auch bei Formulierungen wie "ich will an X arbeiten", "lass uns Bug Y beheben", "neues Feature Z für Grace Cloud" greifen.
---

# Neues Grace-Cloud-Ticket anlegen

Du legst Tickets für die Arbeit an Grace-Cloud-Repositories an. Es gibt **zwei Modi** — wähle anhand des Anliegens:

- **Modus A — Multi-Repo-Ticket**: Änderungen betreffen mehrere Repos oder es ist beim Anlegen noch unklar, welche Repos genau gebraucht werden → Workspace-Ticket im Kidney-Workspace, angelegt mit `kd`.
- **Modus B — Single-Repo-Ticket**: Bug oder Feature betrifft eindeutig nur ein einziges Repo → Ticket-Branch direkt im Repo, angelegt mit `gg`.

Frage im Zweifel den Nutzer, welcher Modus passt. Wenn er von vornherein nur ein Repo nennt, ist Modus B richtig.

**Voraussetzung:** `kd` und `gg` müssen installiert sein:

```bash
dart pub global activate gg
dart pub global activate kd
```

---

## Modus A — Multi-Repo-Ticket (`kd do create ticket`)

### 1. In den Kidney-Workspace wechseln

Der Kidney-Workspace ist der Ordner, der ein `.master/`-Unterverzeichnis und üblicherweise einen `tickets/`-Ordner enthält. Der Pfad ist von Maschine zu Maschine verschieden — frage den Nutzer entweder explizit danach, oder finde den Workspace selbst:

- Mit `Glob` nach `**/.master` suchen (in plausiblen Eltern-Ordnern wie `P:\`, dem Home-Verzeichnis, Dev-Ordnern), oder
- den Nutzer kurz nach dem Pfad fragen.

Sobald der Workspace bekannt ist:

```bash
cd <kidney-workspace>
```

### 2. Verfügbare Repositories ermitteln

Liste die Repos im Master-Workspace, damit du nachher passende Namen für `kd do add` parat hast:

```bash
kd ls repos
```

Alternativ direkt den Inhalt von `.master/` mit `Glob`/`ls` anschauen.

### 3. Ticket-Name und -Beschreibung klären

Aus dem Anliegen des Nutzers (Bug, Feature, Aufgabe) leitest du ab:

- **Ticket-Name** — kurz, snake_case oder kebab-case im Stil bestehender Tickets unter `tickets/`; aussagekräftig (z. B. `fix_login_crash`, `add_dashboard_export`).
- **Ticket-Beschreibung** — ein bis zwei Sätze, die das Problem / Feature beschreiben.

**Frage den Nutzer explizit, ob Name und Beschreibung so passen**, bevor du etwas ausführst. Erst nach Bestätigung weiter.

### 4. Ticket erstellen

Im Workspace-Root:

```bash
kd do create ticket <ticket_name> -m "<ticket_description>"
```

Das legt `tickets/<ticket_name>/` an.

### 5. Relevante Repositories auswählen

Wechsle in den Ticket-Ordner:

```bash
cd tickets/<ticket_name>
```

Überlege anhand des Ticket-Inhalts, welche Repos aus `.master/` für die Umsetzung gebraucht werden. Bei Unsicherheit kurz die `README.md`/`pubspec.yaml` der in Frage kommenden Repos lesen. Heuristik:

- UI-Themen → meistens `kidney_ui` (oder andere `*_ui`-Repos)
- Daten-/Schema-Themen → `rljson`, `gg_json`, `kidney_core`
- Dev-Tools, CI, Release → `gg`, `gg_publish`, `gg_version`, `gg_changelog`, `gg_test`
- Querschnittliche Helfer → `gg_args`, `gg_router`, `gg_value`, etc.

Lieber zu wenige als zu viele Repos vorschlagen — der Nutzer ergänzt bei Bedarf.

**Frage den Nutzer**, ob die ausgewählten Repos zum Ticket hinzugefügt werden sollen. Liste sie einzeln mit kurzer Begründung auf. Erst nach Bestätigung weiter.

### 6. Repos zum Ticket hinzufügen

Im Ticket-Ordner:

```bash
kd do add <repo_1> <repo_2> ...
```

Alle bestätigten Repos in einem Aufruf übergeben.

### 7. Abschluss

Kurz zusammenfassen:
- Ticket-Pfad
- Hinzugefügte Repos
- Vorschlag für nächsten Schritt: VS Code mit `kd do code` öffnen oder Claude Code im Ticket-Workspace mit `kd do claude` starten — aber nicht ungefragt loslegen.

---

## Modus B — Single-Repo-Ticket (`gg do create ticket`)

Wenn klar ist, dass Feature oder Bugfix nur ein einziges Repo betrifft.

### 1. Ins Repo wechseln und aktualisieren

```bash
cd <pfad-zum-grace-cloud-repo>
git pull
```

Wenn der Pfad zum Repo unklar ist: nachfragen. Üblich ist ein gemeinsamer Eltern-Ordner für alle Grace-Cloud-Repos (auf vielen Maschinen `P:\grace_cloud`).

### 2. Branch-Name und Beschreibung klären

- **Branch-Name** — kurz, kebab-case, im Stil bestehender Branches im Repo (`fix-...`, `feat-...` falls dort üblich, sonst flach).
- **Beschreibung** — ein bis zwei Sätze, was geändert wird.

**Frage den Nutzer explizit nach Bestätigung** für Branch-Name und Beschreibung. Erst nach Bestätigung weiter.

### 3. Ticket erstellen

Im Repo-Root:

```bash
gg do create ticket -b "<branch_name>" -m "<ticket_description>"
```

Das legt einen Branch an und schreibt eine `.ticket`-Datei mit der Beschreibung.

### 4. Abschluss

Kurz melden:
- Repo-Pfad und neuer Branch
- Mögliche nächste Schritte — aber nicht ungefragt mit der Umsetzung anfangen.

---

## Wichtig (gilt für beide Modi)

- **Niemals** ohne Nutzer-Bestätigung Ticket anlegen oder Repos hinzufügen.
- Repo-Namen müssen exakt mit den Ordnernamen unter `.master/` (Modus A) bzw. dem Repo-Eltern-Ordner (Modus B) übereinstimmen.
- Wenn der Nutzer Ticketname / Branch / Repos schon vorgibt, nicht überflüssig nachfragen — nur fehlende Teile klären und am Ende kurz bestätigen lassen.
- Modus B: `git pull` **vor** dem Ticket-Befehl, nie danach.
- Bei abweichenden Pfaden auf der Maschine des Nutzers: nachfragen statt Standard-Pfade erzwingen.
