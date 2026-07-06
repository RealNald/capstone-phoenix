# Data source for cloud-init (optional but ensures SSH is ready)
data "cloudinit_config" "node" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      package_update: true
      package_upgrade: false
    EOF
  }
}

resource "aws_instance" "node" {
  count = var.node_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  associate_public_ip_address = true

  # Use a small root volume (gp3 is cheaper and faster)
  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  # Tags to identify role for Ansible
  tags = {
    Name    = "${var.project_name}-${var.role}-${count.index + 1}"
    Role    = var.role
    project = var.project_name
  }

  # Ensure cloud-init finishes before Ansible attempts to SSH
  # provisioner "remote-exec" {
  #   inline = ["sudo cloud-init status --wait"]
  # }
}

# Elastic IP for each node (TOP LEVEL - NOT nested inside aws_instance)
resource "aws_eip" "node" {
  count = var.node_count

  instance = aws_instance.node[count.index].id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.role}-${count.index + 1}-eip"
  }
}