# Values for this specific homelab. No secrets here -- Proxmox credentials come
# from environment variables and public keys are not secret.

proxmox_endpoint = "https://192.168.0.200:8006/"
node_name        = "pve"

vm_id        = 102
vm_name      = "dns-01"
vm_cores     = 1
vm_memory_mb = 1024
vm_disk_gb   = 10

disk_datastore_id  = "local-lvm"
image_datastore_id = "local"

network_bridge  = "vmbr0"
vm_ipv4_address = "192.168.0.211/24"
vm_ipv4_gateway = "192.168.0.1"

# Upstreams for the DNS host itself, never its own address. See variables.tf.
dns_servers = ["1.1.1.1", "9.9.9.9"]

vm_username = "ansible"

ssh_public_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID5ZCDX1E6I9GBtaxW9qc0/cPYobqOa/lGDPmPbMJzHY homelab-ansible",
]

# false for the first build; flip to true after the Ansible common role has
# installed qemu-guest-agent, then apply again.
vm_enable_qemu_agent = false

backup_enabled   = true
backup_schedule  = "03:15"
backup_keep_last = 3
