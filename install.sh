#!/usr/bin/env bash
# aerc-setup installer.
#
#   sudo ./install.sh [--no-systemd]
#
# It installs the helper packages, the configuration and the helper scripts. It does not
# know or ask about your mail accounts: add those afterwards, one at a time, with
#   aerc-add-account            (run as your normal user, without sudo)
#
# Why sudo: installing the helper packages (apt) needs root. Everything else is written
# into YOUR home directory, so the script drops back to the invoking user ($SUDO_USER)
# for all of it; no file under $HOME is ever owned by root.
#
# Note: sudo normally drops XDG_CONFIG_HOME, so the installer writes to ~/.config/aerc unless the
# variable survives (e.g. sudo --preserve-env=XDG_CONFIG_HOME ./install.sh).
#
# Safe to re-run: a file that differs from the repo's version is backed up to
# ~/.config/aerc/backup-<timestamp>/ first, and accounts.conf is never touched.
#
# Flags
#   --no-systemd   do not install the new-mail notification service
#   --user-only    skip the root stage entirely (no package install, no sudo needed);
#                  meant for testing, or when the packages are already installed
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(libsecret-tools w3m catimg xdg-utils libnotify-bin python3)

USER_ONLY=0 NO_SYSTEMD=0
for arg in "$@"; do
  case "$arg" in
    --user-only) USER_ONLY=1 ;;
    --no-systemd) NO_SYSTEMD=1 ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- stage 1: root
if [[ $USER_ONLY -eq 0 ]]; then
  [[ $EUID -eq 0 ]] || die "run this with sudo:  sudo ./install.sh   (see README: \"Why sudo\")"
  TARGET_USER="${SUDO_USER:-}"
  [[ -n "$TARGET_USER" && "$TARGET_USER" != root ]] || die "run it via sudo from your normal user, not from a root login"

  if command -v apt-get >/dev/null 2>&1; then
    say "Installing packages: ${PACKAGES[*]}"
    apt-get install -y "${PACKAGES[@]}"
  else
    warn "apt-get not found. Install these yourself (names may differ): ${PACKAGES[*]}"
  fi

  uid="$(id -u "$TARGET_USER")"
  home="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  say "Continuing as $TARGET_USER"
  extra=(--user-only)
  [[ $NO_SYSTEMD -eq 1 ]] && extra+=(--no-systemd)
  exec runuser -u "$TARGET_USER" -- env HOME="$home" \
       XDG_RUNTIME_DIR="/run/user/$uid" \
       DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
       "$REPO_DIR/install.sh" "${extra[@]}"
fi

# ------------------------------------------------------------- stage 2: the user
[[ $EUID -ne 0 ]] || die "--user-only must not run as root (it would write root-owned files into a home directory)"

CONF_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONF="$CONF_HOME/aerc"
BIN="$HOME/.local/bin"
UNIT_DIR="$CONF_HOME/systemd/user"
BACKUP="$CONF/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$CONF" "$BIN" "$UNIT_DIR"

# Under sudo, PATH is sudo's "secure_path", so these checks cannot judge your normal shell: keep
# the wording to a note and verify in your own terminal instead.
command -v aerc >/dev/null 2>&1 || say "Note: aerc was not found on this PATH (ignore if it is installed elsewhere, e.g. via snap or go)."
NOTE_PATH="Make sure $BIN is on your PATH in your normal shell (check: echo \$PATH)."

# install_file SRC DST MODE: copy, backing up a different existing file first.
install_file() {
  local src="$1" dst="$2" mode="$3"
  if [[ -e "$dst" ]] && ! cmp -s "$src" "$dst"; then
    mkdir -p "$BACKUP"; cp -p "$dst" "$BACKUP/$(basename "$dst")"
    say "Backed up existing $(basename "$dst") to $BACKUP/"
  fi
  install -m "$mode" "$src" "$dst"
}

say "Installing helper scripts to $BIN"
for f in "$REPO_DIR"/bin/*; do install_file "$f" "$BIN/$(basename "$f")" 755; done

say "Installing aerc.conf and the documentation"
install_file "$REPO_DIR/config/aerc.conf" "$CONF/aerc.conf" 644
install_file "$REPO_DIR/docs/shortcuts.md" "$CONF/SHORTCUTS.md" 644

# binds.conf: the repo's version has an empty region between two markers that
# aerc-add-account fills with per-Gmail-account bindings. Carry the existing region over so
# re-running the installer never loses it.
BINDS_TMP="$(mktemp)"; trap 'rm -f "$BINDS_TMP"' EXIT
python3 - "$REPO_DIR/config/binds.conf" "$CONF/binds.conf" >"$BINDS_TMP" <<'PY'
import sys
BEGIN = "# >>> aerc-setup: Gmail Trash bindings"
END = "# <<< aerc-setup: Gmail Trash bindings"
new = open(sys.argv[1]).read()
try:
    old = open(sys.argv[2]).read()
except OSError:
    old = ""
oi, oj = old.find(BEGIN), old.find(END)
ni, nj = new.find(BEGIN), new.find(END)
if 0 <= oi < oj and 0 <= ni < nj:
    nl = new.index("\n", ni) + 1          # keep the repo's marker line, take the old content
    ol = old.index("\n", oi) + 1
    new = new[:nl] + old[ol:oj] + new[nj:]
sys.stdout.write(new)
PY
install_file "$BINDS_TMP" "$CONF/binds.conf" 644

[[ -e "$CONF/accounts.conf" ]] && chmod 600 "$CONF/accounts.conf"

if [[ $NO_SYSTEMD -eq 0 ]]; then
  install_file "$REPO_DIR/systemd/aerc-mailwatch.service" "$UNIT_DIR/aerc-mailwatch.service" 644
  if systemctl --user daemon-reload 2>/dev/null; then
    if [[ -s "$CONF/accounts.conf" ]]; then
      say "Restarting the new-mail notification service"
      systemctl --user enable aerc-mailwatch.service
      systemctl --user restart aerc-mailwatch.service
    else
      say "Notification service installed; it starts when you add your first account."
    fi
  else
    warn "Could not reach your systemd user session; after adding an account run:"
    warn "  systemctl --user daemon-reload && systemctl --user enable --now aerc-mailwatch.service"
  fi
fi

cat <<EOF

Installed. Next, add your mail accounts, one command per account
(as your normal user, WITHOUT sudo):

  aerc-add-account

It asks for the provider, address and password, saves the password in your keyring,
writes the account to $CONF/accounts.conf and checks the login.
Then start aerc. Shortcuts: $CONF/SHORTCUTS.md
$NOTE_PATH
EOF
