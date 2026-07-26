# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------
variable "proxmox_endpoint" {
  type    = string
  default = "https://192.168.0.200:8006/"
}

variable "proxmox_insecure" {
  description = "Skip TLS verification. Required while the node uses its self-signed certificate."
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  type    = string
  default = "root"
}

variable "node_name" {
  type    = string
  default = "pve"
}

# ---------------------------------------------------------------------------
# VM
# ---------------------------------------------------------------------------
variable "vm_id" {
  description = "100 is WinServer2022, 101 is docker-01."
  type        = number
  default     = 102
}

variable "vm_name" {
  type    = string
  default = "dns-01"
}

variable "vm_description" {
  type    = string
  default = "Pi-hole DNS - managed by Terraform (Homelab/terraform/dns-host)"
}

variable "vm_tags" {
  type    = list(string)
  default = ["terraform", "dns", "pihole"]
}

# Pi-hole is very light: FTL idles around 60-90 MB and the blocklists are a few
# hundred thousand domains in memory. 1 core / 1 GB is generous.
variable "vm_cores" {
  type    = number
  default = 1
}

variable "vm_memory_mb" {
  type    = number
  default = 1024
}

variable "vm_disk_gb" {
  description = "Mostly query logs; Pi-hole rotates them itself."
  type        = number
  default     = 10
}

variable "disk_datastore_id" {
  type    = string
  default = "local-lvm"
}

variable "image_datastore_id" {
  description = "Storage holding the cloud image. Must accept 'import' content."
  type        = string
  default     = "local"
}

variable "cloud_image_url" {
  type    = string
  default = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
}

variable "cloud_image_file_name" {
  description = <<-EOT
    Deliberately distinct from the docker-host copy. Both roots download the
    same upstream image, but each must own its own file: two Terraform states
    sharing one resource means destroying either one breaks the other.
  EOT
  type        = string
  default     = "debian-12-genericcloud-amd64-dns.qcow2"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "vm_ipv4_address" {
  description = <<-EOT
    Static, and it must stay static: every device on the LAN will be told to
    use this address as its resolver. Changing it means reconfiguring DHCP.
  EOT
  type        = string
  default     = "192.168.0.211/24"
}

variable "vm_ipv4_gateway" {
  type    = string
  default = "192.168.0.1"
}

variable "dns_servers" {
  description = <<-EOT
    Resolvers for the guest itself -- deliberately NOT its own address.
    cloud-init writes these before Pi-hole exists, so pointing the host at
    itself would leave it unable to resolve well enough to install the thing
    that would answer. It also avoids a resolution loop if Pi-hole is down.
  EOT
  type        = list(string)
  default     = ["1.1.1.1", "9.9.9.9"]
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
}

variable "vm_enable_qemu_agent" {
  description = "Leave false for the first build; see the module's variable docs."
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

variable "backup_storage" {
  type    = string
  default = "local"
}

variable "backup_schedule" {
  description = "03:15 keeps clear of docker-01's 02:30 window."
  type        = string
  default     = "03:15"
}

variable "backup_keep_last" {
  type    = number
  default = 3
}
