variable "region" {
  description = "AWS region, same as the app instance"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "Jenkins needs ~1.5-2 GiB for the controller plus memory for Docker builds. t3.micro (1 GiB) is too small."
  type        = string
  default     = "t3.small"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH to Jenkins and open the Jenkins UI (your public IP, e.g. 203.0.113.7/32)"
  type        = string
}

variable "key_pair_name" {
  description = "Existing key pair (created by terraform/aws) installed for SSH"
  type        = string
  default     = "music-player-deploy"
}

variable "swap_size_gb" {
  description = "Swap file size, as on the app instance, for memory headroom during builds"
  type        = number
  default     = 2
}
