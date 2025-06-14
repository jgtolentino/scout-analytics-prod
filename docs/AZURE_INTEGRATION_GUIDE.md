# 🚀 Azure-Supabase-Vercel Integration Guide

A comprehensive guide for integrating Azure PostgreSQL, Supabase, Azure OpenAI, Vercel, and ADLS2 for Scout Analytics production deployment.

## 🏗️ Architecture Overview

```mermaid
graph TB
    subgraph "Vercel Edge"
        VE[Vercel Edge Functions]
        VA[Vercel Analytics]
        VKV[Vercel KV Cache]
    end
    
    subgraph "Supabase"
        SDB[PostgreSQL Database]
        SRT[Real-time Subscriptions]
        SCD[Change Data Capture]
    end
    
    subgraph "Azure Services"
        AZ_PG[Azure PostgreSQL]
        AZ_AI[Azure OpenAI]
        ADLS[ADLS Gen2]
        AKV[Azure Key Vault]
        AAD[Azure AD OIDC]
    end
    
    VE --> SDB
    VE --> AZ_AI
    VE --> ADLS
    SCD --> ADLS
    AZ_PG --> SDB
    AAD --> VE
    AKV --> VE
```

## 🔗 1. Supabase-Vercel Integration

### Automated Setup via Vercel Marketplace

```bash
# Step 1: Connect Supabase in Vercel Dashboard
# Go to: https://vercel.com/integrations/supabase
# This auto-injects environment variables

# Step 2: Verify auto-injected variables
npx vercel env ls
```

### Environment Variables (Auto-injected)
```bash
POSTGRES_URL=postgresql://postgres:[password]@[host]:6543/postgres?pgbouncer=true&connection_limit=1
NEXT_PUBLIC_SUPABASE_URL=https://[project-ref].supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=[anon-key]
SUPABASE_SERVICE_ROLE_KEY=[service-role-key]
```

### Connection Pooling Configuration

```typescript
// lib/supabase/client.ts
import { createClient } from '@supabase/supabase-js'

// For serverless functions - use transaction mode (port 6543)
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  db: {
    schema: 'public',
  },
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  },
  global: {
    headers: {
      'x-my-custom-header': 'scout-analytics',
    },
  },
})

// For persistent backends - use session mode (port 5432)
export const supabaseServerless = createClient(
  supabaseUrl,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  {
    db: {
      schema: 'public',
    },
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
)
```

### Troubleshooting Common Issues

```typescript
// lib/supabase/troubleshoot.ts
export async function testSupabaseConnection() {
  try {
    const { data, error } = await supabase
      .from('health_check')
      .select('*')
      .limit(1)
    
    if (error) {
      console.error('Supabase connection error:', error)
      return { success: false, error: error.message }
    }
    
    return { success: true, data }
  } catch (err) {
    console.error('Connection test failed:', err)
    return { success: false, error: 'Connection refused - check firewall settings' }
  }
}

// Handle IPv4/IPv6 compatibility issues
export function getCompatibleConnectionString() {
  const baseUrl = process.env.POSTGRES_URL
  
  // Switch to Supavisor session mode for IPv4
  if (process.env.FORCE_IPV4 === 'true') {
    return baseUrl?.replace(':6543', ':5432').replace('pgbouncer=true', 'pgbouncer=false')
  }
  
  return baseUrl
}
```

## 🌐 2. Azure PostgreSQL Connectivity

### Direct Connection Setup

```typescript
// lib/azure/postgres.ts
import { Pool } from 'pg'

const azurePostgresConfig = {
  host: process.env.AZURE_POSTGRES_HOST,
  port: 5432,
  database: process.env.AZURE_POSTGRES_DB,
  user: process.env.AZURE_POSTGRES_USER,
  password: process.env.AZURE_POSTGRES_PASSWORD,
  ssl: {
    rejectUnauthorized: true,
    ca: process.env.AZURE_POSTGRES_CA_CERT
  },
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
}

export const azurePool = new Pool(azurePostgresConfig)

export async function testAzureConnection() {
  try {
    const client = await azurePool.connect()
    const result = await client.query('SELECT version()')
    client.release()
    
    console.log('Azure PostgreSQL version:', result.rows[0].version)
    return { success: true, version: result.rows[0].version }
  } catch (error) {
    console.error('Azure PostgreSQL connection failed:', error)
    return { success: false, error: error.message }
  }
}
```

