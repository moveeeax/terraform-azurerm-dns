# terraform-azurerm-dns

Terraform module that manages an [Azure](https://azure.microsoft.com/) public
DNS zone. It creates a single DNS zone and, optionally, sets of A, CNAME, and
TXT records driven by input maps, exposing the zone ID and its delegated name
servers.

## Usage

```hcl
module "dns" {
  source = "github.com/cybercapybara/terraform-azurerm-dns"

  name                = "example.com"
  resource_group_name = "prod-rg"

  a_records = {
    "@"   = { records = ["203.0.113.10"] }
    "www" = { records = ["203.0.113.11"] }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| azurerm   | >= 3.0   |

## Inputs

| Name                  | Description                                                                   | Type          | Default | Required |
|-----------------------|-------------------------------------------------------------------------------|---------------|---------|:--------:|
| `name`                | Name of the DNS zone (the fully qualified domain name).                        | `string`      | n/a     |   yes    |
| `resource_group_name` | Name of the resource group in which to create the DNS zone.                    | `string`      | n/a     |   yes    |
| `a_records`           | Map of A records keyed by record name. Use `@` for the zone apex.             | `map(object)` | `{}`    |    no    |
| `cname_records`       | Map of CNAME records keyed by record name.                                    | `map(object)` | `{}`    |    no    |
| `txt_records`         | Map of TXT records keyed by record name.                                      | `map(object)` | `{}`    |    no    |
| `tags`                | Map of tags applied to the DNS zone.                                          | `map(string)` | `{}`    |    no    |

## Outputs

| Name           | Description                                       |
|----------------|---------------------------------------------------|
| `id`           | ID of the DNS zone.                               |
| `name`         | Name of the DNS zone.                             |
| `name_servers` | Set of name servers hosting the DNS zone.         |

## License

[MIT](LICENSE)
