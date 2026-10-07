# Nova infrastructure (AWS + CI/CD + monitoring)

How the pieces fit, the order to stand them up, and the manual steps (keys,
credentials, webhook) that can't be scripted into the repo.

## The pieces

| Layer        | Tool                      | Where it lives                                   |
|--------------|---------------------------|--------------------------------------------------|
| App instance | Terraform                 | `terraform/aws/` — t3.micro, Ubuntu 24.04, EIP   |
| Jenkins host | Terraform                 | `terraform/jenkins/` — t3.small, Ubuntu 24.04, EIP |
| App deploy   | Ansible                   | `ansible/deploy-ec2.yml`                         |
| Jenkins setup| Ansible                   | `ansible/jenkins.yml`                            |
| Monitoring   | Ansible + Docker Compose  | `ansible/monitoring.yml`, `monitoring/`          |
| Pipeline     | Jenkins                   | `Jenkinsfile`                                    |
| Local run    | Terraform (Docker provider) | `terraform/` (no cloud, manages a local container) |

Two instances: the **app** (t3.micro) runs the music player; the **Jenkins
host** (t3.small) runs Jenkins and the monitoring stack. Both sit in the
default VPC (`172.31.0.0/16`), so Prometheus scrapes the app's exporters
over private IPs that are never exposed to the internet.

### Why not Kubernetes

One app on one or two instances behind a load balancer doesn't need an
orchestrator — Ansible already handles deploys, and Docker's `restart:
unless-stopped` handles crash recovery. Kubernetes would cost more memory
than the app uses and add a cluster to babysit. Revisit only if the course
grades on Kubernetes by name.

## Stand it up, in order

Everything SSHes with your `~/.ssh/id_ed25519`, so load it into the agent
once (the key has a passphrase, and nothing unattended can type it):

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519   # macOS
ssh-add -l                                        # confirm it's loaded
```

1. **Instances:** `terraform apply` in `terraform/aws` then `terraform/jenkins`.
   Each needs `-var admin_cidr=<your-ip>/32` (get it with `curl checkip.amazonaws.com`).
2. **Generate the inventories** from the Terraform outputs (never hand-edit them):
   `./scripts/gen-inventory.sh`
3. **App:** `cd ansible && ansible-playbook -i inventory-ec2.ini deploy-ec2.yml`
4. **Jenkins:** `ansible-playbook -i inventory-jenkins.ini jenkins.yml`
5. **Monitoring:** `ansible-playbook -i inventory-ec2.ini -i inventory-jenkins.ini monitoring.yml`

Everything SSHes with your `~/.ssh/id_ed25519`, so load it into the agent once
first:

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519   # macOS
ssh-add -l                                        # confirm it's loaded
```

## Deploying to a different AWS account (reusing this repo)

Nothing environment-specific is hand-written — IPs come from Terraform, and
the rest are variables. To stand this up fresh in your own account:

1. Have an SSH key at `~/.ssh/id_ed25519.pub` (or pass
   `-var public_key_path=/path/to/your.pub`).
2. `terraform apply` both stacks with your `-var admin_cidr=<your-ip>/32`
   (and `-var region=<your-region>` if not eu-north-1).
3. `./scripts/gen-inventory.sh` — rewrites the inventories with *your* instances' IPs.
4. Run the playbooks (steps 3–5 above). For a fork, add
   `-e repo_url=https://github.com/you/your-fork` to the app deploy.
5. In Jenkins, create the `ec2-deploy-key` credential and the job (below), and
   point a GitHub webhook at your Jenkins.

No file needs a manual IP edit — `gen-inventory.sh` is the single source for
host addresses, and the monitoring scrape targets come from Ansible facts.

## Manual steps (secrets — not in the repo)

### Jenkins deploy key

Jenkins can't type a passphrase, so it needs a passphrase-free private key
whose public half the app instance already trusts. The app instance already
trusts `id_ed25519.pub` (Terraform installed it), so make a passphrase-free
copy of that same key for Jenkins:

```bash
cp ~/.ssh/id_ed25519 /tmp/jenkins_deploy_key
ssh-keygen -p -f /tmp/jenkins_deploy_key -N ''   # strip the passphrase on the copy
```

In Jenkins: **Manage Jenkins → Credentials → Add** → kind "SSH Username with
private key", id **`ec2-deploy-key`**, username `ubuntu`, paste
`/tmp/jenkins_deploy_key`. Then delete the temp file:

```bash
rm /tmp/jenkins_deploy_key
```

### Jenkins first login and plugins

```bash
ssh ubuntu@<jenkins-ip> 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
```

Open `http://<jenkins-ip>:8080`, paste it, then install: **Git, GitHub,
Pipeline, SSH Agent**. Create a Pipeline job from this repo (branch
`master`, script path `Jenkinsfile`) and enable "GitHub hook trigger for
GITScm polling".

### GitHub webhook

Repo **Settings → Webhooks → Add webhook**:
- Payload URL: `http://<jenkins-ip>:8080/github-webhook/`
- Content type: `application/json`
- Events: just the push event

The Jenkins security group already allows port 8080 from GitHub's published
hook IP ranges (read live from `api.github.com/meta` in Terraform).

### Grafana

Default login is `admin` / `admin` (set `grafana_admin_password` in
`monitoring.yml`, or the `GRAFANA_ADMIN_PASSWORD` env var, to change it).
The Prometheus datasource and a "Nova Overview" dashboard are provisioned
automatically. UI at `http://<jenkins-ip>:3000`, Prometheus at `:9090` —
both admin-IP-only.

## What the pipeline does

Push to `master` → GitHub webhook → Jenkins: build the image, smoke-test
it, run API tests (once `api-tests/pom.xml` exists), then run
`deploy-ec2.yml` against the app instance.

## Teardown

`terraform destroy` in each of `terraform/jenkins` and `terraform/aws`
(needs the same `-var admin_cidr=...`). The Elastic IPs are released then,
so a later rebuild gets new addresses — update DNS accordingly.
