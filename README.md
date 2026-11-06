# aerc-setup

A ready-made configuration for the [aerc](https://aerc-mail.org) terminal mail client, plus an
installer. It targets several IMAP accounts (Gmail / Google Workspace, AOL, Outlook.com) with
**no passwords in any file**: secrets are read from the GNOME keyring at run time.

It is configuration and small helper scripts only; it does not modify or patch aerc itself.
Developed on Ubuntu with GNOME (Wayland) and aerc 0.21. Not affiliated with the aerc project.

## What you get

- **Keyring-based credentials** for every account (`secret-tool`), no secrets in `accounts.conf`.
- **Outlook / Microsoft 365 over OAuth2**, with automatic token renewal, so the connection no
  longer breaks after about an hour of inactivity.
- **New-mail desktop notifications** that work even when aerc is closed (`aerc-mailwatch`,
  a systemd user service), because aerc's own `mail-received` hook did not fire for IMAP here.
- **HTML mail**: rendered as text in the pager (`w3m`), and `B` opens the message as real HTML
  in your default browser, under a strict Content-Security-Policy: no scripts and no remote
  images or other remote content (so no tracking pixels), inline images are embedded. Images
  preview in the terminal (`catimg`); `:open` hands attachments to `xdg-open`, so only open
  attachments you trust.
- **Search that looks at the whole message** (`/`), a list filter (`\`), and Gmail's server-side
  search (`?`).
- **Gmail delete = move to Trash.** Plain IMAP delete does nothing useful on Gmail (the message
  just turns gray); `aerc-add-account` detects each Gmail account's Trash folder and binds `d` / `D` to it.
- Tab switching with `Ctrl+Left` / `Ctrl+Right` everywhere, `Ctrl+r` to check for new mail,
  `x` to toggle read/unread, `f` to forward, `Alt+q` to close a compose window, and a theme (nord).
  The full list is in [docs/shortcuts.md](docs/shortcuts.md).

## Requirements

- Linux with aerc installed, a GNOME keyring (or any Secret Service provider), and `systemd --user`
  for the notification service.
- Debian/Ubuntu is assumed for the package step: `libsecret-tools w3m catimg xdg-utils libnotify-bin python3`.
  On other distributions install the equivalents yourself; the script warns and continues.

## Quick start

Two separate steps: install once, then add your accounts.

```sh
git clone <this repository> && cd aerc-setup
sudo ./install.sh            # 1. packages, configuration, helper scripts
aerc-add-account             # 2. once per mail account, as your normal user (no sudo)
```

`aerc-add-account` asks for the provider (Gmail, Google Workspace, AOL, Outlook, or any other
IMAP server), your address and a short name, and then:

- stores the password in your keyring (typed hidden; it never touches a file, a command line or
  your shell history; for Gmail and AOL use an **app password**),
- appends the account to `~/.config/aerc/accounts.conf` (mode 600),
- tests the login,
- for a Gmail account, finds its Trash folder and binds the delete keys to it,
- (re)starts the new-mail notification service so it includes the new account.

Run it again for each further account, then start `aerc`. If an account name already exists it
only offers to replace the stored password (it asks first; scripts must pass `--replace-password`).
Only one Outlook account is supported, because the OAuth token store is shared. All answers can
also be given as options (`aerc-add-account --help`), and `--password-stdin` reads the password from
standard input for scripting. The name `outlook-oauth` is reserved.

If you would rather edit `accounts.conf` yourself, start from `config/accounts.conf.example` and
store each password with `secret-tool store --label="aerc NAME" service aerc account NAME`.
Then run `aerc-mailwatch --update-trash-binds` once (for Gmail accounts) and `systemctl --user restart aerc-mailwatch`.

Installer options: `--no-systemd` (skip the notification service) and `--user-only` (skip the
root stage; no packages are installed).

### Why sudo

Installing the helper packages with `apt` needs root, so the installer is meant to be run with
`sudo`. It does **not** keep root for the rest: after the package step it re-launches itself as
the user who ran `sudo` (`$SUDO_USER`) and does everything under your home directory as that
user, so no file in your home ends up owned by root and the keyring and your user's systemd
session are reachable. Running it as a plain root login is refused for the same reason.
`aerc-add-account`, in contrast, must **not** be run with `sudo`: the keyring belongs to your own login session.

The script is safe to re-run. Before replacing a file that differs from the repo's version it
saves the old one in `~/.config/aerc/backup-<timestamp>/`, and it never overwrites an existing
`accounts.conf`, which the installer never touches.

## What gets installed

| Where | What |
|---|---|
| `~/.config/aerc/aerc.conf` | filters (HTML, images), openers (`xdg-open`), theme |
| `~/.config/aerc/binds.conf` | aerc's default bindings plus the changes above |
| `~/.config/aerc/accounts.conf` | created by `aerc-add-account`, never by the installer; mode 600 |
| `~/.config/aerc/SHORTCUTS.md` | the shortcut cheat sheet |
| `~/.local/bin/aerc-add-account` | adds an account and stores its password in the keyring |
| `~/.local/bin/aerc-open-html` | opens a message as HTML in the browser (`B`) |
| `~/.local/bin/aerc-outlook-token` | OAuth2 helper for Outlook |
| `~/.local/bin/aerc-mailwatch` | the notification checker |
| `~/.config/systemd/user/aerc-mailwatch.service` | runs the checker at login |

`~/.local/bin` must be on your `PATH`.

## Outlook / Microsoft 365

Microsoft no longer accepts passwords for IMAP/SMTP on Outlook.com, so this account type needs
OAuth2, which needs an **app registration that you control**. Nothing in this repository ships
a client ID.

1. Register an app in the [Microsoft Entra admin center](https://entra.microsoft.com)
   (*Entra ID → App registrations → New registration*). Choose the account type that includes
   personal Microsoft accounts if you use Outlook.com. Leave the redirect URI empty.
2. Under *Authentication*, enable **Allow public client flows**.
3. Under *API permissions*, add the delegated permissions `IMAP.AccessAsUser.All` and
   `SMTP.Send` (resource "Office 365 Exchange Online") and `offline_access`.
4. Copy the **Application (client) ID**, then run `aerc-add-account`, choose `outlook`, and paste it
   when asked. The command saves the ID in `~/.config/aerc/outlook-client-id`, runs the one-time
   login (it shows a code that you approve in the browser) and writes the account section.
5. In Outlook on the web, make sure IMAP is allowed (*Settings → Mail → Sync email*). Without it
   the server answers "User is authenticated but not connected".

The refresh token is stored in the keyring (`service aerc account outlook-oauth`). aerc reads
credentials only once, at start-up, and renews access tokens itself from that refresh token;
`aerc-outlook-token refresh` also rotates the stored copy on every start so its expiry keeps
sliding.

Status: the OAuth plumbing is verified end to end, but the one-time login has not been verified
with a freshly registered personal-account app, and `aerc-add-account`'s Outlook path itself has not been run end to end. Microsoft's own guide lists an Azure account as a
prerequisite for registering apps, which a plain Outlook.com account may not have. If you get an
`AADSTS…` error, re-check steps 1–3 first.

## Notifications

`aerc-mailwatch` reads the IMAP accounts from `accounts.conf`, runs each `source-cred-cmd`, and
checks every INBOX once a minute with a cheap `STATUS` command. It announces **unread** messages
that arrived since the previous check. On start it only records where each mailbox stands, so you
are not flooded with old mail, and mail that arrives while the service is stopped is not announced.

```sh
aerc-mailwatch --list              # which accounts it will watch
aerc-mailwatch --selftest NAME     # one test notification for an account
journalctl --user -u aerc-mailwatch -n 20
```

Optional `~/.config/aerc/mailwatch.conf`:
```ini
[mailwatch]
interval = 60          # seconds, minimum 15
exclude  = aol, other  # account names to skip
```

GNOME note: notifications that carry an application name matching a terminal app (such as
`aerc`) were not shown as banners here, while anonymous ones were. The checker therefore sends
anonymous notifications, which also means a generic icon.

## Troubleshooting

- **A login test fails when adding an account.** Check the address and use an app password, not your
  normal one; run `aerc-add-account` again with the same name to replace the password.
- **An account vanished from aerc.** aerc drops an account whose credential command fails. Run
  the account's `source-cred-cmd` by hand and fix whatever it complains about.
- **Gmail is slow.** Each IMAP command on one account took about 1.3 s while other mail clients
  were connected to it, and about 0.3 s after they were closed. Close other clients that sync
  the same account.
- **Deleted Gmail mail only turns gray.** The Trash bindings come from `aerc-add-account`; re-add the
  account's password with it (or run `aerc-mailwatch --update-trash-binds`) and restart aerc.
- **`B` opens nothing.** The page is written to `~/aerc-html/` (snap-packaged browsers cannot read
  `/tmp`). Check that `xdg-open file.html` works from a terminal.
- **`B` shows no remote images.** Intentional: remote content is blocked so opening a mail does not
  tell the sender anything. Mail text stays in `~/aerc-html/` (a private directory) for up to a
  day, until the next time `B` is used; delete the folder to clear it sooner.

## Uninstall

```sh
systemctl --user disable --now aerc-mailwatch.service
rm ~/.config/systemd/user/aerc-mailwatch.service
rm ~/.local/bin/aerc-{add-account,open-html,outlook-token,mailwatch}
rm -rf ~/aerc-html ~/.config/aerc/outlook-client-id
```
Your aerc configuration stays in `~/.config/aerc/`; remove or restore it from
`~/.config/aerc/backup-*` as you like. Stored secrets (each account's password, and the Outlook
refresh token under the name `outlook-oauth`) can be deleted with
`secret-tool clear service aerc account NAME`.

## License

MIT, see [LICENSE](LICENSE). `config/binds.conf` is based on aerc's default `binds.conf`, which
is also MIT-licensed.
