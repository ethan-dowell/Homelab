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

print("\n=== SOPS files are actually encrypted ===")
for group, key, placeholder in [
    ("docker_hosts", "vault_discord_token", "REPLACE_ME_WITH_YOUR_DISCORD_BOT_TOKEN"),
    ("dns_hosts", "vault_pihole_password", "REPLACE_ME"),
]:
    sops_file = ROOT / f"inventory/group_vars/{group}/secrets.sops.yaml"
    check(f"{group}: secrets file exists", sops_file.is_file())
    if not sops_file.is_file():
        continue
    raw = sops_file.read_text(encoding="utf-8")
    doc = yaml.safe_load(raw)
    check(f"{group}: has a sops metadata block", "sops" in doc)
    check(f"{group}: {key} is ciphertext", str(doc.get(key, "")).startswith("ENC["))
    check(f"{group}: no placeholder left", placeholder not in raw)

print("\n=== Playbook shape ===")
site = yaml.safe_load((ROOT / "playbooks/site.yml").read_text(encoding="utf-8"))
check("site.yml is a list of plays", isinstance(site, list))

EXPECTED_PLAYS = {
    "docker_hosts": ["common", "docker", "discord_music_bot", "bot_autoupdate"],
    "dns_hosts": ["common", "docker", "pihole"],
}
plays = {p.get("hosts"): p for p in site}
check("every expected group has a play", set(plays) == set(EXPECTED_PLAYS), str(set(plays)))
for group, expected_roles in EXPECTED_PLAYS.items():
    play = plays.get(group)
    if play is None:
        check(f"{group}: play present", False)
        continue
    check(
        f"{group}: roles are in dependency order",
        play.get("roles") == expected_roles,
        str(play.get("roles")),
    )

all_roles = sorted({r for p in site for r in p.get("roles", [])})

print("\n=== Roles resolve ===")
roles_dir = ROOT / "roles"
for role in all_roles:
    tasks = roles_dir / role / "tasks" / "main.yml"
    check(f"{role}/tasks/main.yml exists", tasks.is_file())
    if tasks.is_file():
        loaded = yaml.safe_load(tasks.read_text(encoding="utf-8"))
        check(f"{role} tasks parse to a list", isinstance(loaded, list))
        check(f"{role} every task is named", all("name" in t for t in loaded))

print("\n=== Handlers referenced by notify exist ===")
for role in all_roles:
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
children = inv["all"]["children"]
hosts = children["docker_hosts"]["hosts"]
check("docker-01 present", "docker-01" in hosts)
check("dns-01 present", "dns-01" in children.get("dns_hosts", {}).get("hosts", {}))
# Guards the classic drift: Terraform moves a VM, the inventory does not.
def terraform_ip(root: str) -> str:
    tfvars = (ROOT.parent / f"terraform/{root}/terraform.tfvars").read_text(encoding="utf-8")
    return next(
        line.split("=")[1].strip().strip('"').split("/")[0]
        for line in tfvars.splitlines()
        if line.strip().startswith("vm_ipv4_address")
    )


for host, group, tf_root in [
    ("docker-01", "docker_hosts", "docker-host"),
    ("dns-01", "dns_hosts", "dns-host"),
]:
    inv_ip = children[group]["hosts"][host]["ansible_host"]
    tf_ip = terraform_ip(tf_root)
    check(
        f"{host}: inventory IP matches terraform tfvars",
        inv_ip == tf_ip,
        f"inventory={inv_ip} terraform={tf_ip}",
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
