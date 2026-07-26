# Homelab

Infrastructure as code for a single-node Proxmox homelab.

Terraform builds VMs on Proxmox; Ansible configures them and deploys workloads.
Secrets are committed encrypted with SOPS + age.

## What is here

| Path | What it does |
| --- | --- |
| [`terraform/modules/proxmox-vm/`](terraform/modules/proxmox-vm/) | Reusable Debian cloud-init VM + backup job |
| [`terraform/docker-host/`](terraform/docker-host/) | VM 101 `docker-01` — Docker host |
| [`terraform/dns-host/`](terraform/dns-host/) | VM 102 `dns-01` — Pi-hole |
| [`ansible/`](ansible/) | Installs Docker, deploys the music bot and Pi-hole |
| [`docs/secrets.md`](docs/secrets.md) | **Where the encrypted tokens go**, and how |
| [`docs/pihole.md`](docs/pihole.md) | Pointing your network at Pi-hole, and what it does and does not block |
| [`scripts/validate.py`](scripts/validate.py) | Static checks that run without a live host |

## Hosts

| VM | Name | Address | Runs |
| --- | --- | --- | --- |
| 101 | `docker-01` | 192.168.0.210 | Discord music bot. Also the Ansible control node. |
| 102 | `dns-01` | 192.168.0.211 | Pi-hole DNS ad blocking |

`docker-01` doubles as the control node: it holds the SSH key and the age key
and runs the playbooks. Ansible cannot run from Windows, so playbooks are
executed there rather than from the workstation.

## The environment this targets

Discovered from the live API, not assumed:

| | |
| --- | --- |
| Proxmox | 9.2.2, single node `pve` |
| Host | 16 cores, 86 GB RAM |
| Disk storage | `local-lvm` (thin LVM, ~800 GB free) |
| Image storage | `local` (accepts `iso` content) |
| Bridge | `vmbr0`, 192.168.0.0/24, gateway 192.168.0.1 |
| Existing VM | 100 `WinServer2022` |

The node has **no VM templates**, so Terraform downloads the Debian generic
cloud image and imports it as the root disk rather than cloning a template.

## What gets built

```
VM 101  docker-01
        Debian 12 (generic cloud), cloud-init
        2 vCPU / 2 GB RAM / 20 GB on local-lvm
        192.168.0.210/24 static, vmbr0
        user 'ansible', SSH key only, no password
```

