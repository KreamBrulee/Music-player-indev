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
    `D:\Kunal\Remote Projects\Music-player-indev`).

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

This pulls the `Nova_dev` branch, runs `docker compose up -d --build`, and
checks `/api/songs` responds before finishing.

### Why `--ask-pass` instead of key auth

Key-based auth (no password prompt at all) is the better long-term setup —
it's what `ansible_connection=ssh` in `inventory.ini` is ready for. It's
just not working yet: the Windows target accepts this Mac's public key at
the protocol level (confirmed via `ssh -vvv`, "Server accepts key") but
still ultimately denies the login. `sshd_config`'s `administrators_authorized_keys`
setup, its file contents, its ACL, and the containing folder's ACL have all
been checked and are correct — the remaining cause is almost certainly
Win32-OpenSSH's secondary native-Windows-logon step after the SSH-level key
check passes, which needs someone with hands-on access to that machine's
Event Viewer (Applications and Services Logs → OpenSSH) to pin down further.
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
