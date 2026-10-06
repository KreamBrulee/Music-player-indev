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

variable "monitoring_cidr" {
  description = "CIDR allowed to scrape node_exporter (9100) and cAdvisor (8080). Defaults to the VPC so exporters stay internal, never internet-exposed."
  type        = string
  default     = "172.31.0.0/16"
}

variable "ci_cidr" {
  description = "Jenkins host, allowed to SSH in so its pipeline can run the deploy playbook. Defaults to the Jenkins Elastic IP from terraform/jenkins."
  type        = string
  default     = "13.50.73.77/32"
}
