# Runs the app as a container from an image that already exists locally.
# Build it first, from the repo root:
#   docker build -t music-player:terraform .
# (Jenkins does this in CI; the provider's own build path fails on this host.)
# Local Docker only: no cloud provider is involved.

data "docker_image" "app" {
  name = var.image_name
}

resource "docker_container" "app" {
  name    = var.container_name
  image   = data.docker_image.app.id
  restart = "unless-stopped"

  ports {
    internal = 3000
    external = var.host_port
  }

  volumes {
    host_path      = abspath("${path.module}/${var.music_dir}")
    container_path = "/app/songs"
    read_only      = true
  }
}
