# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------
variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint, including scheme and port."
  type        = string
  default     = "https://192.168.0.200:8006/"
}

variable "proxmox_insecure" {
  description = "Skip TLS verification. Required while the node uses its self-signed certificate."
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "User for the provider's fallback SSH connection to the node."
  type        = string
  default     = "root"
}

variable "node_name" {
  description = "Proxmox node to build on."
  type        = string
  default     = "pve"
}

# ---------------------------------------------------------------------------
# VM identity and placement
# ---------------------------------------------------------------------------
variable "vm_id" {
  description = "VMID for the Docker host. 100 is the existing Windows VM."
  type        = number
  default     = 101
}

variable "vm_name" {
  description = "VM name shown in the Proxmox UI, also used as the hostname."
  type        = string
  default     = "docker-01"
}

variable "vm_description" {
  type    = string
  default = "Docker host - managed by Terraform (Homelab/terraform/docker-host)"
}

variable "vm_tags" {
  type    = list(string)
  default = ["terraform", "docker"]
}

# ---------------------------------------------------------------------------
# Sizing
# ---------------------------------------------------------------------------
variable "vm_cores" {
  description = "vCPU count. Audio transcoding is the only real load."
  type        = number
  default     = 2

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
  description = "Root disk size. The image itself is ~2 GB; the rest is for Docker images and logs."
  type        = number
  default     = 20
}

variable "disk_datastore_id" {
  description = "Storage for the VM disk. local-lvm is the thin pool on this node."
  type        = string
  default     = "local-lvm"
}

variable "image_datastore_id" {
  description = "Storage that holds the downloaded cloud image. Must accept 'iso' content."
  type        = string
  default     = "local"
}

# ---------------------------------------------------------------------------
# Guest OS image
# ---------------------------------------------------------------------------
variable "cloud_image_url" {
  description = "Debian generic cloud image. 'genericcloud' has cloud-init and no cloud-vendor agents."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
}

variable "cloud_image_file_name" {
  description = <<-EOT
    Name to store the image under. Proxmox's 'iso' content type only accepts
    .iso and .img extensions, so the .qcow2 is saved as .img. The file's actual
    format is unchanged and the import handles it correctly.
  EOT
  type        = string
  default     = "debian-12-genericcloud-amd64.img"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "vm_ipv4_address" {
  description = "Static address in CIDR form. Must be outside the router's DHCP pool."
  type        = string
  default     = "192.168.0.210/24"
}

variable "vm_ipv4_gateway" {
  type    = string
  default = "192.168.0.1"
}

variable "dns_servers" {
  type    = list(string)
  default = ["192.168.0.1", "1.1.1.1"]
}

# ---------------------------------------------------------------------------
# Guest access
# ---------------------------------------------------------------------------
variable "vm_username" {
  description = "Account cloud-init creates. Ansible connects as this user."
  type        = string
  default     = "ansible"
}

variable "ssh_public_keys" {
  description = <<-EOT
    Public keys authorised for vm_username. Public keys are not secret, so
    these are safe to commit -- the matching private key is not in this repo.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "At least one public key is required, or the VM will be unreachable."
  }
}
