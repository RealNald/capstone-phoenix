variable "project_name" {
  description = "Base name for all resources"
  type        = string
  default     = "taskapp-phoenix"
}


variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for all nodes"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "Name of the existing AWS EC2 Key Pair"
  type        = string
  # CHANGE ME
  default = "your-aws-keypair-name"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH (strictly your public IP)"
  type        = list(string)
  # GET YOUR IP: curl -s ifconfig.me/32
  default = ["YOUR_IP_ADDRESS/32"]
}

variable "control_plane_count" {
  description = "Number of control plane nodes (keep at 1 per README)"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes (must be >= 2)"
  type        = number
  default     = 2
}