### Security Configuration

```typescript
// lib/azure/keyvault.ts
import { SecretClient } from '@azure/keyvault-secrets'
import { DefaultAzureCredential } from '@azure/identity'

const credential = new DefaultAzureCredential()
const vaultName = process.env.AZURE_KEYVAULT_NAME
const url = `https://${vaultName}.vault.azure.net`

const client = new SecretClient(url, credential)

export async function getSecret(secretName: string): Promise<string> {
  try {
    const secret = await client.getSecret(secretName)
    return secret.value || ''
  } catch (error) {
    console.error(`Failed to retrieve secret ${secretName}:`, error)
    throw error
  }
}

export async function getAzurePostgresCredentials() {
  const [host, user, password, caCert] = await Promise.all([
    getSecret('postgres-host'),
    getSecret('postgres-admin-username'),
    getSecret('postgres-admin-password'),
    getSecret('postgres-ca-certificate')
  ])
  
  return { host, user, password, caCert }
}
```

## 🤖 3. Azure OpenAI Integration

### Serverless Access via Vercel Edge Functions

```typescript
// api/ai/chat.ts
import { OpenAI } from 'openai'
import type { NextRequest } from 'next/server'

export const config = {
  runtime: 'edge',
}

const openai = new OpenAI({
  apiKey: process.env.AZURE_OPENAI_API_KEY,
  baseURL: `${process.env.AZURE_OPENAI_ENDPOINT}/openai/deployments/${process.env.AZURE_OPENAI_DEPLOYMENT_NAME}`,
  defaultQuery: { 'api-version': '2024-02-15-preview' },
  defaultHeaders: {
    'api-key': process.env.AZURE_OPENAI_API_KEY,
  },
})

