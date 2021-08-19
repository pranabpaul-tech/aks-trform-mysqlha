variable "subscription_id" {
  default = "118ae9f9-9038-414c-ba64-08c5056602d1"
}
variable "resource_group_name" {
  default = "aksbcdrrg"
}
variable "resource_group_location" {
  default = "North Europe"
}
variable "vnet_name" {
  default = "aksbcdrvnet"
}
variable "subnet_name" {
  default = "aksbcdrsubnet"
}
variable "acr_name" {
  default = "aksbcdracr"
}
variable "aks_name" {
  default = "aksbcdr"
}
variable "kubernetes_version" {
  default = "1.21.1"
}
variable "vm_size" {
  default = "Standard_D2_v2"
}
variable "azurerm_key_vault" {
  default = "aksbcdrkeyvault"
}