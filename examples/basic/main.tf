terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0, < 6.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "example-rg"
  location = "westeurope"
}

# Public IP fronting a load balancer. The zone apex is aliased to it below, so the
# record follows the address instead of hard-coding it.
resource "azurerm_public_ip" "example" {
  name                = "example-lb"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

module "dns" {
  source = "../.."

  name                = "example.com"
  resource_group_name = azurerm_resource_group.example.name

  a_records = {
    # A CNAME is illegal at the apex, so an alias A record is how the bare domain
    # points at an Azure load balancer.
    "@" = {
      ttl                = 300
      target_resource_id = azurerm_public_ip.example.id
    }
    "www" = {
      records = ["203.0.113.11"]
    }
  }

  cname_records = {
    "docs" = {
      record = "www.example.com"
    }
  }

  txt_records = {
    "@" = {
      records = ["v=spf1 -all"]
    }
  }

  mx_records = {
    "@" = {
      records = [
        { preference = 10, exchange = "mx1.example.net" },
        { preference = 20, exchange = "mx2.example.net" },
      ]
    }
  }

  # Only this CA may issue certificates for the zone.
  caa_records = {
    "@" = {
      records = [
        { tag = "issue", value = "letsencrypt.org" },
        { tag = "iodef", value = "mailto:security@example.com" },
      ]
    }
  }

  # Hand the dev subdomain to another zone's name servers.
  ns_records = {
    "dev" = {
      records = ["ns1-01.azure-dns.com.", "ns2-01.azure-dns.net."]
    }
  }

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

output "zone_id" {
  value = module.dns.id
}

output "name_servers" {
  value = module.dns.name_servers
}
