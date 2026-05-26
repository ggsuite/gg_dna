---
name: new-ticket
description: Legt ein neues Arbeits-Ticket an. Zwei Modi - (A) Multi-Repo-Ticket im Workspace, (B) Single-Repo-Ticket als Branch im Repo. Verwende diesen Skill, wenn der Nutzer sinngemäß sagt "neues Ticket anlegen/erstellen", "Bug fixen", "Feature umsetzen/einführen". Auch bei Formulierungen wie "ich will an X arbeiten", "lass uns Bug Y beheben" greifen.
---

# Neues Ticket anlegen

Du legst Tickets für die Arbeit an einem oder mehreren Repositories an. Es gibt **zwei Modi** — wähle anhand des Anliegens:

- **Modus A — Multi-Repo-Ticket**: Änderungen betreffen mehrere Repos oder es ist beim Anlegen noch unklar, welche Repos genau gebraucht werden → Workspace-Ticket, das mehrere Repos klammert.
- **Modus B — Single-Repo-Ticket**: Bug oder Feature betrifft eindeutig nur ein einziges Repo → Ticket-Branch direkt im Repo.

Frage im Zweifel den Nutzer, welcher Modus passt. Wenn er von vornherein nur ein Repo nennt, ist Modus B richtig.

Welche konkreten Tools dafür eingesetzt werden, ist projekt-spezifisch. Beispiele für ein Multi-Repo-Setup: ein Custom-Workspace-CLI mit Sub-Befehlen wie `create ticket`/`add`/`do commit`. Beispiel für Single-Repo: schlicht `git checkout -b <branch>` oder ein Repo-eigener Helfer. Wenn dein Repo per Overlay einen spezifischeren Workflow vorgibt, nimm den.

---

## Modus A — Multi-Repo-Ticket

### 1. In den Workspace wechseln

Der Workspace ist der Ordner, in dem die beteiligten Repos versammelt werden (oft als `.master/` mit eigenem `tickets/`-Ordner organisiert). Der Pfad ist von Maschine zu Maschine verschieden — frage den Nutzer entweder explizit danach, oder finde den Workspace selbst mit `Glob` nach plausiblen Markern (`.master/`, `tickets/`, `workspace.yaml`).

### 2. Verfügbare Repositories ermitteln

Liste die Repos im Workspace, damit du nachher passende Namen zum Hinzufügen parat hast. Wenn das Projekt ein dediziertes CLI hat, das die Repo-Liste kennt, benutze es; sonst direkt `Glob`/`ls` auf den Workspace-Inhalt.

### 3. Ticket-Name und -Beschreibung klären

Aus dem Anliegen des Nutzers leitest du ab:

- **Ticket-Name** — kurz, snake_case oder kebab-case im Stil bestehender Tickets; aussagekräftig (z. B. `fix_login_crash`, `add_dashboard_export`).
- **Ticket-Beschreibung** — ein bis zwei Sätze, die das Problem / Feature beschreiben.

**Frage den Nutzer explizit, ob Name und Beschreibung so passen**, bevor du etwas ausführst. Erst nach Bestätigung weiter.

### 4. Ticket erstellen

Verwende das projekttypische Create-Kommando. Frage erst `--help` ab, wenn du das Tool nicht kennst, und konstruiere den Aufruf daraus.

### 5. Relevante Repositories auswählen

Überlege anhand des Ticket-Inhalts, welche Repos für die Umsetzung gebraucht werden. Bei Unsicherheit kurz die `README.md` / das Manifest der in Frage kommenden Repos lesen.

Lieber zu wenige als zu viele Repos vorschlagen — der Nutzer ergänzt bei Bedarf.

**Frage den Nutzer**, ob die ausgewählten Repos zum Ticket hinzugefügt werden sollen. Liste sie einzeln mit kurzer Begründung auf. Erst nach Bestätigung weiter.

### 6. Repos zum Ticket hinzufügen

Mit dem projekttypischen Add-Kommando alle bestätigten Repos in einem Aufruf hinzufügen.

### 7. Abschluss

Kurz zusammenfassen:
- Ticket-Pfad
- Hinzugefügte Repos
- Vorschlag für nächsten Schritt — aber nicht ungefragt loslegen.

---

## Modus B — Single-Repo-Ticket

Wenn klar ist, dass Feature oder Bugfix nur ein einziges Repo betrifft.

### 1. Ins Repo wechseln und aktualisieren

```bash
cd <pfad-zum-repo>
git pull
```

Wenn der Pfad zum Repo unklar ist: nachfragen.

### 2. Branch-Name und Beschreibung klären

- **Branch-Name** — kurz, kebab-case, im Stil bestehender Branches im Repo (`fix-...`, `feat-...` falls dort üblich, sonst flach).
- **Beschreibung** — ein bis zwei Sätze, was geändert wird.

**Frage den Nutzer explizit nach Bestätigung** für Branch-Name und Beschreibung. Erst nach Bestätigung weiter.

### 3. Branch und Ticket-Notiz erstellen

Standardvariante:

```bash
git checkout -b <branch_name>
```

Wenn das Projekt einen eigenen Wrapper bereitstellt (z. B. ein CLI, das gleich eine `.ticket`-Datei mit Beschreibung anlegt), nimm den stattdessen. Konsultiere den projekt-spezifischen Guide (z. B. unter `dna/agents/guides/`), falls vorhanden.

### 4. Abschluss

Kurz melden:
- Repo-Pfad und neuer Branch
- Mögliche nächste Schritte — aber nicht ungefragt mit der Umsetzung anfangen.

---

## Wichtig (gilt für beide Modi)

- **Niemals** ohne Nutzer-Bestätigung Ticket anlegen oder Repos hinzufügen.
- Repo-Namen müssen exakt mit den Ordnernamen im Workspace bzw. dem Repo-Eltern-Ordner übereinstimmen.
- Wenn der Nutzer Ticketname / Branch / Repos schon vorgibt, nicht überflüssig nachfragen — nur fehlende Teile klären und am Ende kurz bestätigen lassen.
- Modus B: `git pull` **vor** dem Ticket-Befehl, nie danach.
- Bei abweichenden Pfaden auf der Maschine des Nutzers: nachfragen statt Standard-Pfade erzwingen.
