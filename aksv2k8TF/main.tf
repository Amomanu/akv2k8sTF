provider "azurerm" {
  version = "=2.12.0"
  features {}
}

terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.9.4"
    }
  }
}

provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  load_config_file       = false
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  load_config_file       = false
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-eydev1"
  location = var.rg_location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-eydev1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kubernetes_version  = "1.16.13"
  dns_prefix          = "aks"

  default_node_pool {
    name       = "default"
    node_count = var.aks_node_count
    vm_size    = var.aks_vm_size
  }

  identity {
    type = "SystemAssigned"
  }
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
    username               = azurerm_kubernetes_cluster.aks.kube_config.0.username
    password               = azurerm_kubernetes_cluster.aks.kube_config.0.password
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  }
}

data "azurerm_resource_group" "aks_node_rg" {
  name = azurerm_kubernetes_cluster.aks.node_resource_group
}


data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

# Set permissions for currently logged-in Terraform SP to be able to read/modify secrets
resource "azurerm_key_vault_access_policy" "kv" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete"
  ]
}

resource "azurerm_role_assignment" "kv" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Reader"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id
  depends_on = [azurerm_kubernetes_cluster.aks,azurerm_key_vault_access_policy.aks]
}

resource "azurerm_key_vault_access_policy" "aks" {
  key_vault_id       = azurerm_key_vault.kv.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id
  secret_permissions = ["Get"]
  depends_on = [azurerm_kubernetes_cluster.aks,azurerm_key_vault_access_policy.aks]
}

resource "kubernetes_namespace" "aks" {
  metadata {
    annotations = {
      name = "aks-test"
    }

    labels = {
      azure-key-vault-env-injection = "enabled"
    }

     name = "aks-namespace"
  }
  depends_on = [azurerm_kubernetes_cluster.aks]
}



resource "kubectl_manifest" "Akv2k8sCRD" {                                #DefaultCRDs that need deployed
    yaml_body = "${file("AzureKeyVaultSecret.yaml")}"
    
 
}

resource "helm_release" "spv-charts" {
  name       = "akv2k8s"
  chart      = "./helms/akv2k8s-1.1.26.tgz"
  namespace        = "akv2k8s"
  create_namespace = true
  depends_on = [azurerm_kubernetes_cluster.aks]
  }



resource "azurerm_key_vault_secret" "demo" {
  name         = "ey-secret"
  value        = "ey-value"
  key_vault_id = azurerm_key_vault.kv.id

  # Must wait for Terraform SP policy to kick in before creating secrets
  depends_on = [azurerm_key_vault_access_policy.aks]
}

resource "kubectl_manifest" "Akv2k8sSecretSync" {
    yaml_body = "${file("akvs-secret-sync.yaml")}"
    depends_on = [azurerm_key_vault_secret.demo ,kubernetes_namespace.aks ]

    }

resource "kubectl_manifest" "Akv2k8sSecretInject" {
    yaml_body = "${file("akvs-secret-inject.yaml")}"
    depends_on = [azurerm_key_vault_secret.demo ,kubernetes_namespace.aks ]

    }    

resource "kubectl_manifest" "Akv2k8sSecretInjectDeploy" {
    yaml_body = "${file("secret-deployment.yaml")}" 
    depends_on = [kubectl_manifest.Akv2k8sSecretInject , kubernetes_namespace.aks ]

    }    