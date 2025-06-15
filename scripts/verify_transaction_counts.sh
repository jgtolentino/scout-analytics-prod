#!/usr/bin/env bash
set -euo pipefail

# Load environment variables
source .env.production

# 1. Query total transactions from the database
db_count=$(./scripts/direct-sql-executor.sh -q "SELECT COUNT(*) FROM transactions;" | tr -d '[:space:]')

# 2. Query total transactions from the dashboard API
#    Replace DASHBOARD_API_URL with your actual endpoint
ui_count=$(curl -s "$DASHBOARD_API_URL/api/metrics" \
  | jq '.totalTransactions')

echo "DB count : $db_count"
echo "UI count : $ui_count"

if [ "$db_count" -eq "$ui_count" ]; then
  echo "✅ Transaction counts match."
  exit 0
else
  echo "❌ Mismatch detected: DB=$db_count, UI=$ui_count"
  exit 1
fi