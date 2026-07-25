# Secrets

**Short answer to "where do the encrypted tokens go":**

```
ansible/inventory/group_vars/docker_hosts/secrets.sops.yaml
```

That file is committed to this repo **encrypted**. Ansible decrypts it in
memory at run time and never writes plaintext to disk.

## How it works

[SOPS](https://github.com/getsops/sops) encrypts the *values* in a YAML file
and leaves the *keys* readable, so an encrypted file still produces a sensible
git diff. Encryption is done with an [age](https://github.com/FiloSottile/age)
keypair — no cloud KMS, nothing to pay for, nothing to phone home to.

```
secrets.sops.yaml          committed, encrypted        <- tokens go here
~/.config/sops/age/keys.txt   NEVER committed          <- the key that opens it
```

The age **public** key (the recipient) is in [`.sops.yaml`](../.sops.yaml) at
the repo root. Public keys are not secret. The **private** key lives only on
machines allowed to decrypt.

## Setting your Discord token

The repo currently ships a placeholder. Replace it:

```bash
sops edit ansible/inventory/group_vars/docker_hosts/secrets.sops.yaml
```

Your editor opens on the *decrypted* contents. Change the placeholder:

```yaml
vault_discord_token: MTIzNDU2Nzg5MDEyMzQ1Njc4.GaBcDe.your-real-token-here
```

Save and close — SOPS re-encrypts on write. Commit the result; it is
ciphertext. The Ansible role refuses to deploy while the placeholder is still
there, so a forgotten token fails immediately instead of producing a container
that silently cannot log in.

To verify what is committed is genuinely encrypted:

```bash
git show HEAD:ansible/inventory/group_vars/docker_hosts/secrets.sops.yaml
```

You should see `ENC[AES256_GCM,...]`, not your token.

## The private key

It was generated on the Windows box at:

```
C:\Users\Administrator\.config\sops\age\keys.txt
```

**Back this up somewhere outside this repo** — a password manager entry is
ideal. Lose it and every encrypted value here becomes unreadable, and you will
have to re-create the file from scratch with a new key.

Its public half, already in `.sops.yaml`:

```
age1qls3y5x9nymax25h9tes98huf8cwe923h95nyp03xduww64qmvnqht0x6l
```

## Decrypting from another machine

Copy `keys.txt` to `~/.config/sops/age/keys.txt` on that machine, or point
SOPS at it explicitly:

```bash
export SOPS_AGE_KEY_FILE=/path/to/keys.txt
```

## Granting access to a second key

Generate a keypair on the other machine, add its public key to the `age:` list
in `.sops.yaml`, then re-key the existing files:

```bash
sops updatekeys ansible/inventory/group_vars/docker_hosts/secrets.sops.yaml
```

## Where the token ends up at run time

1. `sops` decrypts `secrets.sops.yaml` into an Ansible variable
   (`vault_discord_token`) — in memory only.
2. The role writes it to `/opt/discord-music-bot/secrets/discord_token` on the
   Docker host, mode `0600`, root-owned. The task is `no_log: true`, so it does
   not appear in Ansible output.
3. Compose mounts that file as a Docker secret at
   `/run/secrets/discord_token`.
4. The bot reads `DISCORD_TOKEN_FILE` and loads the token from there.

The token is deliberately **never** an environment variable in the container.
Environment variables show up in `docker inspect`, in `/proc/<pid>/environ`,
and in crash dumps; a mounted secret file does not.

## Rotating a leaked token

1. Discord Developer Portal → your application → Bot → **Reset Token**.
2. `sops edit` the file above, paste the new value, commit.
3. Re-run the playbook. The changed token triggers a container restart.

The old token stops working the moment you reset it, so do this in that order.

## Other credentials

**Proxmox.** Terraform reads credentials from environment variables and they
are not stored in this repo at all — see
[`terraform/docker-host/providers.tf`](../terraform/docker-host/providers.tf).
Prefer an API token over the root password:

*Datacenter → Permissions → API Tokens → Add*, user `root@pam`, token ID
`terraform`, **uncheck Privilege Separation**. Copy the secret — Proxmox shows
it exactly once.

```powershell
$env:PROXMOX_VE_API_TOKEN = 'root@pam!terraform=<the-uuid>'
```

An API token can be revoked from the UI without changing the root password, and
it does not grant shell access to the node.

**SSH.** The keypair Ansible uses is at `~/.ssh/homelab_ed25519`. Only the
public half is in this repo (in `terraform.tfvars`), which is fine — that is
what public keys are for. Back up the private half alongside the age key.
