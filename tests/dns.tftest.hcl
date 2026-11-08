# Test-only requirement: `mock_provider` needs Terraform >= 1.7 / OpenTofu >= 1.7.
# The module itself still only requires >= 1.5, so consumers are unaffected.
mock_provider "azurerm" {}

variables {
  name                = "example.com"
  resource_group_name = "example-rg"
}

run "zone_defaults" {
  variables {
    tags = { ManagedBy = "terraform" }
  }

  assert {
    condition     = azurerm_dns_zone.this.name == "example.com"
    error_message = "The zone must be named after var.name."
  }

  assert {
    condition     = azurerm_dns_zone.this.tags["ManagedBy"] == "terraform"
    error_message = "var.tags must reach the DNS zone."
  }
}

run "record_ttl_defaults_to_one_hour" {
  variables {
    a_records = {
      "www" = { records = ["203.0.113.10"] }
    }
    cname_records = {
      "docs" = { record = "www.example.com" }
    }
    txt_records = {
      "@" = { records = ["v=spf1 -all"] }
    }
  }

  assert {
    condition     = azurerm_dns_a_record.this["www"].ttl == 3600
    error_message = "A records must default to a 3600s TTL."
  }

  assert {
    condition     = azurerm_dns_cname_record.this["docs"].ttl == 3600
    error_message = "CNAME records must default to a 3600s TTL."
  }

  assert {
    condition     = azurerm_dns_txt_record.this["@"].ttl == 3600
    error_message = "TXT records must default to a 3600s TTL."
  }

  assert {
    condition     = azurerm_dns_a_record.this["www"].zone_name == azurerm_dns_zone.this.name
    error_message = "Records must be attached to the zone this module creates."
  }
}

run "explicit_ttl_wins" {
  variables {
    a_records = {
      "www" = { ttl = 60, records = ["203.0.113.10", "203.0.113.11"] }
    }
  }

  assert {
    condition     = azurerm_dns_a_record.this["www"].ttl == 60
    error_message = "An explicit ttl must override the default."
  }

  assert {
    condition     = length(azurerm_dns_a_record.this["www"].records) == 2
    error_message = "All supplied addresses must be sent to the record set."
  }
}

# The zone apex cannot be a CNAME, so an alias A record is the only way to put an
# Azure load balancer / Front Door / Traffic Manager behind the bare domain.
run "apex_can_alias_an_azure_resource" {
  variables {
    a_records = {
      "@" = {
        target_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/publicIPAddresses/example-lb"
      }
    }
  }

  assert {
    condition     = azurerm_dns_a_record.this["@"].target_resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/publicIPAddresses/example-lb"
    error_message = "The apex A record must forward target_resource_id to create an alias record set."
  }

  assert {
    condition     = azurerm_dns_a_record.this["@"].records == null
    error_message = "An alias record set must not also send literal addresses."
  }
}

run "cname_can_alias_an_azure_resource" {
  variables {
    cname_records = {
      "cdn" = {
        target_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/trafficManagerProfiles/example"
      }
    }
  }

  assert {
    condition     = azurerm_dns_cname_record.this["cdn"].record == null
    error_message = "An alias CNAME must not also send a literal canonical name."
  }
}

run "rejects_cname_at_the_apex" {
  command = plan

  variables {
    cname_records = {
      "@" = { record = "www.example.com" }
    }
  }

  expect_failures = [var.cname_records]
}

run "rejects_a_record_with_both_records_and_alias" {
  command = plan

  variables {
    a_records = {
      "www" = {
        records            = ["203.0.113.10"]
        target_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/publicIPAddresses/example-lb"
      }
    }
  }

  expect_failures = [var.a_records]
}

run "rejects_a_record_with_neither_records_nor_alias" {
  command = plan

  variables {
    a_records = {
      "www" = { ttl = 300 }
    }
  }

  expect_failures = [var.a_records]
}

run "rejects_empty_a_record_list" {
  command = plan

  variables {
    a_records = {
      "www" = { records = [] }
    }
  }

  expect_failures = [var.a_records]
}

run "rejects_empty_txt_record_list" {
  command = plan

  variables {
    txt_records = {
      "@" = { records = [] }
    }
  }

  expect_failures = [var.txt_records]
}

run "rejects_negative_ttl" {
  command = plan

  variables {
    a_records = {
      "www" = { ttl = -1, records = ["203.0.113.10"] }
    }
  }

  expect_failures = [var.a_records]
}

run "defaults_create_no_new_record_types" {
  command = plan

  assert {
    condition = (
      length(azurerm_dns_aaaa_record.this) == 0 &&
      length(azurerm_dns_mx_record.this) == 0 &&
      length(azurerm_dns_caa_record.this) == 0 &&
      length(azurerm_dns_srv_record.this) == 0 &&
      length(azurerm_dns_ns_record.this) == 0
    )
    error_message = "Without the new inputs, no AAAA, MX, CAA, SRV or NS record sets may be planned."
  }
}

