# Arbeitsweise mit Claude auf srv1429651

Stand: 21.10.2026.

## Zwei Zugänge

| | Mac-Terminal (`nf <projekt>`) | iPhone / Claude Desktop (Remote Control) |
|---|---|---|
| Benutzer | root | `claude` (ohne sudo) |
| Sieht | alles: alle Projekte, `.env`, `/var/www`, Docker | nur `/home/claude/projects/` |
| Wofür | Server, Cronjobs, nf-os, ai-trading, Companion-App, **Live schalten** | Website-Arbeit, kleine Änderungen, Aufgaben über Nacht |
| Erreichbar | solange die SSH-Verbindung steht | immer, auch wenn der Mac aus ist |

## Mac-Terminal

```bash
ssh -i ~/.ssh/thomasjlhahn_site root@185.170.198.140
nf <projekt>          # z. B. nf getasnack, nf aurelius
```

Nur hier wird live geschaltet.

## Claude Desktop (Code-Tab) und iPhone (Claude-App → Code)

- Umgebung **srv1429651-soft-dusk** wählen, neue Sitzung starten.
- Immer mit dem Projekt beginnen: *„Im Projekt getasnack: erst git pull, dann …“*
- Push gibt man in der App frei, wenn Claude fragt.
- Live geht von hier aus nichts.

Projekte des Benutzers `claude`:

| Name | GitHub-Repo |
|---|---|
| oneworld | Naturfactor/oneworld-fund |
| getasnack | Naturfactor/getasnack |
| findsbytom | Naturfactor/findsbytom |
| nataliebonetska | Naturfactor/nataliebonetska |
| thomasjlhahn-com | Naturfactor/thomasjlhahn-com |
| nfcosmetics | Naturfactor/nf-agency |

Bewusst **nicht** freigegeben: nf-os (Skripte, die root ausführt), ai-trading
(echtes Geld, Broker-Zugänge), nf-companion-app (Build braucht root),
pocket-bridge, nf-vault, vps-setup (enthält Claudes eigene Regeln).

Neues Projekt: `claude-vps add <name> git@github.com:Naturfactor/<repo>.git`,
den angezeigten Schlüssel im jeweiligen Repo als Deploy-Key mit Schreibrecht
eintragen.

## Ablauf einer Änderung

```
Handy/Desktop: Claude ändert → committet → pusht (nach Freigabe)
        ↓
     GitHub
        ↓
Mac (root): git pull → deploy
```

Jedes Website-Projekt existiert zweimal (root und `claude`), verbunden über
GitHub. Darum:

1. **Vor jeder Arbeit `git pull`, nach der Arbeit pushen** – auf beiden Seiten.
   Für root steht das in `/root/claude-system/standards/global-rules.md`.
2. **Ausnahme Live-Webroots unter `/var/www`:** dort kein automatischer Pull,
   nur Push. Ein Pull dort stellt GitHub-Stände sofort live.

## Live schalten (nur root)

Deployt wird immer aus `/root/projects/<projekt>` bzw. dem Live-Ordner –
die Deploy-Skripte haben diese Pfade fest eingetragen. Aus
`/home/claude/projects/*` deployt niemand.

| Projekt | Befehl |
|---|---|
| oneworld | `cd /root/projects/oneworld && git pull && nf world deploy` |
| nfcosmetics | `cd /var/www/nfcosmetics && git pull --rebase && nf-refresh` |
| getasnack | `cd /root/projects/getasnack && git pull --ff-only --autostash && bash pipeline/deploy_web.sh` |
| findsbytom | `cd /root/projects/findsbytom && git pull --ff-only && scripts/deploy.sh --live && git push` |
| nataliebonetska | `cd /root/projects/nataliebonetska && git pull --ff-only && bash deploy/deploy.sh` |
| thomasjlhahn-com | `cd /root/projects/tjlh && git pull --rebase && ./deploy.sh && git push` |

Hinweise:

- **getasnack:** Caddy liefert `/var/www/getasnack/web`; das Skript macht
  rsync und komprimiert vor, kein Neustart. `--autostash`, weil der Nachtlauf
  Zahlen in `web/*` ändert, ohne zu committen (die gehen laut Projektregel mit
  jedem Deploy mit; trifft ein Pull dieselben Dateien, kann es einen Konflikt
  geben). Nur bei Änderungen in `app/` zusätzlich die Next-App (PM2-Dienst
  `getasnack`, Port 3006):
  `cd /root/projects/getasnack/app && npm ci && npm run build && pm2 restart getasnack`
