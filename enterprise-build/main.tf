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

variable "services" {
 description = "Docker services on the host. Key = short name (gitea, wordpress)."
 type = map(object({
  image = string
  network = string
  ports = optional(list(object({
   internal = number
   external = number
  })), [])
  env = optional(map(string), {})
 }))
 default = {}
}

variable "vms" {
 description = "KVM virtual machines. Key = domain name (prefix with student_name)."
 type = map(object({
  os = string
  memory_mb = optional(number)
  vcpu = optional(number)
 }))
 default = {}

 validation {
  condition = alltrue([
   for v in values(var.vms) :
   contains(["win-server", "win11", "ubuntu-server"], v.os)
  ])
  error_message = "OS must be one of: win-server, win11, ubuntu-server"
 }
}

# copied and pasted these next few vars so I wouldn't mess it up
variable "networks" {
  description = "Docker network segments. Each becomes student_name-NAME-net"
  type        = list(string)
  default     = ["devops", "internal", "web"]
}

variable "corp_octet" {
  description = "Third octet of the KVM NAT subnet (192.168.CORP_OCTET.0/24). Student A: 50. Student B: 51."
  type        = number
  default     = 50

  validation {
    condition     = var.corp_octet >= 1 && var.corp_octet <= 254
    error_message = "corp_octet must be between 1 and 254."
  }
}

variable "cloud_image_path" {
  description = "Path to the Ubuntu cloud image on the hypervisor host"
  type        = string
  default     = "/opt/images/ubuntu-26.04-server-cloudimg-amd64.img"
}

variable "win_server_image_path" {
  description = "Path to the golden Windows Server qcow2 on the hypervisor host"
  type        = string
  default     = "/opt/images/orig/windows-server-2022.qcow2"
}

variable "win11_image_path" {
  description = "Path to the golden Windows 11 qcow2 on the hypervisor host"
  type        = string
  default     = "/opt/images/orig/aliyah-win11.qcow2"
}

# C&P'd this next section as well so I won't mess it up
locals {
  os_defaults = {
    win-server = {
      image      = var.win_server_image_path
      vcpu       = 2
      memory_mb  = 2048
      disk_bus   = "sata"
      disk_dev   = "sda"
      nic        = "e1000e"
      uefi       = true
      loader     = "/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
      nvram_tmpl = "/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
      cloud_init = false
    }
    win11 = {
      image      = var.win11_image_path
      vcpu       = 4
      memory_mb  = 4096
      disk_bus   = "sata"
      disk_dev   = "sda"
      nic        = "e1000e"
      uefi       = true
      loader     = "/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
      nvram_tmpl = "/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
      cloud_init = false
    }
    ubuntu-server = {
      image      = var.cloud_image_path
      vcpu       = 2
      memory_mb  = 2048
      disk_bus   = "virtio"
      disk_dev   = "vda"
      nic        = "virtio"
      uefi       = false
      loader     = null
      nvram_tmpl = null
      cloud_init = true
    }
  }

  # Merged VM map: student overrides win, profile defaults fill the rest
  vms = { for name, cfg in var.vms : name => {
    os         = cfg.os
    image      = local.os_defaults[cfg.os].image
    memory     = (coalesce(cfg.memory_mb, local.os_defaults[cfg.os].memory_mb)) * 1024
    vcpu       = coalesce(cfg.vcpu, local.os_defaults[cfg.os].vcpu)
    disk_bus   = local.os_defaults[cfg.os].disk_bus
    disk_dev   = local.os_defaults[cfg.os].disk_dev
    nic        = local.os_defaults[cfg.os].nic
    uefi       = local.os_defaults[cfg.os].uefi
    loader     = local.os_defaults[cfg.os].loader
    nvram_tmpl = local.os_defaults[cfg.os].nvram_tmpl
    cloud_init = local.os_defaults[cfg.os].cloud_init
  } }
}

# Phase 3 cause I forgot to label phase 2 oops
resource "docker_network" "segment" {
  for_each = toset(var.networks)

  name   = "${var.student_name}-${each.value}-net"
  driver = "bridge"
}

resource "docker_container" "service" {
  for_each = var.services

  name  = "${var.student_name}-${each.key}"
  image = each.value.image

  networks_advanced {
    name = "${var.student_name}-${each.value.network}-net"
  }

  dynamic "ports" {
    for_each = each.value.ports
    content {
      internal = ports.value.internal
      external = ports.value.external
    }
  }

  env = [for k, v in each.value.env : "${k}=${v}"]

  restart = "unless-stopped"
}

# Phase 4, I'm tired
resource "tls_private_key" "deploy" {
  algorithm = "ED25519"
}

# Optional output so you can save the private key locally:
output "deploy_private_key_pem" {
  value     = tls_private_key.deploy.private_key_pem
  sensitive = true
}

resource "libvirt_network" "corp" {
  name      = "${var.student_name}-corp-lan"
  autostart = true

  forward = {
    mode = "nat"
  }

  ips = [{
    address = "192.168.${var.corp_octet}.1"
    prefix  = 24
    family  = "ipv4"
    dhcp = {
      ranges = [{
        start = "192.168.${var.corp_octet}.100"
        end   = "192.168.${var.corp_octet}.254"
      }]
    }
  }]
}

