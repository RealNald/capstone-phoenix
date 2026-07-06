# Compute Module Outputs
output "public_ips" {
  description = "Public IP addresses (Elastic IPs) of the nodes"
  value       = aws_eip.node[*].public_ip
}

output "private_ips" {
  description = "Private IP addresses of the nodes (for k3s internal comms)"
  value       = aws_instance.node[*].private_ip
}

output "instance_ids" {
  description = "Instance IDs of the nodes"
  value       = aws_instance.node[*].id
}