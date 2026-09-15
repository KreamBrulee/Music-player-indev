# Deploying to the home hosting machine

This automates what you'd otherwise type by hand over SSH: pull the latest
code, rebuild the image, restart the container.

## Prerequisites

- **Control machine** (wherever you run `ansible-playbook` from) needs
  Ansible installed, and needs to be Linux, macOS, or WSL — Ansible's own
  `ansible-playbook` command doesn't run on native Windows.
- **Target machine** (the Windows hosting box) needs:
  - OpenSSH Server enabled — already true, since that's how you SSH into it
    today.
  - Docker Desktop installed and started (this playbook checks it's running
    and fails with a clear message if not — it can't launch a GUI app
    remotely, so you start it manually if needed).
  - The repo already cloned (matches the path already in use:
    `D:\Kunal\VS_codes\music-player-indev`).

## Setup

Edit `inventory.ini` and fill in `ansible_host` (the machine's hostname/IP)
and `ansible_user` (your Windows username on it).

## Run

```bash
ansible-playbook -i inventory.ini deploy.yml --ask-pass
```

Type the same Windows password you use to SSH in manually when prompted —
run this yourself, in your own terminal. Don't paste the password anywhere
else (including to Claude/an AI assistant) — it'd end up sitting in that
tool's logs.

This pulls the `Nova_dev` branch, builds the image, starts the container,
and checks `/api/songs` responds before finishing.

### Why the build and the container start are separate steps

`docker compose up --build` doesn't work on this host — see below. So
`deploy.yml` runs `docker build` (with the legacy builder) as its own step,
then `docker compose up -d` with no `--build` flag, which just starts a
container from the image that step already produced instead of trying to
build one itself.

### Why the legacy builder (`DOCKER_BUILDKIT=0`)

This machine's Docker Desktop can't pull `debian:bookworm-slim` — even
though it's a public image needing no real credentials — with an error like
`error getting credentials ... A specified logon session does not exist`.
Confirmed root cause, not a guess: `docker-credential-desktop.exe` **and**
`docker-credential-wincred.exe` (Docker's own helper and the plain Windows
Credential Manager API helper) both fail identically when run directly,
which rules out anything Docker-specific being broken. What's actually
going on: Windows Credential Manager relies on DPAPI, which only unlocks
for a user's profile on a true **interactive** logon (console or RDP) — an
SSH logon, even with a correct password, establishes a **network**-type
logon instead, which never unlocks it. Confirmed this isn't a stale/fixable
state either — it survives a full, genuine restart of the machine.

BuildKit (Docker's default builder, and what `docker compose` always uses
for its build step, unconditionally) hard-fails the moment a credential
helper errors, even for a pull that needs no credentials at all. The
legacy builder is more forgiving — a failed/empty credential lookup just
means "try anonymously" instead of aborting — so setting
`DOCKER_BUILDKIT=0` before `docker build` sidesteps the whole problem for
that command. `docker compose`'s build step doesn't respect that variable
(it always goes through `buildx`/`bake`), which is exactly why it has to be
avoided entirely rather than fixed with the same flag.

If you ever do get physical or RDP access to that machine, `docker compose
up -d --build` should just work there, unmodified — this is specific to
building over an SSH session, not anything wrong with the Dockerfile or
compose setup itself.

## Why `--ask-pass` instead of key auth

Key-based auth (no password prompt at all) is the better long-term setup —
it's what `ansible_connection=ssh` in `inventory.ini` is ready for. It's
just not working yet: the Windows target accepts this Mac's public key at
the protocol level (confirmed via `ssh -vvv`, "Server accepts key") but
still ultimately denies the login. `sshd_config`'s `administrators_authorized_keys`
setup, its file contents, its ACL, and the containing folder's ACL have all
been checked and are correct — the remaining cause is almost certainly
Win32-OpenSSH's secondary native-Windows-logon step after the SSH-level key
check passes, which needs someone with hands-on access to that machine's
Event Viewer (Applications and Services Logs → OpenSSH) to pin down
further. Possibly the same underlying limitation as the Credential Manager
issue above — SSH logons on Windows not behaving like a true interactive
one — though unconfirmed; the two symptoms (total auth denial vs. a
DPAPI-specific failure after a successful logon) aren't obviously the same
mechanism.

`--ask-pass` (needs `sshpass` on the control node — `brew install sshpass`
on macOS) is the pragmatic unblock in the meantime: same playbook, just a
password prompt on every run instead of silent key auth.

Switch back to plain `ansible-playbook -i inventory.ini deploy.yml` (no
`--ask-pass`) once key auth is sorted out — nothing else about the setup
needs to change.

## Why `raw` instead of normal Ansible modules

Connecting to Windows over plain SSH (rather than WinRM) means Ansible's
usual Python-based modules (`git`, `command`, `uri`, ...) only work if
Python is confirmed installed on the target. `deploy.yml` uses
`ansible.builtin.raw` instead, which sends commands straight to the remote
shell with no such dependency — works whether or not Python is on that
machine, at the cost of Ansible's usual idempotency/change-tracking, which
doesn't matter much for a script this small.
