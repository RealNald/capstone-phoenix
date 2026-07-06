variable "project_name" {
  description = "project_name for tagging"
  type        = string
  default     = "taskapp-phoenix"
}

variable "ami_id" {
  description = "AMI ID for the instance (Ubuntu 22.04)"
  type        = string
}
#ec2 instance
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance into"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "key_name" {
  description = "AWS SSH key pair name"
  type        = string
}

variable "role" {
  description = "Node role: control-plane or worker"
  type        = string
}

variable "node_count" {
  description = "Number of nodes to provision for this role"
  type        = number
  default     = 1
}


variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 10
}