# A Debian cloud-init VM on Proxmox, plus its backup job.
#
# The node has no VM templates, so there is nothing to clone -- the root disk
# is imported from a downloaded cloud image that the calling root module owns.

resource "proxmox_virtual_environment_vm" "this" {
  node_name = var.node_name
  vm_id     = var.vm_id
  name      = var.vm_name
  tags      = var.vm_tags

  description = var.vm_description

  # Come back after a power cut without anyone logging in.
  on_boot = true
  started = true

  agent {
    enabled = var.vm_enable_qemu_agent
  }

  cpu {
    cores = var.vm_cores
    # 'host' passes the physical CPU flags through, which matters for the AES
    # and AVX paths workloads like ffmpeg use.
    type = "host"
  }

  memory {
    dedicated = var.vm_memory_mb
  }

  disk {
    datastore_id = var.disk_datastore_id
    import_from  = var.cloud_image_file_id
    interface    = "scsi0"
    size         = var.vm_disk_gb
    discard      = "on"
    ssd          = true
    iothread     = true
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  # The generic cloud image logs boot output to serial. Without this there is
  # no way to see why a VM never came up on the network.
  serial_device {}

  initialization {
    datastore_id = var.disk_datastore_id

    ip_config {
      ipv4 {
        address = var.vm_ipv4_address
        gateway = var.vm_ipv4_gateway
      }
    }

    # Note for DNS servers built with this module: do not list the guest's own
    # address here. cloud-init writes these before anything is installed, so a
    # self-reference leaves the host unable to resolve well enough to fetch the
    # very software that would answer it.
    dns {
      servers = var.dns_servers
    }

    user_account {
      username = var.vm_username
      keys     = var.ssh_public_keys
      # Key-only login. Console access still works through the Proxmox UI.
    }
  }

  lifecycle {
    ignore_changes = [
      # Proxmox rewrites the cloud-init drive on every boot; without this
      # Terraform proposes a spurious diff on each plan.
      initialization[0].user_account,
    ]
  }
}

resource "proxmox_backup_job" "this" {
  count = var.backup_enabled ? 1 : 0

  id       = coalesce(var.backup_job_id, "backup-${var.vm_name}")
  node     = var.node_name
  storage  = var.backup_storage
  schedule = var.backup_schedule
  vmid     = [tostring(proxmox_virtual_environment_vm.this.vm_id)]
  enabled  = true

  # snapshot mode backs up without stopping the guest.
  mode = "snapshot"

  # zstd is markedly faster than gzip at a similar ratio, and this runs on the
  # same node that serves the workloads.
  compress = "zstd"

  notes_template = "{{guestname}} - scheduled backup (terraform)"

  prune_backups = {
    "keep-last" = tostring(var.backup_keep_last)
  }
}