# Ubuntu
resource "libvirt_cloudinit_disk" "init" {
  for_each = { for k, v in local.vms : k => v if v.cloud_init }

  name = "${each.key}-cloudinit.iso"

  # templatefile() replaces ${hostname}, ${student_name}, ${ssh_public_key}
  # before the YAML is written onto the ISO.
  user_data = templatefile("${path.module}/cloud-init-server.yaml", {
    hostname       = each.key
    student_name   = var.student_name
    ssh_public_key = tls_private_key.deploy.public_key_openssh
  })

  # instance-id changes per VM key so cloud-init runs on each new disk.
  meta_data = yamlencode({
    instance-id    = "${each.key}-cloudinit"
    local-hostname = each.key
  })
}

resource "libvirt_volume" "ubuntu_base" {
  for_each = { for k, v in local.vms : k => v if v.cloud_init }

  name = "${each.key}-base.qcow2"
  pool = "default"

  target = {
    format = { type = "qcow2" }
  }

  create = {
    content = {
      url = each.value.image
    }
  }
}

resource "libvirt_volume" "vm_disk" {
  for_each = { for k, v in local.vms : k => v if v.cloud_init }

  name     = "${each.key}.qcow2"
  pool     = "default"
  capacity = 21474836480  # 20 GB thin provisioned

  target = {
    format = { type = "qcow2" }
  }

  backing_store = {
    path   = libvirt_volume.ubuntu_base[each.key].path
    format = { type = "qcow2" }
  }
}

# Windows
resource "terraform_data" "windows_disk" {
  for_each = { for k, v in local.vms : k => v if !v.cloud_init }

  input = {
    name  = each.key
    image = each.value.image
  }

  provisioner "local-exec" {
    command = "sudo cp ${each.value.image} /var/lib/libvirt/images/${each.key}.qcow2"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "sudo rm -f /var/lib/libvirt/images/${self.input.name}.qcow2"
  }
}

# Win & Ubun
resource "libvirt_domain" "windows" {
  for_each = { for k, v in local.vms : k => v if v.uefi }

  name        = each.key
  memory      = each.value.memory
  memory_unit = "KiB"
  vcpu        = each.value.vcpu
  type        = "kvm"
  autostart   = true
  running     = true

  features = {
    acpi = true
    apic = {}
    smm  = { state = "on" }
  }

  os = {
    type             = "hvm"
    type_arch        = "x86_64"
    type_machine     = "q35"
    firmware         = "efi"
    loader           = each.value.loader
    loader_readonly  = "yes"
    loader_type      = "pflash"
    loader_format    = "raw"
    nv_ram = {
      nv_ram          = "/var/lib/libvirt/qemu/nvram/${each.key}_VARS.fd"
      template        = each.value.nvram_tmpl
      template_format = "raw"
      format          = "raw"
    }
    boot_devices = [{ dev = "hd" }]
  }

  devices = {
    disks = [{
      source = {
        file = {
          file = "/var/lib/libvirt/images/${each.key}.qcow2"
        }
      }
      driver = { type = "qcow2" }
      target = {
        dev = each.value.disk_dev
        bus = each.value.disk_bus
      }
    }]
    interfaces = [{
      model = { type = each.value.nic }
      source = {
        network = { network = libvirt_network.corp.name }
      }
    }]
    graphics = [{
      vnc = { auto_port = true }
    }]
    serials    = [{ type = "pty" }]
    consoles   = [{
      type   = "pty"
      target = { type = "serial", port = 0 }
    }]
  }

  depends_on = [terraform_data.windows_disk]
}

resource "libvirt_domain" "ubuntu" {
  for_each = { for k, v in local.vms : k => v if v.cloud_init }

  name        = each.key
  memory      = each.value.memory
  memory_unit = "KiB"
  vcpu        = each.value.vcpu
  type        = "kvm"
  autostart   = true
  running     = true

  features = {
    acpi = true
    apic = {}
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [{ dev = "hd" }]
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = "default"
            volume = libvirt_volume.vm_disk[each.key].name
          }
        }
        driver = { type = "qcow2" }
        target = {
          dev = each.value.disk_dev
          bus = each.value.disk_bus
        }
      },
      {
        source = {
          file = {
            file = libvirt_cloudinit_disk.init[each.key].path
          }
        }
        target = {
          dev = "sdb"
          bus = "sata"
        }
        device = "cdrom"
      }
    ]
    interfaces = [{
      model = { type = each.value.nic }
      source = {
        network = { network = libvirt_network.corp.name }
      }
    }]
    graphics = [{
      vnc = { auto_port = true }
    }]
    serials  = [{ type = "pty" }]
    consoles = [{
      type   = "pty"
      target = { type = "serial", port = 0 }
    }]
  }

  depends_on = [
    libvirt_volume.vm_disk,
    libvirt_cloudinit_disk.init
  ]
}

# Final
output "docker_services" {
  description = "Docker services deployed on the host"
  value = {
    for name, svc in var.services : name => {
      container = "${var.student_name}-${name}"
      image     = svc.image
      network   = "${var.student_name}-${svc.network}-net"
      ports     = [for p in svc.ports : "${p.external}->${p.internal}"]
    }
  }
}

output "kvm_vms" {
  description = "KVM virtual machines"
  value = {
    for name, vm in libvirt_domain.ubuntu : name => "ubuntu | ${vm.memory / 1024}MB | ${vm.vcpu} vCPU"
  }
  depends_on = [libvirt_domain.windows]
}

output "corp_network" {
  description = "KVM NAT network"
  value       = libvirt_network.corp.name
}