export default async function handler(req: NextRequest) {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    const { messages, context } = await req.json()
    
    // Add Scout Analytics context
    const systemMessage = {
      role: 'system',
      content: `You are Scout AI, a retail analytics assistant for FMCG data in the Philippines. 
                Context: ${context || 'General retail analytics query'}`
    }

    const completion = await openai.chat.completions.create({
      model: process.env.AZURE_OPENAI_DEPLOYMENT_NAME || 'gpt-4',
      messages: [systemMessage, ...messages],
      temperature: 0.7,
      max_tokens: 1000,
      stream: true
    })

    // Stream response back to client
    const encoder = new TextEncoder()
    const stream = new ReadableStream({
      async start(controller) {
        for await (const chunk of completion) {
          const content = chunk.choices[0]?.delta?.content || ''
          if (content) {
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({ content })}\n\n`))
          }
        }
        controller.enqueue(encoder.encode('data: [DONE]\n\n'))
        controller.close()
      }
    })

    return new Response(stream, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    })
  } catch (error) {
    console.error('Azure OpenAI error:', error)
    return new Response(JSON.stringify({ error: 'AI service unavailable' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
}
```

### Response Caching with ADLS2

```typescript
// lib/azure/ai-cache.ts
import { BlobServiceClient } from '@azure/storage-blob'
import { DefaultAzureCredential } from '@azure/identity'

const credential = new DefaultAzureCredential()
const accountName = process.env.ADLS_ACCOUNT_NAME
const blobServiceClient = new BlobServiceClient(
  `https://${accountName}.blob.core.windows.net`,
  credential
)

export async function cacheAIResponse(queryHash: string, response: string) {
  try {
    const containerClient = blobServiceClient.getContainerClient('ai-cache')
    const blockBlobClient = containerClient.getBlockBlobClient(`responses/${queryHash}.json`)
    
    const cacheData = {
      response,
      timestamp: new Date().toISOString(),
      ttl: Date.now() + (24 * 60 * 60 * 1000) // 24 hours
    }
    
    await blockBlobClient.upload(
      JSON.stringify(cacheData),
      JSON.stringify(cacheData).length,
      {
        blobHTTPHeaders: { blobContentType: 'application/json' },
        metadata: { 'cache-type': 'ai-response' }
      }
    )
    
    return true
  } catch (error) {
    console.error('Failed to cache AI response:', error)
    return false
  }
}

export async function getCachedAIResponse(queryHash: string): Promise<string | null> {
  try {
    const containerClient = blobServiceClient.getContainerClient('ai-cache')
    const blockBlobClient = containerClient.getBlockBlobClient(`responses/${queryHash}.json`)
    
    const downloadResponse = await blockBlobClient.download()
    const cacheData = JSON.parse(await streamToText(downloadResponse.readableStreamBody!))
    
    // Check if cache is still valid
    if (Date.now() > cacheData.ttl) {
      await blockBlobClient.delete()
      return null
    }
    
    return cacheData.response
  } catch (error) {
    return null // Cache miss
  }
}

async function streamToText(readable: NodeJS.ReadableStream): Promise<string> {
  const chunks: Buffer[] = []
  return new Promise((resolve, reject) => {
    readable.on('data', (data) => chunks.push(data))
    readable.on('end', () => resolve(Buffer.concat(chunks).toString()))
    readable.on('error', reject)
  })
}
```

## 📦 4. ADLS2 Data Pipeline

### Data Flow Architecture

```typescript
// lib/azure/adls-pipeline.ts
import { DataLakeServiceClient } from '@azure/storage-file-datalake'
import { DefaultAzureCredential } from '@azure/identity'

const credential = new DefaultAzureCredential()
const accountName = process.env.ADLS_ACCOUNT_NAME
const fileSystemName = process.env.ADLS_FILESYSTEM_NAME

const serviceClient = new DataLakeServiceClient(
  `https://${accountName}.dfs.core.windows.net`,
  credential
)

export class ADLSDataPipeline {
  private fileSystemClient = serviceClient.getFileSystemClient(fileSystemName!)

  async uploadTransactionData(data: any[], timestamp: string) {
    const fileName = `raw-data/transactions/${timestamp}.json`
    const fileClient = this.fileSystemClient.getFileClient(fileName)
    
    try {
      await fileClient.upload(JSON.stringify(data), JSON.stringify(data).length, {
        overwrite: true,
        properties: {
          contentType: 'application/json',
          metadata: {
            'data-type': 'transactions',
            'upload-timestamp': new Date().toISOString(),
            'record-count': data.length.toString()
          }
        }
      })
      
      console.log(`Uploaded ${data.length} transactions to ${fileName}`)
      return { success: true, fileName, recordCount: data.length }
    } catch (error) {
      console.error('Failed to upload transaction data:', error)
      throw error
    }
  }

  async uploadAnalyticsData(analytics: any, category: string) {
    const fileName = `analytics/${category}/${new Date().toISOString().split('T')[0]}.json`
    const fileClient = this.fileSystemClient.getFileClient(fileName)
    
    try {
      await fileClient.upload(JSON.stringify(analytics), JSON.stringify(analytics).length, {
        overwrite: true,
        properties: {
          contentType: 'application/json',
          metadata: {
            'data-type': 'analytics',
            'category': category,
            'generated-timestamp': new Date().toISOString()
          }
        }
      })
      
      return { success: true, fileName }
    } catch (error) {
      console.error('Failed to upload analytics data:', error)
      throw error
    }
  }

  async exportDashboardData(exportData: any, format: 'json' | 'csv' = 'json') {
    const timestamp = new Date().toISOString().split('T')[0]
    const fileName = `exports/dashboard-export-${timestamp}.${format}`
    const fileClient = this.fileSystemClient.getFileClient(fileName)
    
    try {
      let content: string
      let contentType: string
      
      if (format === 'csv') {
        content = this.jsonToCsv(exportData)
        contentType = 'text/csv'
      } else {
        content = JSON.stringify(exportData, null, 2)
        contentType = 'application/json'
      }
      
      await fileClient.upload(content, content.length, {
        overwrite: true,
        properties: {
          contentType,
          metadata: {
            'export-type': 'dashboard',
            'export-format': format,
            'export-timestamp': new Date().toISOString()
          }
        }
      })
      
      return { success: true, fileName, downloadUrl: fileClient.url }
    } catch (error) {
      console.error('Failed to export dashboard data:', error)
      throw error
    }
  }

  private jsonToCsv(data: any[]): string {
    if (!data.length) return ''
    
    const headers = Object.keys(data[0])
    const csvRows = [
      headers.join(','),
      ...data.map(row => 
        headers.map(header => {
          const value = row[header]
          return typeof value === 'string' ? `"${value.replace(/"/g, '""')}"` : value
        }).join(',')
      )
    ]
    
    return csvRows.join('\n')
  }

  async listFiles(directoryPath: string) {
    try {
      const directoryClient = this.fileSystemClient.getDirectoryClient(directoryPath)
      const files = []
      
      for await (const item of directoryClient.listPaths()) {
        files.push({
          name: item.name,
          isDirectory: item.isDirectory,
          lastModified: item.lastModified,
          contentLength: item.contentLength
        })
      }
      
      return files
    } catch (error) {
      console.error('Failed to list files:', error)
      throw error
    }
  }
}

export const adlsPipeline = new ADLSDataPipeline()
```

### Change Data Capture (CDC) from Supabase

```typescript
// lib/supabase/cdc.ts
import { createClient } from '@supabase/supabase-js'
import { adlsPipeline } from '../azure/adls-pipeline'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

export function setupCDCPipeline() {
  // Listen for transaction changes
  const transactionSubscription = supabase
    .channel('transactions-cdc')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'transactions_fmcg' },
      async (payload) => {
        console.log('Transaction change detected:', payload.eventType)
        
        if (payload.eventType === 'INSERT') {
          await handleNewTransaction(payload.new)
        } else if (payload.eventType === 'UPDATE') {
          await handleUpdatedTransaction(payload.new, payload.old)
        }
      }
    )
    .subscribe()

  // Listen for customer changes
  const customerSubscription = supabase
    .channel('customers-cdc')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'customers' },
      async (payload) => {
        console.log('Customer change detected:', payload.eventType)
        await handleCustomerChange(payload)
      }
    )
    .subscribe()

  return { transactionSubscription, customerSubscription }
}

