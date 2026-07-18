variable "name" {
  description = "Name of the DNS zone (the fully qualified domain name, e.g. example.com)."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group in which to create the DNS zone."
  type        = string
}

variable "a_records" {
  description = "Map of A records to create in the zone, keyed by record name. Use \"@\" for the zone apex."
  type = map(object({
    ttl     = optional(number, 3600)
    records = list(string)
  }))
  default = {}
}

variable "cname_records" {
  description = "Map of CNAME records to create in the zone, keyed by record name."
  type = map(object({
    ttl    = optional(number, 3600)
    record = string
  }))
  default = {}
}

variable "txt_records" {
  description = "Map of TXT records to create in the zone, keyed by record name. Each record is a list of value strings."
  type = map(object({
    ttl     = optional(number, 3600)
    records = list(string)
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags applied to the DNS zone."
  type        = map(string)
  default     = {}
}
