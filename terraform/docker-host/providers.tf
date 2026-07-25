provider "proxmox" {
  endpoint = var.proxmox_endpoint

  # Credentials come from the environment, never from a committed file:
  #
  #   $env:PROXMOX_VE_API_TOKEN = 'root@pam!terraform=<uuid>'
  #
  # or, if you have not made a token yet:
  #
  #   $env:PROXMOX_VE_USERNAME = 'root@pam'
  #   $env:PROXMOX_VE_PASSWORD = '<password>'
  #
  # The provider reads both automatically, so nothing is set here.

  # Proxmox ships a self-signed certificate by default. Set proxmox_insecure to
  # false once you have put a real certificate on the node.
  insecure = var.proxmox_insecure

  ssh {
    agent    = false
    username = var.proxmox_ssh_username
    # Password comes from PROXMOX_VE_SSH_PASSWORD when set.
    #
    # The provider only opens an SSH session for operations the API cannot do
    # (uploading snippets, some disk imports). The configuration in this
    # directory is designed to avoid those, so this block is usually unused --
    # it is here so that a plan does not fail if the provider decides it needs
    # a shell.
  }
}
