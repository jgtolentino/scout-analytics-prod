# ADLS Gen2 Storage Account for Scout Analytics Data Lake
resource "azurerm_storage_account" "datalake" {
  name                     = var.adls_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true  # Hierarchical namespace for Data Lake

  # Enhanced security settings
  min_tls_version                = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled      = true

  # Network access rules
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [
      azurerm_subnet.aks.id,
      azurerm_subnet.postgres.id
    ]
  }

  # Blob properties for lifecycle management
  blob_properties {
    versioning_enabled       = true
    change_feed_enabled      = true
    change_feed_retention_in_days = 7
    
    delete_retention_policy {
      days = 30
    }
    
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = {
    Environment = var.environment
    Purpose     = "Data Lake"
    Project     = "Scout Analytics"
  }
}

# Data Lake Gen2 filesystem for Scout Analytics
resource "azurerm_storage_data_lake_gen2_filesystem" "scout" {
  name               = "scout-data"
  storage_account_id = azurerm_storage_account.datalake.id

  properties = {
    description = "Scout Analytics primary data filesystem"
  }
}

# Container for data exports
resource "azurerm_storage_container" "exports" {
  name                  = "exports"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}

# Container for raw data ingestion
resource "azurerm_storage_container" "raw_data" {
  name                  = "raw-data"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}

# Container for processed analytics data
resource "azurerm_storage_container" "analytics" {
  name                  = "analytics"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}

# Container for ML models and artifacts
resource "azurerm_storage_container" "ml_models" {
  name                  = "ml-models"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}

# Lifecycle management policy
resource "azurerm_storage_management_policy" "datalake" {
  storage_account_id = azurerm_storage_account.datalake.id

  rule {
    name    = "lifecycle_rule"
    enabled = true
    
    filters {
      prefix_match = ["raw-data/"]
      blob_types   = ["blockBlob"]
    }
    
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }
      
      snapshot {
        delete_after_days_since_creation_greater_than = 90
      }
      
      version {
        delete_after_days_since_creation = 30
      }
    }
  }
}

# Private endpoint for secure access
resource "azurerm_private_endpoint" "datalake" {
  name                = "${var.prefix}-adls-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.aks.id

  private_service_connection {
    name                           = "${var.prefix}-adls-psc"
    private_connection_resource_id = azurerm_storage_account.datalake.id
    subresource_names              = ["dfs"]
    is_manual_connection           = false
  }

  tags = {
    Environment = var.environment
  }
}