# Claude Code auf dem VPS (Remote Control)

Claude läuft dauerhaft auf srv1429651 und wird aus der Claude-App gesteuert –
iPhone, Desktop oder Browser, unter **Code**. Der Mac muss dafür nicht laufen.
Am Server wird kein Port geöffnet: Die Verbindung geht vom VPS aus zu Anthropic.

## Aufbau

| Was | Wo |
|---|---|
| Benutzer | `claude`, ohne Passwort, ohne sudo |
| Projekte | `/home/claude/projects/<name>/` (eigene Git-Klone) |
| Dienst (Normalfall) | `claude-remote.service` → tmux-Sitzung `claude-alle`, Arbeitsordner `/home/claude/projects` – eine Sitzung für alle Projekte |
| Dienst (einzeln, optional) | `claude-remote@<name>.service` → tmux-Sitzung `claude-<name>` |
| Sperrliste | `/etc/claude-code/managed-settings.json` (root-eigen, Quelle `claude-remote/claude-managed-settings.json`) |
| Verwaltung | `/usr/local/bin/claude-vps` (Quelle `claude-remote/claude-vps`) |
| GitHub | ein Deploy-Key pro Projekt, Host-Alias `github-<name>` in `~claude/.ssh/config` |

## Einrichten (einmalig, als root per SSH)

```bash
git clone git@github.com:Naturfactor/vps-setup.git /root/vps-setup   # später: git -C /root/vps-setup pull
bash /root/vps-setup/claude-remote/setup.sh

claude-vps login          # Claude startet, /login, Account bestätigen, /exit
claude-vps add oneworld git@github.com:Naturfactor/oneworld-fund.git
                          # zeigt einen Schlüssel → GitHub: Repo → Settings →
                          # Deploy keys → Add, "Allow write access" an → Enter
claude-vps start            # eine Sitzung für alle Projekte
claude-vps attach           # beim ersten Mal Rückfragen bestätigen, Ctrl+b d
```

Dann in der Claude-App unter **Code** die Sitzung öffnen.

## Alltag

```bash
claude-vps status
claude-vps restart
claude-vps logs
claude-vps attach
claude-vps stop
```

Weitere Projekte: `claude-vps add <name> <git-url>` – sie liegen danach in
`~/projects/<name>` und sind in der laufenden Sitzung sofort erreichbar. In
der App einfach sagen, in welchem Projekt gearbeitet wird („im Projekt
oneworld …“). Ein Projekt mit eigener Sitzung: `claude-vps start <name>`.

Vom iPhone aus geht das mit einer SSH-App (Termius, Blink Shell).
Nach einem Neustart des VPS startet alles von selbst.

## Was Claude darf – und was nicht

- **Darf:** in `/home/claude/` lesen und schreiben, Befehle ausführen, nach
  Rückfrage committen und auf GitHub pushen (nur in die Repos mit Deploy-Key).
- **Darf nicht:** sudo, `/root/` lesen (also auch nicht `/root/projects/`),
  nach `/etc`, `/usr`, `/var/www` schreiben, die `.env` der Dienste lesen
  (`/opt/oneworld-*` gehören anderen Benutzern).
- **Rückfragen bleiben an:** `disableBypassPermissionsMode` verhindert, dass
  der Modus ohne Rückfragen eingeschaltet wird.
- **Ohne Rückfrage (für alle Projekte, damit Nachtaufgaben durchlaufen):**
  Dateien unter `~/projects/` bearbeiten, lokales Git (status, diff, log,
  add, commit, Branch anlegen, fetch, pull), Bauen und Testen
  (`node build.mjs`, `npm test`, `npm run build|test|lint`, `pnpm`, `pytest`).
- **Immer mit Rückfrage:** `git push`, `git reset`, `git rebase`, `rm`,
  `curl`/`wget`, Paketinstallationen – und alles, was nicht in der Liste steht.
- **Gesperrt:** Force-Push.
- Bewusst nicht freigegeben: `cat`, `grep`, `find` in der Shell – damit ließe
  sich die Sperrliste umgehen. Claude nutzt dafür seine eigenen Werkzeuge, die
  die Sperrliste beachten.
- Die Liste liegt root-eigen in `/etc/claude-code/managed-settings.json`;
  Claude kann sie nicht erweitern. Ändern: Quelle im Repo anpassen,
  `claude-remote/setup.sh` erneut ausführen.
- **Sperrliste:** `.env`, Schlüssel, `~/.ssh` und `secrets/` sind für das
  Lese-Werkzeug gesperrt. Ein Shell-Befehl wie `cat .env` ist dadurch nicht
  ausgeschlossen, fragt aber vorher nach – solche Rückfragen ablehnen.

## Deployen

Claude arbeitet im eigenen Klon und pusht auf GitHub. Live geht es weiterhin
über root:

```bash
cd /root/projects/oneworld && git pull && nf world deploy
```

Absichtlich so: Ein Deploy braucht root (Caddy, `/var/www`). Soll Claude das
selbst können, wäre eine eng gefasste sudo-Regel nur für `nf world deploy`
der Weg – erst prüfen, was `nf_world` alles ausführt.

## Sicherheit

- 2-Faktor-Anmeldung für den Claude-Account – er ist jetzt der Schlüssel zum Server.
- iPhone mit Code/Face ID sperren.
- Keine Passwörter oder Tokens in `/home/claude/projects/` ablegen.
- Was Claude liest, geht zur Verarbeitung an Anthropic – keine Kundendaten
  in die Projekte legen.
- Zugang entziehen: `claude-vps stop`, Deploy-Key bei GitHub löschen,
  in der Claude-App abmelden.