async function handleNewTransaction(transaction: any) {
  try {
    // Stream new transaction to ADLS2
    await adlsPipeline.uploadTransactionData(
      [transaction],
      `realtime-${new Date().toISOString()}`
    )
    
    // Trigger analytics update
    await updateRealtimeAnalytics(transaction)
  } catch (error) {
    console.error('Failed to handle new transaction:', error)
  }
}

async function handleUpdatedTransaction(newData: any, oldData: any) {
  try {
    // Log the change for audit purposes
    const changeLog = {
      timestamp: new Date().toISOString(),
      transactionId: newData.id,
      changes: getChanges(oldData, newData),
      userId: newData.updated_by
    }
    
    await adlsPipeline.uploadAnalyticsData(changeLog, 'audit-trail')
  } catch (error) {
    console.error('Failed to handle transaction update:', error)
  }
}

async function handleCustomerChange(payload: any) {
  try {
    const customerAnalytics = await generateCustomerAnalytics(payload.new)
    await adlsPipeline.uploadAnalyticsData(customerAnalytics, 'customer-insights')
  } catch (error) {
    console.error('Failed to handle customer change:', error)
  }
}

function getChanges(oldData: any, newData: any) {
  const changes: any = {}
  
  for (const key in newData) {
    if (oldData[key] !== newData[key]) {
      changes[key] = {
        from: oldData[key],
        to: newData[key]
      }
    }
  }
  
  return changes
}

async function updateRealtimeAnalytics(transaction: any) {
  // Implementation for real-time analytics updates
  // This could trigger Azure Functions or update caches
}

async function generateCustomerAnalytics(customer: any) {
  // Generate customer-specific analytics
  return {
    customerId: customer.id,
    segmentation: await calculateCustomerSegment(customer),
    lifetimeValue: await calculateLTV(customer),
    riskScore: await calculateChurnRisk(customer),
    generatedAt: new Date().toISOString()
  }
}

async function calculateCustomerSegment(customer: any) {
  // Customer segmentation logic
  return 'premium' // placeholder
}

async function calculateLTV(customer: any) {
  // Lifetime value calculation
  return 0 // placeholder
}

async function calculateChurnRisk(customer: any) {
  // Churn risk calculation
  return 0 // placeholder
}
```

## ⚙️ 5. Vercel-Azure OIDC Federation

### Azure Configuration

```typescript
// scripts/setup-azure-oidc.ts
import { DefaultAzureCredential } from '@azure/identity'
import { GraphServiceClient } from '@microsoft/graph-core'

const credential = new DefaultAzureCredential()

export async function setupVercelOIDC() {
  const teamSlug = process.env.VERCEL_TEAM_SLUG
  const projectName = process.env.VERCEL_PROJECT_NAME
  
  const federatedCredential = {
    name: `vercel-${projectName}-production`,
    issuer: `https://oidc.vercel.com/${teamSlug}`,
    subject: `owner:${teamSlug}:project:${projectName}:environment:production`,
    audiences: ['api://AzureADTokenExchange'],
    description: 'Vercel OIDC federation for Scout Analytics'
  }
  
  console.log('Configure this federated credential in Azure AD:')
  console.log(JSON.stringify(federatedCredential, null, 2))
  
  return federatedCredential
}

