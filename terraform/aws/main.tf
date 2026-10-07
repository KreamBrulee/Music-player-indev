# EC2 instance for the music player: Ubuntu 24.04, SSH from admin_cidr only,
# app port open to the world. Ansible configures Docker and deploys the app.

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "deploy" {
  key_name   = "music-player-deploy"
  public_key = file(pathexpand(var.public_key_path))
}

resource "aws_security_group" "app" {
  name        = "music-player"
  description = "SSH from admin only, app port public"

  ingress {
    description = "SSH from admin (public) and from inside the VPC (Jenkins CI deploys over the private network)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr, var.vpc_cidr]
  }

  ingress {
    description = "Music player API and frontend"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP (ACME challenge and redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "node_exporter (Prometheus scrape, VPC only)"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "cAdvisor (Prometheus scrape, VPC only)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "music-player"
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deploy.key_name
  vpc_security_group_ids = [aws_security_group.app.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  # Swap before anything else runs, so the 1 GiB instance can survive the
  # C++ compile during the image build.
  user_data = <<-EOF
    #!/bin/bash
    set -e
    fallocate -l ${var.swap_size_gb}G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  EOF

  # most_recent AMI drifts as Canonical publishes new images; without this a
  # later apply would destroy and recreate the running instance just to move
  # to a newer AMI. Pin against that; recreate deliberately if you want a
  # fresh base image.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "music-player"
  }
}

# Fixed public IP. Survives stop/start and keeps the domain's DNS record valid.
resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id

  tags = {
    Name = "music-player"
  }
}
