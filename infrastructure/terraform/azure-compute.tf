# Azure Kubernetes Service (AKS) Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.prefix}-aks"
  kubernetes_version  = var.kubernetes_version
  node_resource_group = "${var.prefix}-aks-nodes-rg"

  # System-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  # Default node pool for system workloads
  default_node_pool {
    name                = "system"
    node_count          = var.node_count
    vm_size             = var.vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = var.node_count
    max_count           = 10
    os_disk_size_gb     = 100
    os_disk_type        = "Managed"
    
    # Node labels and taints for system pods
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
    }
    
    # Only system pods on this node pool
    only_critical_addons_enabled = true
  }

  # Network configuration
  network_profile {
    network_plugin      = "azure"
    network_policy      = "azure"
    service_cidr        = "10.10.0.0/16"
    dns_service_ip      = "10.10.0.10"
    outbound_type       = "loadBalancer"
    load_balancer_sku   = "standard"
  }

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # Monitoring integration
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Auto-scaler configuration
  auto_scaler_profile {
    balance_similar_node_groups      = false
    expander                         = "random"
    max_graceful_termination_sec     = 600
    max_node_provision_time          = "15m"
    max_unready_nodes               = 3
    max_unready_percentage          = 45
    new_pod_scale_up_delay          = "10s"
    scale_down_delay_after_add      = "10m"
    scale_down_delay_after_delete   = "10s"
    scale_down_delay_after_failure  = "3m"
    scan_interval                   = "10s"
    scale_down_unneeded             = "10m"
    scale_down_unready              = "20m"
    scale_down_utilization_threshold = 0.5
  }

  # Key Vault secrets provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  tags = {
    Environment = var.environment
    Purpose     = "Container Orchestration"
    Project     = "Scout Analytics"
  }
}

# User node pool for application workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D8s_v3"  # 8 vCores, 32 GB RAM
  node_count            = 3
  enable_auto_scaling   = true
  min_count             = 3
  max_count             = 15
  vnet_subnet_id        = azurerm_subnet.aks.id
  os_disk_size_gb       = 128
  os_disk_type          = "Premium_LRS"
  
  node_labels = {
    "nodepool-type" = "user"
    "environment"   = var.environment
    "workload-type" = "general"
  }

  tags = {
    Environment = var.environment
    NodePool    = "user"
  }
}

# GPU node pool for AI/ML workloads
resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  name                  = "gpu"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_NC6s_v3"  # 6 vCores, 112 GB RAM, 1 V100 GPU
  node_count            = 1
  enable_auto_scaling   = true
  min_count             = 0  # Can scale to zero for cost savings
  max_count             = 3
  vnet_subnet_id        = azurerm_subnet.aks.id
  os_disk_size_gb       = 256
  os_disk_type          = "Premium_LRS"
  
  # GPU-specific node configuration
  node_labels = {
    "nodepool-type"    = "gpu"
    "environment"      = var.environment
    "accelerator"      = "nvidia-tesla-v100"
    "workload-type"    = "ai-ml"
  }
  
  # Taint GPU nodes so only GPU workloads are scheduled
  node_taints = [
    "nvidia.com/gpu=true:NoSchedule"
  ]

  tags = {
    Environment = var.environment
    NodePool    = "gpu"
    Accelerator = "nvidia-v100"
  }
}

# Spot instance node pool for non-critical workloads
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D4s_v3"
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = 0.05  # Max price per hour
  node_count            = 2
  enable_auto_scaling   = true
  min_count             = 0
  max_count             = 10
  vnet_subnet_id        = azurerm_subnet.aks.id
  
  node_labels = {
    "nodepool-type"      = "spot"
    "environment"        = var.environment
    "workload-type"      = "batch"
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }
  
  # Taint spot nodes
  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]

  tags = {
    Environment = var.environment
    NodePool    = "spot"
    Priority    = "spot"
  }
}

# Container Registry for storing Docker images
resource "azurerm_container_registry" "main" {
  name                = "${var.prefix}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Premium"
  admin_enabled       = false

  # Network access configuration
  network_rule_set {
    default_action = "Deny"
    
    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.aks.id
    }
  }

  # Enable vulnerability scanning
  quarantine_policy_enabled = true
  trust_policy_enabled      = true
  retention_policy_enabled  = true

  tags = {
    Environment = var.environment
    Purpose     = "Container Images"
    Project     = "Scout Analytics"
  }
}

# Grant AKS cluster access to ACR
resource "azurerm_role_assignment" "aks_to_acr" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# Application Gateway for ingress
resource "azurerm_public_ip" "appgw" {
  name                = "${var.prefix}-appgw-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_application_gateway" "main" {
  name                = "${var.prefix}-appgw"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-configuration"
    subnet_id = azurerm_subnet.application_gateway.id
  }

  frontend_port {
    name = "frontend-port-80"
    port = 80
  }

  frontend_port {
    name = "frontend-port-443"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-configuration"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name = "aks-backend-pool"
  }

  backend_http_settings {
    name                  = "aks-backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "aks-http-listener"
    frontend_ip_configuration_name = "frontend-ip-configuration"
    frontend_port_name             = "frontend-port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "aks-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "aks-http-listener"
    backend_address_pool_name  = "aks-backend-pool"
    backend_http_settings_name = "aks-backend-http-settings"
    priority                   = 1
  }

  tags = {
    Environment = var.environment
    Purpose     = "Application Gateway"
    Project     = "Scout Analytics"
  }
}