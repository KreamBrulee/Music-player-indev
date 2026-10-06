# Jenkins controller on its own instance, separate from the app so it can
# later manage several app instances. Jenkins itself is installed by Ansible.

# GitHub publishes the IP ranges its webhook deliveries come from. Read them
# at plan time so the Jenkins security group stays in step with GitHub.
data "http" "github_meta" {
  url = "https://api.github.com/meta"

  request_headers = {
    Accept = "application/vnd.github+json"
  }
}

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

data "aws_key_pair" "deploy" {
  key_name = var.key_pair_name
}

locals {
  github_hook_cidrs = [
    for c in jsondecode(data.http.github_meta.response_body).hooks : c
    if !strcontains(c, ":") # IPv4 only
  ]
}

resource "aws_security_group" "jenkins" {
  name        = "jenkins"
  description = "Jenkins: SSH and UI from admin, webhooks from GitHub"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Jenkins UI (admin)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Jenkins webhook deliveries from GitHub"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = local.github_hook_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins"
  }
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = data.aws_key_pair.deploy.key_name
  vpc_security_group_ids = [aws_security_group.jenkins.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    fallocate -l ${var.swap_size_gb}G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  EOF

  tags = {
    Name = "jenkins"
  }
}

resource "aws_eip" "jenkins" {
  domain   = "vpc"
  instance = aws_instance.jenkins.id

  tags = {
    Name = "jenkins"
  }
}
