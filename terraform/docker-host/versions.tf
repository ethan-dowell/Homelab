terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      # bpg/proxmox is the actively maintained provider. Telmate/proxmox, which
      # most older homelab guides use, has been effectively unmaintained since
      # 2023 and does not support PVE 8/9 disk imports.
      source  = "bpg/proxmox"
      version = ">= 0.60.0"
    }
  }
}
