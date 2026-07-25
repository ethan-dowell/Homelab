output "vm_id" {
  description = "Proxmox VMID."
  value       = proxmox_virtual_environment_vm.docker_host.vm_id
}

output "vm_name" {
  value = proxmox_virtual_environment_vm.docker_host.name
}

output "vm_ipv4_address" {
  description = "Static address assigned via cloud-init."
  value       = split("/", var.vm_ipv4_address)[0]
}

output "ssh_command" {
  description = "Ready-to-paste SSH command."
  value       = "ssh -i ~/.ssh/homelab_ed25519 ${var.vm_username}@${split("/", var.vm_ipv4_address)[0]}"
}

output "ansible_inventory_hint" {
  description = "Values that must match ansible/inventory/hosts.yml."
  value = {
    ansible_host = split("/", var.vm_ipv4_address)[0]
    ansible_user = var.vm_username
  }
}
