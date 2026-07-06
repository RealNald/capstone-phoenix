resource "aws_security_group" "nodes" {
  name_prefix = "${var.project_name}-nodes-"
  description = "Least-privilege security group for k3s nodes"
  vpc_id      = var.vpc_id

  # Allow all internal node-to-node traffic (k3s flannel/overlay)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # SSH - ONLY YOUR IP (README compliance)
  ingress {
    description = "allow ssh traffic from specified cidr blocks"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # HTTP/HTTPS - World open (for the app)
  ingress {
    description = "allow http traffic from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow https traffic from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API (6443) - VPC ONLY. NOT PUBLIC. (README hard requirement)
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow outbound internet for updates and k3s install
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg" }
}