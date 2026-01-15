terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "best-buy-rg"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.resource_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  node_resource_group = var.node_resource_group
  
  private_cluster_enabled = var.enable_private_cluster

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "masterpool"
    node_count = 1
    vm_size    = "Standard_D2as_v4"
  }

  role_based_access_control_enabled = var.enable_rbac

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.enable_aad_profile ? [1] : []
    content {
      managed                = true
      admin_group_object_ids = var.admin_group_object_ids
      azure_rbac_enabled     = var.azure_rbac
    }
  }

  network_profile {
    network_plugin      = var.network_plugin
    network_plugin_mode = var.network_plugin_mode
    network_data_plane   = var.network_data_plane
  }

  oidc_issuer_enabled       = var.enable_oidc_issuer
  workload_identity_enabled = var.enable_workload_identity
  
  image_cleaner_enabled        = var.image_cleaner_enabled
  image_cleaner_interval_hours = var.image_cleaner_interval_hours

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "workers" {
  name                  = "workerspool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D2as_v4"
  node_count            = 1
  mode                  = "User"
  
  tags = var.tags
}

output "control_plane_fqdn" {
  value = azurerm_kubernetes_cluster.aks.fqdn
}