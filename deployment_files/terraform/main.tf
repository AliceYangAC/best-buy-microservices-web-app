terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
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

  # kube_admin_config {
  #   client_certificate     = true
  #   client_key             = true
  #   cluster_ca_certificate = true
  # }

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
    network_data_plane  = var.network_data_plane
  }

  oidc_issuer_enabled       = var.enable_oidc_issuer
  workload_identity_enabled = var.enable_workload_identity
  
  image_cleaner_enabled        = var.image_cleaner_enabled
  image_cleaner_interval_hours = var.image_cleaner_interval_hours

  tags = var.tags
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_admin_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_admin_config[0].cluster_ca_certificate)

  # depends_on = [
  #   azurerm_kubernetes_cluster.aks
  # ]
}

resource "azurerm_kubernetes_cluster_node_pool" "workers" {
  name                  = "workerspool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D2as_v4"
  node_count            = 1
  mode                  = "User"
  
  tags = var.tags
}

resource "azurerm_servicebus_namespace" "sb" {
  name                = "${var.resource_name}-bus"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"

  tags = var.tags
}

resource "azurerm_servicebus_queue" "orders" {
  name         = "orders"
  namespace_id = azurerm_servicebus_namespace.sb.id
}

resource "azurerm_servicebus_queue" "shipping" {
  name         = "shipping"
  namespace_id = azurerm_servicebus_namespace.sb.id
}

resource "azurerm_storage_account" "sa" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}


resource "azurerm_storage_container" "product_images" {
  name                  = "product-images"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "product_images" {
  for_each = fileset("${path.module}/images", "*")

  name                   = each.value
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.product_images.name
  type                   = "Block"
  source                 = "${path.module}/images/${each.value}"
}

resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "${var.resource_name}-cosmos"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  enable_free_tier = true

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }

  tags = var.tags
}

resource "azurerm_cosmosdb_mongo_database" "productdb" {
  name                = "productdb"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

resource "kubernetes_secret" "best-buy-secrets" {
  # depends_on = [
  #   azurerm_kubernetes_cluster.aks,
  #   azurerm_servicebus_namespace.sb,
  #   azurerm_storage_account.sa,
  #   azurerm_cosmosdb_account.cosmos
  # ]

  metadata {
    name      = "best-buy-secrets"
    namespace = "default"
  }

  data = {
    ASB_CONNECTION_STRING  = base64encode(azurerm_servicebus_namespace.sb.default_primary_connection_string)
    BLOB_CONNECTION_STRING = base64encode(azurerm_storage_account.sa.primary_connection_string)
    MONGO_URI              = base64encode(azurerm_cosmosdb_account.cosmos.primary_mongodb_connection_string)
  }
}


