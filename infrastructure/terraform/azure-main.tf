# Azure Production Infrastructure for Scout Analytics
# This file serves as the main entry point and contains additional resources

# Local values for common naming and tagging
locals {
  common_tags = {
    Environment = var.environment
    Project     = "Scout Analytics"
    ManagedBy   = "Terraform"
    CreatedDate = timestamp()
  }
  
  naming_prefix = "${var.prefix}-${var.environment}"
}

# Resource naming validation
resource "validation" "naming_convention" {
  condition = can(regex("^[a-z0-9-]+$", var.prefix))
  error_message = "Prefix must contain only lowercase letters, numbers, and hyphens."
}

# Azure Monitor Action Group for alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "${local.naming_prefix}-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "scout"

  email_receiver {
    name          = "admin"
    email_address = "admin@tbwa.com"  # Replace with actual email
  }

  sms_receiver {
    name         = "admin-sms"
    country_code = "63"  # Philippines
    phone_number = "9171234567"  # Replace with actual number
  }

  tags = local.common_tags
}

# Metric alerts for critical resources
resource "azurerm_monitor_metric_alert" "postgres_cpu" {
  name                = "${local.naming_prefix}-postgres-cpu"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "PostgreSQL CPU usage is too high"
  enabled             = true
  frequency           = "PT1M"
  severity            = 2
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "postgres_memory" {
  name                = "${local.naming_prefix}-postgres-memory"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "PostgreSQL memory usage is too high"
  enabled             = true
  frequency           = "PT1M"
  severity            = 2
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "memory_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "aks_pod_ready" {
  name                = "${local.naming_prefix}-aks-pod-ready"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_kubernetes_cluster.main.id]
  description         = "AKS pods not ready percentage is too high"
  enabled             = true
  frequency           = "PT1M"
  severity            = 1
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "kube_pod_status_ready"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 0.9  # 90% ready
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "frontdoor_5xx_errors" {
  name                = "${local.naming_prefix}-frontdoor-5xx"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_cdn_frontdoor_profile.main.id]
  description         = "Front Door 5xx error rate is too high"
  enabled             = true
  frequency           = "PT1M"
  severity            = 1
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Cdn/profiles"
    metric_name      = "Percentage5XX"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 5  # 5% error rate
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = local.common_tags
}

# Log queries for custom alerts
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "application_errors" {
  name                = "${local.naming_prefix}-app-errors"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [azurerm_log_analytics_workspace.main.id]
  severity             = 2
  description          = "High number of application errors detected"
  enabled              = true

  criteria {
    query = <<-QUERY
      ContainerLog
      | where LogEntry contains "ERROR" or LogEntry contains "FATAL"
      | where TimeGenerated > ago(5m)
      | summarize ErrorCount = count() by bin(TimeGenerated, 1m)
      | where ErrorCount > 10
    QUERY

    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThanOrEqual"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.main.id]
  }

  tags = local.common_tags
}

# Application Insights for APM
resource "azurerm_application_insights" "main" {
  name                = "${local.naming_prefix}-appinsights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = local.common_tags
}

# Azure Backup for PostgreSQL
resource "azurerm_data_protection_backup_vault" "main" {
  name                = "${local.naming_prefix}-backup-vault"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Backup policy for PostgreSQL
resource "azurerm_data_protection_backup_policy_postgresql" "main" {
  name     = "${local.naming_prefix}-postgres-backup-policy"
  vault_id = azurerm_data_protection_backup_vault.main.id

  backup_repeating_time_intervals = ["R/2024-01-01T02:00:00+00:00/P1D"]
  default_retention_duration       = "P30D"

  retention_rule {
    name     = "weekly"
    duration = "P12W"
    priority = 20
    criteria {
      absolute_criteria = "FirstOfWeek"
    }
  }

  retention_rule {
    name     = "monthly"
    duration = "P12M"
    priority = 15
    criteria {
      absolute_criteria = "FirstOfMonth"
    }
  }
}

# Cost management budget
resource "azurerm_consumption_budget_resource_group" "main" {
  name              = "${local.naming_prefix}-budget"
  resource_group_id = azurerm_resource_group.main.id

  amount     = 1000  # $1000 USD monthly budget
  time_grain = "Monthly"

  time_period {
    start_date = "2024-01-01T00:00:00Z"
    end_date   = "2025-12-31T00:00:00Z"
  }

  filter {
    dimension {
      name = "ResourceGroupName"
      values = [
        azurerm_resource_group.main.name,
      ]
    }
  }

  notification {
    enabled   = true
    threshold = 80
    operator  = "GreaterThan"

    contact_emails = [
      "admin@tbwa.com",  # Replace with actual email
    ]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"

    contact_emails = [
      "admin@tbwa.com",  # Replace with actual email
    ]
  }

  depends_on = [azurerm_resource_group.main]
}

# Azure Automation Account for maintenance tasks
resource "azurerm_automation_account" "main" {
  name                = "${local.naming_prefix}-automation"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Runbook for automated maintenance
resource "azurerm_automation_runbook" "postgres_maintenance" {
  name                    = "postgres-maintenance"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = true
  log_progress            = true
  description             = "PostgreSQL maintenance tasks"
  runbook_type            = "PowerShell"

  content = <<-EOT
    param(
        [string]$ResourceGroupName,
        [string]$ServerName
    )
    
    # Connect to Azure using managed identity
    Connect-AzAccount -Identity
    
    # PostgreSQL maintenance commands
    Write-Output "Starting PostgreSQL maintenance for server: $ServerName"
    
    # Add your maintenance scripts here
    # Example: Update statistics, check index fragmentation, etc.
    
    Write-Output "PostgreSQL maintenance completed"
  EOT

  tags = local.common_tags
}

# Schedule for automated maintenance
resource "azurerm_automation_schedule" "weekly_maintenance" {
  name                    = "weekly-maintenance"
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  frequency               = "Week"
  interval                = 1
  timezone                = "Asia/Manila"
  start_time              = "2024-01-07T02:00:00+08:00"  # Sunday 2 AM
  description             = "Weekly maintenance schedule"
  week_days               = ["Sunday"]
}

# Link runbook to schedule
resource "azurerm_automation_job_schedule" "postgres_maintenance" {
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  schedule_name           = azurerm_automation_schedule.weekly_maintenance.name
  runbook_name           = azurerm_automation_runbook.postgres_maintenance.name

  parameters = {
    ResourceGroupName = azurerm_resource_group.main.name
    ServerName        = azurerm_postgresql_flexible_server.main.name
  }
}