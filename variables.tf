# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default = "West Europe"
}

variable "vm_number" {
  description = "The number of Virtual Machines to create"
}

variable "username" {
  description = "The username for the Virtual Machine Resources"
  default = "azureuser"
}

variable "password" {
  description = "The password used for the Virtual Machine Resources"
  default = "Testing.12345"
}