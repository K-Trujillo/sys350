# My varsss... ough my vars
# I copy and paste to save my precious tiiimee
variable "student_name" {
  type        = string
  description = "Your student identifier (e.g., jsmith, mgarcia)"

  validation {
    condition     = can(regex("^[a-z]{2,10}$", var.student_name))
    error_message = "Student name must be 2-10 lowercase letters."
  }
}

variable "web_port" {
  description = "Host port for the web server"
  type        = number
  default     = 8080
}

variable "mysql_root_password" {
  description = "MySQL root password"
  type        = string
  default     = "rootpassword"
  sensitive   = true
}

variable "mysql_database" {
  description = "MySQL database name"
  type        = string
  default     = "myapp"
}

variable "mysql_user" {
  description = "MySQL application user"
  type        = string
  default     = "appuser"
}

variable "mysql_password" {
  description = "MySQL application password"
  type        = string
  default     = "apppassword"
  sensitive   = true
}

variable "web_count" {
  description = "Number of web containers to deploy"
  type        = number
  default     = 1
}