// Role assignments for ADLS2 access
export const adlsRoleAssignments = [
  {
    roleDefinitionName: 'Storage Blob Data Contributor',
    scope: '/subscriptions/{subscription-id}/resourceGroups/scout-production-rg/providers/Microsoft.Storage/storageAccounts/scoutdatalake'
  },
  {
    roleDefinitionName: 'Storage Blob Data Reader',
    scope: '/subscriptions/{subscription-id}/resourceGroups/scout-production-rg/providers/Microsoft.Storage/storageAccounts/scoutdatalake/blobServices/default/containers/analytics'
  }
]
```

### Vercel Environment Configuration

```bash
# .env.local (for local development)
# These should be configured in Vercel dashboard for production

# Supabase Configuration
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
POSTGRES_URL=postgresql://postgres:password@db.your-project.supabase.co:6543/postgres?pgbouncer=true

# Azure Configuration
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id
AZURE_KEYVAULT_NAME=scout-kv-xxxxx
ADLS_ACCOUNT_NAME=scoutdatalake
ADLS_FILESYSTEM_NAME=scout-data

# Azure OpenAI Configuration
AZURE_OPENAI_API_KEY=your-openai-key
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4

# Azure PostgreSQL (if using direct connection)
AZURE_POSTGRES_HOST=scout-postgres.postgres.database.azure.com
AZURE_POSTGRES_DB=scoutdb
AZURE_POSTGRES_USER=scoutadmin
AZURE_POSTGRES_PASSWORD=your-secure-password

# Vercel OIDC Configuration
VERCEL_TEAM_SLUG=your-team-slug
VERCEL_PROJECT_NAME=scout-analytics-prod
```

## 💡 6. Cost & Performance Optimization

### ADLS2 Lifecycle Policies

```json
{
  "rules": [
    {
      "name": "scout-analytics-lifecycle",
      "enabled": true,
      "type": "Lifecycle",
      "definition": {
        "filters": {
          "prefixMatch": ["raw-data/", "analytics/"],
          "blobTypes": ["blockBlob"]
        },
        "actions": {
          "baseBlob": {
            "tierToCool": {
              "daysAfterModificationGreaterThan": 30
            },
            "tierToArchive": {
              "daysAfterModificationGreaterThan": 90
            },
            "delete": {
              "daysAfterModificationGreaterThan": 365
            }
          }
        }
      }
    }
  ]
}
```

### Vercel KV Caching

```typescript
// lib/cache/vercel-kv.ts
import { kv } from '@vercel/kv'

export class VercelCache {
  private static readonly TTL = {
    SHORT: 60 * 5,      // 5 minutes
    MEDIUM: 60 * 30,    // 30 minutes
    LONG: 60 * 60 * 24  // 24 hours
  }

  static async cacheSupabaseQuery(
    query: string,
    data: any,
    ttl: number = this.TTL.MEDIUM
  ) {
    const key = `supabase:${Buffer.from(query).toString('base64')}`
    await kv.setex(key, ttl, JSON.stringify(data))
    return key
  }

  static async getCachedQuery(query: string) {
    const key = `supabase:${Buffer.from(query).toString('base64')}`
    const cached = await kv.get(key)
    return cached ? JSON.parse(cached as string) : null
  }

  static async cacheAIResponse(
    prompt: string,
    response: string,
    ttl: number = this.TTL.LONG
  ) {
    const key = `ai:${Buffer.from(prompt).toString('base64')}`
    await kv.setex(key, ttl, response)
    return key
  }

  static async getCachedAIResponse(prompt: string) {
    const key = `ai:${Buffer.from(prompt).toString('base64')}`
    return await kv.get(key) as string | null
  }

  static async invalidatePattern(pattern: string) {
    // Note: Vercel KV doesn't support pattern deletion
    // Consider implementing a key tracking system for bulk invalidation
    console.warn('Pattern invalidation not directly supported in Vercel KV')
  }
}
```

### Supavisor Connection Optimization

```typescript
// lib/supabase/connection-optimizer.ts
export class ConnectionOptimizer {
  private static connectionPools = new Map<string, any>()