- **findsbytom:** statisches Astro. Das Skript baut, prüft, legt einen
  Snapshot an, rsync nach `/var/www/findsbytom`, komprimiert, prüft live und
  committet – pusht aber nicht, daher `git push` am Schluss.
- **nataliebonetska:** Next.js als systemd-Dienst `nataliebonetska`
  (Port 3012). Das Skript pullt selbst, `npm ci`, baut, legt ein Release unter
  `/opt/nataliebonetska` an, startet den Dienst neu und testet; bei Fehler
  automatisch zurück auf das vorige Release.
- **thomasjlhahn-com:** Ordner `/root/projects/tjlh`, rein statisch, rsync von
  `site/` nach `/var/www/thomasjlhahn`. `site/` ist eingecheckt;
  `python3 assemble.py` nur, wenn `gen/` geändert wurde, ohne `site/` neu zu
  bauen.

## nfcosmetics im Detail

- Live-Ordner `/var/www/nfcosmetics` ist zugleich das Git-Repo, Caddy liefert
  die Dateien statisch aus. `.git/`, `docs/` und `CLAUDE.md` liefern 404.
- Remote: `Naturfactor/nf-agency` (privat). Der Verlauf wurde vor dem ersten
  Push bereinigt (Zugangsdaten der Storage Box ersetzt); Sicherung des alten
  Verlaufs: `/root/backups/nfcosmetics-git-vor-filter-repo-20261021-211944.bundle`.
- root pusht über den Host-Alias `github-nf-agency` (eigener Deploy-Key).
- `nf-refresh` (Symlink auf `tools/nf-refresh.sh`) committet nur seine eigenen
  Dateien (`*.min.*`, HTML-Dateien mit reinen `?v=`-Änderungen) und pusht
  danach – nie ein Pull. Ist GitHub weiter als live, meldet es
  „GitHub ist weiter als live – erst bewusst deployen“. Log:
  `/var/log/nf_refresh.log`. Alte Fassung:
  `/root/backups/nf-refresh.sh.bak.20261021-214103`.

## Regeln für Claude (gelten für alle Benutzer)

`/etc/claude-code/managed-settings.json` (Quelle:
`claude-remote/claude-managed-settings.json`) gilt für `claude` **und root**,
also auch in `nf`-Sitzungen:

- Modus ohne Rückfragen gesperrt.
- `.env`, Schlüssel, `~/.ssh`, `secrets/` für das Lese-Werkzeug gesperrt.
- Rückfrage bei `git push`, `git reset`, `git rebase`, `rm`, `curl`, `wget`,
  `npm install`/`npm ci`, `pnpm install`.
- Force-Push gesperrt.

## Server-Pflege 21.10.2026

- Platte von 90 % auf 66 % (33 GB frei): MobSF-Container und -Image entfernt,
  npm-/Gradle-/Cache-Ordner und alte Claude-Versionen gelöscht,
  Android-Build-Ordner der Companion-App gelöscht.
- Handsicherungen aus `/root/backups` (umbau-wissen-hub, nf-os_20260618…,
  hub_20260618…, artefakte, phase0-20261006, sicherung-1.0.5-b95-vc22) liegen
  im Archiv auf der Storage Box unter `archiv/vps-backups/` (264.342 Dateien,
  10,9 GB, per Prüfsumme verglichen) und wurden lokal gelöscht. Behalten:
  `ai-trading`, `supabase`, `nf-companion`, `nf-os-pre-remote` (von Cronjobs
  bzw. dem Restore-Test genutzt).
- 64 Pakete aktualisiert, Neustart: alle Dienste und Container wieder da,
  Claude Remote startete von selbst.

Offen: `/swapfile2` (4 GB, Swap derzeit kaum genutzt), nächtlicher Download
der OSM-Kartendaten in getasnack (5,9 GB) prüfen.

## Notfall

```bash
claude-vps stop       # Remote-Zugang sofort aus
```

Zusätzlich die Deploy-Keys `claude@srv1429651` bei GitHub löschen.