Then Ansible installs Docker CE, clones
[discord-music-bot](https://github.com/ethan-dowell/discord-music-bot), builds
the image on the host, and runs it under compose with the token mounted as a
Docker secret.

## Scheduled jobs

| When | What | Where it is defined |
| --- | --- | --- |
| Daily 02:30 | Proxmox snapshot backup of VM 101, zstd, keep-last 3 | `proxmox_backup_job` in the [VM module](terraform/modules/proxmox-vm/main.tf) |
| Daily 03:15 | Proxmox snapshot backup of VM 102 | same module, via [dns-host](terraform/dns-host/) |
| Sunday 04:00 (±30 min) | Rebuild the bot image so yt-dlp stays current | [`bot_autoupdate`](ansible/roles/bot_autoupdate/) role |

**Why the weekly rebuild matters.** yt-dlp is the shortest-lived dependency in
this stack — YouTube changes its player regularly and yt-dlp ships fixes within
days. An image built once and left alone typically starts failing to resolve
anything within weeks (`Sign in to confirm you're not a bot`, or HTTP 403 on
everything). `requirements.txt` pins a floating lower bound, but Docker's layer
cache would keep serving the version that was current at first build, so the
timer rebuilds with `--pull --no-cache` to force a re-resolve.

It refreshes **dependencies only** — it deliberately does not pull new bot
source, so nobody wakes up to an untested commit in production. Deploying code
stays an explicit playbook run. A failed build leaves the running container
untouched, since compose only replaces it on success.

```bash
systemctl list-timers discord-music-bot-update.timer
```

```bash
sudo systemctl start discord-music-bot-update.service   # force a refresh now
```

**What the backup protects.** The VM rebuilds from this repo in about four
minutes, so the guest itself is nearly disposable. The Docker volume is not —
that holds the bot's logs and anything else under `/data`.

## Prerequisites

On whatever machine you run this from:

- Terraform >= 1.6
- Ansible (Linux/macOS/WSL — Ansible cannot run from Windows as a control node)
- `sops` and `age`
- The SSH private key `~/.ssh/homelab_ed25519`
- The age private key at `~/.config/sops/age/keys.txt` (see
  [docs/secrets.md](docs/secrets.md))

## Deploying

### 1. Set your Discord token

```bash
sops edit ansible/inventory/group_vars/docker_hosts/secrets.sops.yaml
```

Replace the placeholder with your real token. Full detail in
[docs/secrets.md](docs/secrets.md).

### 2. Build the VM

Credentials come from the environment so nothing lands in a committed file:

```powershell
$env:PROXMOX_VE_USERNAME = 'root@pam'; $env:PROXMOX_VE_PASSWORD = '<password>'
```

An API token is better than the root password — see
[docs/secrets.md](docs/secrets.md#other-credentials). Then:

```bash
terraform -chdir=terraform/docker-host init
```

```bash
terraform -chdir=terraform/docker-host apply
```

First apply takes a few minutes: it downloads ~300 MB of cloud image onto the
node. Subsequent applies reuse it.

### 3. Deploy the bot

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

```bash
cd ansible && ansible-playbook playbooks/site.yml
```

Or target one group: `--limit dns_hosts`, `--limit docker_hosts`.

The bot play waits for the container to report **healthy** before finishing, so
a green run means it is actually connected to Discord — not merely that the
container started. The Pi-hole play likewise waits until DNS genuinely answers
a query before declaring success.

### 4. Point the network at Pi-hole

Deploying Pi-hole changes nothing until your router hands out `192.168.0.211`
as the DNS server. That step, plus what it does and does not block, is in
[docs/pihole.md](docs/pihole.md).

## Checking on it

```bash
ssh -i ~/.ssh/homelab_ed25519 ansible@192.168.0.210
```

```bash
docker logs -f discord-music-bot
```

```bash
docker inspect -f '{{.State.Health.Status}}' discord-music-bot
```

Health is not a process check: the bot touches a heartbeat file only while its
Discord gateway connection is live, so a bot that is running but disconnected
reports unhealthy and Docker restarts it.

## Validating changes without a host

```bash
python scripts/validate.py
```

Parses every YAML file, checks each `notify` has a matching handler, confirms
the inventory IP still agrees with `terraform.tfvars`, and renders the compose
template to check it produces valid YAML with and without `DEV_GUILD_ID` set.

```bash
terraform -chdir=terraform/docker-host validate
```

## Notes

**Provider choice.** `bpg/proxmox`, not the `Telmate/proxmox` most older
homelab guides use — Telmate has been effectively unmaintained since 2023 and
does not handle PVE 8/9 disk imports. Within bpg, note that the newer
`proxmox_vm` resource is explicitly marked experimental and *"MUST NOT be used
in production"*, so this uses `proxmox_virtual_environment_vm`.

**QEMU guest agent is two-phase.** `vm_enable_qemu_agent` is currently `true`,
which is only valid because the `common` role has already installed the agent.
Building a **fresh** VM requires setting it back to `false` for the first apply:
the generic cloud image ships no agent, so Proxmox blocks waiting for a reply
that never comes. The two sides depend on each other — Proxmox only attaches
`/dev/virtio-ports/org.qemu.guest_agent.0` when the flag is on, and
`qemu-guest-agent.service` hard-depends on that device, so the role enables the
unit but only starts it once the port exists.

Sequence for a rebuild: apply with the flag `false`, run the playbook, set it
`true`, apply again (Terraform reboots the VM itself).

**State.** Terraform state is local and gitignored — it contains every resource
attribute in plaintext. Back up `terraform.tfstate` or move to a remote backend
before this grows past one VM.
