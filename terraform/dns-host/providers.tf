provider "proxmox" {
  endpoint = var.proxmox_endpoint

  # Credentials come from the environment, never a committed file:
  #
  #   $env:PROXMOX_VE_API_TOKEN = 'root@pam!terraform=<uuid>'
  #
  # or:
  #
  #   $env:PROXMOX_VE_USERNAME = 'root@pam'
  #   $env:PROXMOX_VE_PASSWORD = '<password>'

  insecure = var.proxmox_insecure

  ssh {
    agent    = false
    username = var.proxmox_ssh_username
  }
}
