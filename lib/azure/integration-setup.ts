/**
 * Azure Integration Setup Utilities
 * Complete setup and configuration for Azure services integration
 */

import { DefaultAzureCredential } from '@azure/identity'
import { SecretClient } from '@azure/keyvault-secrets'
import { BlobServiceClient } from '@azure/storage-blob'
import { DataLakeServiceClient } from '@azure/storage-file-datalake'
import { createClient } from '@supabase/supabase-js'
import { OpenAI } from 'openai'

export interface AzureConfig {
  tenantId: string
  clientId: string
  keyVaultName: string
  adlsAccountName: string
  adlsFileSystemName: string
  openAIEndpoint: string
  openAIDeploymentName: string
}

export interface SupabaseConfig {
  url: string
  anonKey: string
  serviceRoleKey: string
  postgresUrl: string
}

export class AzureIntegrationSetup {
  private credential: DefaultAzureCredential
  private keyVaultClient: SecretClient
  private adlsClient: DataLakeServiceClient
  private openAIClient: OpenAI
  private supabaseClient: any

  constructor(private config: AzureConfig & SupabaseConfig) {
    this.credential = new DefaultAzureCredential()
    this.setupClients()
  }

  private setupClients() {
    // Key Vault client
    this.keyVaultClient = new SecretClient(
      `https://${this.config.keyVaultName}.vault.azure.net`,
      this.credential
    )

    // ADLS Gen2 client
    this.adlsClient = new DataLakeServiceClient(
      `https://${this.config.adlsAccountName}.dfs.core.windows.net`,
      this.credential
    )

    // Supabase client with optimized settings
    this.supabaseClient = createClient(
      this.config.url,
      this.config.serviceRoleKey,
      {
        db: {
          schema: 'public',
        },
        auth: {
          autoRefreshToken: false,
          persistSession: false
        },
        global: {
          headers: {
            'x-client-info': 'scout-analytics-azure-integration'
          }
        }
      }
    )
  }

  /**
   * Initialize Azure OpenAI client with proper configuration
   */
  async setupOpenAI(): Promise<OpenAI> {
    try {
      const apiKey = await this.getSecret('azure-openai-key')
      
      this.openAIClient = new OpenAI({
        apiKey,
        baseURL: `${this.config.openAIEndpoint}/openai/deployments/${this.config.openAIDeploymentName}`,
        defaultQuery: { 'api-version': '2024-02-15-preview' },
        defaultHeaders: {
          'api-key': apiKey,
        },
      })

      // Test the connection
      await this.testOpenAIConnection()
      
      console.log('✅ Azure OpenAI client configured successfully')
      return this.openAIClient
    } catch (error) {
      console.error('❌ Failed to setup Azure OpenAI:', error)
      throw error
    }
  }

  /**
   * Setup ADLS2 filesystem and containers
   */
  async setupADLS(): Promise<void> {
    try {
      const fileSystemClient = this.adlsClient.getFileSystemClient(this.config.adlsFileSystemName)
      
      // Create filesystem if it doesn't exist
      await fileSystemClient.createIfNotExists({
        metadata: {
          purpose: 'scout-analytics-data-lake',
          environment: 'production'
        }
      })

      // Create directory structure
      const directories = [
        'raw-data/transactions',
        'raw-data/customers',
        'raw-data/products',
        'analytics/daily-metrics',
        'analytics/customer-segments',
        'analytics/product-performance',
        'exports/dashboard-reports',
        'exports/scheduled-exports',
        'ml-models/training-data',
        'ml-models/model-artifacts',
        'ai-cache/responses',
        'audit-trail/changes'
      ]

      for (const dir of directories) {
        const directoryClient = fileSystemClient.getDirectoryClient(dir)
        await directoryClient.createIfNotExists()
        console.log(`📁 Created directory: ${dir}`)
      }

      console.log('✅ ADLS2 filesystem and directories configured successfully')
    } catch (error) {
      console.error('❌ Failed to setup ADLS2:', error)
      throw error
    }
  }

  /**
   * Setup Supabase real-time subscriptions and CDC
   */
  async setupSupabaseCDC(): Promise<void> {
    try {
      // Enable real-time for required tables
      const tables = ['transactions_fmcg', 'customers', 'products', 'brands']
      
      for (const table of tables) {
        const { error } = await this.supabaseClient
          .from(table)
          .select('count')
          .limit(1)
        
        if (error) {
          console.warn(`⚠️ Table ${table} not accessible:`, error.message)
        } else {
          console.log(`✅ Table ${table} accessible for CDC`)
        }
      }

      // Setup CDC channels
      this.setupCDCChannels()
      
      console.log('✅ Supabase CDC configured successfully')
    } catch (error) {
      console.error('❌ Failed to setup Supabase CDC:', error)
      throw error
    }
  }

