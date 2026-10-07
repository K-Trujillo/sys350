# Part 1, providers & student_name
terraform {
 required_providers {
  docker = {
   source = "kreuzwerker/docker"
   version = "~> 3.0"
  }
  libvirt = {
   source = "dmacvicar/libvirt"
   version = "~> 0.9"
  }
  tls = {
   source = "hashicorp/tls"
   version = "~> 4.0"
  }
 }
}

provider "docker" {
 # Nada aqui, nothing needed
}

provider "libvirt" {
 uri = "qemu:///system"
}

# Mah vars
variable "student_name" {
 type = string
 description = "Your student identifier (e.g., jsmith, mgarcia)"
 
 validation {
  condition = can(regex("^[a-z]{2,10}$", var.student_name))
  error_message = "Student name must be 2-10 lowercase letters."
 }
}
