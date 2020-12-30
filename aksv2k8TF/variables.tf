variable rg_location {
  default = "westeurope"
}

variable aks_version {
  default = "1.16.15"
}

variable aks_node_count {
  default = 1
}

variable aks_vm_size {
  default = "Standard_D2_v2"
}

variable kv_csi_ns {
  default = "kv-csi"
}




variable "key_vault_name" {
  default     = "terraformclient"
  description = "The name of Key vault"
}