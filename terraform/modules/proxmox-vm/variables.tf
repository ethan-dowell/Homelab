# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------
variable "node_name" {
  description = "Proxmox node to build on."
  type        = string
}

variable "vm_id" {
  type = number
}

variable "vm_name" {
  description = "VM name in the Proxmox UI, also the guest hostname."
  type        = string
}

variable "vm_description" {
  type    = string
  default = "Managed by Terraform"
}

variable "vm_tags" {
  type    = list(string)
  default = ["terraform"]
}

# ---------------------------------------------------------------------------
# Sizing
# ---------------------------------------------------------------------------
variable "vm_cores" {
  type    = number
  default = 2

  validation {
    condition     = var.vm_cores >= 1 && var.vm_cores <= 16
    error_message = "The node has 16 cores; pick a value between 1 and 16."
  }
}

variable "vm_memory_mb" {
  type    = number
  default = 2048

  validation {
    condition     = var.vm_memory_mb >= 512
    error_message = "Give it at least 512 MB."
  }
}

variable "vm_disk_gb" {
  type    = number
  default = 20
}

variable "disk_datastore_id" {
  type    = string
  default = "local-lvm"
}

# ---------------------------------------------------------------------------
# Image
#
# Taken as an input rather than downloaded here: each root module owns its own
# proxmox_download_file. Two Terraform states must never both claim the same
# resource, or destroying one silently breaks the other.
# ---------------------------------------------------------------------------
variable "cloud_image_file_id" {
  description = "Datastore file ID to import the root disk from, e.g. local:import/debian-12-genericcloud-amd64.qcow2"
  type        = string
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "vm_ipv4_address" {
  description = "Static address in CIDR form, outside the router's DHCP pool."
  type        = string
}

variable "vm_ipv4_gateway" {
  type    = string
  default = "192.168.0.1"
}

variable "dns_servers" {
  description = "Resolvers for the guest itself. See the note in main.tf about not pointing a DNS server at itself."
  type        = list(string)
  default     = ["192.168.0.1", "1.1.1.1"]
}

# ---------------------------------------------------------------------------
# Guest access
# ---------------------------------------------------------------------------
variable "vm_username" {
  type    = string
  default = "ansible"
}

variable "ssh_public_keys" {
  type = list(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "At least one public key is required, or the VM will be unreachable."
  }
}

variable "vm_enable_qemu_agent" {
  description = <<-EOT
    False for a first build: the Debian generic cloud image ships no
    qemu-guest-agent, so Proxmox waits for a reply that never comes and
    Terraform blocks. Set true only after Ansible has installed it, then
    Terraform reboots the guest to attach the virtio port.
  EOT
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Backups
# ---------------------------------------------------------------------------
variable "backup_enabled" {
  type    = bool
  default = true
}

variable "backup_job_id" {
  description = "Stable identifier so re-applies update the job rather than duplicating it."
  type        = string
  default     = null
}

variable "backup_storage" {
  type    = string
  default = "local"
}

variable "backup_schedule" {
  description = "systemd calendar event."
  type        = string
  default     = "02:30"
}

variable "backup_keep_last" {
  type    = number
  default = 3
}
