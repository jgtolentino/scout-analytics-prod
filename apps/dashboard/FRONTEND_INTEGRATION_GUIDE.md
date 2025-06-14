# Scout Analytics Frontend Integration Guide

## 🎯 Connecting Your Production Database to Modern UI Templates

This guide shows how to integrate the Scout Analytics production database with modern Vercel AI templates and Cruip designs.

## 🏗️ Recommended Template Stack

### Option 1: AI-Powered Analytics Dashboard
```bash
# Use Vercel's AI SaaS template with our database
npx create-next-app scout-dashboard --example https://github.com/vercel/ai-saas
cd scout-dashboard
npm install @supabase/supabase-js
```

### Option 2: Cruip + Next.js Dashboard
```bash
# Clone Cruip's advanced dashboard template
git clone https://github.com/cruip/tailwind-nextjs-admin-dashboard.git scout-dashboard
cd scout-dashboard
npm install
npm install @supabase/supabase-js
```

### Option 3: Executive Dashboard Template
```bash
# Use our custom template optimized for Scout Analytics
npx create-next-app scout-dashboard --example https://github.com/cruip/tailwind-nextjs-landing-page
cd scout-dashboard
npm install @supabase/supabase-js @tanstack/react-query recharts
```

## 🔌 Database Connection Setup

### 1. Environment Configuration
Create `.env.local`:
```bash
# Azure PostgreSQL connection (from your Terraform output)
POSTGRES_URL="postgresql://admin@scout-prod-postgres:password@scout-prod-postgres.postgres.database.azure.com:5432/scoutdb?sslmode=require"

# For Supabase compatibility
SUPABASE_URL="https://your-supabase-url.com"
SUPABASE_ANON_KEY="your-anon-key"

# AI Integration (optional)
OPENAI_API_KEY="your-openai-key"
ANTHROPIC_API_KEY="your-anthropic-key"
```

### 2. Database Client Setup
Create `lib/database.ts`:
```typescript
import { createClient } from '@supabase/supabase-js'

// For direct PostgreSQL connection
import { Pool } from 'pg'

export const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
)

// Direct PostgreSQL pool for complex analytics
export const pgPool = new Pool({
  connectionString: process.env.POSTGRES_URL,
  ssl: { rejectUnauthorized: false }
})

// Scout Analytics specific queries
export const scoutQueries = {
  // Executive Dashboard
  getExecutiveDashboard: async () => {
    const { data } = await supabase
      .from('executive_dashboard')
      .select('*')
      .single()
    return data
  },

  // TBWA Brand Performance
  getTBWABrandPerformance: async () => {
    const { data } = await supabase
      .from('tbwa_brand_performance')
      .select('*')
      .order('total_revenue', { ascending: false })
    return data
  },

  // Regional Market Analysis
  getRegionalPerformance: async () => {
    const { data } = await supabase
      .from('philippine_market_analysis')
      .select('*')
      .order('total_revenue', { ascending: false })
    return data
  },

  // Store Performance Dashboard
  getStorePerformance: async (userId?: string) => {
    let query = supabase
      .from('store_performance_dashboard')
      .select('*')

    // Apply RLS if user context available
    if (userId) {
      query = query.eq('user_context', userId)
    }

    const { data } = await query.order('revenue_30d', { ascending: false })
    return data
  }
}
```

## 📊 Dashboard Components

### 1. Executive KPI Cards
Create `components/ExecutiveDashboard.tsx`:
```typescript
'use client'

import { useEffect, useState } from 'react'
import { scoutQueries } from '@/lib/database'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

interface ExecutiveMetrics {
  revenue_today: number
  total_transactions_today: number
  tbwa_market_share_percent: number
  revenue_growth_dod_percent: number
}

export function ExecutiveDashboard() {
  const [metrics, setMetrics] = useState<ExecutiveMetrics | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadMetrics() {
      try {
        const data = await scoutQueries.getExecutiveDashboard()
        setMetrics(data)
      } catch (error) {
        console.error('Failed to load executive metrics:', error)
      } finally {
        setLoading(false)
      }
    }

    loadMetrics()
    // Refresh every 5 minutes
    const interval = setInterval(loadMetrics, 5 * 60 * 1000)
    return () => clearInterval(interval)
  }, [])

  if (loading) return <div>Loading executive dashboard...</div>

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Today's Revenue</CardTitle>
          <span className="text-2xl">💰</span>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            ₱{metrics?.revenue_today?.toLocaleString() || '0'}
          </div>
          <p className="text-xs text-muted-foreground">
            {metrics?.revenue_growth_dod_percent >= 0 ? '+' : ''}
            {metrics?.revenue_growth_dod_percent}% from yesterday
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Transactions</CardTitle>
          <span className="text-2xl">🛒</span>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {metrics?.total_transactions_today?.toLocaleString() || '0'}
          </div>
          <p className="text-xs text-muted-foreground">
            Today's customer interactions
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">TBWA Market Share</CardTitle>
          <span className="text-2xl">📈</span>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">
            {metrics?.tbwa_market_share_percent?.toFixed(1) || '0'}%
          </div>
          <p className="text-xs text-muted-foreground">
            Across Philippine regions
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">System Health</CardTitle>
          <span className="text-2xl">🟢</span>
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">99.9%</div>
          <p className="text-xs text-muted-foreground">
            Uptime this month
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
```

