# Need
variable "student_name" {
  type        = string
  description = "Your student identifier (e.g., jsmith, mgarcia)"

  validation {
    condition     = can(regex("^[a-z]{2,10}$", var.student_name))
    error_message = "Student name must be 2-10 lowercase letters."
  }
}

variable "host_port" {
	description = "Port on the host"
	type = number
	default = 8080
}

# Baby's first Terraform config
terraform {
	required_providers {
		docker = {
			source = "kreuzwerker/docker"
			version = "~> 3.0"
		}
	}
}

provider "docker" {}

resource "docker_image" "nginx" {
	name = "nginx:latest"
}

resource "docker_network" "lan" {
	name = "${var.student_name}-sys350-lan"
}

resource "docker_container" "web_server" {
	name = "${var.student_name}-web-server"
	image = docker_image.nginx.image_id

	ports {
		internal = 80
		external = var.host_port
	}
	
	networks_advanced {
		name = docker_network.lan.name
	}

	volumes {
		volume_name = docker_volume.web_data.name
		container_path = "/usr/share/nginx/html"
		read_only = false
	}
}

resource "docker_volume" "web_data" {
	name = "${var.student_name}-ngnix-html"
}

output "container_ip" {
	value = docker_container.web_server.network_data[0].ip_address
}
