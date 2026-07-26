output "vm_id" {
  value = module.vm.vm_id
}

output "vm_name" {
  value = module.vm.vm_name
}

output "vm_ipv4_address" {
  description = "Point your router's DHCP DNS option at this address."
  value       = module.vm.ipv4_address
}

output "ssh_command" {
  value = module.vm.ssh_command
}

output "pihole_admin_url" {
  value = "http://${module.vm.ipv4_address}/admin"
}

output "ansible_inventory_hint" {
  value = module.vm.ansible_inventory_hint
}
