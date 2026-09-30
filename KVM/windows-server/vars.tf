# Necessary Vars
variable "student_name" {
  type        = string
  description = "Your student identifier (e.g., jsmith, mgarcia)"
  validation {
    condition     = can(regex("^[a-z]{2,10}$", var.student_name))
    error_message = "Student name must be 2-10 lowercase letters."
  }
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 4
}

variable "ram_size" {
  description = "RAM in KiB (2097152 = 2 GB)"
  type        = number
  default     = 2097152
}

variable "image_path" {
  description = "URL or path to the qcow2 base image"
  type        = string
  default     = "/opt/images/win2k25.qcow2"
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "dc1"
}