  private setupCDCChannels() {
    // Transactions CDC
    this.supabaseClient
      .channel('transactions-cdc')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'transactions_fmcg' },
        this.handleTransactionChange.bind(this)
      )
      .subscribe()

    // Customers CDC
    this.supabaseClient
      .channel('customers-cdc')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'customers' },
        this.handleCustomerChange.bind(this)
      )
      .subscribe()

    console.log('📡 CDC channels established')
  }

  private async handleTransactionChange(payload: any) {
    try {
      console.log(`🔄 Transaction ${payload.eventType}:`, payload.new?.id)
      
      if (payload.eventType === 'INSERT') {
        await this.streamToADLS('transactions', [payload.new])
      }
    } catch (error) {
      console.error('Failed to handle transaction change:', error)
    }
  }

  private async handleCustomerChange(payload: any) {
    try {
      console.log(`🔄 Customer ${payload.eventType}:`, payload.new?.id)
      
      // Stream customer analytics to ADLS
      const analytics = {
        customerId: payload.new?.id,
        changeType: payload.eventType,
        timestamp: new Date().toISOString(),
        data: payload.new
      }
      
      await this.streamToADLS('customer-changes', [analytics])
    } catch (error) {
      console.error('Failed to handle customer change:', error)
    }
  }

  /**
   * Stream data to ADLS2
   */
  private async streamToADLS(category: string, data: any[]): Promise<void> {
    try {
      const fileSystemClient = this.adlsClient.getFileSystemClient(this.config.adlsFileSystemName)
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
      const fileName = `raw-data/${category}/${timestamp}.json`
      
      const fileClient = fileSystemClient.getFileClient(fileName)
      const content = JSON.stringify(data, null, 2)
      
      await fileClient.upload(content, content.length, {
        overwrite: true,
        properties: {
          contentType: 'application/json',
          metadata: {
            'data-category': category,
            'record-count': data.length.toString(),
            'upload-timestamp': new Date().toISOString()
          }
        }
      })
      
      console.log(`📤 Streamed ${data.length} records to ${fileName}`)
    } catch (error) {
      console.error('Failed to stream to ADLS:', error)
    }
  }

  /**
   * Test all integrations
   */
  async runIntegrationTests(): Promise<boolean> {
    console.log('🧪 Running integration tests...')
    
    const tests = [
      { name: 'Azure Key Vault', test: () => this.testKeyVault() },
      { name: 'ADLS2 Access', test: () => this.testADLS() },
      { name: 'Supabase Connection', test: () => this.testSupabase() },
      { name: 'Azure OpenAI', test: () => this.testOpenAIConnection() }
    ]

    let allPassed = true
    
    for (const { name, test } of tests) {
      try {
        await test()
        console.log(`✅ ${name}: PASSED`)
      } catch (error) {
        console.error(`❌ ${name}: FAILED -`, error.message)
        allPassed = false
      }
    }

    console.log(allPassed ? '🎉 All integration tests passed!' : '⚠️ Some tests failed')
    return allPassed
  }

  private async testKeyVault(): Promise<void> {
    try {
      // Try to get a known secret
      await this.keyVaultClient.getSecret('supabase-url')
    } catch (error) {
      if (error.code === 'SecretNotFound') {
        console.log('Key Vault accessible, secret not found (expected)')
        return
      }
      throw error
    }
  }

  private async testADLS(): Promise<void> {
    const fileSystemClient = this.adlsClient.getFileSystemClient(this.config.adlsFileSystemName)
    
    // Try to list files in raw-data directory
    const directoryClient = fileSystemClient.getDirectoryClient('raw-data')
    const iterator = directoryClient.listPaths({ maxResults: 1 })
    await iterator.next()
  }

  private async testSupabase(): Promise<void> {
    const { data, error } = await this.supabaseClient
      .from('brands')
      .select('count')
      .limit(1)
    
    if (error) throw error
  }

  private async testOpenAIConnection(): Promise<void> {
    if (!this.openAIClient) {
      await this.setupOpenAI()
    }
    
    const completion = await this.openAIClient.chat.completions.create({
      model: this.config.openAIDeploymentName,
      messages: [{ role: 'user', content: 'Test connection - respond with "OK"' }],
      max_tokens: 5
    })
    
    if (!completion.choices[0]?.message?.content) {
      throw new Error('No response from Azure OpenAI')
    }
  }

  /**
   * Helper method to get secrets from Key Vault
   */
  async getSecret(secretName: string): Promise<string> {
    try {
      const secret = await this.keyVaultClient.getSecret(secretName)
      return secret.value || ''
    } catch (error) {
      console.error(`Failed to retrieve secret ${secretName}:`, error)
      throw error
    }
  }

  /**
   * Store a secret in Key Vault
   */
  async setSecret(secretName: string, secretValue: string): Promise<void> {
    try {
      await this.keyVaultClient.setSecret(secretName, secretValue, {
        tags: {
          'managed-by': 'scout-analytics-integration',
          'created-at': new Date().toISOString()
        }
      })
      console.log(`✅ Secret ${secretName} stored successfully`)
    } catch (error) {
      console.error(`Failed to store secret ${secretName}:`, error)
      throw error
    }
  }

  /**
   * Setup environment variables for Vercel deployment
   */
  generateVercelEnvVars(): Record<string, string> {
    return {
      // Azure Configuration
      AZURE_TENANT_ID: this.config.tenantId,
      AZURE_CLIENT_ID: this.config.clientId,
      AZURE_KEYVAULT_NAME: this.config.keyVaultName,
      ADLS_ACCOUNT_NAME: this.config.adlsAccountName,
      ADLS_FILESYSTEM_NAME: this.config.adlsFileSystemName,
      
      // Azure OpenAI Configuration
      AZURE_OPENAI_ENDPOINT: this.config.openAIEndpoint,
      AZURE_OPENAI_DEPLOYMENT_NAME: this.config.openAIDeploymentName,
      
      // Supabase Configuration
      NEXT_PUBLIC_SUPABASE_URL: this.config.url,
      NEXT_PUBLIC_SUPABASE_ANON_KEY: this.config.anonKey,
      SUPABASE_SERVICE_ROLE_KEY: this.config.serviceRoleKey,
      POSTGRES_URL: this.config.postgresUrl,
      
      // Additional Configuration
      NODE_ENV: 'production',
      NEXT_PUBLIC_APP_ENV: 'production'
    }
  }

  /**
   * Cleanup resources (for testing/development)
   */
  async cleanup(): Promise<void> {
    try {
      // Close Supabase subscriptions
      if (this.supabaseClient) {
        this.supabaseClient.removeAllChannels()
      }
      
      console.log('✅ Resources cleaned up successfully')
    } catch (error) {
      console.error('⚠️ Cleanup error:', error)
    }
  }
}

