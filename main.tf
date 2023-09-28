# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "azurerm" {
  features {}
}

# Create the Resource group
resource "azurerm_resource_group" "Azuredevops" {
    name     = "Azuredevops"
    location = "westeurope"

    tags     = {
        application = "webserver"
    }
}

# Create the VNet and a subnet in it
resource "azurerm_virtual_network" "main" {
    name                = "${var.prefix}-network"
    address_space       = ["10.0.0.0/22"]
    location            = azurerm_resource_group.Azuredevops.location
    resource_group_name = azurerm_resource_group.Azuredevops.name

    tags = {
        environment = "Testing"
    }
}

resource "azurerm_subnet" "main" {
    name                 = "${var.prefix}-internal-subnet"
    resource_group_name  = azurerm_resource_group.Azuredevops.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes     = ["10.0.1.0/24"]
}

# Create a Network Security Group
# Allow access to other VMs and deny the direct access from the internet

resource "azurerm_network_security_group" "main" {
    name                = "${var.prefix}-nsg"
    location            = azurerm_resource_group.Azuredevops.location
    resource_group_name = azurerm_resource_group.Azuredevops.name

    security_rule {
        name                       = "Deny-Internet"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "Internet"
        destination_address_prefix = "10.0.1.0/24"
    }

    security_rule {
        name                       = "Allow-Inbound-Subnet"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "VirtualNetwork"
        destination_address_prefix = "VirtualNetwork"
    }

    security_rule {
        name                       = "Allow-Out-Subnet"
        priority                   = 120
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "10.0.1.0/24"
        destination_address_prefix = "10.0.1.0/24"
    }

    security_rule {
        name                       = "Allow-From-LB"
        priority                   = 130
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "80"
        destination_port_range     = "*"
        source_address_prefix      = "AzureLoadBalancer"
        destination_address_prefix = "10.0.1.0/24"
    }

    tags = {
        environment = "Testing"
    }

}


# Create a Public IP
resource "azurerm_public_ip" "main" {
    name                = "${var.prefix}-public-ip"
    resource_group_name = azurerm_resource_group.Azuredevops.name
    location            = azurerm_resource_group.Azuredevops.location
    allocation_method   = "Dynamic"

    tags = {
        environment = "Testing"
    }
}

# Create a Load Balancer
resource "azurerm_lb" "main" {
    name                = "${var.prefix}-lb"
    location            = azurerm_resource_group.Azuredevops.location
    resource_group_name = azurerm_resource_group.Azuredevops.name

    frontend_ip_configuration {
        name                 = "public-ip-address"
        public_ip_address_id = azurerm_public_ip.main.id
    }

    tags = {
        environment = "Testing"
    }
}

resource "azurerm_lb_backend_address_pool" "main" {
    name            = "${var.prefix}-backend-pool"
    loadbalancer_id = azurerm_lb.main.id
}

# Create NIC
resource "azurerm_network_interface" "main" {
    count               =  var.count
    name                = "${var.prefix}-nic-${count.index}"
    resource_group_name = azurerm_resource_group.Azuredevops.name
    location            = azurerm_resource_group.Azuredevops.location

    ip_configuration {
        name                          = "internal-ip-nic"
        subnet_id                     = azurerm_subnet.main.id
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "Testing"
    }
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
    count               =  var.count

    network_interface_id    = element(azurerm_network_interface.main[*].id, count.index)
    ip_configuration_name   = azurerm_network_interface.main[count.index].ip_configuration[0].name
    backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

# Availability Set
resource "azurerm_availability_set" "main" {
    name                = "${var.prefix}-av-set"
    location            = azurerm_resource_group.Azuredevops.location
    resource_group_name = azurerm_resource_group.Azuredevops.name

    tags = {
        environment = "Testing"
    }
}

# PackerImage

data "azurerm_image" "main" {
  name                = "myPackerImage"
  resource_group_name = azurerm_resource_group.Azuredevops.name
}

# VMs and managed disk
resource "azurerm_linux_virtual_machine" "main" {
    count = var.count
    name                            = "${var.prefix}-vm-${count.index}"
    resource_group_name             = azurerm_resource_group.Azuredevops.name
    location                        = azurerm_resource_group.Azuredevops.location
    size                            = "Standard_D2s_v3"
    admin_username                  = var.username
    admin_password                  = var.password
    disable_password_authentication = false
    network_interface_ids           = [element(azurerm_network_interface.main[*].id, count.index)]
    availability_set_id             = azurerm_availability_set.main.id

    source_image_id = data.azurerm_image.main.id

    os_disk {
        storage_account_type    = "Standard_LRS"
        caching                 = "ReadWrite"
    }

    tags = {
        project = "udacity"
    }
}