  static getOptimizedClient(environment: 'serverless' | 'persistent' = 'serverless') {
    const cacheKey = `${environment}-${process.env.NEXT_PUBLIC_SUPABASE_URL}`
    
    if (this.connectionPools.has(cacheKey)) {
      return this.connectionPools.get(cacheKey)
    }

    let client
    if (environment === 'serverless') {
      // Use transaction mode for serverless (port 6543)
      client = createClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
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
              'Connection': 'close'
            }
          }
        }
      )
    } else {
      // Use session mode for persistent connections (port 5432)
      const sessionUrl = process.env.POSTGRES_URL?.replace(':6543', ':5432')
        .replace('pgbouncer=true', 'pgbouncer=false')
      
      client = createClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.SUPABASE_SERVICE_ROLE_KEY!,
        {
          db: {
            schema: 'public',
          }
        }
      )
    }

    this.connectionPools.set(cacheKey, client)
    return client
  }

  static async healthCheck() {
    try {
      const client = this.getOptimizedClient('serverless')
      const { data, error } = await client
        .from('health_check')
        .select('*')
        .limit(1)
      
      return { success: !error, error: error?.message }
    } catch (err) {
      return { success: false, error: err.message }
    }
  }
}
```

## ⚠️ 7. Troubleshooting Common Issues

### Diagnostic Tools

```typescript
// lib/diagnostics/integration-test.ts
export class IntegrationDiagnostics {
  static async runFullDiagnostics() {
    const results = {
      supabase: await this.testSupabase(),
      azurePostgres: await this.testAzurePostgres(),
      azureOpenAI: await this.testAzureOpenAI(),
      adls: await this.testADLS(),
      vercelKV: await this.testVercelKV()
    }

    return {
      allPassed: Object.values(results).every(r => r.success),
      results
    }
  }

  private static async testSupabase() {
    try {
      const { data, error } = await supabase
        .from('brands')
        .select('count')
        .limit(1)
      
      return {
        success: !error,
        message: error?.message || 'Supabase connection successful',
        latency: Date.now() // Add timing logic
      }
    } catch (err) {
      return {
        success: false,
        message: `Supabase error: ${err.message}`,
        troubleshooting: [
          'Check NEXT_PUBLIC_SUPABASE_URL and SUPABASE_ANON_KEY',
          'Verify Supabase project is active',
          'Check firewall/network settings',
          'Try incognito mode if using browser'
        ]
      }
    }
  }

  private static async testAzurePostgres() {
    try {
      const { success, version, error } = await testAzureConnection()
      return {
        success,
        message: success ? `Connected to ${version}` : error,
        troubleshooting: success ? [] : [
          'Check Azure NSG rules for port 5432',
          'Verify SSL certificates are valid',
          'Check Azure Key Vault permissions',
          'Ensure managed identity is configured'
        ]
      }
    } catch (err) {
      return {
        success: false,
        message: `Azure PostgreSQL error: ${err.message}`,
        troubleshooting: [
          'Verify AZURE_POSTGRES_* environment variables',
          'Check Azure PostgreSQL firewall rules',
          'Ensure SSL is properly configured'
        ]
      }
    }
  }

  private static async testAzureOpenAI() {
    try {
      const completion = await openai.chat.completions.create({
        model: 'gpt-3.5-turbo',
        messages: [{ role: 'user', content: 'Test connection' }],
        max_tokens: 5
      })
      
      return {
        success: true,
        message: 'Azure OpenAI connection successful',
        usage: completion.usage
      }
    } catch (err) {
      return {
        success: false,
        message: `Azure OpenAI error: ${err.message}`,
        troubleshooting: [
          'Check AZURE_OPENAI_API_KEY and AZURE_OPENAI_ENDPOINT',
          'Verify deployment name is correct',
          'Check Azure OpenAI resource quotas',
          'Ensure API version is supported'
        ]
      }
    }
  }

  private static async testADLS() {
    try {
      const files = await adlsPipeline.listFiles('raw-data')
      return {
        success: true,
        message: `ADLS2 connection successful, found ${files.length} files`,
        fileCount: files.length
      }
    } catch (err) {
      return {
        success: false,
        message: `ADLS2 error: ${err.message}`,
        troubleshooting: [
          'Check ADLS_ACCOUNT_NAME and ADLS_FILESYSTEM_NAME',
          'Verify managed identity has Storage Blob Data Contributor role',
          'Check network access rules on storage account',
          'Ensure filesystem exists'
        ]
      }
    }
  }

