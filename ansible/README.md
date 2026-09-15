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
ansible-playbook -i inventory.ini deploy.yml
```

This pulls the `Nova_dev` branch, runs `docker compose up -d --build`, and
checks `/api/songs` responds before finishing.

## Why `raw` instead of normal Ansible modules

Connecting to Windows over plain SSH (rather than WinRM) means Ansible's
usual Python-based modules (`git`, `command`, `uri`, ...) only work if
Python is confirmed installed on the target. `deploy.yml` uses
`ansible.builtin.raw` instead, which sends commands straight to the remote
shell with no such dependency — works whether or not Python is on that
machine, at the cost of Ansible's usual idempotency/change-tracking, which
doesn't matter much for a script this small.
