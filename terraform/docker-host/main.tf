# ---------------------------------------------------------------------------
# Cloud image
#
# The node has no VM templates, so there is nothing to clone. Instead the
# Debian generic cloud image is downloaded onto the node once and imported as
# the VM's root disk. Terraform keeps the download in state, so rebuilding the
# VM does not re-fetch the image.
# ---------------------------------------------------------------------------
# Note the resource name: proxmox_virtual_environment_download_file is
# deprecated and goes away in provider v1.0.
resource "proxmox_download_file" "debian_cloud_image" {
  content_type = "iso"
  datastore_id = var.image_datastore_id
  node_name    = var.node_name

  url       = var.cloud_image_url
  file_name = var.cloud_image_file_name

  # Debian rebuilds the image in place behind the 'latest' URL. Leave the
  # downloaded copy alone rather than re-fetching 300 MB on every apply.
  overwrite = false

  # Adopt the file if it is already on the datastore from a previous run or a
  # manual download, instead of failing the apply.
  overwrite_unmanaged = true
}

# ---------------------------------------------------------------------------
# Docker host
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "docker_host" {
  node_name = var.node_name
  vm_id     = var.vm_id
  name      = var.vm_name
  tags      = var.vm_tags


  description = var.vm_description

  # Start on boot so the bot comes back after a power cut without intervention.
  on_boot = true
  started = true

  # The generic cloud image does not ship qemu-guest-agent. Leaving this
  # enabled makes Terraform block for minutes waiting for an agent that will
  # never answer. Ansible installs the agent later; until then Proxmox falls
  # back to the static address configured below.
  agent {
    enabled = false
  }

  cpu {
    cores = var.vm_cores
    # 'host' passes the physical CPU flags straight through, which matters for
    # the AES and AVX paths ffmpeg uses.
    type = "host"
  }

  memory {
    dedicated = var.vm_memory_mb
  }

  disk {
    datastore_id = var.disk_datastore_id
    import_from  = proxmox_download_file.debian_cloud_image.id
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

  # Serial console: the generic cloud image logs boot output here, which is the
  # only way to see what happened if the VM never comes up on the network.
  serial_device {}

  initialization {
    datastore_id = var.disk_datastore_id

    ip_config {
      ipv4 {
        address = var.vm_ipv4_address
        gateway = var.vm_ipv4_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      username = var.vm_username
      keys     = var.ssh_public_keys
      # No password is set on purpose: key-only login. Console access still
      # works through the Proxmox UI if you ever lock yourself out.
    }
  }

  lifecycle {
    ignore_changes = [
      # Proxmox rewrites the cloud-init drive on every boot; without this
      # Terraform proposes a spurious diff each plan.
      initialization[0].user_account,
    ]
  }
}
