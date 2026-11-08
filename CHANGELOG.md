# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `aaaa_records`, `mx_records`, `caa_records`, `srv_records` and `ns_records`
  inputs creating `azurerm_dns_aaaa_record`, `azurerm_dns_mx_record`,
  `azurerm_dns_caa_record`, `azurerm_dns_srv_record` and `azurerm_dns_ns_record`
  sets. All default to `{}`, so existing zones plan unchanged. AAAA records
  support alias record sets via `target_resource_id`, like A records.
- Plan-time checks: empty record lists, MX preference and SRV priority, weight
  and port outside 0-65535, CAA flags outside 0-255, and an NS record set at the
  zone apex (Azure already creates that one with the zone) are rejected.

## [1.1.0] - 2026-11-05

### Changed

- Bound `azurerm` to `>= 3.0, < 6.0` and test against the 3.0.0 floor in CI.
- CI: refresh actions and tool versions.

## [1.0.0] - 2026-07-26

Initial release with A, CNAME and TXT records, alias record sets via
`target_resource_id`, and plan-time rejection of a CNAME at the zone apex
(`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-azurerm-dns/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/moveeeax/terraform-azurerm-dns/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/moveeeax/terraform-azurerm-dns/releases/tag/v1.0.0
