-- =====================================================
-- Scout Analytics Production Database Schema Migration
-- Version: 001 - Core Production Setup
-- Purpose: Create materialized views, stored procedures, and security enhancements
-- Target: Azure PostgreSQL Flexible Server
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- Create audit log table for security tracking
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID,
    table_name TEXT NOT NULL,
    action TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT
);

-- Create anomalies table for data quality monitoring
CREATE TABLE IF NOT EXISTS anomalies (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    type TEXT NOT NULL,
    details JSONB,
    severity TEXT DEFAULT 'medium',
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- =====================================================
-- MATERIALIZED VIEWS FOR ANALYTICS PERFORMANCE
-- =====================================================

-- Daily Sales Summary (Refreshed hourly)
DROP MATERIALIZED VIEW IF EXISTS daily_sales CASCADE;
CREATE MATERIALIZED VIEW daily_sales AS
SELECT 
    DATE(transaction_date) AS sale_date,
    store_id,
    s.region,
    s.name AS store_name,
    COUNT(*) AS transaction_count,
    SUM(total_amount) AS daily_revenue,
    AVG(total_amount) AS avg_transaction_value,
    SUM(CASE WHEN is_attendant_influenced THEN 1 ELSE 0 END) AS influenced_transactions,
    SUM(CASE WHEN substitution_occurred THEN 1 ELSE 0 END) AS substitution_transactions,
    EXTRACT(DOW FROM transaction_date) AS day_of_week,
    EXTRACT(HOUR FROM transaction_date) AS peak_hour
FROM sales_interactions si
JOIN stores s ON si.store_id = s.id
WHERE transaction_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY 1, 2, 3, 4, 9, 10;

-- Create unique index for faster queries
CREATE UNIQUE INDEX idx_daily_sales_unique ON daily_sales (sale_date, store_id, day_of_week, peak_hour);
CREATE INDEX idx_daily_sales_region ON daily_sales (region, sale_date);
CREATE INDEX idx_daily_sales_revenue ON daily_sales (daily_revenue DESC);

-- Product Performance Analysis (Refreshed nightly)
DROP MATERIALIZED VIEW IF EXISTS product_performance CASCADE;
CREATE MATERIALIZED VIEW product_performance AS
SELECT 
    p.id AS product_id,
    p.name AS product_name,
    b.name AS brand_name,
    p.category,
    p.is_fmcg,
    SUM(ti.quantity) AS total_units_sold,
    SUM(ti.quantity * p.unit_price) AS total_revenue,
    COUNT(DISTINCT ti.interaction_id) AS transaction_count,
    AVG(ti.quantity) AS avg_quantity_per_transaction,
    SUM(ti.quantity * p.unit_price) / NULLIF(SUM(SUM(ti.quantity * p.unit_price)) OVER (), 0) * 100 AS market_share_percent,
    RANK() OVER (PARTITION BY p.category ORDER BY SUM(ti.quantity) DESC) AS category_rank,
    -- Velocity metrics
    SUM(ti.quantity) / NULLIF(EXTRACT(DAYS FROM (MAX(si.transaction_date) - MIN(si.transaction_date))), 0) AS daily_velocity,
    -- Performance indicators
    CASE 
        WHEN SUM(ti.quantity) > 1000 THEN 'High Performer'
        WHEN SUM(ti.quantity) > 500 THEN 'Medium Performer'
        ELSE 'Low Performer'
    END AS performance_tier
FROM transaction_items ti
JOIN products p ON ti.product_id = p.id
JOIN brands b ON p.brand_id = b.id
JOIN sales_interactions si ON ti.interaction_id = si.interaction_id
WHERE si.transaction_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY p.id, p.name, b.name, p.category, p.is_fmcg;

-- Create indexes for product performance
CREATE UNIQUE INDEX idx_product_perf_unique ON product_performance (product_id);
CREATE INDEX idx_product_perf_brand ON product_performance (brand_name, total_revenue DESC);
CREATE INDEX idx_product_perf_category ON product_performance (category, category_rank);
CREATE INDEX idx_product_perf_tier ON product_performance (performance_tier, total_revenue DESC);

-- Customer Segmentation View
DROP VIEW IF EXISTS customer_segments CASCADE;
CREATE VIEW customer_segments AS
WITH customer_metrics AS (
    SELECT 
        customer_id,
        COUNT(*) AS transaction_count,
        SUM(total_amount) AS total_spent,
        AVG(total_amount) AS avg_transaction_value,
        MAX(transaction_date) AS last_transaction_date,
        MIN(transaction_date) AS first_transaction_date,
        EXTRACT(DAYS FROM (MAX(transaction_date) - MIN(transaction_date))) + 1 AS customer_lifetime_days,
        COUNT(DISTINCT DATE(transaction_date)) AS active_days
    FROM sales_interactions 
    WHERE customer_id IS NOT NULL
    AND transaction_date >= CURRENT_DATE - INTERVAL '365 days'
    GROUP BY customer_id
)
SELECT 
    customer_id,
    transaction_count,
    total_spent,
    avg_transaction_value,
    last_transaction_date,
    customer_lifetime_days,
    active_days,
    -- RFM Segmentation
    CASE 
        WHEN last_transaction_date >= CURRENT_DATE - INTERVAL '30 days' THEN 'Recent'
        WHEN last_transaction_date >= CURRENT_DATE - INTERVAL '90 days' THEN 'Active'
        ELSE 'Inactive'
    END AS recency_segment,
    CASE 
        WHEN transaction_count >= 10 THEN 'Frequent'
        WHEN transaction_count >= 5 THEN 'Regular'
        ELSE 'Occasional'
    END AS frequency_segment,
    CASE 
        WHEN total_spent >= 10000 THEN 'Premium'
        WHEN total_spent >= 5000 THEN 'Standard'
        ELSE 'Budget'
    END AS monetary_segment,
    -- Combined segment
    CASE 
        WHEN total_spent >= 10000 AND transaction_count >= 10 AND last_transaction_date >= CURRENT_DATE - INTERVAL '30 days' THEN 'VIP'
        WHEN total_spent >= 5000 AND transaction_count >= 5 AND last_transaction_date >= CURRENT_DATE - INTERVAL '60 days' THEN 'Loyal'
        WHEN last_transaction_date >= CURRENT_DATE - INTERVAL '30 days' THEN 'Active'
        ELSE 'At Risk'
    END AS customer_segment
FROM customer_metrics;

-- Regional Performance Dashboard
DROP MATERIALIZED VIEW IF EXISTS regional_performance CASCADE;
CREATE MATERIALIZED VIEW regional_performance AS
WITH region_metrics AS (
    SELECT 
        s.region,
        COUNT(DISTINCT si.store_id) AS store_count,
        COUNT(DISTINCT si.interaction_id) AS total_transactions,
        SUM(si.total_amount) AS total_revenue,
        AVG(si.total_amount) AS avg_transaction_value,
        COUNT(DISTINCT si.customer_id) AS unique_customers,
        SUM(CASE WHEN si.is_attendant_influenced THEN 1 ELSE 0 END) AS influenced_sales,
        SUM(CASE WHEN si.substitution_occurred THEN 1 ELSE 0 END) AS substitution_events,
        -- Brand performance by region
        SUM(CASE WHEN b.name = 'Alaska' THEN ti.quantity * p.unit_price ELSE 0 END) AS alaska_revenue,
        SUM(CASE WHEN b.name = 'Oishi' THEN ti.quantity * p.unit_price ELSE 0 END) AS oishi_revenue,
        SUM(CASE WHEN b.name = 'Peerless' THEN ti.quantity * p.unit_price ELSE 0 END) AS peerless_revenue,
        SUM(CASE WHEN b.name = 'Del Monte' THEN ti.quantity * p.unit_price ELSE 0 END) AS del_monte_revenue
    FROM sales_interactions si
    JOIN stores s ON si.store_id = s.id
    LEFT JOIN transaction_items ti ON si.interaction_id = ti.interaction_id
    LEFT JOIN products p ON ti.product_id = p.id
    LEFT JOIN brands b ON p.brand_id = b.id
    WHERE si.transaction_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY s.region
)
SELECT 
    region,
    store_count,
    total_transactions,
    total_revenue,
    avg_transaction_value,
    unique_customers,
    ROUND(total_revenue / NULLIF(store_count, 0), 2) AS revenue_per_store,
    ROUND(influenced_sales::NUMERIC / NULLIF(total_transactions, 0) * 100, 2) AS influence_rate_percent,
    ROUND(substitution_events::NUMERIC / NULLIF(total_transactions, 0) * 100, 2) AS substitution_rate_percent,
    alaska_revenue,
    oishi_revenue,
    peerless_revenue,
    del_monte_revenue,
    (alaska_revenue + oishi_revenue + peerless_revenue + del_monte_revenue) AS tbwa_total_revenue,
    ROUND((alaska_revenue + oishi_revenue + peerless_revenue + del_monte_revenue) / NULLIF(total_revenue, 0) * 100, 2) AS tbwa_market_share_percent,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM region_metrics;

-- Create indexes for regional performance
CREATE UNIQUE INDEX idx_regional_perf_unique ON regional_performance (region);
CREATE INDEX idx_regional_perf_revenue ON regional_performance (total_revenue DESC);
CREATE INDEX idx_regional_perf_market_share ON regional_performance (tbwa_market_share_percent DESC);

-- =====================================================
-- PERFORMANCE INDEXES FOR CORE TABLES
-- =====================================================

-- Optimize sales_interactions queries
CREATE INDEX IF NOT EXISTS idx_sales_interactions_date ON sales_interactions (transaction_date);
CREATE INDEX IF NOT EXISTS idx_sales_interactions_store_date ON sales_interactions (store_id, transaction_date);
CREATE INDEX IF NOT EXISTS idx_sales_interactions_customer ON sales_interactions (customer_id) WHERE customer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sales_interactions_amount ON sales_interactions (total_amount);
CREATE INDEX IF NOT EXISTS idx_sales_interactions_flags ON sales_interactions (is_attendant_influenced, substitution_occurred);

-- Optimize transaction_items queries
CREATE INDEX IF NOT EXISTS idx_transaction_items_product ON transaction_items (product_id);
CREATE INDEX IF NOT EXISTS idx_transaction_items_interaction ON transaction_items (interaction_id);
CREATE INDEX IF NOT EXISTS idx_transaction_items_quantity ON transaction_items (quantity);

-- Optimize products queries
CREATE INDEX IF NOT EXISTS idx_products_brand ON products (brand_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products (category);
CREATE INDEX IF NOT EXISTS idx_products_fmcg ON products (is_fmcg);
CREATE INDEX IF NOT EXISTS idx_products_price ON products (unit_price);

-- Optimize stores queries
CREATE INDEX IF NOT EXISTS idx_stores_region ON stores (region);
CREATE INDEX IF NOT EXISTS idx_stores_name ON stores (name);

-- Optimize device_master queries
CREATE INDEX IF NOT EXISTS idx_device_master_store ON device_master (store_id);
CREATE INDEX IF NOT EXISTS idx_device_master_status ON device_master (status);
CREATE INDEX IF NOT EXISTS idx_device_master_mac ON device_master (mac_address);

-- Comment on materialized views for documentation
COMMENT ON MATERIALIZED VIEW daily_sales IS 'Daily sales aggregation by store with transaction metrics. Refreshed hourly for real-time analytics.';
COMMENT ON MATERIALIZED VIEW product_performance IS 'Product sales performance with market share and velocity metrics. Refreshed nightly.';
COMMENT ON MATERIALIZED VIEW regional_performance IS 'Regional sales performance with TBWA brand analysis. Refreshed nightly.';
COMMENT ON VIEW customer_segments IS 'RFM customer segmentation analysis with behavioral categorization.';

-- Grant permissions for application access
GRANT SELECT ON daily_sales TO dashboard_user;
GRANT SELECT ON product_performance TO dashboard_user;
GRANT SELECT ON customer_segments TO dashboard_user;
GRANT SELECT ON regional_performance TO dashboard_user;
GRANT SELECT ON audit_log TO dashboard_user;
GRANT SELECT ON anomalies TO dashboard_user;