run "mail_ipv6_caa_srv_and_delegation" {
  variables {
    aaaa_records = {
      "www" = { records = ["2001:db8::10"] }
    }
    mx_records = {
      "@" = {
        records = [
          { preference = 10, exchange = "mx1.example.net" },
          { preference = 20, exchange = "mx2.example.net" },
        ]
      }
    }
    caa_records = {
      "@" = {
        ttl = 300
        records = [
          { tag = "issue", value = "letsencrypt.org" },
          { flags = 0, tag = "iodef", value = "mailto:security@example.com" },
        ]
      }
    }
    srv_records = {
      "_sip._tcp" = {
        records = [{ priority = 10, weight = 60, port = 5060, target = "sip.example.com" }]
      }
    }
    ns_records = {
      "dev" = { records = ["ns1.example.net", "ns2.example.net"] }
    }
  }

  assert {
    condition     = azurerm_dns_aaaa_record.this["www"].ttl == 3600 && length(azurerm_dns_aaaa_record.this["www"].records) == 1
    error_message = "AAAA records must default to a 3600s TTL and send the supplied addresses."
  }

  assert {
    condition     = azurerm_dns_mx_record.this["@"].name == "@" && length(azurerm_dns_mx_record.this["@"].record) == 2
    error_message = "MX records must keep their name and send every exchange."
  }

  assert {
    condition     = contains([for r in azurerm_dns_mx_record.this["@"].record : r.preference], "10")
    error_message = "MX preference must be passed to the provider as a string."
  }

  assert {
    condition     = azurerm_dns_caa_record.this["@"].ttl == 300 && length(azurerm_dns_caa_record.this["@"].record) == 2
    error_message = "CAA records must honour ttl and send every record."
  }

  assert {
    condition     = alltrue([for r in azurerm_dns_caa_record.this["@"].record : r.flags == 0])
    error_message = "CAA flags must default to 0."
  }

  assert {
    condition     = one(azurerm_dns_srv_record.this["_sip._tcp"].record).port == 5060
    error_message = "SRV records must send the port."
  }

  assert {
    condition     = azurerm_dns_ns_record.this["dev"].records == tolist(["ns1.example.net", "ns2.example.net"])
    error_message = "NS records must delegate to the supplied name servers in order."
  }

  assert {
    condition     = azurerm_dns_ns_record.this["dev"].zone_name == azurerm_dns_zone.this.name
    error_message = "New record types must be attached to the zone this module creates."
  }
}

run "aaaa_apex_can_alias_an_azure_resource" {
  variables {
    aaaa_records = {
      "@" = {
        target_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/publicIPAddresses/example-lb-v6"
      }
    }
  }

  assert {
    condition     = azurerm_dns_aaaa_record.this["@"].records == null
    error_message = "An alias AAAA record set must not also send literal addresses."
  }
}

run "rejects_aaaa_record_with_both_records_and_alias" {
  command = plan

  variables {
    aaaa_records = {
      "www" = {
        records            = ["2001:db8::10"]
        target_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Network/publicIPAddresses/example-lb-v6"
      }
    }
  }

  expect_failures = [var.aaaa_records]
}

run "rejects_empty_aaaa_record_list" {
  command = plan

  variables {
    aaaa_records = {
      "www" = { records = [] }
    }
  }

  expect_failures = [var.aaaa_records]
}

run "rejects_empty_mx_record_list" {
  command = plan

  variables {
    mx_records = {
      "@" = { records = [] }
    }
  }

  expect_failures = [var.mx_records]
}

run "rejects_out_of_range_mx_preference" {
  command = plan

  variables {
    mx_records = {
      "@" = { records = [{ preference = 70000, exchange = "mx1.example.net" }] }
    }
  }

  expect_failures = [var.mx_records]
}

run "rejects_empty_caa_record_list" {
  command = plan

  variables {
    caa_records = {
      "@" = { records = [] }
    }
  }

  expect_failures = [var.caa_records]
}

run "rejects_out_of_range_caa_flags" {
  command = plan

  variables {
    caa_records = {
      "@" = { records = [{ flags = 256, tag = "issue", value = "letsencrypt.org" }] }
    }
  }

  expect_failures = [var.caa_records]
}

run "rejects_empty_srv_record_list" {
  command = plan

  variables {
    srv_records = {
      "_sip._tcp" = { records = [] }
    }
  }

  expect_failures = [var.srv_records]
}

run "rejects_out_of_range_srv_port" {
  command = plan

  variables {
    srv_records = {
      "_sip._tcp" = { records = [{ priority = 10, weight = 60, port = 65536, target = "sip.example.com" }] }
    }
  }

  expect_failures = [var.srv_records]
}

run "rejects_ns_record_at_the_apex" {
  command = plan

  variables {
    ns_records = {
      "@" = { records = ["ns1.example.net"] }
    }
  }

  expect_failures = [var.ns_records]
}

run "rejects_empty_ns_record_list" {
  command = plan

  variables {
    ns_records = {
      "dev" = { records = [] }
    }
  }

  expect_failures = [var.ns_records]
}

run "rejects_negative_ttl_on_new_record_types" {
  command = plan

  variables {
    srv_records = {
      "_sip._tcp" = { ttl = -1, records = [{ priority = 10, weight = 60, port = 5060, target = "sip.example.com" }] }
    }
  }

  expect_failures = [var.srv_records]
}
