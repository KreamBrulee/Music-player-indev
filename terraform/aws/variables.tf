variable "region" {
  description = "AWS region for the instance"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH in (your public IP, e.g. 203.0.113.7/32)"
  type        = string
}

variable "public_key_path" {
  description = "Public key installed on the instance for SSH"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "app_port" {
  description = "Port the app listens on, open to the internet"
  type        = number
  default     = 3000
}

variable "swap_size_gb" {
  description = "Swap file size. The t3.micro has 1 GiB RAM, and compiling the C++ app on the instance needs more headroom."
  type        = number
  default     = 2
}

variable "vpc_cidr" {
  description = "The VPC's CIDR. Used to allow, from inside the VPC only: exporter scraping (9100/8080) and SSH from the Jenkins host (so its pipeline deploys over the private network). Default is the AWS default VPC range."
  type        = string
  default     = "172.31.0.0/16"
}
