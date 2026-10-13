#!/usr/bin/env bash
# ============================================================================
#  Einmalige Einrichtung: Claude Code Remote Control auf dem VPS.
#  Auf dem Server aus dem Repo heraus ausfuehren, als root:
#
#      cd /root/vps-setup && git pull
#      bash claude-remote/setup.sh
#
#  Legt an:
#    - Benutzer "claude" ohne sudo, Projekte unter /home/claude/projects/
#    - Claude Code fuer diesen Benutzer (offizieller Installer)
#    - /etc/claude-code/managed-settings.json (Sperrliste, root-eigen,
#      kann von Claude nicht geaendert werden)
#    - systemd-Vorlage claude-remote@.service
#    - Befehl /usr/local/bin/claude-vps
#  Mehrfaches Ausfuehren schadet nicht.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

U=claude
[ "$(id -u)" = 0 ] || { echo "Bitte als root ausfuehren."; exit 1; }

echo "→ Pakete"
apt-get update -qq
apt-get install -y -qq tmux git curl sudo openssh-client >/dev/null

echo "→ Benutzer $U"
if ! id "$U" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$U"
  passwd -l "$U" >/dev/null          # kein Passwort-Login
fi
# Sicherheitsnetz: der Benutzer darf nicht in sudo/admin stehen.
for g in sudo admin wheel; do gpasswd -d "$U" "$g" >/dev/null 2>&1 || true; done
install -d -o "$U" -g "$U" -m 700 /home/$U/projects /home/$U/.ssh
chmod 750 /home/$U
sudo -iu "$U" bash -c 'touch ~/.ssh/config && chmod 600 ~/.ssh/config'
sudo -iu "$U" bash -c 'ssh-keyscan -t ed25519 github.com 2>/dev/null >> ~/.ssh/known_hosts; sort -u -o ~/.ssh/known_hosts ~/.ssh/known_hosts'
sudo -iu "$U" git config --global user.name  "${GIT_NAME:-Claude ($(hostname))}"
sudo -iu "$U" git config --global user.email "${GIT_EMAIL:-claude@$(hostname)}"

echo "→ Claude Code"
if ! sudo -iu "$U" bash -lc 'command -v claude' >/dev/null; then
  sudo -iu "$U" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
fi
# Installer legt claude nach ~/.local/bin – auch fuer nicht-Login-Shells (tmux) in den PATH.
sudo -iu "$U" bash -c 'grep -q "/.local/bin" ~/.bashrc || echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc'
sudo -iu "$U" bash -lc 'claude --version'

echo "→ Sperrliste /etc/claude-code/managed-settings.json"
install -d -m 755 /etc/claude-code
install -m 644 -o root -g root claude-managed-settings.json /etc/claude-code/managed-settings.json

echo "→ systemd-Vorlage"
install -m 644 claude-remote@.service /etc/systemd/system/claude-remote@.service
systemctl daemon-reload

echo "→ Befehl claude-vps"
install -m 755 claude-vps /usr/local/bin/claude-vps

command -v node >/dev/null || echo "! node fehlt – fuer 'node build.mjs' nachinstallieren."

cat <<EOF

✓ Grundeinrichtung fertig. Weiter (siehe claude-remote/README.md):

  1. claude-vps login
  2. claude-vps add oneworld git@github.com:Naturfactor/oneworld-fund.git
  3. claude-vps start oneworld
  4. claude-vps attach oneworld      (einmal Rueckfragen bestaetigen, Ctrl+b d)

Danach in der Claude-App (iPhone/Desktop) unter "Code" die Sitzung oeffnen.
EOF
