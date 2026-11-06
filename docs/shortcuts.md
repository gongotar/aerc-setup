# aerc shortcuts

Keys from `~/.config/aerc/binds.conf`. Restart aerc after changing that file.
`:` opens the command line. `Esc` cancels. `q` closes the message viewer.

## Message list (inbox view)

| Action | Key | Notes |
|---|---|---|
| Open message | `Enter` | Opening a message also marks it read |
| Next / previous message | `j` / `k` | Arrow keys work too |
| Jump to top / bottom | `g` / `G` | |
| **Mark read / unread (toggle)** | `x` | Works on the selected message, or on all marked messages |
| **Delete** | `d` | Gmail accounts: asks "Move to Trash?" (`y` to confirm) and moves the mail to Trash. Other accounts: asks "Really delete this message" |
| Delete without asking | `D` | Same as `d`, but no question |
| Archive | `a` | Archives the selected message |
| Archive the whole thread | `A` | Unmarks everything, marks the thread, archives it |
| **New message** | `C` or `m` | Opens the composer |
| **Reply (reply all)** | `rr` | Everyone on the thread |
| Reply all, quoting the original | `rq` | |
| **Reply to sender only** | `Rr` | |
| Reply to sender only, quoted | `Rq` | |
| **Forward** | `f` | |
| Mark message (for bulk actions) | `v` or `Space` | `Space` also moves to the next one |
| Visual mark mode | `V` | Move the cursor to extend the selection; then `x`, `d`, `a` act on all marked |
| Next / previous folder | `J` / `K` | |
| Collapse / expand a folder group | `H` / `L` | |
| **Refresh / check for new mail** | `Ctrl+r` | Checks the current account. If the list still looks stale, reopen the folder with `c INBOX` |
| Change folder by name | `c` | Then type the folder name, e.g. `c Sent` |
| **Switch account tab** | `Ctrl+Right` / `Ctrl+Left` | Next / previous tab. Also `]t` / `[t`, and `Ctrl+n` / `Ctrl+p` outside the compose window |
| Quit | `q` | Asks to confirm |

## While reading a message

| Action | Key |
|---|---|
| Close the message, back to the list | `q` |
| Next / previous message | `J` / `K` |
| Toggle read / unread | `x` |
| Delete (Gmail accounts: move to Trash) | `D` |
| Archive | `A` |
| Reply all / reply sender only | `rr` / `Rr` |
| Reply all quoted / sender only quoted | `rq` / `Rq` |
| Forward | `f` |
| **Open the message as HTML in your default browser** (no scripts, no remote images) | `B` |
| Open the current part (attachment, text) | `o` or `O` |
| Next / previous part (for example the HTML part) | `Ctrl+j` / `Ctrl+k` |
| Show or hide full headers | `H` |
| Save an attachment | `S`, then a path |
| Open or copy a link | `Ctrl+l` / `Ctrl+y`, then the link |

## Search

These work in the message list, and they search only the **current folder**.

| Action | Key | Notes |
|---|---|---|
| **Full-text search** | `/` | Searches headers and body. Type the words, then `Enter` |
| Next / previous result | `n` / `N` | |
| **Filter the list** | `\` | Same search, but the list shows only the matches |
| **Gmail's own search** | `?` | Gmail accounts only. Supports `from:bob has:attachment older_than:1y` |
| Clear a search or filter | `Esc` | |

Useful options when typing the command yourself (`:search` or `:filter`, then these before the words):

- `-f <sender>` finds mail from a sender.
- `-t <recipient>` finds mail to someone.
- `-d 2026-01-01..2026-06-01` limits to a date range. `-d 2026-01-01..` means from that date until now.
- `-u` or `-r` finds only unread or only read mail.
- `-x flagged` finds mail with a flag set.

Tip: to search all mail in a Gmail account, switch to its all-mail folder first. Use `c` and type its name, which depends on the account's language (for example `[Gmail]/All Mail`).

## Other

| Action | Key |
|---|---|
| Show all active key bindings | `?` (outside the message list) or `:help keys` |
| Toggle threading | `T` |
| Run a shell command | `$` or `!` |

## Compose window

| Action | Key |
|---|---|
| Switch the sending account | `Ctrl+n` / `Ctrl+p` (or `Alt+n` / `Alt+p`) |
| Switch tab (same as everywhere) | `Ctrl+Right` / `Ctrl+Left` |
| **Close the compose window** | `Alt+q`, then `d` to discard or `p` to postpone (save as a draft) |
| Next / previous field | `Tab` / `Shift+Tab` (or `Ctrl+j` / `Ctrl+k`) |
| Run a command | `Ctrl+x`, then for example `:abort` to discard right away |
| Send | on the review screen after you finish editing, press `y` |
| Abort / postpone from the review screen | `n` discards without asking, `q` asks, `p` postpones |

## Deleting in Gmail accounts

For Gmail accounts, `d` and `D` move the mail to the account's Trash folder, which `aerc-add-account` looks up by its IMAP `\Trash` flag (it is named differently per language). Gmail ignores aerc's normal delete in many folders, and then the message only turns gray. Deleted mail stays in Trash for 30 days before Gmail removes it for good.
