# Arbeiten mit Claude Code

Kurzanleitung für Entwickler. Ziel: in unter 10 Minuten produktiv mit Claude Code arbeiten.

## 1. Installation

**Windows (PowerShell):**
```powershell
irm https://claude.ai/install.ps1 | iex
```

**macOS / Linux / WSL:**
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Alternativen: `brew install --cask claude-code` (macOS), `winget install Anthropic.ClaudeCode` (Windows), `npm install -g @anthropic-ai/claude-code`.

Voraussetzung: Claude-Account (Pro/Max/Team/Enterprise) oder Console-API-Key. Auf nativem Windows wird zusätzlich [Git for Windows](https://git-scm.com/downloads/win) empfohlen.

Prüfen:
```bash
claude --version
claude doctor
```

## 2. Projekt initialisieren

In den Projektordner wechseln und Claude starten:

```bash
cd P:\pfad\zum\projekt
claude
```

Beim ersten Start: einmal einloggen (Browser öffnet sich automatisch).

Optional als ersten Schritt im Projekt:
```
/init
```
Erstellt eine `CLAUDE.md` mit Projekt-Kontext, den Claude in jeder Session automatisch lädt.

## 3. Plan-Mode vs. Programming-Mode

Claude Code hat zwei relevante Arbeitsmodi:

| Modus | Was er tut | Dateien anfassen? |
|---|---|---|
| **Programming-Mode** (Default) | Liest, schreibt, editiert Code, führt Befehle aus | Ja — fragt vor jeder Änderung um Erlaubnis (oder `Auto-Accept`) |
| **Plan-Mode** | Liest nur, analysiert, fragt zurück, erstellt einen Plan | **Nein** — read-only, keine Edits, keine Schreib-Befehle |

### Hin- und herwechseln

- **In der Session:** `Shift+Tab` zykliert durch die Modi: *Normal → Auto-Accept → Plan → Normal …*. Der aktuelle Modus steht unten in der Statuszeile (`⏸ plan mode on`).
- **Beim Start:** `claude --permission-mode plan`
- **Plan annehmen:** Claude legt am Ende einen Plan vor — du bestätigst, danach wechselt er automatisch in den Programming-Mode und setzt um.
- **Aus Plan-Mode raus, ohne Plan:** `Esc` oder erneut `Shift+Tab`.

## 4. Warum erst planen?

Bei nicht-trivialen Aufgaben (mehrere Dateien, Refactoring, neues Feature, unklare Architektur) zahlt sich Plan-Mode aus:

- **Kein versehentliches Verschlimmbessern** — read-only, du siehst die Strategie *bevor* etwas geschrieben wird.
- **Du kannst korrigieren** — wenn Claude den Bug an der falschen Stelle vermutet, korrigierst du den Plan, statt einen kaputten Patch zu reverten.
- **Bessere Ergebnisse** — Claude analysiert erst Codebase + Anforderungen, bevor er Code produziert. Das spart Iterationen.
- **Geteiltes Verständnis** — du weißt, was passieren wird, und kannst Edge Cases ergänzen, die Claude noch nicht kennt.

Faustregel: **Triviale Edits → direkt im Programming-Mode. Alles andere (Bug fixen ohne klare Zeile, Feature, Refactor, Migration) → erst Plan-Mode.**

## 5. Über mehrere Repos arbeiten (Kidney / Grace Cloud)

Wenn ein Ticket Änderungen in mehreren Repositories braucht, arbeite **im Ticket-Workspace**, nicht im einzelnen Repo:

```bash
cd P:\workspace_grace_cloud\<ticket_name>
kd do claude
```

`kd do claude` startet Claude Code im Ticket-Workspace mit Zugriff auf **alle** dem Ticket per `kd do add` zugewiesenen Repos. Damit kann Claude repo-übergreifend lesen, ändern und Konsistenz herstellen — z. B. eine Schema-Änderung in `kidney_core` mit der UI in `kidney_ui` zusammen anpassen.

Für Tickets, die nur ein einziges Repo betreffen, reicht weiterhin `claude` direkt im Repo-Ordner.

## 6. Häufige Befehle

| Befehl | Zweck |
|---|---|
| `claude` | Interaktive Session starten |
| `claude -c` | Letzte Session im aktuellen Ordner fortsetzen |
| `claude -r` | Session-Picker zum Auswählen |
| `claude -p "<frage>"` | Einmalige Frage, sofort Antwort, Exit |
| `/init` | `CLAUDE.md` mit Projekt-Kontext anlegen |
| `/clear` | Verlauf der aktuellen Session löschen |
| `/help` | Alle Befehle anzeigen |
| `Shift+Tab` | Zwischen Modi wechseln |
| `Esc` | Aktion abbrechen / Plan-Mode verlassen |
| `Ctrl+D` oder `exit` | Beenden |

Mehr: [code.claude.com/docs](https://code.claude.com/docs/en/quickstart)
