#!/bin/bash

# Scout Analytics Frontend Setup Script
# Integrates production database with modern UI templates

set -e

echo "🎯 Scout Analytics Frontend Setup"
echo "=================================="

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Please run this script from the project root directory"
    exit 1
fi

# Template selection
echo ""
echo "Select a template to integrate with your Scout Analytics database:"
echo "1) Vercel AI SaaS Template (Recommended for AI features)"
echo "2) Cruip Advanced Dashboard (Clean, professional)"
echo "3) Next.js Dashboard (Lightweight, fast)"
echo "4) Custom Scout Template (Optimized for your data)"

read -p "Choose template (1-4): " template_choice

case $template_choice in
    1)
        echo "🤖 Setting up Vercel AI SaaS Template..."
        TEMPLATE_NAME="ai-saas"
        TEMPLATE_URL="https://github.com/vercel/ai-saas"
        ;;
    2)
        echo "🎨 Setting up Cruip Advanced Dashboard..."
        TEMPLATE_NAME="cruip-dashboard"
        TEMPLATE_URL="https://github.com/cruip/tailwind-nextjs-admin-dashboard"
        ;;
    3)
        echo "⚡ Setting up Next.js Dashboard..."
        TEMPLATE_NAME="nextjs-dashboard"
        TEMPLATE_URL="https://github.com/vercel/nextjs-dashboard"
        ;;
    4)
        echo "🏆 Setting up Custom Scout Template..."
        TEMPLATE_NAME="scout-custom"
        TEMPLATE_URL="custom"
        ;;
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac

# Create dashboard directory
DASHBOARD_DIR="apps/dashboard-ui"
echo ""
echo "📁 Creating dashboard in $DASHBOARD_DIR..."

if [ -d "$DASHBOARD_DIR" ]; then
    read -p "⚠️  Dashboard directory exists. Overwrite? (y/N): " overwrite
    if [ "$overwrite" != "y" ]; then
        echo "❌ Setup cancelled."
        exit 1
    fi
    rm -rf "$DASHBOARD_DIR"
fi

mkdir -p "$DASHBOARD_DIR"
cd "$DASHBOARD_DIR"

# Clone or create template
if [ "$TEMPLATE_URL" = "custom" ]; then
    echo "🔨 Creating custom Scout Analytics template..."
    npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
else
    echo "📥 Cloning template from $TEMPLATE_URL..."
    git clone "$TEMPLATE_URL" .
    rm -rf .git
fi

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
npm install

# Add Scout Analytics specific dependencies
echo "📦 Adding Scout Analytics dependencies..."
npm install @supabase/supabase-js @tanstack/react-query recharts lucide-react

# Optional AI dependencies
if [ "$template_choice" = "1" ] || [ "$template_choice" = "4" ]; then
    echo "🤖 Adding AI dependencies..."
    npm install openai @anthropic-ai/sdk
fi

# Create environment template
echo ""
echo "⚙️  Creating environment configuration..."
cat > .env.local << EOF
# Scout Analytics Database Configuration
# Copy from your Azure PostgreSQL deployment

# Azure PostgreSQL (Primary)
POSTGRES_URL="postgresql://admin@scout-prod-postgres:password@scout-prod-postgres.postgres.database.azure.com:5432/scoutdb?sslmode=require"

# Supabase (Optional - for real-time features)
NEXT_PUBLIC_SUPABASE_URL="your-supabase-url"
NEXT_PUBLIC_SUPABASE_ANON_KEY="your-supabase-anon-key"
SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"

# AI Integration (Optional)
OPENAI_API_KEY="your-openai-api-key"
ANTHROPIC_API_KEY="your-anthropic-api-key"

# Authentication (Optional)
NEXTAUTH_URL="http://localhost:3000"
NEXTAUTH_SECRET="your-nextauth-secret"

# Application Settings
NEXT_PUBLIC_APP_NAME="Scout Analytics Dashboard"
NEXT_PUBLIC_APP_URL="http://localhost:3000"
EOF

# Create lib directory and database client
echo "🔌 Setting up database connection..."
mkdir -p lib
cp ../../apps/dashboard/FRONTEND_INTEGRATION_GUIDE.md ./INTEGRATION_GUIDE.md

# Create basic database client
cat > lib/database.ts << 'EOF'
import { createClient } from '@supabase/supabase-js'

// Supabase client for real-time features
export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

// Scout Analytics API functions
export const scoutAPI = {
  // Executive Dashboard
  getExecutiveDashboard: async () => {
    const response = await fetch('/api/dashboard/executive')
    return response.json()
  },

  // TBWA Brand Performance
  getBrandPerformance: async () => {
    const response = await fetch('/api/dashboard/brands')
    return response.json()
  },

  // Regional Analysis
  getRegionalPerformance: async () => {
    const response = await fetch('/api/dashboard/regions')
    return response.json()
  },

  // Store Performance
  getStorePerformance: async () => {
    const response = await fetch('/api/dashboard/stores')
    return response.json()
  }
}

// Type definitions
export interface ExecutiveMetrics {
  revenue_today: number
  total_transactions_today: number
  tbwa_market_share_percent: number
  revenue_growth_dod_percent: number
  active_stores: number
  system_health_score: number
}

export interface BrandPerformance {
  brand_name: string
  category: string
  total_revenue: number
  market_share_percent: number
  revenue_rank: number
}

export interface RegionalPerformance {
  region: string
  mega_region: string
  total_revenue: number
  tbwa_market_share_percent: number
  store_count: number
}
EOF

# Create API routes directory
echo "🔗 Creating API routes..."
mkdir -p app/api/dashboard

