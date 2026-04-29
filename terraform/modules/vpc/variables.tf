variable "environment" {
  description = "Environment name."
  type        = string
}

variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use."
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "If true, create only one NAT gateway."
  type        = bool
  default     = true
}
