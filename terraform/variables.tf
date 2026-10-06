variable "image_name" {
  description = "Image name:tag built from the repo Dockerfile"
  type        = string
  default     = "music-player:terraform"
}

variable "container_name" {
  description = "Name of the running container"
  type        = string
  default     = "music-player-tf"
}

variable "host_port" {
  description = "Host port mapped to the app's port 3000. Kept off 3000 so it doesn't clash with docker compose."
  type        = number
  default     = 3200
}

variable "music_dir" {
  description = "Host folder mounted read-only at /app/songs"
  type        = string
  default     = "../songs"
}
