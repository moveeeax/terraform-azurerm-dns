# terraform-azurerm-dns

Terraform module that manages an [Azure](https://azure.microsoft.com/) public
DNS zone. It creates a single DNS zone and, optionally, sets of A, AAAA, CNAME,
TXT, MX, CAA, SRV and NS records driven by input maps, exposing the zone ID and its delegated name
servers.

## Usage

```hcl
module "dns" {
  source = "github.com/moveeeax/terraform-azurerm-dns?ref=v1.0.0"

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

### Pointing the zone apex at an Azure resource

DNS forbids a CNAME at the zone apex, so the bare domain cannot be a CNAME to a
load balancer. Azure solves this with *alias record sets*: set
`target_resource_id` instead of `records` and Azure resolves the record to the
target's current address and tracks it as the target changes.

```hcl
module "dns" {
  source = "github.com/moveeeax/terraform-azurerm-dns?ref=v1.0.0"

  name                = "example.com"
  resource_group_name = "prod-rg"

  a_records = {
    # apex -> public IP of a load balancer / Front Door / Traffic Manager profile
    "@" = { target_resource_id = azurerm_public_ip.lb.id }
  }

  cname_records = {
    # non-apex names may alias too
    "cdn" = { target_resource_id = azurerm_traffic_manager_profile.cdn.id }
  }
}
```

Each `a_records` entry must set exactly one of `records` or
`target_resource_id`; each `cname_records` entry exactly one of `record` or
`target_resource_id`. Supplying `@` as a `cname_records` key is rejected at plan
time rather than failing part-way through an apply.

### Mail, CAA, SRV and subdomain delegation

```hcl
module "dns" {
  source = "github.com/moveeeax/terraform-azurerm-dns?ref=v1.0.0"

  name                = "example.com"
  resource_group_name = "prod-rg"

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
      records = [
        { tag = "issue", value = "letsencrypt.org" }, # flags defaults to 0
        { tag = "iodef", value = "mailto:security@example.com" },
      ]
    }
  }

  srv_records = {
    "_sip._tcp" = {
      records = [{ priority = 10, weight = 60, port = 5060, target = "sip.example.com" }]
    }
  }

  # Delegate dev.example.com to another zone, e.g. a child module's name_servers output.
  ns_records = {
    "dev" = { records = module.dev_dns.name_servers }
  }
}
```

Recommended for most zones: one `caa_records` entry at `@` listing the CAs you
actually use, so no other CA may issue certificates for the domain. The module
does not create one by default, so upgrading never adds records to an existing
zone.

`aaaa_records` accepts `target_resource_id` alias record sets exactly like
`a_records`. `ns_records` rejects `@`: Azure creates the apex NS record set with
the zone, so a second one fails at apply time. MX preference, SRV priority,
weight and port are checked against 0-65535 and CAA flags against 0-255 at plan
time.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| azurerm   | >= 3.0, < 6.0 |

CI validates and tests the module against the 3.0.0 floor and the latest 5.x
release. 6.x is excluded until it has been tested.

## Inputs

| Name                  | Description                                                                   | Type          | Default | Required |
|-----------------------|-------------------------------------------------------------------------------|---------------|---------|:--------:|
| `name`                | Name of the DNS zone (the fully qualified domain name).                        | `string`      | n/a     |   yes    |
| `resource_group_name` | Name of the resource group in which to create the DNS zone.                    | `string`      | n/a     |   yes    |
| `a_records`           | Map of A records keyed by record name. Use `@` for the zone apex.             | `map(object)` | `{}`    |    no    |
| `cname_records`       | Map of CNAME records keyed by record name. `@` is rejected.                   | `map(object)` | `{}`    |    no    |
| `txt_records`         | Map of TXT records keyed by record name.                                      | `map(object)` | `{}`    |    no    |
| `aaaa_records`        | Map of AAAA records keyed by record name. Use `@` for the zone apex.          | `map(object)` | `{}`    |    no    |
| `mx_records`          | Map of MX records keyed by record name.                                       | `map(object)` | `{}`    |    no    |
| `caa_records`         | Map of CAA records keyed by record name.                                      | `map(object)` | `{}`    |    no    |
| `srv_records`         | Map of SRV records keyed by `_service._proto`.                                | `map(object)` | `{}`    |    no    |
| `ns_records`          | Map of NS records for subdomain delegation. `@` is rejected.                  | `map(object)` | `{}`    |    no    |
| `tags`                | Map of tags applied to the DNS zone.                                          | `map(string)` | `{}`    |    no    |

Record map value shapes (`ttl` defaults to `3600` everywhere):

| Variable        | Attributes                                                       |
|-----------------|------------------------------------------------------------------|
| `a_records`     | `ttl`, `records` (list of IPv4), `target_resource_id` — exactly one of the latter two |
| `cname_records` | `ttl`, `record` (string), `target_resource_id` — exactly one of the latter two        |
| `txt_records`   | `ttl`, `records` (list of TXT values, at least one)               |
| `aaaa_records`  | `ttl`, `records` (list of IPv6), `target_resource_id`; exactly one of the latter two |
| `mx_records`    | `ttl`, `records` (list of `{ preference, exchange }`, at least one) |
| `caa_records`   | `ttl`, `records` (list of `{ flags = 0, tag, value }`, at least one) |
| `srv_records`   | `ttl`, `records` (list of `{ priority, weight, port, target }`, at least one) |
| `ns_records`    | `ttl`, `records` (list of name server host names, at least one)  |

## Outputs

| Name           | Description                                       |
|----------------|---------------------------------------------------|
| `id`           | ID of the DNS zone.                               |
| `name`         | Name of the DNS zone.                             |
| `name_servers` | Set of name servers hosting the DNS zone.         |

## Tests

```sh
terraform init -backend=false
terraform test
```

The suite in [`tests/`](tests) uses `mock_provider`, so it needs no Azure
credentials and no network access. It requires Terraform/OpenTofu >= 1.7; the
module itself still only requires >= 1.5.

## License

[MIT](LICENSE)