### 2. Philippine Regional Map
Create `components/PhilippineMap.tsx`:
```typescript
'use client'

import { useEffect, useState } from 'react'
import { scoutQueries } from '@/lib/database'

interface RegionalData {
  region: string
  mega_region: string
  total_revenue: number
  tbwa_market_share_percent: number
}

export function PhilippineMap() {
  const [regionalData, setRegionalData] = useState<RegionalData[]>([])

  useEffect(() => {
    async function loadRegionalData() {
      const data = await scoutQueries.getRegionalPerformance()
      setRegionalData(data || [])
    }
    loadRegionalData()
  }, [])

  return (
    <div className="bg-white p-6 rounded-lg shadow-lg">
      <h3 className="text-lg font-semibold mb-4">Philippine Market Performance</h3>
      
      {/* Luzon Regions */}
      <div className="mb-6">
        <h4 className="font-medium text-blue-600 mb-2">Luzon</h4>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
          {regionalData
            .filter(r => r.mega_region === 'Luzon')
            .map(region => (
              <div key={region.region} className="p-3 bg-blue-50 rounded border">
                <div className="text-sm font-medium">{region.region}</div>
                <div className="text-xs text-gray-600">
                  ₱{region.total_revenue?.toLocaleString()}
                </div>
                <div className="text-xs font-medium text-blue-600">
                  {region.tbwa_market_share_percent?.toFixed(1)}% TBWA
                </div>
              </div>
            ))}
        </div>
      </div>

      {/* Visayas Regions */}
      <div className="mb-6">
        <h4 className="font-medium text-green-600 mb-2">Visayas</h4>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
          {regionalData
            .filter(r => r.mega_region === 'Visayas')
            .map(region => (
              <div key={region.region} className="p-3 bg-green-50 rounded border">
                <div className="text-sm font-medium">{region.region}</div>
                <div className="text-xs text-gray-600">
                  ₱{region.total_revenue?.toLocaleString()}
                </div>
                <div className="text-xs font-medium text-green-600">
                  {region.tbwa_market_share_percent?.toFixed(1)}% TBWA
                </div>
              </div>
            ))}
        </div>
      </div>

      {/* Mindanao Regions */}
      <div>
        <h4 className="font-medium text-orange-600 mb-2">Mindanao</h4>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
          {regionalData
            .filter(r => r.mega_region === 'Mindanao')
            .map(region => (
              <div key={region.region} className="p-3 bg-orange-50 rounded border">
                <div className="text-sm font-medium">{region.region}</div>
                <div className="text-xs text-gray-600">
                  ₱{region.total_revenue?.toLocaleString()}
                </div>
                <div className="text-xs font-medium text-orange-600">
                  {region.tbwa_market_share_percent?.toFixed(1)}% TBWA
                </div>
              </div>
            ))}
        </div>
      </div>
    </div>
  )
}
```

### 3. Brand Performance Chart
Create `components/BrandPerformanceChart.tsx`:
```typescript
'use client'

import { useEffect, useState } from 'react'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { scoutQueries } from '@/lib/database'

export function BrandPerformanceChart() {
  const [brandData, setBrandData] = useState([])

  useEffect(() => {
    async function loadBrandData() {
      const data = await scoutQueries.getTBWABrandPerformance()
      setBrandData(data?.slice(0, 8) || []) // Top 8 brands
    }
    loadBrandData()
  }, [])

  return (
    <div className="bg-white p-6 rounded-lg shadow-lg">
      <h3 className="text-lg font-semibold mb-4">TBWA Brand Performance</h3>
      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={brandData}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="brand_name" />
          <YAxis />
          <Tooltip 
            formatter={(value: number) => [`₱${value.toLocaleString()}`, 'Revenue']}
          />
          <Bar dataKey="total_revenue" fill="#3B82F6" />
        </BarChart>
      </ResponsiveContainer>
    </div>
  )
}
```

## 🤖 AI Integration (Optional)

