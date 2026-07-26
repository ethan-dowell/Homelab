# ---------------------------------------------------------------------------
# Cloud image (owned by this root -- see cloud_image_file_name in variables.tf)
# ---------------------------------------------------------------------------
resource "proxmox_download_file" "debian_cloud_image" {
  # "import", not "iso": PVE 9 will not import a root disk from 'iso' content.
  content_type = "import"
  datastore_id = var.image_datastore_id
  node_name    = var.node_name

  url       = var.cloud_image_url
  file_name = var.cloud_image_file_name

  overwrite           = false
  overwrite_unmanaged = true
}

# ---------------------------------------------------------------------------
# Pi-hole DNS host
#
# Separate from docker-01 on purpose. DNS is the highest blast-radius service
# on a home network: if it stops answering, every device looks broken to
# everyone in the house. Sharing a host with the media bot would tie DNS uptime
# to a container that gets rebuilt weekly and redeployed on every playbook run.
# docker-01 also already runs systemd-resolved on port 53.
# ---------------------------------------------------------------------------
module "vm" {
  source = "../modules/proxmox-vm"

  node_name      = var.node_name
  vm_id          = var.vm_id
  vm_name        = var.vm_name
  vm_description = var.vm_description
  vm_tags        = var.vm_tags

  vm_cores          = var.vm_cores
  vm_memory_mb      = var.vm_memory_mb
  vm_disk_gb        = var.vm_disk_gb
  disk_datastore_id = var.disk_datastore_id

  cloud_image_file_id = proxmox_download_file.debian_cloud_image.id

  network_bridge  = var.network_bridge
  vm_ipv4_address = var.vm_ipv4_address
  vm_ipv4_gateway = var.vm_ipv4_gateway
  dns_servers     = var.dns_servers

  vm_username          = var.vm_username
  ssh_public_keys      = var.ssh_public_keys
  vm_enable_qemu_agent = var.vm_enable_qemu_agent

  backup_enabled   = var.backup_enabled
  backup_storage   = var.backup_storage
  backup_schedule  = var.backup_schedule
  backup_keep_last = var.backup_keep_last
}
