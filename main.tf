terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# HIER ERSETZT: Erlaubt Terraform das Löschen der feststeckenden Ressourcengruppe
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# 1. Ressourcengruppe
resource "azurerm_resource_group" "asr_test" {
  name     = "rg-asr-test-linkedin-v2" # HIER -v2 HINZUGEFÜGT
  location = "northeurope"
}

# 2. Netzwerk (VNet und Subnetze)
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-asr-test"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.asr_test.location
  resource_group_name = azurerm_resource_group.asr_test.name
}

# Subnetz für die VM
resource "azurerm_subnet" "subnet_vm" {
  name                 = "internal-vm-subnet"
  resource_group_name  = azurerm_resource_group.asr_test.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# ZWINGEND: Subnetz für Azure Bastion (Muss genau so heißen!)
resource "azurerm_subnet" "subnet_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.asr_test.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/26"]
}

# 3. Öffentliche IP für Azure Bastion (Standard-SKU erforderlich)
resource "azurerm_public_ip" "bastion_pip" {
  name                = "pip-bastion"
  location            = azurerm_resource_group.asr_test.location
  resource_group_name = azurerm_resource_group.asr_test.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 4. Azure Bastion Host (Günstiges Developer SKU benötigt KEINE IP-Konfiguration!)
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-asr-test"
  location            = azurerm_resource_group.asr_test.location
  resource_group_name = azurerm_resource_group.asr_test.name
  sku                 = "Developer" 
  virtual_network_id  = azurerm_virtual_network.vnet.id
}


# 5. Netzwerkkarte für die VM (Keine öffentliche IP mehr!)
resource "azurerm_network_interface" "nic" {
  name                = "nic-asr-vm"
  location            = azurerm_resource_group.asr_test.location
  resource_group_name = azurerm_resource_group.asr_test.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

# 6. Unabhängige Test-Festplatte (Umgeht alle Azure Compute-Kapazitätssperren!)
resource "azurerm_managed_disk" "test_disk" {
  name                 = "disk-asr-source-linkedin"
  location             = azurerm_resource_group.asr_test.location
  resource_group_name  = azurerm_resource_group.asr_test.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
}



# 7. Recovery Services Tresor
resource "azurerm_recovery_services_vault" "vault" {
  name                = "vault-asr-linkedin"
  location            = azurerm_resource_group.asr_test.location
  resource_group_name = azurerm_resource_group.asr_test.name
  sku                 = "Standard"
  # Die Zeile soft_delete_enabled wurde hier entfernt
}

# 8. Cache-Speicherkonto für ASR
resource "azurerm_storage_account" "cache_storage" {
  name                     = "stasrcachelinkedinv2" # HIER v2 HINZUGEFÜGT
  resource_group_name      = azurerm_resource_group.asr_test.name
  location                 = azurerm_resource_group.asr_test.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
