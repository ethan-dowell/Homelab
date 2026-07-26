output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}

output "vm_name" {
  value = proxmox_virtual_environment_vm.this.name
}

output "ipv4_address" {
  description = "Address without the CIDR suffix."
  value       = split("/", var.vm_ipv4_address)[0]
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/homelab_ed25519 ${var.vm_username}@${split("/", var.vm_ipv4_address)[0]}"
}

output "ansible_inventory_hint" {
  description = "Values that must match the Ansible inventory."
  value = {
    ansible_host = split("/", var.vm_ipv4_address)[0]
    ansible_user = var.vm_username
  }
}

output "backup_job_id" {
  value = var.backup_enabled ? proxmox_backup_job.this[0].id : null
}