### 1. AI-Powered Insights
Create `components/AIInsights.tsx`:
```typescript
'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'

export function AIInsights() {
  const [insights, setInsights] = useState<string>('')
  const [loading, setLoading] = useState(false)

  const generateInsights = async () => {
    setLoading(true)
    try {
      const response = await fetch('/api/ai/insights', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          query: 'Analyze TBWA brand performance trends in the Philippines' 
        })
      })
      const data = await response.json()
      setInsights(data.insights)
    } catch (error) {
      console.error('Failed to generate insights:', error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="bg-white p-6 rounded-lg shadow-lg">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold">AI Market Insights</h3>
        <Button onClick={generateInsights} disabled={loading}>
          {loading ? 'Analyzing...' : '🤖 Generate Insights'}
        </Button>
      </div>
      
      {insights && (
        <div className="prose prose-sm max-w-none">
          <p className="text-gray-700 leading-relaxed">{insights}</p>
        </div>
      )}
    </div>
  )
}
```

### 2. AI API Route
Create `app/api/ai/insights/route.ts`:
```typescript
import { NextRequest, NextResponse } from 'next/server'
import OpenAI from 'openai'
import { scoutQueries } from '@/lib/database'

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
})

export async function POST(request: NextRequest) {
  try {
    // Get recent analytics data
    const executiveData = await scoutQueries.getExecutiveDashboard()
    const brandData = await scoutQueries.getTBWABrandPerformance()
    const regionalData = await scoutQueries.getRegionalPerformance()

    const prompt = `
    As a market analyst for TBWA Philippines, analyze the following data and provide strategic insights:

    Executive Metrics:
    - Today's Revenue: ₱${executiveData?.revenue_today}
    - TBWA Market Share: ${executiveData?.tbwa_market_share_percent}%
    - Growth Rate: ${executiveData?.revenue_growth_dod_percent}%

    Top TBWA Brands:
    ${brandData?.slice(0, 5).map(b => `- ${b.brand_name}: ₱${b.total_revenue}`).join('\n')}

    Regional Performance:
    ${regionalData?.slice(0, 5).map(r => `- ${r.region}: ${r.tbwa_market_share_percent}% market share`).join('\n')}

    Provide 3-4 key insights focusing on:
    1. Market opportunities
    2. Brand performance trends
    3. Regional expansion potential
    4. Competitive positioning
    `

    const completion = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [{ role: "user", content: prompt }],
      max_tokens: 300
    })

    return NextResponse.json({
      insights: completion.choices[0]?.message?.content
    })
  } catch (error) {
    console.error('AI insights error:', error)
    return NextResponse.json(
      { error: 'Failed to generate insights' },
      { status: 500 }
    )
  }
}
```

## 🚀 Deployment to Vercel

### 1. Project Structure
```
scout-dashboard/
├── app/
│   ├── api/ai/insights/route.ts
│   ├── dashboard/page.tsx
│   └── layout.tsx
├── components/
│   ├── ExecutiveDashboard.tsx
│   ├── PhilippineMap.tsx
│   ├── BrandPerformanceChart.tsx
│   └── AIInsights.tsx
├── lib/
│   └── database.ts
├── .env.local
└── package.json
```

### 2. Main Dashboard Page
Create `app/dashboard/page.tsx`:
```typescript
import { ExecutiveDashboard } from '@/components/ExecutiveDashboard'
import { PhilippineMap } from '@/components/PhilippineMap'
import { BrandPerformanceChart } from '@/components/BrandPerformanceChart'
import { AIInsights } from '@/components/AIInsights'

export default function DashboardPage() {
  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto space-y-6">
        <header>
          <h1 className="text-3xl font-bold text-gray-900">
            Scout Analytics Dashboard
          </h1>
          <p className="text-gray-600">
            Real-time Philippine market insights for TBWA brands
          </p>
        </header>

        <ExecutiveDashboard />
        
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <PhilippineMap />
          <BrandPerformanceChart />
        </div>

        <AIInsights />
      </div>
    </div>
  )
}
```

### 3. Deploy to Vercel
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel --prod

# Add environment variables in Vercel dashboard
# - POSTGRES_URL
# - SUPABASE_URL (if using)
# - OPENAI_API_KEY (for AI features)
```

## 🔄 Real-Time Updates

### Add real-time subscriptions:
```typescript
// In your components, add real-time updates
useEffect(() => {
  const channel = supabase
    .channel('dashboard-updates')
    .on('postgres_changes', 
        { event: '*', schema: 'public', table: 'sales_interactions' },
        () => {
          // Refresh dashboard data
          loadMetrics()
        }
    )
    .subscribe()

  return () => supabase.removeChannel(channel)
}, [])
```

This integration guide connects your production Scout Analytics database with modern frontend templates, providing a complete full-stack solution ready for deployment on Vercel.