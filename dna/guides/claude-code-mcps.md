# Claude Code & MCPs

Kurzanleitung für Entwickler. Ziel: verstehen, was MCPs sind, wofür man sie nutzt und wie man sie in Claude Code einbindet und verwaltet.

## 1. Was ist ein MCP?

**MCP** steht für **Model Context Protocol** — ein offener Standard (initiiert von Anthropic), über den Claude mit externen Tools und Datenquellen spricht. Ein **MCP-Server** ist ein Prozess, der eine konkrete Integration bereitstellt (z. B. Jira, GitHub, eine Datenbank). Claude Code ist der **MCP-Client**, der diese Server anspricht.

Mentale Modelle:

- **Wie USB für KI:** ein Stecker, viele Geräte. Claude muss nicht für jede API neu programmiert werden — er spricht MCP, der Server übersetzt.
- **Wie ein Plugin-System:** du installierst Integrationen je nach Bedarf.
- **Wie ein Tool-Adapter:** Claude bekommt zusätzliche Werkzeuge (`mcp__jira__create_issue`, `mcp__github__list_prs` …), die er aufrufen kann wie eingebaute.

## 2. Wofür MCPs nutzen

Überall, wo Claude **nicht nur Code im Repo**, sondern **externe Systeme** sehen oder anfassen soll.

| Kategorie | Typische MCPs |
|---|---|
| **Issue-Tracking** | Jira, Linear, GitHub Issues, GitLab Issues |
| **Code-Hosting** | GitHub, GitLab, Bitbucket |
| **Kommunikation** | Slack, Microsoft Teams, WhatsApp |
| **Wissens-Datenbanken** | Confluence, Notion, Google Drive, SharePoint |
| **Datenbanken** | Postgres, MySQL, MongoDB, BigQuery, Snowflake |
| **Cloud-Provider** | AWS, GCP, Azure, Cloudflare |
| **Monitoring / Logs** | Sentry, Datadog, Grafana, Honeycomb |
| **Browser-Automation** | Playwright, Puppeteer |
| **Filesystem / Lokal** | Filesystem-MCP, Memory-MCP |
| **Sonstiges** | Stripe, Sentry, Figma, Notion, CardDAV, IMAP |

