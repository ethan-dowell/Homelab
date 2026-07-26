output "vm_id" {
  description = "Proxmox VMID."
  value       = module.vm.vm_id
}

output "vm_name" {
  value = module.vm.vm_name
}

output "vm_ipv4_address" {
  description = "Static address assigned via cloud-init."
  value       = module.vm.ipv4_address
}

output "ssh_command" {
  description = "Ready-to-paste SSH command."
  value       = module.vm.ssh_command
}

output "ansible_inventory_hint" {
  description = "Values that must match ansible/inventory/hosts.yml."
  value       = module.vm.ansible_inventory_hint
}
