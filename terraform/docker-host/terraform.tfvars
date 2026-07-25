# Values for this specific homelab. No secrets here -- credentials come from
# environment variables (see providers.tf) and public keys are not secret.

proxmox_endpoint = "https://192.168.0.200:8006/"
node_name        = "pve"

vm_id        = 101
vm_name      = "docker-01"
vm_cores     = 2
vm_memory_mb = 2048
vm_disk_gb   = 20

disk_datastore_id  = "local-lvm"
image_datastore_id = "local"

network_bridge  = "vmbr0"
vm_ipv4_address = "192.168.0.210/24"
vm_ipv4_gateway = "192.168.0.1"
dns_servers     = ["192.168.0.1", "1.1.1.1"]

vm_username = "ansible"

ssh_public_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID5ZCDX1E6I9GBtaxW9qc0/cPYobqOa/lGDPmPbMJzHY homelab-ansible",
]
