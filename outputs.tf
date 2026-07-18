output "id" {
  description = "ID of the DNS zone."
  value       = azurerm_dns_zone.this.id
}

output "name" {
  description = "Name of the DNS zone."
  value       = azurerm_dns_zone.this.name
}

output "name_servers" {
  description = "Set of name servers hosting the DNS zone."
  value       = azurerm_dns_zone.this.name_servers
}
