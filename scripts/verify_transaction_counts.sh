#!/usr/bin/env bash
set -euo pipefail

# Load environment variables if file exists
if [ -f ".env.production" ]; then
    source .env.production
fi

# Check for required environment variables
if [ -z "${DATABASE_URL:-}" ]; then
    echo "❌ DATABASE_URL environment variable is required"
    exit 1
fi

if [ -z "${DASHBOARD_API_URL:-}" ]; then
    echo "❌ DASHBOARD_API_URL environment variable is required"
    exit 1
fi

# 1. Query total transactions from the database
echo "🔍 Querying database for transaction count..."
db_count=$(./scripts/direct-sql-executor.sh -q "SELECT COUNT(*) FROM transactions;" | grep -E '^[0-9]+$' | head -1 | tr -d '[:space:]')

# 2. Query total transactions from the dashboard API
echo "🔍 Querying dashboard API for transaction count..."
ui_count=$(curl -s "$DASHBOARD_API_URL/api/metrics" \
  | jq -r '.totalTransactions // empty' 2>/dev/null || echo "0")

echo "DB count : $db_count"
echo "UI count : $ui_count"

if [ "$db_count" -eq "$ui_count" ]; then
  echo "✅ Transaction counts match."
  exit 0
else
  echo "❌ Mismatch detected: DB=$db_count, UI=$ui_count"
  exit 1
fi