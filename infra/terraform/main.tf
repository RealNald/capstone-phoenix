# 1. NETWORK MODULE
module "network" {
  source = "./modules/network"

  project_name = var.project_name
  aws_region   = var.aws_region
}

# 2. SECURITY GROUP MODULE
module "security_group" {
  source = "./modules/security_group"

  vpc_id            = module.network.vpc_id
  project_name      = var.project_name
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  vpc_cidr          = module.network.vpc_cidr
}

# 3. DATA SOURCE: Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

}

# 4. COMPUTE: Control Plane (1 node)
module "compute_control_plane" {
  source = "./modules/compute"

  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = var.instance_type
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.security_group.security_group_id]
  key_name           = var.ssh_key_name
  role               = "control-plane"
  node_count         = var.control_plane_count
  project_name       = var.project_name
  root_volume_size   = 20
}

# 5. COMPUTE: Workers (2+ nodes)
module "compute_workers" {
  source = "./modules/compute"

  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = var.instance_type
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.security_group.security_group_id]
  key_name           = var.ssh_key_name
  role               = "worker"
  node_count         = var.worker_count
  project_name       = var.project_name
  root_volume_size   = 20
}
