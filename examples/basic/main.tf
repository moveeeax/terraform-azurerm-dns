terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "dns" {
  source = "../.."

  name                = "example.com"
  resource_group_name = "example-rg"

  a_records = {
    "@" = {
      ttl     = 300
      records = ["10.10.0.4"]
    }
    "www" = {
      records = ["10.10.0.5"]
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
