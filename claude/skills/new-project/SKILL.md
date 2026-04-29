---
name: new-project
description: Legt ein neues Grace-Cloud-Repository / -Package an. Bestätigt Name und ggf. Beschreibung mit dem Nutzer und nutzt `gg_create_package`. Verwende diesen Skill automatisch, wenn der Nutzer sinngemäß sagt "neues Projekt anlegen", "neues Repository erstellen", "neues Grace-Cloud-Package", "neues `gg_*`/`kidney_*`/`ds_*`-Paket", oder einen GitHub/GitLab-Link für ein noch leeres Repository nennt.
---

# Neues Grace-Cloud-Projekt anlegen

Du legst neue Grace-Cloud-Repositories an. Halte dich strikt an diese Reihenfolge — frage **immer** vor dem tatsächlichen Anlegen nach Bestätigung.

## 1. Zielordner ermitteln

Grace-Cloud-Repositories liegen üblicherweise alle nebeneinander in einem gemeinsamen Eltern-Ordner (z. B. `P:\grace_cloud` auf vielen Maschinen). Liste den vermuteten Ordner mit `Glob` oder `ls`, um:

- zu verifizieren, dass der Pfad existiert,
- bestehende Geschwister-Repos zu sehen (Namens-Konventionen, Prefixes wie `gg_`, `kidney_`, `ds_`).

Existiert der Standard-Pfad nicht oder ist nicht eindeutig: **frage den Nutzer nach dem korrekten Eltern-Ordner.**

## 2. Bestätigung beim Nutzer einholen

Bevor irgendetwas erstellt wird, fasse zusammen und lass bestätigen:

- **Zielordner** (`<grace-cloud-root>\<projektname>`)
- **Projektname** — sollte einem der Team-Prefixes folgen (`gg_`, `kidney_`, `ds_`), wenn passend.
- **GitHub-Org** — meistens `ggsuite`. Frage explizit nach, falls unklar.
- **Beschreibung** — `gg_create_package` verlangt eine Beschreibung mit **mindestens 60 Zeichen**.
- **Open Source ja/nein** — frage nach.
- **Flutter-Paket?** — nur wenn der Nutzer das sagt.

Erst nach expliziter Bestätigung weitermachen.

## 3. Projekt anlegen

Grace-Cloud-Pakete werden mit `gg_create_package` angelegt. **Führe vorher immer**

```bash
gg_create_package -h
```

**aus**, um die aktuelle Syntax/Flags zu sehen, und konstruiere den Aufruf basierend auf der Hilfe-Ausgabe. Niemals Flags raten.

Typischer Aufruf (im Eltern-Ordner ausführen):

```bash
gg_create_package -n <projektname> -g <github-org> -d "<beschreibung mit mind. 60 zeichen>" [--no-open-source]
```

## 4. GitHub / GitLab-Link bekommen?

Wenn der Nutzer beim Anlegen einen Repo-Link mitliefert, ist das Remote-Repo wahrscheinlich schon angelegt (eventuell mit README/LICENSE/.gitignore vorbefüllt).

- Frage den Nutzer, ob bestehende Dateien im Remote überschrieben werden dürfen.
- **Im Zweifel** vorher kurz prüfen, was schon im Repo liegt (`gh repo view <owner>/<repo> --json …` bzw. `git ls-remote`), und das dem Nutzer melden, falls dort nicht-triviale Inhalte liegen.
- Workflow nach `gg_create_package`: lokal commiten → `git push -u origin main`. Falls Remote bereits Commits hat: nur nach Rücksprache mit `--force-with-lease` pushen.

## 5. Nach dem Anlegen

- Kurz bestätigen, was wo angelegt wurde (absoluter Pfad).
- Push-Befehl nennen, aber **nicht ungefragt pushen**.
- Nicht ungefragt zusätzliche Boilerplate, CI-Configs, Lizenzen oder READMEs erzeugen — `gg_create_package` liefert die Standard-Struktur.

## Wichtig

- **Niemals** ohne Nutzer-Bestätigung von Pfad, Name, GitHub-Org und Beschreibung etwas erstellen.
- **Niemals** `gg_create_package`-Flags raten — immer erst `-h` aufrufen.
- Bestehende Ordner unter dem Zielpfad nicht überschreiben, ohne nachzufragen.
- Beschreibung muss mindestens 60 Zeichen lang sein, sonst lehnt `gg_create_package` ab.