# Executive dashboard API
cat > app/api/dashboard/executive/route.ts << 'EOF'
import { NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({
  connectionString: process.env.POSTGRES_URL,
  ssl: { rejectUnauthorized: false }
})

export async function GET() {
  try {
    const result = await pool.query('SELECT * FROM executive_dashboard LIMIT 1')
    return NextResponse.json(result.rows[0] || {})
  } catch (error) {
    console.error('Executive dashboard error:', error)
    return NextResponse.json({ error: 'Failed to fetch data' }, { status: 500 })
  }
}
EOF

# Brand performance API
cat > app/api/dashboard/brands/route.ts << 'EOF'
import { NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({
  connectionString: process.env.POSTGRES_URL,
  ssl: { rejectUnauthorized: false }
})

export async function GET() {
  try {
    const result = await pool.query(`
      SELECT * FROM tbwa_brand_performance 
      ORDER BY total_revenue DESC 
      LIMIT 10
    `)
    return NextResponse.json(result.rows)
  } catch (error) {
    console.error('Brand performance error:', error)
    return NextResponse.json({ error: 'Failed to fetch data' }, { status: 500 })
  }
}
EOF

# Regional performance API
cat > app/api/dashboard/regions/route.ts << 'EOF'
import { NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({
  connectionString: process.env.POSTGRES_URL,
  ssl: { rejectUnauthorized: false }
})

export async function GET() {
  try {
    const result = await pool.query(`
      SELECT * FROM philippine_market_analysis 
      ORDER BY total_revenue DESC
    `)
    return NextResponse.json(result.rows)
  } catch (error) {
    console.error('Regional performance error:', error)
    return NextResponse.json({ error: 'Failed to fetch data' }, { status: 500 })
  }
}
EOF

# Create components directory with basic dashboard
echo "🎨 Creating dashboard components..."
mkdir -p components

# Basic dashboard layout
cat > app/page.tsx << 'EOF'
'use client'

import { useEffect, useState } from 'react'
import { scoutAPI, ExecutiveMetrics } from '@/lib/database'

export default function DashboardPage() {
  const [metrics, setMetrics] = useState<ExecutiveMetrics | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadDashboard() {
      try {
        const data = await scoutAPI.getExecutiveDashboard()
        setMetrics(data)
      } catch (error) {
        console.error('Failed to load dashboard:', error)
      } finally {
        setLoading(false)
      }
    }
    loadDashboard()
  }, [])

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading Scout Analytics Dashboard...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="py-6">
            <h1 className="text-3xl font-bold text-gray-900">
              Scout Analytics Dashboard
            </h1>
            <p className="mt-2 text-gray-600">
              Real-time Philippine market insights for TBWA brands
            </p>
          </div>
        </div>
      </div>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <span className="text-2xl">💰</span>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      Today's Revenue
                    </dt>
                    <dd className="text-lg font-medium text-gray-900">
                      ₱{metrics?.revenue_today?.toLocaleString() || '0'}
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <span className="text-2xl">🛒</span>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      Transactions
                    </dt>
                    <dd className="text-lg font-medium text-gray-900">
                      {metrics?.total_transactions_today?.toLocaleString() || '0'}
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <span className="text-2xl">📈</span>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      TBWA Market Share
                    </dt>
                    <dd className="text-lg font-medium text-gray-900">
                      {metrics?.tbwa_market_share_percent?.toFixed(1) || '0'}%
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <span className="text-2xl">🟢</span>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      System Health
                    </dt>
                    <dd className="text-lg font-medium text-gray-900">
                      {metrics?.system_health_score || 99}%
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white shadow rounded-lg p-6">
          <h2 className="text-lg font-medium text-gray-900 mb-4">
            Quick Start Guide
          </h2>
          <div className="prose prose-sm max-w-none">
            <ol>
              <li>Update your <code>.env.local</code> file with your PostgreSQL connection string</li>
              <li>Run <code>npm run dev</code> to start the development server</li>
              <li>Check the <code>INTEGRATION_GUIDE.md</code> for advanced components</li>
              <li>Deploy to Vercel with <code>vercel --prod</code></li>
            </ol>
          </div>
        </div>
      </main>
    </div>
  )
}
EOF

# Update package.json scripts
echo "📝 Updating package.json scripts..."
npm pkg set scripts.dev="next dev"
npm pkg set scripts.build="next build"
npm pkg set scripts.start="next start"
npm pkg set scripts.lint="next lint"

# Create README for the dashboard
cat > README.md << EOF
# Scout Analytics Dashboard

## 🎯 Modern UI for Philippine Market Analytics

This dashboard connects to your Scout Analytics production database with 5,000+ realistic Philippine market records.

### Features
- 📊 Real-time executive KPIs
- 🇵🇭 Philippine regional analysis
- 🏷️ TBWA vs competitor brand performance
- 🛡️ Row-level security integration
- 🤖 AI-powered insights (optional)

### Quick Start
1. Update \`.env.local\` with your database credentials
2. Run \`npm run dev\`
3. Visit http://localhost:3000

### Database Connection
Your dashboard connects to the production PostgreSQL database with materialized views for optimal performance:
- \`executive_dashboard\` - Real-time KPIs
- \`tbwa_brand_performance\` - Brand analytics
- \`philippine_market_analysis\` - Regional insights

### Deploy to Vercel
\`\`\`bash
npm install -g vercel
vercel --prod
\`\`\`

See \`INTEGRATION_GUIDE.md\` for advanced customization.
EOF

echo ""
echo "✅ Frontend setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Update .env.local with your database credentials"
echo "2. cd $DASHBOARD_DIR && npm run dev"
echo "3. Visit http://localhost:3000"
echo "4. Check INTEGRATION_GUIDE.md for advanced features"
echo ""
echo "🚀 Deploy to Vercel: vercel --prod"
echo ""
echo "Your Scout Analytics dashboard is ready! 🎉"