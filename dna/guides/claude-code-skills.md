# Claude Code Skills

Kurzanleitung für Entwickler. Ziel: verstehen, was Skills sind, wann man sie baut und wie man sie zusammen mit Claude erstellt.

## 1. Was ist ein Skill?

Ein **Skill** ist eine benannte, wiederverwendbare Anweisung, die Claude Code situativ lädt — vergleichbar mit einem Mini-Runbook oder spezialisierten Slash-Command. Du rufst ihn explizit per `/skill-name` auf, oder Claude lädt ihn automatisch, wenn das Thema im Gespräch passt.

Technisch: ein Ordner mit einer `SKILL.md`-Datei (plus optional Templates, Scripts, Referenzen). Die Datei hat ein Frontmatter (`name`, `description`) und einen Body mit den Anweisungen.

Wo Skills leben:

| Ort | Geltungsbereich |
|---|---|
| `~/.claude/skills/<name>/` | Global, alle Projekte |
| `<projekt>/.claude/skills/<name>/` | Projekt-Team (committen) |
| `<projekt>/.claude/skills.local/` | Persönlich pro Projekt (gitignored) |

## 2. Wann Skills sinnvoll sind

Skills lohnen sich bei **wiederkehrenden, mehrstufigen Aufgaben** oder Konventionen, die Claude nicht aus dem Code allein ableiten kann.

| Anwendungsfall | Beispiel |
|---|---|
| Release-Workflow | Version bumpen, Changelog erzeugen, Tag vorschlagen |
| Domain-Heuristik | "Beim Anfassen von Billing-Code diese Invarianten beachten…" |
| Code-Pattern | Migration anlegen nach Projekt-Konvention |
| Review-Checkliste | Diff gegen Security- und Performance-Pitfalls prüfen |
| Doku-Generierung | ADR aus Diskussion nach Template ableiten |

Faustregel: Wenn du dieselbe Anweisung an Claude dreimal gegeben hast — wird's ein Skill.

## 3. Skill vs. andere Mechanismen

| Mechanismus | Wofür |
|---|---|
| **`CLAUDE.md`** | Immer geltende Projektregeln, in jedem Chat aktiv |
| **Skill** | Situativ geladene Anleitung, per Trigger oder explizit |
| **Hook** | Automatische Reaktion auf Tool-Events (in `settings.json`) |
| **Subagent** | Parallele oder isolierte Recherche im eigenen Kontext |

Skills sind **nutzergetrieben und situativ** — nicht "passiert immer" (das wären Hooks) und nicht "gilt überall" (das wäre `CLAUDE.md`).

## 4. Anatomie eines Skills

Minimales Beispiel:

```
.claude/skills/release-pr/
└── SKILL.md
```

```markdown
---
name: release-pr
description: Bereitet einen Release-PR vor — Version in package.json bumpen,
  Changelog aus Commits seit letztem Tag erzeugen, Tag-Name vorschlagen.
  Aufrufen, wenn der Nutzer einen Release oder eine neue Version vorbereitet.
---

# Release-PR

## Schritte
1. Lies aktuelle Version aus `package.json`.
2. Liste Commits seit letztem Tag: `git log <last-tag>..HEAD --oneline`.
3. Gruppiere in Features / Fixes / Chores.
4. Schlage SemVer-Bump vor (major/minor/patch).
5. **Vor dem Bumpen rückfragen.**

## Hinweise
- Niemals direkt auf `main` pushen.
- Bei Breaking Changes immer Rückfrage.
```

Bei komplexeren Skills kommen weitere Dateien dazu (Templates, Hilfsscripts, Referenz-Markdown), die aus der `SKILL.md` relativ referenziert werden.

## 5. Skill mit Claude erstellen

Der schnellste Weg: Claude den ersten Entwurf bauen lassen.

**Schritt 1 — Bedarf formulieren.** In einem Prompt: was der Skill tun soll, wann er auslösen soll, welche Schritte, welche Edge Cases.

> "Erstelle einen Skill `db-migration`: findet die nächste freie Nummer in `migrations/`, legt Up- und Down-File aus Template an, warnt bei `DROP COLUMN` ohne `NOT NULL`-Check. Auslösen bei 'Migration', 'Schema-Änderung', 'ALTER TABLE'."

**Schritt 2 — Scaffold prüfen.** Claude legt den Ordner und die `SKILL.md` an. Lies kritisch:
- Frontmatter `name` und `description` gesetzt und scharf?
- Schritte explizit, nummeriert, einzeln testbar?
- Destruktive Aktionen mit Nutzer-Rückfrage?

**Schritt 3 — In frischem Context testen.** Neue Session starten:
- **Explizit:** `/db-migration` — wird der Skill geladen?
- **Implizit:** Typischen Satz sagen ("Ich brauche eine Migration für die users-Tabelle") — schlägt Claude den Skill vor?

Wenn implizit nicht klappt → Description schärfen (siehe §6).

**Schritt 4 — Iterieren.** Skills sind lebende Dokumente. Korrigierst du dieselbe Sache dreimal, gehört sie in den Skill.

## 6. Worauf achten

**Description ist die wichtigste Zeile.** Claude entscheidet anhand der Description, ob er den Skill auto-triggert. Schlechte Description = Skill wird nie geladen.

- Konkret statt vage: "Bereitet Release-PR vor inkl. Changelog und Version-Bump" statt "Hilft beim Release".
- Trigger-Wörter benennen.
- Falls nötig: Negativabgrenzung ("Nicht aufrufen für Hotfixes ohne Versionssprung").

**Scope-Disziplin.** Zu breit → Claude weiß nicht, wann er greift. Zu eng → du brauchst 30 Skills für 30 Tabellen. Sweet Spot: ein Skill = ein Verfahren.

**Sicherheit.**
- Keine Secrets ins Skill committen.
- Destruktive Schritte (rm, drop, force-push) immer mit Rückfrage.
- Team-Skills im PR-Review behandeln wie Code — sie *sind* Code, der Verhalten steuert.

**Kontext-Budget.** Jeder auto-geladene Skill kostet Tokens. Lieber wenige, scharf geschriebene Skills als viele unscharfe.

**Wartung.** Workflows ändern sich. Plane vierteljährliches Review der Skill-Sammlung — gerade in Team-Repos.

## 7. Checkliste vor dem Commit

- [ ] `name` in kebab-case, eindeutig
- [ ] `description` konkret, mit Trigger-Kontexten
- [ ] Schritte nummeriert, einzeln testbar
- [ ] Keine Secrets, keine persönlichen Pfade
- [ ] Destruktive Schritte erfordern Nutzer-Bestätigung
- [ ] In frischer Session getestet (explizit + implizit)
- [ ] Bei Team-Skill: PR-Review wie für normalen Code

Mehr: [code.claude.com/docs](https://code.claude.com/docs/en/skills)
