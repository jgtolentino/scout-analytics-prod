# Azure Key Vault for secrets management
resource "azurerm_key_vault" "main" {
  name                        = "${var.prefix}-kv-${random_id.keyvault.hex}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  sku_name                    = "premium"

  # Network access configuration
  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
  }

  tags = {
    Environment = var.environment
    Purpose     = "Secrets Management"
    Project     = "Scout Analytics"
  }
}

# Random ID for Key Vault name uniqueness
resource "random_id" "keyvault" {
  byte_length = 4
}

# Access policy for current user/service principal
resource "azurerm_key_vault_access_policy" "current" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
  ]

  certificate_permissions = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "ManageContacts", "ManageIssuers", "GetIssuers", "ListIssuers", "SetIssuers", "DeleteIssuers", "Purge"
  ]

  key_permissions = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "Decrypt", "Encrypt", "UnwrapKey", "WrapKey", "Verify", "Sign", "Purge"
  ]
}

# Access policy for AKS cluster
resource "azurerm_key_vault_access_policy" "aks" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_kubernetes_cluster.main.identity[0].tenant_id
  object_id    = azurerm_kubernetes_cluster.main.identity[0].principal_id

  secret_permissions = [
    "Get", "List"
  ]
}

# Access policy for AKS kubelet identity
resource "azurerm_key_vault_access_policy" "aks_kubelet" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_kubernetes_cluster.main.kubelet_identity[0].tenant_id
  object_id    = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id

  secret_permissions = [
    "Get", "List"
  ]
}

# Supabase/PostgreSQL connection secrets
resource "azurerm_key_vault_secret" "supabase_url" {
  name         = "supabase-url"
  value        = "postgresql://${var.postgres_admin}:${var.postgres_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/scoutdb?sslmode=require"
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "Database"
  }
}

resource "azurerm_key_vault_secret" "supabase_key" {
  name         = "supabase-key"
  value        = "your-supabase-service-role-key"  # Replace with actual value
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "Database"
  }
}

# Database credentials
resource "azurerm_key_vault_secret" "postgres_admin" {
  name         = "postgres-admin-username"
  value        = var.postgres_admin
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "Database"
  }
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-admin-password"
  value        = var.postgres_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "Database"
  }
}

# ADLS Gen2 access keys
resource "azurerm_key_vault_secret" "adls_key" {
  name         = "adls-access-key"
  value        = azurerm_storage_account.datalake.primary_access_key
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "Storage"
  }
}

resource "azurerm_key_vault_secret" "adls_connection_string" {
  name         = "adls-connection-string"
  value        = azurerm_storage_account.datalake.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "Storage"
  }
}

# Azure OpenAI secrets (placeholder)
resource "azurerm_key_vault_secret" "azure_openai_key" {
  name         = "azure-openai-key"
  value        = "your-azure-openai-key"  # Replace with actual value
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "AI"
  }
}

resource "azurerm_key_vault_secret" "azure_openai_endpoint" {
  name         = "azure-openai-endpoint"
  value        = "https://scout-openai.openai.azure.com/"  # Replace with actual endpoint
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "AI"
  }
}

# Application secrets
resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = random_password.jwt_secret.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "Application"
  }
}

resource "azurerm_key_vault_secret" "session_secret" {
  name         = "session-secret"
  value        = random_password.session_secret.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "Application"
  }
}

# Generate random passwords for application secrets
resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

resource "random_password" "session_secret" {
  length  = 64
  special = true
}

# Certificate for custom domain (if needed)
resource "azurerm_key_vault_certificate" "domain_cert" {
  name         = "scout-domain-cert"
  key_vault_id = azurerm_key_vault.main.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # Customize subject and subject alternative names
      subject            = "CN=${var.domain_name}"
      validity_in_months = 12

      subject_alternative_names {
        dns_names = [var.domain_name, "www.${var.domain_name}"]
      }
    }
  }

  depends_on = [azurerm_key_vault_access_policy.current]

  tags = {
    Environment = var.environment
    Service     = "SSL"
  }
}