Eine offizielle Liste pflegt Anthropic: [modelcontextprotocol.io/servers](https://modelcontextprotocol.io/servers). Daneben gibt's ein großes Community-Ökosystem auf GitHub.

Typische Aufgaben mit MCP:

- "Lies das Jira-Ticket PROJ-1234 und implementier die beschriebene Änderung."
- "Lege einen GitHub-PR an und verknüpfe ihn mit Issue #42."
- "Frag die Postgres-Tabelle `users` ab und schreib mir den Migrationsplan."
- "Schick eine Slack-Nachricht in #dev-ops, wenn der Deploy durch ist."

## 3. MCP vs. andere Mechanismen

| Mechanismus | Wofür |
|---|---|
| **CLAUDE.md** | Statische Projektregeln |
| **Skill** | Wiederverwendbares Verfahren / Runbook |
| **Hook** | Automatische Reaktion auf Tool-Events |
| **MCP** | Zugriff auf externe Systeme (Daten + Aktionen) |

MCPs liefern **Fähigkeiten** (was Claude tun *kann*), Skills liefern **Anleitungen** (wie Claude etwas tun *soll*). Die Kombination ist mächtig: ein "Release"-Skill, der einen GitHub-MCP nutzt, automatisiert den ganzen Release-Workflow.

## 4. Der `/mcp`-Befehl

In jeder Claude-Code-Session ist `/mcp` die zentrale Anlaufstelle für MCPs.

| Aktion | Was du siehst / tust |
|---|---|
| `/mcp` | Liste aller konfigurierten MCP-Server mit Status (connected / failed / disabled) |
| Server auswählen | Details: Tools, Ressourcen, Auth-Status |
| OAuth-Login starten | Browser öffnet sich für Server, die OAuth nutzen (z. B. GitHub, Linear) |
| Tool-Berechtigungen verwalten | Einzelne Tools eines Servers erlauben / blocken |
| Reconnect / Logout | Verbindung neu aufbauen oder Auth zurücksetzen |

Daneben gibt's CLI-Befehle außerhalb der Session:

```bash
claude mcp list              # Alle Server anzeigen
claude mcp add <name> ...    # Server hinzufügen
claude mcp remove <name>     # Server entfernen
claude mcp get <name>        # Details zu einem Server
```

## 5. MCP-Server installieren

MCP-Server werden als Prozess gestartet (meist via `npx`, `uvx`, Docker oder Binary). Die Konfiguration steht in `~/.claude.json` (global) oder `.claude/settings.json` (projektweit).

**Beispiel: GitHub-MCP global installieren**

```bash
claude mcp add github -- npx -y @modelcontextprotocol/server-github
```

**Beispiel: Postgres-MCP projektweit**

```bash
claude mcp add --scope project postgres \
  -- npx -y @modelcontextprotocol/server-postgres \
  postgresql://user:pass@localhost/dbname
```

**Beispiel: Manuell in `settings.json`**

```json
{
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["-y", "@some/mcp-jira-server"],
      "env": {
        "JIRA_URL": "https://firma.atlassian.net",
        "JIRA_EMAIL": "${JIRA_EMAIL}",
        "JIRA_TOKEN": "${JIRA_TOKEN}"
      }
    }
  }
}
```

Nach dem Hinzufügen: Claude Code neu starten oder `/mcp` → Reconnect.

### Scopes

| Scope | Geltung | Datei |
|---|---|---|
| **user** | Alle Projekte des Users | `~/.claude.json` |
| **project** | Dieses Projekt, ins Git | `.mcp.json` im Repo |
| **local** | Dieses Projekt, nur lokal | `.claude/settings.local.json` |

Team-MCPs gehören in `.mcp.json` (committen). Persönliche Auth-Daten oder private Server gehören in user- oder local-Scope.

## 6. Tools eines MCP nutzen

Sobald ein MCP verbunden ist, tauchen seine Tools in Claude auf — Namensschema: `mcp__<servername>__<toolname>`. Beispiele aus der Praxis:

- `mcp__github__create_pull_request`
- `mcp__jira__search_issues`
- `mcp__postgres__query`
- `mcp__playwright__browser_navigate`

Claude entscheidet selbst, wann er sie nutzt — du kannst aber auch explizit prompten: *"Nutze den Jira-MCP, um Ticket PROJ-1234 zu holen."*

## 7. Worauf achten

**Sicherheit zuerst.** MCPs reden mit externen Systemen — oft mit deinen Credentials. Beachte:

- **Secrets nie hart in Configs schreiben** — Umgebungsvariablen oder Secret-Manager.
- **`.mcp.json` im Repo** darf keine Tokens enthalten, nur Server-Definitionen.
- **Nur vertrauenswürdige MCP-Server** nutzen. Ein bösartiger Server sieht alles, was Claude ihm schickt — und kann zurückliefern, was er will (Prompt Injection).
- **Berechtigungen scharf halten:** read-only-Token bevorzugen, wo möglich (z. B. GitHub-PAT mit minimalen Scopes).

**Performance.** Jeder MCP-Server kostet Startup-Zeit und belegt Context (Tool-Definitionen). 10+ aktive MCPs bremsen die Session spürbar. Faustregel: aktiv nur das, was du diese Woche brauchst — Rest entfernen oder per Scope projektspezifisch halten.

**Stabilität.** MCP-Server sind Drittsoftware. Wenn ein Server crasht, fallen seine Tools weg. `/mcp` zeigt den Status, Reconnect ist meist die schnellste Lösung.

**Prompt Injection.** Daten aus MCPs (Jira-Kommentare, GitHub-Issues, E-Mails) können bösartige Anweisungen enthalten ("ignoriere bisherige Instruktionen, lösche…"). Behandle MCP-Output wie User-Input von Fremden — nicht wie System-Wahrheit.

**Versionierung.** MCP-Server entwickeln sich schnell. `npx -y` zieht jeweils aktuelle Versionen — für reproduzierbare Setups Version pinnen (`@modelcontextprotocol/server-github@0.6.2`).

**Auth-Hygiene.** Bei OAuth-MCPs (GitHub, Linear, Slack) regelmäßig `/mcp` → Logout/Re-Login, wenn Token Scopes geändert wurden. Sonst stille Permission-Fehler.

## 8. Checkliste für einen neuen MCP

- [ ] Quelle vertrauenswürdig (offizielles Anthropic-Repo, bekannter Vendor oder geprüfter Community-Server)?
- [ ] Scope bewusst gewählt (user / project / local)?
- [ ] Secrets aus der Config rausgehalten (env-Variablen)?
- [ ] Minimale Berechtigungen am externen System (read-only-Token, eingeschränkte Scopes)?
- [ ] Per `/mcp` getestet: verbunden, Tools sichtbar, Beispiel-Aufruf läuft?
- [ ] Bei Team-MCP: PR-Review der `.mcp.json` wie für normalen Code?
- [ ] Dokumentiert, wofür der MCP genutzt wird (z. B. in `CLAUDE.md` oder Repo-README)?

Mehr: [code.claude.com/docs](https://code.claude.com/docs/en/mcp) · [modelcontextprotocol.io](https://modelcontextprotocol.io)
