resource "azurerm_dns_zone" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_dns_a_record" "this" {
  for_each = var.a_records

  name                = each.key
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = var.resource_group_name
  ttl                 = each.value.ttl
  records             = each.value.records
  target_resource_id  = each.value.target_resource_id
}

resource "azurerm_dns_cname_record" "this" {
  for_each = var.cname_records

  name                = each.key
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = var.resource_group_name
  ttl                 = each.value.ttl
  record              = each.value.record
  target_resource_id  = each.value.target_resource_id
}

resource "azurerm_dns_txt_record" "this" {
  for_each = var.txt_records

  name                = each.key
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = var.resource_group_name
  ttl                 = each.value.ttl

  dynamic "record" {
    for_each = each.value.records
    content {
      value = record.value
    }
  }
}
