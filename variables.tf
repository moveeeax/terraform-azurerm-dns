variable "name" {
  description = "Name of the DNS zone (the fully qualified domain name, e.g. example.com)."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group in which to create the DNS zone."
  type        = string
}

variable "a_records" {
  description = <<-EOT
    Map of A records to create in the zone, keyed by record name. Use "@" for the zone apex.
    Each entry must set exactly one of:
      * `records`            - list of literal IPv4 addresses;
      * `target_resource_id` - resource ID of an Azure Public IP, Traffic Manager profile or
                               Front Door endpoint, which creates an Azure DNS *alias* record
                               set. This is the only way to point the zone apex at an Azure
                               load balancer, because a CNAME is not permitted at the apex.
  EOT
  type = map(object({
    ttl                = optional(number, 3600)
    records            = optional(list(string))
    target_resource_id = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.a_records : (v.records == null) != (v.target_resource_id == null)
    ])
    error_message = "Each entry in a_records must set exactly one of \"records\" or \"target_resource_id\"."
  }

  validation {
    condition = alltrue([
      for k, v in var.a_records : length(v.records) > 0 if v.records != null
    ])
    error_message = "Entries in a_records that set \"records\" must list at least one address; Azure DNS rejects an empty record set."
  }

  validation {
    condition     = alltrue([for k, v in var.a_records : v.ttl >= 0 && v.ttl <= 2147483647])
    error_message = "Every ttl in a_records must be between 0 and 2147483647 seconds."
  }
}

variable "cname_records" {
  description = <<-EOT
    Map of CNAME records to create in the zone, keyed by record name. Each entry must set
    exactly one of `record` (the literal canonical name) or `target_resource_id` (an Azure
    resource ID, creating an alias record set). A CNAME may not be created at the zone apex
    ("@") - use an `a_records` entry with `target_resource_id` there instead.
  EOT
  type = map(object({
    ttl                = optional(number, 3600)
    record             = optional(string)
    target_resource_id = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for k in keys(var.cname_records) : k != "@" && k != ""])
    error_message = "A CNAME record cannot exist at the zone apex (\"@\"): RFC 1034 forbids it and Azure DNS rejects it at apply time. Point the apex at an Azure resource with an a_records entry that sets target_resource_id."
  }

  validation {
    condition = alltrue([
      for k, v in var.cname_records : (v.record == null) != (v.target_resource_id == null)
    ])
    error_message = "Each entry in cname_records must set exactly one of \"record\" or \"target_resource_id\"."
  }

  validation {
    condition     = alltrue([for k, v in var.cname_records : v.ttl >= 0 && v.ttl <= 2147483647])
    error_message = "Every ttl in cname_records must be between 0 and 2147483647 seconds."
  }
}

variable "txt_records" {
  description = "Map of TXT records to create in the zone, keyed by record name. Each record is a list of value strings."
  type = map(object({
    ttl     = optional(number, 3600)
    records = list(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.txt_records : length(v.records) > 0])
    error_message = "Every entry in txt_records must list at least one value; Azure DNS rejects an empty record set."
  }

  validation {
    condition     = alltrue([for k, v in var.txt_records : v.ttl >= 0 && v.ttl <= 2147483647])
    error_message = "Every ttl in txt_records must be between 0 and 2147483647 seconds."
  }
}

variable "tags" {
  description = "Map of tags applied to the DNS zone."
  type        = map(string)
  default     = {}
}
