/**
 * Supabase-Vercel Optimized Client
 * Handles connection pooling, caching, and serverless optimization
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js'
import { kv } from '@vercel/kv'

interface ConnectionConfig {
  mode: 'serverless' | 'persistent'
  pooling: boolean
  ssl: boolean
  caching: boolean
}

interface QueryCache {
  key: string
  data: any
  ttl: number
  timestamp: number
}

export class VercelOptimizedSupabase {
  private static instances = new Map<string, SupabaseClient>()
  private static readonly CACHE_PREFIX = 'supabase-query:'
  private static readonly DEFAULT_TTL = 300 // 5 minutes

  /**
   * Get optimized Supabase client for Vercel environment
   */
  static getClient(config: Partial<ConnectionConfig> = {}): SupabaseClient {
    const defaultConfig: ConnectionConfig = {
      mode: 'serverless',
      pooling: true,
      ssl: true,
      caching: true
    }

    const finalConfig = { ...defaultConfig, ...config }
    const cacheKey = this.getClientCacheKey(finalConfig)

    if (this.instances.has(cacheKey)) {
      return this.instances.get(cacheKey)!
    }

    const client = this.createOptimizedClient(finalConfig)
    this.instances.set(cacheKey, client)

    return client
  }

  private static createOptimizedClient(config: ConnectionConfig): SupabaseClient {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
    const key = config.mode === 'serverless' 
      ? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
      : process.env.SUPABASE_SERVICE_ROLE_KEY!

    // Configure connection string based on mode
    let postgresUrl = process.env.POSTGRES_URL!
    
    if (config.mode === 'serverless' && config.pooling) {
      // Use Supavisor transaction mode for serverless (port 6543)
      postgresUrl = postgresUrl.includes('pgbouncer=true') 
        ? postgresUrl 
        : postgresUrl.replace(':5432', ':6543') + '?pgbouncer=true&connection_limit=1'
    } else {
      // Use direct connection or session mode (port 5432)
      postgresUrl = postgresUrl.replace(':6543', ':5432').replace('pgbouncer=true', 'pgbouncer=false')
    }

    const clientOptions = {
      db: {
        schema: 'public',
      },
      auth: {
        autoRefreshToken: config.mode === 'persistent',
        persistSession: config.mode === 'persistent',
        detectSessionInUrl: false
      },
      global: {
        headers: {
          'x-client-info': `scout-analytics-${config.mode}`,
          ...(config.mode === 'serverless' && { 'Connection': 'close' })
        }
      }
    }

    console.log(`🔗 Creating ${config.mode} Supabase client with ${config.pooling ? 'pooling' : 'direct'} connection`)

    return createClient(supabaseUrl, key, clientOptions)
  }

  private static getClientCacheKey(config: ConnectionConfig): string {
    return `${config.mode}-${config.pooling}-${config.ssl}-${config.caching}`
  }

  /**
   * Execute query with caching support
   */
  static async queryWithCache<T = any>(
    query: () => Promise<{ data: T | null; error: any }>,
    cacheKey: string,
    ttl: number = this.DEFAULT_TTL
  ): Promise<{ data: T | null; error: any; fromCache: boolean }> {
    try {
      // Check cache first
      const cachedResult = await this.getCachedQuery(cacheKey)
      if (cachedResult) {
        return { ...cachedResult, fromCache: true }
      }

      // Execute query
      const result = await query()
      
      // Cache successful results
      if (!result.error && result.data) {
        await this.setCachedQuery(cacheKey, result, ttl)
      }

      return { ...result, fromCache: false }
    } catch (error) {
      console.error('Query execution error:', error)
      return { data: null, error, fromCache: false }
    }
  }

  private static async getCachedQuery(key: string): Promise<any | null> {
    try {
      const cached = await kv.get(`${this.CACHE_PREFIX}${key}`)
      if (!cached) return null

      const queryCache = cached as QueryCache
      
      // Check if cache is still valid
      if (Date.now() - queryCache.timestamp > queryCache.ttl * 1000) {
        await kv.del(`${this.CACHE_PREFIX}${key}`)
        return null
      }

      return queryCache.data
    } catch (error) {
      console.error('Cache read error:', error)
      return null
    }
  }

  private static async setCachedQuery(key: string, data: any, ttl: number): Promise<void> {
    try {
      const queryCache: QueryCache = {
        key,
        data,
        ttl,
        timestamp: Date.now()
      }

      await kv.setex(`${this.CACHE_PREFIX}${key}`, ttl, queryCache)
    } catch (error) {
      console.error('Cache write error:', error)
    }
  }

  /**
   * Invalidate cache entries by pattern
   */
  static async invalidateCache(pattern: string): Promise<void> {
    try {
      // Note: Vercel KV doesn't support pattern-based deletion
      // This is a simplified implementation
      console.log(`Cache invalidation requested for pattern: ${pattern}`)
      
      // For now, we'll need to track keys manually or implement a different strategy
      // Consider using a separate tracking mechanism for bulk invalidation
    } catch (error) {
      console.error('Cache invalidation error:', error)
    }
  }

  /**
   * Health check for Supabase connection
   */
  static async healthCheck(): Promise<{
    success: boolean
    latency: number
    error?: string
    connectionMode?: string
  }> {
    const start = Date.now()
    
    try {
      const client = this.getClient({ mode: 'serverless' })
      
      const { data, error } = await client
        .from('brands')
        .select('count')
        .limit(1)

      const latency = Date.now() - start

      if (error) {
        return {
          success: false,
          latency,
          error: error.message,
          connectionMode: 'serverless'
        }
      }

      return {
        success: true,
        latency,
        connectionMode: 'serverless'
      }
    } catch (error) {
      return {
        success: false,
        latency: Date.now() - start,
        error: error.message,
        connectionMode: 'serverless'
      }
    }
  }

  /**
   * Test different connection modes
   */
  static async testConnectionModes(): Promise<{
    serverless: any
    persistent: any
    recommendation: string
  }> {
    const results = {
      serverless: await this.testConnectionMode('serverless'),
      persistent: await this.testConnectionMode('persistent'),
      recommendation: ''
    }

    // Determine recommendation based on results
    if (results.serverless.success && results.persistent.success) {
      results.recommendation = results.serverless.latency < results.persistent.latency 
        ? 'Use serverless mode for better performance'
        : 'Use persistent mode for better performance'
    } else if (results.serverless.success) {
      results.recommendation = 'Use serverless mode (persistent mode failed)'
    } else if (results.persistent.success) {
      results.recommendation = 'Use persistent mode (serverless mode failed)'
    } else {
      results.recommendation = 'Both modes failed - check configuration'
    }

    return results
  }

  private static async testConnectionMode(mode: 'serverless' | 'persistent'): Promise<{
    success: boolean
    latency: number
    error?: string
  }> {
    const start = Date.now()
    
    try {
      const client = this.getClient({ mode })
      
      const { data, error } = await client
        .from('brands')
        .select('count')
        .limit(1)

      const latency = Date.now() - start

      return {
        success: !error,
        latency,
        error: error?.message
      }
    } catch (error) {
      return {
        success: false,
        latency: Date.now() - start,
        error: error.message
      }
    }
  }

  /**
   * Optimized query patterns for common Scout Analytics queries
   */
  static async getTransactionMetrics(filters: any = {}) {
    const cacheKey = `transaction-metrics-${JSON.stringify(filters)}`
    
    return this.queryWithCache(
      async () => {
        const client = this.getClient()
        return await client.rpc('get_transaction_metrics', filters)
      },
      cacheKey,
      600 // 10 minutes cache
    )
  }

  static async getBrandPerformance(filters: any = {}) {
    const cacheKey = `brand-performance-${JSON.stringify(filters)}`
    
    return this.queryWithCache(
      async () => {
        const client = this.getClient()
        return await client.rpc('get_brand_performance', filters)
      },
      cacheKey,
      300 // 5 minutes cache
    )
  }

  static async getCustomerSegments(filters: any = {}) {
    const cacheKey = `customer-segments-${JSON.stringify(filters)}`
    
    return this.queryWithCache(
      async () => {
        const client = this.getClient()
        return await client.rpc('get_customer_segments', filters)
      },
      cacheKey,
      1800 // 30 minutes cache (segments change less frequently)
    )
  }

  /**
   * Real-time subscription setup for Scout Analytics
   */
  static setupRealtimeSubscriptions(handlers: {
    onTransactionInsert?: (payload: any) => void
    onCustomerUpdate?: (payload: any) => void
    onProductUpdate?: (payload: any) => void
  }) {
    const client = this.getClient({ mode: 'persistent' })

    const subscriptions = []

    if (handlers.onTransactionInsert) {
      const transactionSub = client
        .channel('transactions-realtime')
        .on(
          'postgres_changes',
          { event: 'INSERT', schema: 'public', table: 'transactions_fmcg' },
          handlers.onTransactionInsert
        )
        .subscribe()
      
      subscriptions.push(transactionSub)
    }

    if (handlers.onCustomerUpdate) {
      const customerSub = client
        .channel('customers-realtime')
        .on(
          'postgres_changes',
          { event: 'UPDATE', schema: 'public', table: 'customers' },
          handlers.onCustomerUpdate
        )
        .subscribe()
      
      subscriptions.push(customerSub)
    }

    if (handlers.onProductUpdate) {
      const productSub = client
        .channel('products-realtime')
        .on(
          'postgres_changes',
          { event: 'UPDATE', schema: 'public', table: 'products' },
          handlers.onProductUpdate
        )
        .subscribe()
      
      subscriptions.push(productSub)
    }

    console.log(`📡 Setup ${subscriptions.length} real-time subscriptions`)

    return {
      subscriptions,
      unsubscribeAll: () => {
        subscriptions.forEach(sub => client.removeChannel(sub))
        console.log('📡 Unsubscribed from all real-time channels')
      }
    }
  }

  /**
   * Troubleshooting utilities
   */
  static async diagnoseConnection(): Promise<{
    status: 'healthy' | 'degraded' | 'error'
    issues: string[]
    recommendations: string[]
    tests: any[]
  }> {
    const issues: string[] = []
    const recommendations: string[] = []
    const tests: any[] = []

    // Test environment variables
    const envTest = this.testEnvironmentVariables()
    tests.push(envTest)
    if (!envTest.success) {
      issues.push('Missing or invalid environment variables')
      recommendations.push('Check all required Supabase environment variables are set')
    }

    // Test basic connectivity
    const connectivityTest = await this.healthCheck()
    tests.push(connectivityTest)
    if (!connectivityTest.success) {
      issues.push('Basic connectivity failed')
      recommendations.push('Check network connectivity and Supabase project status')
    }

    // Test connection modes
    const modeTest = await this.testConnectionModes()
    tests.push(modeTest)

    // Test caching
    const cacheTest = await this.testCaching()
    tests.push(cacheTest)
    if (!cacheTest.success) {
      issues.push('Caching system not working')
      recommendations.push('Check Vercel KV configuration')
    }

    let status: 'healthy' | 'degraded' | 'error' = 'healthy'
    if (issues.length > 0) {
      status = connectivityTest.success ? 'degraded' : 'error'
    }

    return {
      status,
      issues,
      recommendations,
      tests
    }
  }

  private static testEnvironmentVariables(): { success: boolean; missing: string[] } {
    const required = [
      'NEXT_PUBLIC_SUPABASE_URL',
      'NEXT_PUBLIC_SUPABASE_ANON_KEY',
      'SUPABASE_SERVICE_ROLE_KEY',
      'POSTGRES_URL'
    ]

    const missing = required.filter(varName => !process.env[varName])
    
    return {
      success: missing.length === 0,
      missing
    }
  }

  private static async testCaching(): Promise<{ success: boolean; error?: string }> {
    try {
      const testKey = 'test-cache-key'
      const testValue = { test: 'data', timestamp: Date.now() }
      
      await kv.setex(`${this.CACHE_PREFIX}${testKey}`, 10, testValue)
      const retrieved = await kv.get(`${this.CACHE_PREFIX}${testKey}`)
      await kv.del(`${this.CACHE_PREFIX}${testKey}`)
      
      return {
        success: JSON.stringify(retrieved) === JSON.stringify(testValue)
      }
    } catch (error) {
      return {
        success: false,
        error: error.message
      }
    }
  }

  /**
   * Cleanup all connections and caches
   */
  static cleanup(): void {
    this.instances.clear()
    console.log('🧹 Cleaned up all Supabase client instances')
  }
}

// Export convenience functions
export const getSupabaseClient = VercelOptimizedSupabase.getClient
export const queryWithCache = VercelOptimizedSupabase.queryWithCache
export const healthCheck = VercelOptimizedSupabase.healthCheck
export const setupRealtimeSubscriptions = VercelOptimizedSupabase.setupRealtimeSubscriptions

// Export the main class
export default VercelOptimizedSupabase