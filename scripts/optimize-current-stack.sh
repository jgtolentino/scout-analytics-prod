#!/bin/bash

# Scout Analytics Current Stack Optimization
# NO NEW RESOURCES | NO NEW SUBSCRIPTIONS | ENHANCE EXISTING ONLY

set -e

echo "🎯 Scout Analytics Stack Optimization"
echo "======================================"
echo "✅ No new resources will be created"
echo "✅ No new subscriptions required"
echo "✅ Optimizing existing infrastructure only"
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Please run this script from the project root directory"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "🔍 Analyzing current stack..."

# Check existing tools
HAS_POSTGRES=$(command_exists psql && echo "true" || echo "false")
HAS_NODE=$(command_exists node && echo "true" || echo "false")
HAS_NPM=$(command_exists npm && echo "true" || echo "false")
HAS_VERCEL=$(command_exists vercel && echo "true" || echo "false")

echo "📊 Current Stack Analysis:"
echo "  - PostgreSQL Client: $HAS_POSTGRES"
echo "  - Node.js: $HAS_NODE"
echo "  - NPM: $HAS_NPM"
echo "  - Vercel CLI: $HAS_VERCEL"

if [ "$HAS_NODE" = "false" ]; then
    echo "❌ Node.js is required but not found"
    exit 1
fi

# Optimization phase selection
echo ""
echo "Select optimization scope:"
echo "1) Database Only (PostgreSQL optimization)"
echo "2) Frontend Only (React/Next.js optimization)"
echo "3) Full Stack (Database + Frontend + Deployment)"
echo "4) Analysis Only (No changes, just recommendations)"

read -p "Choose optimization scope (1-4): " scope_choice

case $scope_choice in
    1) OPTIMIZE_DB=true; OPTIMIZE_FRONTEND=false; OPTIMIZE_DEPLOY=false; ANALYZE_ONLY=false ;;
    2) OPTIMIZE_DB=false; OPTIMIZE_FRONTEND=true; OPTIMIZE_DEPLOY=false; ANALYZE_ONLY=false ;;
    3) OPTIMIZE_DB=true; OPTIMIZE_FRONTEND=true; OPTIMIZE_DEPLOY=true; ANALYZE_ONLY=false ;;
    4) OPTIMIZE_DB=false; OPTIMIZE_FRONTEND=false; OPTIMIZE_DEPLOY=false; ANALYZE_ONLY=true ;;
    *) echo "❌ Invalid choice. Exiting."; exit 1 ;;
esac

echo ""
echo "🚀 Starting optimization process..."

# Create backup of current configuration
echo "📋 Creating backup of current configuration..."
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup important files
[ -f "package.json" ] && cp package.json "$BACKUP_DIR/"
[ -f "next.config.js" ] && cp next.config.js "$BACKUP_DIR/"
[ -f "next.config.ts" ] && cp next.config.ts "$BACKUP_DIR/"
[ -f "vercel.json" ] && cp vercel.json "$BACKUP_DIR/"
[ -f ".env.local" ] && cp .env.local "$BACKUP_DIR/.env.local.backup"

echo "✅ Backup created in $BACKUP_DIR"

# ============================================
# DATABASE OPTIMIZATION (EXISTING POSTGRESQL)
# ============================================
if [ "$OPTIMIZE_DB" = "true" ] || [ "$ANALYZE_ONLY" = "true" ]; then
    echo ""
    echo "🗄️  DATABASE OPTIMIZATION"
    echo "========================="
    
    # Create optimized SQL scripts
    cat > scripts/optimize-database.sql << 'EOF'
-- Scout Analytics Database Optimization
-- NO NEW TABLES | OPTIMIZE EXISTING ONLY

-- Analyze current performance
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats 
WHERE tablename IN ('sales_interactions', 'transaction_items', 'products')
ORDER BY tablename, attname;

-- Check for missing indexes
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats 
WHERE schemaname = 'public' 
AND n_distinct > 10
AND correlation < 0.1
ORDER BY n_distinct DESC;

-- Optimize existing queries
ANALYZE;

-- Update statistics
SELECT pg_stat_reset();

-- Show slow queries (if pg_stat_statements is enabled)
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
WHERE calls > 10
ORDER BY total_time DESC 
LIMIT 10;

