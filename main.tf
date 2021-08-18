####################
# Provider section #
####################
provider "azurerm" {
  version = ">= 2.45"
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}
provider "azuread" {
  version = ">= 1.4.0"
}

####################
# Data section #
####################
data "azurerm_client_config" "current" {}

#####################
# Resource section #
#####################
resource "azurerm_resource_group" "aks-bcdr" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_virtual_network" "aks-bcdr" {
  name                = var.vnet_name
  location            = azurerm_resource_group.aks-bcdr.location
  resource_group_name = azurerm_resource_group.aks-bcdr.name
  address_space       = ["10.0.0.0/16"]
  depends_on = [azurerm_resource_group.aks-bcdr]
}

resource "azurerm_subnet" "aks-bcdr" {
  name                 =  var.subnet_name
  resource_group_name  = azurerm_resource_group.aks-bcdr.name
  virtual_network_name = azurerm_virtual_network.aks-bcdr.name
  address_prefixes     = ["10.0.0.0/24"]
  depends_on = [azurerm_virtual_network.aks-bcdr]
}

resource "azurerm_container_registry" "aks-bcdr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.aks-bcdr.name
  location            = azurerm_resource_group.aks-bcdr.location
  sku                 = "Standard"
  admin_enabled       = false
  depends_on = [azurerm_resource_group.aks-bcdr]
}

resource "azurerm_kubernetes_cluster" "aks-bcdr" {
  name                = var.aks_name
  location            = azurerm_resource_group.aks-bcdr.location
  resource_group_name = azurerm_resource_group.aks-bcdr.name
  dns_prefix          = "aksbcdr"
  kubernetes_version = var.kubernetes_version
  depends_on = [azurerm_resource_group.aks-bcdr, azurerm_subnet.aks-bcdr]
  identity {
    type = "SystemAssigned"
  }
  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = var.vm_size
    availability_zones = [ "1", "2", "3" ]
    os_disk_size_gb = 128
    enable_node_public_ip = false
  }
  network_profile {
    load_balancer_sku  = "standard"
    outbound_type      = "loadBalancer"
    network_plugin     = "azure"
    network_policy     = "calico"
    dns_service_ip     = "10.1.0.10"
    docker_bridge_cidr = "172.17.0.1/24"
    service_cidr       = "10.1.0.0/24"
  }
}

resource "azurerm_key_vault" "aks-bcdr" {
  name                        = var.azurerm_key_vault
  location                    = azurerm_resource_group.aks-bcdr.location
  resource_group_name         = azurerm_resource_group.aks-bcdr.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  depends_on = [azurerm_resource_group.aks-bcdr, azurerm_kubernetes_cluster.aks-bcdr]
  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id    = data.azurerm_client_config.current.object_id

    key_permissions = [
      "create",
      "get",
    ]

    secret_permissions = [
      "set",
      "get",
      "delete",
      "purge",
      "recover"
    ]

    storage_permissions = [
      "Get",
    ]
  }
}

resource "azurerm_key_vault_access_policy" "aks-bcdr" {
  key_vault_id = azurerm_key_vault.aks-bcdr.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_kubernetes_cluster.aks-bcdr.kubelet_identity[0].object_id
  depends_on = [azurerm_key_vault.aks-bcdr]
  key_permissions = [
    "Get", "List",  
  ]

  secret_permissions = [
    "Get", "List", 
  ]
  storage_permissions = [
      "Get", "List",  
    ]
}
resource "azurerm_key_vault_secret" "aks-bcdr" {
  name         = "mysqlpass"
  value        = "Use3306Port"
  key_vault_id = azurerm_key_vault.aks-bcdr.id
  depends_on = [azurerm_key_vault.aks-bcdr]
}
resource "azurerm_role_assignment" "aks_acr" {
  scope                = azurerm_container_registry.aks-bcdr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks-bcdr.kubelet_identity[0].object_id
  depends_on = [azurerm_container_registry.aks-bcdr, azurerm_kubernetes_cluster.aks-bcdr]
}
resource "azurerm_role_assignment" "aks_subnet" {
  scope                = azurerm_subnet.aks-bcdr.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks-bcdr.identity[0].principal_id
  depends_on = [azurerm_subnet.aks-bcdr, azurerm_kubernetes_cluster.aks-bcdr]
}
