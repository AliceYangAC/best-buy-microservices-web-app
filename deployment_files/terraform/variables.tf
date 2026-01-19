variable "resource_name" {
  type    = string
  default = "best-buy-aks-cluster"
}

variable "location" {
  type    = string
  default = "canadacentral"
}

variable "kubernetes_version" {
  type    = string
  default = "1.32.9"
}

variable "dns_prefix" {
  type    = string
  default = "best-buy-aks-cluster-dns"
}

variable "sku_tier" {
  type    = string
  default = "Free" 
}

variable "node_resource_group" {
  type    = string
  default = "best-buy-aks-cluster-nodes-rg"
}

variable "admin_group_object_ids" {
  type    = list(string)
  default = []
}

variable "enable_rbac" {
  type    = bool
  default = true
}

variable "azure_rbac" {
  type    = bool
  default = false
}

variable "enable_aad_profile" {
  type    = bool
  default = false
}

variable "enable_private_cluster" {
  type    = bool
  default = false
}

variable "network_plugin" {
  type    = string
  default = "azure"
}

variable "network_plugin_mode" {
  type    = string
  default = "overlay"
}

variable "network_data_plane" {
  type    = string
  default = "azure"
}

variable "enable_oidc_issuer" {
  type    = bool
  default = true
}

variable "enable_workload_identity" {
  type    = bool
  default = true
}

variable "image_cleaner_enabled" {
  type    = bool
  default = true
}

variable "image_cleaner_interval_hours" {
  type    = number
  default = 168
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_cosmos_free_tier" {
  type    = bool
  default = true
}

variable "storage_account_name" {
  type    = string
  default = "bestbuystorageacct"
}