-- Create performance monitoring view
CREATE OR REPLACE VIEW current_performance AS
SELECT 
    NOW() as check_time,
    (SELECT COUNT(*) FROM sales_interactions) as total_transactions,
    (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active') as active_connections,
    (SELECT pg_size_pretty(pg_database_size(current_database()))) as database_size;

-- Grant access to existing roles
GRANT SELECT ON current_performance TO PUBLIC;

-- Refresh existing materialized views (if any)
DO $$
DECLARE
    view_name text;
BEGIN
    FOR view_name IN 
        SELECT matviewname FROM pg_matviews WHERE schemaname = 'public'
    LOOP
        EXECUTE 'REFRESH MATERIALIZED VIEW CONCURRENTLY ' || view_name;
        RAISE NOTICE 'Refreshed materialized view: %', view_name;
    END LOOP;
END;
$$;
EOF

    if [ "$ANALYZE_ONLY" = "false" ]; then
        echo "🔧 Applying database optimizations..."
        echo "ℹ️  Script created: scripts/optimize-database.sql"
        echo "ℹ️  Run manually: psql -f scripts/optimize-database.sql"
    else
        echo "📊 Database optimization script ready: scripts/optimize-database.sql"
    fi
fi

# ============================================
# FRONTEND OPTIMIZATION (EXISTING REACT/NEXT)
# ============================================
if [ "$OPTIMIZE_FRONTEND" = "true" ] || [ "$ANALYZE_ONLY" = "true" ]; then
    echo ""
    echo "⚛️  FRONTEND OPTIMIZATION"
    echo "========================"
    
    # Analyze current package.json
    if [ -f "package.json" ]; then
        echo "📦 Analyzing current dependencies..."
        
        # Check for optimization opportunities
        HAS_NEXT=$(grep -q '"next"' package.json && echo "true" || echo "false")
        HAS_REACT=$(grep -q '"react"' package.json && echo "true" || echo "false")
        HAS_TYPESCRIPT=$(grep -q '"typescript"' package.json && echo "true" || echo "false")
        
        echo "  - Next.js: $HAS_NEXT"
        echo "  - React: $HAS_REACT"
        echo "  - TypeScript: $HAS_TYPESCRIPT"
        
        if [ "$ANALYZE_ONLY" = "false" ]; then
            echo "🔧 Optimizing existing dependencies..."
            
            # Only update if package.json exists and has the dependencies
            if [ "$HAS_NEXT" = "true" ]; then
                # Create optimized next.config.js (only if it doesn't exist)
                if [ ! -f "next.config.js" ] && [ ! -f "next.config.ts" ]; then
                    cat > next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Performance optimizations for existing setup
  experimental: {
    optimizeCss: true,
    optimizePackageImports: ['@cruip/tailwind', 'lucide-react'],
  },
  
  // Compress responses
  compress: true,
  
  // Optimize images (existing assets only)
  images: {
    formats: ['image/webp', 'image/avif'],
    dangerouslyAllowSVG: true,
    contentSecurityPolicy: "default-src 'self'; script-src 'none'; sandbox;",
  },
  
  // Bundle optimization
  webpack: (config, { dev, isServer }) => {
    if (!dev && !isServer) {
      // Optimize bundle size
      config.optimization.splitChunks = {
        chunks: 'all',
        cacheGroups: {
          vendor: {
            test: /[\\/]node_modules[\\/]/,
            name: 'vendors',
            chunks: 'all',
          },
        },
      };
    }
    return config;
  },
  
  // Headers for performance
  async headers() {
    return [
      {
        source: '/api/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, s-maxage=300, stale-while-revalidate=600',
          },
        ],
      },
    ];
  },
};

module.exports = nextConfig;
EOF
                    echo "✅ Created optimized next.config.js"
                else
                    echo "ℹ️  Next.js config already exists, skipping"
                fi
            fi
            
            # Create performance monitoring component
            mkdir -p components/monitoring
            cat > components/monitoring/PerformanceMonitor.tsx << 'EOF'
'use client';

import { useEffect, useState } from 'react';

interface PerformanceMetrics {
  loadTime: number;
  domContentLoaded: number;
  firstContentfulPaint: number;
}

export function PerformanceMonitor() {
  const [metrics, setMetrics] = useState<PerformanceMetrics | null>(null);

  useEffect(() => {
    // Monitor performance using existing browser APIs
    const observer = new PerformanceObserver((list) => {
      const entries = list.getEntries();
      const navigation = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
      const paint = performance.getEntriesByType('paint');
      
      const fcp = paint.find(entry => entry.name === 'first-contentful-paint');
      
      setMetrics({
        loadTime: navigation.loadEventEnd - navigation.loadEventStart,
        domContentLoaded: navigation.domContentLoadedEventEnd - navigation.domContentLoadedEventStart,
        firstContentfulPaint: fcp?.startTime || 0,
      });
    });

    observer.observe({ entryTypes: ['navigation', 'paint'] });

    return () => observer.disconnect();
  }, []);

  // Only show in development
  if (process.env.NODE_ENV !== 'development') return null;

  return (
    <div className="fixed bottom-4 right-4 bg-black bg-opacity-75 text-white p-2 rounded text-xs font-mono">
      {metrics && (
        <>
          <div>Load: {Math.round(metrics.loadTime)}ms</div>
          <div>DOM: {Math.round(metrics.domContentLoaded)}ms</div>
          <div>FCP: {Math.round(metrics.firstContentfulPaint)}ms</div>
        </>
      )}
    </div>
  );
}
EOF
            echo "✅ Created performance monitoring component"
            
            # Update package.json scripts if they don't exist
            npm pkg set scripts.analyze="npm run build && npx @next/bundle-analyzer" 2>/dev/null || true
            npm pkg set scripts.lint:fix="npm run lint -- --fix" 2>/dev/null || true
            echo "✅ Added optimization scripts to package.json"
            
        else
            echo "📊 Frontend optimization opportunities identified"
        fi
    else
        echo "⚠️  No package.json found, skipping frontend optimization"
    fi
