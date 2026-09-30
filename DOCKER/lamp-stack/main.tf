# Terraform init
terraform {
 required_providers {
  docker = {
   source = "kreuzwerker/docker"
   version = "~> 3.0"
  }
 }
}

provider "docker" {
 host = "unix:///var/run/docker.sock"
}

# Los Resources
resource "docker_network" "lamp_network" {
 name = "${var.student_name}-lamp-network"
 driver = "bridge"
}

resource "docker_volume" "db_data" {
 name = "${var.student_name}-db-data"
}

resource "docker_image" "mysql" {
 name = "mysql:8.0"
}

# Container
resource "docker_container" "db" {
  name  = "${var.student_name}-db"
  image = docker_image.mysql.image_id

  env = [
    "DB_HOST=${var.student_name}-db",   # jsmith-db or mgarcia-db
    "DB_USER=${var.mysql_user}",
    "DB_PASSWORD=${var.mysql_password}",
    "DB_NAME=${var.mysql_database}",
  ]

  volumes {
    volume_name    = docker_volume.db_data.name
    container_path = "/var/lib/mysql"
  }

  volumes {
    host_path      = abspath("${path.module}/db/init.sql")
    container_path = "/docker-entrypoint-initdb.d/init.sql"
  }

  networks_advanced {
    name = docker_network.lamp_network.name
  }
}

# Image
resource "docker_image" "web" {
 name = "${var.student_name}-lamp-web:latest"
 build {
  context = abspath("${path.module}/php")
  dockerfile = "Dockerfile"
 }
}

# Web
resource "docker_container" "web" {
  count = var.web_count

  name  = "${var.student_name}-web-${count.index}"
  image = docker_image.web.image_id

  ports {
    internal = 80
    external = var.web_port + count.index
  }

  volumes {
    host_path      = abspath("${path.module}/php/src")
    container_path = "/var/www/html"
  }

  env = [
    "DB_HOST=${var.student_name}-db",
    "DB_USER=${var.mysql_user}",
    "DB_PASSWORD=${var.mysql_password}",
    "DB_NAME=${var.mysql_database}",
  ]

  networks_advanced {
    name = docker_network.lamp_network.name
  }

  depends_on = [docker_container.db]
}
