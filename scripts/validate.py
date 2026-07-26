"""Static validation of the Ansible tree.

Runs anywhere Python does, including a Windows control node where Ansible
itself cannot run (it imports pwd/grp). Checks what can be checked without
Ansible: that every YAML file parses, that playbooks and roles have the
expected shape, that every notify has a matching handler, that the inventory
agrees with Terraform, and that the compose template renders to valid YAML.

    pip install pyyaml jinja2
    python scripts/validate.py

Exits non-zero on the first problem, so it works as a pre-commit hook or CI
step. It does not replace `ansible-playbook --check` against a real host.
"""

import sys
from pathlib import Path

import yaml
from jinja2 import Environment, StrictUndefined

ROOT = Path(__file__).resolve().parent.parent / "ansible"
failures = []
checked = 0


def check(label, ok, detail=""):
    global checked
    checked += 1
    if ok:
        print(f"  PASS  {label}")
    else:
        print(f"  FAIL  {label} :: {detail}")
        failures.append(label)


print("=== YAML parses ===")
yaml_files = sorted(p for p in ROOT.rglob("*.yml") if "secrets.sops" not in p.name)
for path in yaml_files:
    rel = path.relative_to(ROOT)
    try:
        yaml.safe_load(path.read_text(encoding="utf-8"))
        check(str(rel), True)
    except Exception as exc:
        check(str(rel), False, str(exc))

print("\n=== SOPS file is actually encrypted ===")
sops_file = ROOT / "inventory/group_vars/docker_hosts/secrets.sops.yaml"
doc = yaml.safe_load(sops_file.read_text(encoding="utf-8"))
check("has a sops metadata block", "sops" in doc)
check("token value is ciphertext", doc.get("vault_discord_token", "").startswith("ENC["))
check(
    "no plaintext token leaked",
    "REPLACE_ME_WITH_YOUR_DISCORD_BOT_TOKEN" not in sops_file.read_text(encoding="utf-8"),
)

print("\n=== Playbook shape ===")
site = yaml.safe_load((ROOT / "playbooks/site.yml").read_text(encoding="utf-8"))
check("site.yml is a list of plays", isinstance(site, list) and len(site) == 1)
play = site[0]
check("targets docker_hosts", play.get("hosts") == "docker_hosts")
check(
    "roles are in dependency order",
    play.get("roles") == ["common", "docker", "discord_music_bot", "bot_autoupdate"],
    str(play.get("roles")),
)

print("\n=== Roles resolve ===")
roles_dir = ROOT / "roles"
for role in play.get("roles", []):
    tasks = roles_dir / role / "tasks" / "main.yml"
    check(f"{role}/tasks/main.yml exists", tasks.is_file())
    if tasks.is_file():
        loaded = yaml.safe_load(tasks.read_text(encoding="utf-8"))
        check(f"{role} tasks parse to a list", isinstance(loaded, list))
        check(f"{role} every task is named", all("name" in t for t in loaded))

print("\n=== Handlers referenced by notify exist ===")
for role in play.get("roles", []):
    tasks_path = roles_dir / role / "tasks" / "main.yml"
    handlers_path = roles_dir / role / "handlers" / "main.yml"
    tasks = yaml.safe_load(tasks_path.read_text(encoding="utf-8")) or []
    notified = {t["notify"] for t in tasks if "notify" in t}
    if not notified:
        continue
    handlers = yaml.safe_load(handlers_path.read_text(encoding="utf-8")) or []
    defined = {h["name"] for h in handlers}
    for name in notified:
        check(f"{role}: handler '{name}' defined", name in defined, f"have {defined}")

print("\n=== Inventory ===")
inv = yaml.safe_load((ROOT / "inventory/hosts.yml").read_text(encoding="utf-8"))
hosts = inv["all"]["children"]["docker_hosts"]["hosts"]
check("docker-01 present", "docker-01" in hosts)
# Guards the classic drift: Terraform moves the VM, the inventory does not.
tfvars = (ROOT.parent / "terraform/docker-host/terraform.tfvars").read_text(encoding="utf-8")
tf_ip = next(
    line.split("=")[1].strip().strip('"').split("/")[0]
    for line in tfvars.splitlines()
    if line.strip().startswith("vm_ipv4_address")
)
check(
    "inventory IP matches terraform tfvars",
    hosts["docker-01"]["ansible_host"] == tf_ip,
    f'inventory={hosts["docker-01"]["ansible_host"]} terraform={tf_ip}',
)

print("\n=== Compose template renders ===")
group_vars = yaml.safe_load(
    (ROOT / "inventory/group_vars/docker_hosts/vars.yml").read_text(encoding="utf-8")
)
env = Environment(undefined=StrictUndefined, keep_trailing_newline=True)
template_path = roles_dir / "discord_music_bot/templates/docker-compose.yml.j2"
template = env.from_string(template_path.read_text(encoding="utf-8"))

for label, extra in [
    ("without dev guild", {}),
    ("with dev guild", {"dmb_dev_guild_id": "123456789012345678"}),
]:
    try:
        rendered = template.render(ansible_managed="ANSIBLE MANAGED", **{**group_vars, **extra})
        compose = yaml.safe_load(rendered)
        svc = compose["services"]["discord-music-bot"]
        check(f"{label}: renders to valid YAML", True)
        check(f"{label}: token comes from a file", svc["environment"]["DISCORD_TOKEN_FILE"]
              == "/run/secrets/discord_token")
        check(f"{label}: no plaintext DISCORD_TOKEN", "DISCORD_TOKEN" not in svc["environment"])
        check(f"{label}: restart policy set", svc["restart"] == "unless-stopped")
        check(f"{label}: secret is declared", "discord_token" in compose["secrets"])
        has_guild = "DEV_GUILD_ID" in svc["environment"]
        check(f"{label}: DEV_GUILD_ID conditional works", has_guild == bool(extra))
    except Exception as exc:
        check(f"{label}: renders", False, f"{type(exc).__name__}: {exc}")

print(f"\n{checked - len(failures)}/{checked} checks passed")
if failures:
    print("FAILED: " + ", ".join(failures))
sys.exit(1 if failures else 0)
