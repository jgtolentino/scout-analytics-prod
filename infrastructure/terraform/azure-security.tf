# Azure AD Application for Scout Analytics
resource "azuread_application" "scout" {
  display_name = "scout-analytics-${var.environment}"
  owners       = [data.azurerm_client_config.current.object_id]

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }

  web {
    homepage_url  = "https://${var.domain_name}"
    redirect_uris = ["https://${var.domain_name}/auth/callback"]

    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  tags = ["scout-analytics", var.environment]
}

# Service Principal for the application
resource "azuread_service_principal" "scout" {
  application_id               = azuread_application.scout.application_id
  app_role_assignment_required = false
  owners                       = [data.azurerm_client_config.current.object_id]

  tags = ["scout-analytics", var.environment]
}

# Application secret
resource "azuread_application_password" "scout" {
  application_object_id = azuread_application.scout.object_id
  display_name          = "Scout Analytics Secret"
  end_date_relative     = "8760h" # 1 year
}

# Store the application secret in Key Vault
resource "azurerm_key_vault_secret" "azure_ad_client_secret" {
  name         = "azure-ad-client-secret"
  value        = azuread_application_password.scout.value
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "Authentication"
  }
}

# Store the application ID in Key Vault
resource "azurerm_key_vault_secret" "azure_ad_client_id" {
  name         = "azure-ad-client-id"
  value        = azuread_application.scout.application_id
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "Authentication"
  }
}

# RBAC assignments for AKS to access resources
resource "azurerm_role_assignment" "aks_to_adls" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "aks_to_keyvault" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "aks_to_postgres" {
  scope                = azurerm_postgresql_flexible_server.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "aks_to_acr" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# Service principal RBAC assignments
resource "azurerm_role_assignment" "scout_to_postgres" {
  scope                = azurerm_postgresql_flexible_server.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.scout.object_id
}

resource "azurerm_role_assignment" "scout_to_adls" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azuread_service_principal.scout.object_id
}

# User-assigned managed identity for workload identity
resource "azurerm_user_assigned_identity" "scout_workload" {
  location            = azurerm_resource_group.main.location
  name                = "${var.prefix}-workload-identity"
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
    Purpose     = "Workload Identity"
  }
}

# Federated identity credential for workload identity
resource "azuread_application_federated_identity_credential" "scout_workload" {
  application_object_id = azuread_application.scout.object_id
  display_name          = "scout-workload-identity"
  description           = "Workload identity for Scout Analytics pods"
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject               = "system:serviceaccount:scout:scout-workload-identity"
}

# Security Center (Defender for Cloud) configuration
resource "azurerm_security_center_subscription_pricing" "vm" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "kubernetes" {
  tier          = "Standard"
  resource_type = "KubernetesService"
}

resource "azurerm_security_center_subscription_pricing" "databases" {
  tier          = "Standard"
  resource_type = "SqlServers"
}

resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "ContainerRegistry"
}

# Azure Policy assignments for compliance
resource "azurerm_resource_group_policy_assignment" "kubernetes_cluster_pod_security" {
  name                 = "kubernetes-cluster-pod-security"
  resource_group_id    = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/233a2a17-77ca-4fb1-9b6b-69223d272a44"
  
  parameters = jsonencode({
    effect = {
      value = "audit"
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "storage_account_https" {
  name                 = "storage-account-https"
  resource_group_id    = azurerm_resource_group.main.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
  
  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}

# Network Security Group rules for additional security
resource "azurerm_network_security_rule" "deny_internet_inbound" {
  name                        = "DenyInternetInbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.aks.name
}

# Private DNS zone for Key Vault
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "keyvault-vnet-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

# Private endpoint for Key Vault
resource "azurerm_private_endpoint" "keyvault" {
  name                = "${var.prefix}-kv-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.aks.id

  private_service_connection {
    name                           = "${var.prefix}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }

  tags = {
    Environment = var.environment
  }
}

# Azure Monitor Private Link Scope for secure monitoring
resource "azurerm_monitor_private_link_scope" "main" {
  name                = "${var.prefix}-ampls"
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_monitor_private_link_scoped_service" "logs" {
  name                = "${var.prefix}-logs-pls"
  resource_group_name = azurerm_resource_group.main.name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = azurerm_log_analytics_workspace.main.id
}