  private static async testVercelKV() {
    try {
      await kv.set('test-key', 'test-value', { ex: 10 })
      const value = await kv.get('test-key')
      await kv.del('test-key')
      
      return {
        success: value === 'test-value',
        message: 'Vercel KV connection successful'
      }
    } catch (err) {
      return {
        success: false,
        message: `Vercel KV error: ${err.message}`,
        troubleshooting: [
          'Check if Vercel KV is enabled for your project',
          'Verify KV environment variables are set',
          'Check Vercel KV dashboard for connection issues'
        ]
      }
    }
  }
}
```

### Error Handling Utilities

```typescript
// lib/utils/error-handling.ts
export class ErrorHandler {
  static handleSupabaseError(error: any) {
    const errorMap = {
      'PGRST116': 'No rows found - check your query filters',
      'PGRST301': 'Row Level Security policy violation',
      '08P01': 'Connection timeout - try again or check network',
      '28P01': 'Password authentication failed - rotate credentials',
      '3D000': 'Database does not exist - check database name'
    }

    const code = error.code
    const hint = errorMap[code] || 'Unknown Supabase error'
    
    console.error(`Supabase Error [${code}]: ${error.message}`)
    console.error(`Hint: ${hint}`)
    
    return {
      code,
      message: error.message,
      hint,
      action: this.getActionForError(code)
    }
  }

  static handleAzureError(error: any) {
    if (error.code === 'ENOTFOUND') {
      return {
        message: 'DNS resolution failed',
        action: 'Check network connectivity and DNS settings'
      }
    }
    
    if (error.code === 'ECONNREFUSED') {
      return {
        message: 'Connection refused',
        action: 'Check firewall rules and service availability'
      }
    }
    
    if (error.statusCode === 401) {
      return {
        message: 'Authentication failed',
        action: 'Check credentials and permissions'
      }
    }
    
    if (error.statusCode === 403) {
      return {
        message: 'Authorization failed',
        action: 'Check RBAC permissions and resource access'
      }
    }
    
    return {
      message: error.message || 'Unknown Azure error',
      action: 'Check Azure service status and configuration'
    }
  }

  private static getActionForError(code: string): string {
    const actions = {
      'PGRST116': 'Verify your query parameters and try a broader filter',
      'PGRST301': 'Check user permissions or use service role key',
      '08P01': 'Retry the request or switch to session mode',
      '28P01': 'Rotate password in Supabase dashboard and update env vars',
      '3D000': 'Verify POSTGRES_URL database name is correct'
    }
    
    return actions[code] || 'Contact support if issue persists'
  }
}
```

## ✅ Implementation Checklist

### Phase 1: Basic Integration
- [ ] Connect Supabase in Vercel marketplace
- [ ] Configure Supavisor transaction mode for serverless functions
- [ ] Set up Azure Key Vault for credential storage
- [ ] Configure Azure OpenAI endpoint and test connectivity
- [ ] Create ADLS2 containers and set up access permissions

### Phase 2: Security & OIDC
- [ ] Set up Azure AD application registration
- [ ] Configure Vercel OIDC federation
- [ ] Assign RBAC roles for ADLS2 access
- [ ] Enable SSL/TLS for all database connections
- [ ] Implement secure credential rotation

### Phase 3: Performance Optimization
- [ ] Implement Vercel KV caching for frequent queries
- [ ] Set up ADLS2 lifecycle policies
- [ ] Configure CDN caching for static assets
- [ ] Optimize database connection pooling
- [ ] Set up monitoring and alerting

### Phase 4: Production Hardening
- [ ] Implement comprehensive error handling
- [ ] Set up health checks and diagnostics
- [ ] Configure backup and disaster recovery
- [ ] Implement rate limiting and security headers
- [ ] Set up cost monitoring and budgets

## 📚 Additional Resources

- [Supabase-Vercel Integration Guide](https://supabase.com/docs/guides/database/connecting-to-postgres)
- [Azure OIDC with Vercel](https://vercel.com/docs/oidc/azure)
- [ADLS2 Best Practices](https://docs.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-best-practices)
- [Azure OpenAI Service Documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/openai/)
- [Vercel Edge Functions Guide](https://vercel.com/docs/concepts/functions/edge-functions)

This integration provides a robust, scalable, and secure foundation for Scout Analytics with enterprise-grade performance and monitoring capabilities.