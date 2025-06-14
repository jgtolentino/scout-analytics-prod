output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "frontdoor_endpoint" {
  description = "Front Door endpoint URL"
  value       = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "custom_domain" {
  description = "Custom domain name"
  value       = azurerm_cdn_frontdoor_custom_domain.main.host_name
}

output "postgres_host" {
  description = "PostgreSQL server FQDN"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgres_database" {
  description = "PostgreSQL database name"
  value       = azurerm_postgresql_flexible_server_database.scout.name
}

output "adls_endpoint" {
  description = "ADLS Gen2 primary DFS endpoint"
  value       = azurerm_storage_account.datalake.primary_dfs_endpoint
}

output "adls_name" {
  description = "ADLS Gen2 storage account name"
  value       = azurerm_storage_account.datalake.name
}

output "adls_filesystem" {
  description = "ADLS Gen2 filesystem name"
  value       = azurerm_storage_data_lake_gen2_filesystem.scout.name
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_fqdn" {
  description = "AKS cluster FQDN"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_kube_config" {
  description = "AKS kubeconfig command"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
  sensitive   = false
}

output "container_registry_name" {
  description = "Azure Container Registry name"
  value       = azurerm_container_registry.main.name
}

output "container_registry_login_server" {
  description = "Azure Container Registry login server"
  value       = azurerm_container_registry.main.login_server
}

output "keyvault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "keyvault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "application_gateway_ip" {
  description = "Application Gateway public IP"
  value       = azurerm_public_ip.appgw.ip_address
}

output "application_gateway_fqdn" {
  description = "Application Gateway FQDN"
  value       = azurerm_public_ip.appgw.fqdn
}

# Azure AD Application outputs
output "azure_ad_application_id" {
  description = "Azure AD application (client) ID"
  value       = azuread_application.scout.application_id
}

output "azure_ad_tenant_id" {
  description = "Azure AD tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

# Service principal outputs
output "service_principal_object_id" {
  description = "Service principal object ID"
  value       = azuread_service_principal.scout.object_id
}

# AKS identity outputs
output "aks_identity_principal_id" {
  description = "AKS cluster identity principal ID"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

output "aks_kubelet_identity_object_id" {
  description = "AKS kubelet identity object ID"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# Workload identity outputs
output "workload_identity_client_id" {
  description = "Workload identity client ID"
  value       = azurerm_user_assigned_identity.scout_workload.client_id
}

# Network outputs
output "virtual_network_name" {
  description = "Virtual network name"
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "AKS subnet ID"
  value       = azurerm_subnet.aks.id
}

output "postgres_subnet_id" {
  description = "PostgreSQL subnet ID"
  value       = azurerm_subnet.postgres.id
}

# Connection strings and URLs (for application configuration)
output "connection_strings" {
  description = "Application connection strings and URLs"
  value = {
    postgres_url        = "postgresql://${var.postgres_admin}@${azurerm_postgresql_flexible_server.main.name}:${azurerm_postgresql_flexible_server.main.fqdn}:5432/scoutdb?sslmode=require"
    adls_url           = azurerm_storage_account.datalake.primary_dfs_endpoint
    keyvault_url       = azurerm_key_vault.main.vault_uri
    app_gateway_url    = "https://${azurerm_public_ip.appgw.fqdn}"
    frontdoor_url      = "https://${azurerm_cdn_frontdoor_endpoint.main.host_name}"
    custom_domain_url  = "https://${azurerm_cdn_frontdoor_custom_domain.main.host_name}"
  }
  sensitive = false
}

# Environment variables for applications
output "environment_variables" {
  description = "Environment variables for Scout Analytics applications"
  value = {
    AZURE_TENANT_ID                = data.azurerm_client_config.current.tenant_id
    AZURE_CLIENT_ID                = azuread_application.scout.application_id
    POSTGRES_HOST                  = azurerm_postgresql_flexible_server.main.fqdn
    POSTGRES_DB                    = azurerm_postgresql_flexible_server_database.scout.name
    POSTGRES_PORT                  = "5432"
    POSTGRES_SSL                   = "require"
    ADLS_ACCOUNT_NAME             = azurerm_storage_account.datalake.name
    ADLS_FILESYSTEM_NAME          = azurerm_storage_data_lake_gen2_filesystem.scout.name
    KEYVAULT_NAME                 = azurerm_key_vault.main.name
    LOG_ANALYTICS_WORKSPACE_ID    = azurerm_log_analytics_workspace.main.workspace_id
    ACR_LOGIN_SERVER              = azurerm_container_registry.main.login_server
    WORKLOAD_IDENTITY_CLIENT_ID   = azurerm_user_assigned_identity.scout_workload.client_id
    FRONTDOOR_ENDPOINT            = azurerm_cdn_frontdoor_endpoint.main.host_name
    CUSTOM_DOMAIN                 = azurerm_cdn_frontdoor_custom_domain.main.host_name
  }
  sensitive = false
}

# Deployment commands
output "deployment_commands" {
  description = "Commands for deploying Scout Analytics"
  value = {
    connect_to_aks     = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
    login_to_acr       = "az acr login --name ${azurerm_container_registry.main.name}"
    build_and_push_cmd = "docker build -t ${azurerm_container_registry.main.login_server}/scout-dashboard:latest . && docker push ${azurerm_container_registry.main.login_server}/scout-dashboard:latest"
    view_logs          = "az monitor log-analytics query --workspace ${azurerm_log_analytics_workspace.main.workspace_id} --analytics-query 'ContainerLog | limit 100'"
    access_keyvault    = "az keyvault secret show --vault-name ${azurerm_key_vault.main.name} --name supabase-url"
  }
  sensitive = false
}

# Monitoring and troubleshooting URLs
output "monitoring_urls" {
  description = "URLs for monitoring and troubleshooting"
  value = {
    azure_portal_rg          = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}"
    aks_workbooks           = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.ContainerService/managedClusters/${azurerm_kubernetes_cluster.main.name}/workbooks"
    log_analytics_workspace = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.OperationalInsights/workspaces/${azurerm_log_analytics_workspace.main.name}"
    frontdoor_analytics     = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.Cdn/profiles/${azurerm_cdn_frontdoor_profile.main.name}/analytics"
    postgres_metrics        = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.DBforPostgreSQL/flexibleServers/${azurerm_postgresql_flexible_server.main.name}/metrics"
  }
  sensitive = false
}