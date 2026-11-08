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

variable "aaaa_records" {
  description = <<-EOT
    Map of AAAA records to create in the zone, keyed by record name. Use "@" for the zone apex.
    Each entry must set exactly one of `records` (list of literal IPv6 addresses) or
    `target_resource_id` (an Azure Public IP, Traffic Manager profile or Front Door endpoint,
    creating an alias record set), the same as `a_records`.
  EOT
  type = map(object({
    ttl                = optional(number, 3600)
    records            = optional(list(string))
    target_resource_id = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.aaaa_records : (v.records == null) != (v.target_resource_id == null)
    ])
    error_message = "Each entry in aaaa_records must set exactly one of \"records\" or \"target_resource_id\"."
  }

  validation {
    condition = alltrue([
      for k, v in var.aaaa_records : length(v.records) > 0 if v.records != null
    ])
    error_message = "Entries in aaaa_records that set \"records\" must list at least one address; Azure DNS rejects an empty record set."
  }

  validation {
    condition     = alltrue([for k, v in var.aaaa_records : v.ttl >= 0 && v.ttl <= 2147483647])
    error_message = "Every ttl in aaaa_records must be between 0 and 2147483647 seconds."
  }
}

variable "mx_records" {
  description = <<-EOT
    Map of MX records to create in the zone, keyed by record name. Use "@" for the zone apex.
    Each record is a list of `{ preference, exchange }` objects; lower preference wins.
  EOT
  type = map(object({
    ttl = optional(number, 3600)
    records = list(object({
      preference = number
      exchange   = string
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.mx_records : length(v.records) > 0])
    error_message = "Every entry in mx_records must list at least one record; Azure DNS rejects an empty record set."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.mx_records : [
        for r in v.records : r.preference >= 0 && r.preference <= 65535 && floor(r.preference) == r.preference
      ]
    ]))
    error_message = "Every MX preference must be a whole number between 0 and 65535 (RFC 1035)."
  }

  validation {
    condition     = alltrue([for k, v in var.mx_records : v.ttl >= 0 && v.ttl <= 2147483647])
    error_message = "Every ttl in mx_records must be between 0 and 2147483647 seconds."
  }
}

variable "caa_records" {
  description = <<-EOT
    Map of CAA records to create in the zone, keyed by record name. Use "@" for the zone apex.
    Each record is a list of `{ flags, tag, value }` objects, e.g.
    `{ flags = 0, tag = "issue", value = "letsencrypt.org" }`. The provider accepts the tags
    "issue", "issuewild", "iodef" and "contactemail".
  EOT
  type = map(object({
    ttl = optional(number, 3600)
    records = list(object({
      flags = optional(number, 0)
      tag   = string
      value = string
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.caa_records : length(v.records) > 0])
    error_message = "Every entry in caa_records must list at least one record; Azure DNS rejects an empty record set."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.caa_records : [
        for r in v.records : r.flags >= 0 && r.flags <= 255 && floor(r.flags) == r.flags
      ]
    ]))
    error_message = "Every CAA flags value must be a whole number between 0 and 255 (RFC 8659)."
  }

  validation {
    condition     = alltrue([for k, v in var.caa_records : v.ttl >= 0 && v.ttl <= 2147483647])
    error_message = "Every ttl in caa_records must be between 0 and 2147483647 seconds."
  }
}

variable "srv_records" {
  description = <<-EOT
    Map of SRV records to create in the zone, keyed by record name in the form
    "_service._proto" (e.g. "_sip._tcp"). Each record is a list of
    `{ priority, weight, port, target }` objects.
  EOT
  type = map(object({
    ttl = optional(number, 3600)
    records = list(object({
      priority = number
      weight   = number
      port     = number
      target   = string
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.srv_records : length(v.records) > 0])
    error_message = "Every entry in srv_records must list at least one record; Azure DNS rejects an empty record set."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.srv_records : [
        for r in v.records : alltrue([
          for n in [r.priority, r.weight, r.port] : n >= 0 && n <= 65535 && floor(n) == n
        ])
      ]
    ]))
    error_message = "Every SRV priority, weight and port must be a whole number between 0 and 65535 (RFC 2782)."
  }

  validation {
    condition     = alltrue([for k, v in var.srv_records : v.ttl >= 0 && v.ttl <= 2147483647])
    error_message = "Every ttl in srv_records must be between 0 and 2147483647 seconds."
  }
}

variable "ns_records" {
  description = <<-EOT
    Map of NS records to create in the zone, keyed by record name, for delegating a subdomain
    to other name servers. Each record is a list of name server host names. The apex ("@") is
    rejected: Azure creates and manages the apex NS record set with the zone itself.
  EOT
  type = map(object({
    ttl     = optional(number, 3600)
    records = list(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for k in keys(var.ns_records) : k != "@" && k != ""])
    error_message = "ns_records cannot contain the zone apex (\"@\"): Azure creates the apex NS record set with the zone, so creating it again fails at apply time. Use ns_records only to delegate subdomains."
  }

  validation {
    condition     = alltrue([for k, v in var.ns_records : length(v.records) > 0])
    error_message = "Every entry in ns_records must list at least one name server; Azure DNS rejects an empty record set."
  }

  validation {
    condition     = alltrue([for k, v in var.ns_records : v.ttl >= 0 && v.ttl <= 2147483647])
    error_message = "Every ttl in ns_records must be between 0 and 2147483647 seconds."
  }
}

variable "tags" {
  description = "Map of tags applied to the DNS zone."
  type        = map(string)
  default     = {}
}