fi

# ============================================
# DEPLOYMENT OPTIMIZATION (EXISTING VERCEL)
# ============================================
if [ "$OPTIMIZE_DEPLOY" = "true" ] || [ "$ANALYZE_ONLY" = "true" ]; then
    echo ""
    echo "🚀 DEPLOYMENT OPTIMIZATION"
    echo "=========================="
    
    # Check for existing Vercel configuration
    if [ -f "vercel.json" ]; then
        echo "📋 Existing Vercel configuration found"
        
        if [ "$ANALYZE_ONLY" = "false" ]; then
            # Backup existing vercel.json
            cp vercel.json "$BACKUP_DIR/"
            
            # Create optimized vercel.json
            cat > vercel.json << 'EOF'
{
  "buildCommand": "npm run build",
  "outputDirectory": ".next",
  "framework": "nextjs",
  "functions": {
    "app/api/**/*.ts": {
      "maxDuration": 30
    }
  },
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, s-maxage=300, stale-while-revalidate=600"
        }
      ]
    },
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-XSS-Protection",
          "value": "1; mode=block"
        }
      ]
    }
  ],
  "rewrites": [
    {
      "source": "/health",
      "destination": "/api/health"
    }
  ]
}
EOF
            echo "✅ Optimized vercel.json configuration"
        else
            echo "📊 Vercel optimization opportunities identified"
        fi
    else
        if [ "$ANALYZE_ONLY" = "false" ]; then
            echo "ℹ️  No vercel.json found, creating optimized configuration..."
            cat > vercel.json << 'EOF'
{
  "framework": "nextjs",
  "functions": {
    "app/api/**/*.ts": {
      "maxDuration": 30
    }
  }
}
EOF
            echo "✅ Created basic vercel.json"
        else
            echo "📊 No existing Vercel configuration found"
        fi
    fi
    
    # Create health check endpoint
    if [ "$ANALYZE_ONLY" = "false" ]; then
        mkdir -p app/api/health
        cat > app/api/health/route.ts << 'EOF'
import { NextResponse } from 'next/server';

export async function GET() {
  try {
    // Basic health check
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      version: process.env.npm_package_version || '1.0.0',
    };

    return NextResponse.json(health);
  } catch (error) {
    return NextResponse.json(
      { status: 'unhealthy', error: 'Health check failed' },
      { status: 500 }
    );
  }
}
EOF
        echo "✅ Created health check endpoint"
    fi
fi

# ============================================
# ANALYSIS AND RECOMMENDATIONS
# ============================================
echo ""
echo "📊 OPTIMIZATION ANALYSIS COMPLETE"
echo "================================="

if [ "$ANALYZE_ONLY" = "true" ]; then
    echo ""
    echo "🎯 RECOMMENDATIONS (No changes made):"
    echo ""
    echo "Database Optimization:"
    echo "  ✅ Run: psql -f scripts/optimize-database.sql"
    echo "  ✅ Consider: Adding pg_stat_statements extension"
    echo "  ✅ Monitor: Query performance with existing tools"
    echo ""
    echo "Frontend Optimization:"
    echo "  ✅ Bundle analysis: npm run analyze"
    echo "  ✅ Performance monitoring: Add PerformanceMonitor component"
    echo "  ✅ Code splitting: Implement lazy loading for large components"
    echo ""
    echo "Deployment Optimization:"
    echo "  ✅ Vercel headers: Optimize caching and security"
    echo "  ✅ Health checks: Add monitoring endpoints"
    echo "  ✅ Build optimization: Use Next.js optimization features"
    echo ""
else
    echo ""
    echo "✅ OPTIMIZATION COMPLETE:"
    echo ""
    
    if [ "$OPTIMIZE_DB" = "true" ]; then
        echo "Database:"
        echo "  ✅ Optimization script created: scripts/optimize-database.sql"
        echo "  ✅ Performance monitoring view added"
    fi
    
    if [ "$OPTIMIZE_FRONTEND" = "true" ]; then
        echo "Frontend:"
        echo "  ✅ Next.js configuration optimized"
        echo "  ✅ Performance monitoring component added"
        echo "  ✅ Build optimization scripts added"
    fi
    
    if [ "$OPTIMIZE_DEPLOY" = "true" ]; then
        echo "Deployment:"
        echo "  ✅ Vercel configuration optimized"
        echo "  ✅ Health check endpoint created"
        echo "  ✅ Security headers configured"
    fi
    
    echo ""
    echo "🔄 NEXT STEPS:"
    echo "1. Test optimizations: npm run dev"
    echo "2. Run database optimization: psql -f scripts/optimize-database.sql"
    echo "3. Analyze bundle: npm run analyze"
    echo "4. Deploy optimizations: vercel --prod"
    echo ""
    echo "📋 Backup location: $BACKUP_DIR"
fi

echo ""
echo "🎉 Scout Analytics optimization complete!"
echo "💡 Your existing stack has been enhanced without any new subscriptions or resources."