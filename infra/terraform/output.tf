# Control Plane outputs
output "control_plane_public_ips" {
  description = "Public IPs of control plane nodes (for SSH/kubectl)"
  value       = module.compute_control_plane.public_ips
}

output "control_plane_private_ips" {
  description = "Private IPs of control plane nodes (for worker join)"
  value       = module.compute_control_plane.private_ips
}

# Worker outputs
output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = module.compute_workers.public_ips
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = module.compute_workers.private_ips
}

# Convenience outputs
output "all_public_ips" {
  description = "All node public IPs (control-plane first, then workers)"
  value       = concat(module.compute_control_plane.public_ips, module.compute_workers.public_ips)
}

output "all_private_ips" {
  description = "All node private IPs"
  value       = concat(module.compute_control_plane.private_ips, module.compute_workers.private_ips)
}

output "ssh_command" {
  description = "Example SSH command to the control plane"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${module.compute_control_plane.public_ips[0]}"
}