/**
 * Factory function to create and initialize Azure integration
 */
export async function createAzureIntegration(
  azureConfig: AzureConfig,
  supabaseConfig: SupabaseConfig
): Promise<AzureIntegrationSetup> {
  const integration = new AzureIntegrationSetup({ ...azureConfig, ...supabaseConfig })
  
  // Initialize all services
  await integration.setupOpenAI()
  await integration.setupADLS()
  await integration.setupSupabaseCDC()
  
  // Run integration tests
  const testsPass = await integration.runIntegrationTests()
  
  if (!testsPass) {
    console.warn('⚠️ Some integration tests failed. Check configuration.')
  }
  
  return integration
}

/**
 * Environment configuration helper
 */
export function getConfigFromEnv(): AzureConfig & SupabaseConfig {
  const requiredEnvVars = [
    'AZURE_TENANT_ID',
    'AZURE_CLIENT_ID',
    'AZURE_KEYVAULT_NAME',
    'ADLS_ACCOUNT_NAME',
    'ADLS_FILESYSTEM_NAME',
    'AZURE_OPENAI_ENDPOINT',
    'AZURE_OPENAI_DEPLOYMENT_NAME',
    'NEXT_PUBLIC_SUPABASE_URL',
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    'SUPABASE_SERVICE_ROLE_KEY',
    'POSTGRES_URL'
  ]

  const missing = requiredEnvVars.filter(varName => !process.env[varName])
  
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`)
  }

  return {
    tenantId: process.env.AZURE_TENANT_ID!,
    clientId: process.env.AZURE_CLIENT_ID!,
    keyVaultName: process.env.AZURE_KEYVAULT_NAME!,
    adlsAccountName: process.env.ADLS_ACCOUNT_NAME!,
    adlsFileSystemName: process.env.ADLS_FILESYSTEM_NAME!,
    openAIEndpoint: process.env.AZURE_OPENAI_ENDPOINT!,
    openAIDeploymentName: process.env.AZURE_OPENAI_DEPLOYMENT_NAME!,
    url: process.env.NEXT_PUBLIC_SUPABASE_URL!,
    anonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY!,
    postgresUrl: process.env.POSTGRES_URL!
  }
}