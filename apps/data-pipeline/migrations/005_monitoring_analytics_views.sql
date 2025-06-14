-- =====================================================
-- Scout Analytics Monitoring and Business Intelligence Views
-- Version: 005 - Comprehensive Dashboards and KPI Monitoring
-- Purpose: Executive dashboards, operational monitoring, and advanced analytics
-- Target: Azure PostgreSQL Flexible Server
-- =====================================================

-- =====================================================
-- EXECUTIVE DASHBOARD VIEWS
-- =====================================================

-- Executive Summary Dashboard (Real-time KPIs)
CREATE OR REPLACE VIEW executive_dashboard AS
WITH current_period AS (
    SELECT 
        COUNT(DISTINCT interaction_id) as total_transactions_today,
        SUM(total_amount) as revenue_today,
        COUNT(DISTINCT store_id) as active_stores_today,
        AVG(total_amount) as avg_transaction_today
    FROM sales_interactions 
    WHERE DATE(transaction_date) = CURRENT_DATE
),
previous_period AS (
    SELECT 
        COUNT(DISTINCT interaction_id) as total_transactions_yesterday,
        SUM(total_amount) as revenue_yesterday,
        AVG(total_amount) as avg_transaction_yesterday
    FROM sales_interactions 
    WHERE DATE(transaction_date) = CURRENT_DATE - INTERVAL '1 day'
),
weekly_metrics AS (
    SELECT 
        COUNT(DISTINCT interaction_id) as transactions_7d,
        SUM(total_amount) as revenue_7d,
        COUNT(DISTINCT customer_id) as unique_customers_7d
    FROM sales_interactions 
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
),
monthly_metrics AS (
    SELECT 
        COUNT(DISTINCT interaction_id) as transactions_30d,
        SUM(total_amount) as revenue_30d,
        COUNT(DISTINCT customer_id) as unique_customers_30d,
        -- TBWA vs Competitor split
        SUM(CASE WHEN b.name IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
                 THEN ti.quantity * p.unit_price ELSE 0 END) as tbwa_revenue_30d,
        SUM(CASE WHEN b.name NOT IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
                 THEN ti.quantity * p.unit_price ELSE 0 END) as competitor_revenue_30d
    FROM sales_interactions si
    JOIN transaction_items ti ON si.interaction_id = ti.interaction_id
    JOIN products p ON ti.product_id = p.id
    JOIN brands b ON p.brand_id = b.id
    WHERE si.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    CURRENT_DATE as dashboard_date,
    -- Today's performance
    cp.total_transactions_today,
    cp.revenue_today,
    cp.active_stores_today,
    cp.avg_transaction_today,
    -- Day-over-day growth
    ROUND(
        CASE WHEN pp.revenue_yesterday > 0 
             THEN ((cp.revenue_today - pp.revenue_yesterday) / pp.revenue_yesterday) * 100 
             ELSE 0 END, 2
    ) as revenue_growth_dod_percent,
    -- Weekly metrics
    wm.transactions_7d,
    wm.revenue_7d,
    wm.unique_customers_7d,
    -- Monthly metrics
    mm.transactions_30d,
    mm.revenue_30d,
    mm.unique_customers_30d,
    -- TBWA market performance
    mm.tbwa_revenue_30d,
    mm.competitor_revenue_30d,
    ROUND(
        mm.tbwa_revenue_30d / NULLIF(mm.tbwa_revenue_30d + mm.competitor_revenue_30d, 0) * 100, 2
    ) as tbwa_market_share_percent,
    -- Operational health
    (SELECT COUNT(*) FROM anomalies WHERE status = 'active') as active_anomalies,
    (SELECT COUNT(*) FROM device_master WHERE status = 'active') as active_devices,
    (SELECT COUNT(*) FROM device_master WHERE status != 'active') as inactive_devices
FROM current_period cp
CROSS JOIN previous_period pp
CROSS JOIN weekly_metrics wm
CROSS JOIN monthly_metrics mm;

-- =====================================================
-- OPERATIONAL MONITORING DASHBOARDS
-- =====================================================

-- Store Performance Dashboard
CREATE OR REPLACE VIEW store_performance_dashboard AS
WITH store_metrics AS (
    SELECT 
        s.id as store_id,
        s.name as store_name,
        s.region,
        s.store_type,
        COUNT(DISTINCT si.interaction_id) as transactions_30d,
        SUM(si.total_amount) as revenue_30d,
        AVG(si.total_amount) as avg_transaction_value,
        COUNT(DISTINCT si.customer_id) as unique_customers_30d,
        -- Performance indicators
        SUM(CASE WHEN si.is_attendant_influenced THEN 1 ELSE 0 END) as influenced_sales,
        SUM(CASE WHEN si.substitution_occurred THEN 1 ELSE 0 END) as substitution_events,
        -- Device status
        dm.status as device_status,
        dm.last_seen,
        -- TBWA performance
        SUM(CASE WHEN b.name IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
                 THEN ti.quantity * p.unit_price ELSE 0 END) as tbwa_revenue
    FROM stores s
    LEFT JOIN sales_interactions si ON s.id = si.store_id 
        AND si.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
    LEFT JOIN transaction_items ti ON si.interaction_id = ti.interaction_id
    LEFT JOIN products p ON ti.product_id = p.id
    LEFT JOIN brands b ON p.brand_id = b.id
    LEFT JOIN device_master dm ON s.id = dm.store_id
    GROUP BY s.id, s.name, s.region, s.store_type, dm.status, dm.last_seen
)
SELECT 
    store_id,
    store_name,
    region,
    store_type,
    transactions_30d,
    revenue_30d,
    avg_transaction_value,
    unique_customers_30d,
    ROUND(influenced_sales::NUMERIC / NULLIF(transactions_30d, 0) * 100, 2) as influence_rate_percent,
    ROUND(substitution_events::NUMERIC / NULLIF(transactions_30d, 0) * 100, 2) as substitution_rate_percent,
    device_status,
    last_seen,
    tbwa_revenue,
    ROUND(tbwa_revenue / NULLIF(revenue_30d, 0) * 100, 2) as tbwa_share_percent,
    -- Performance tier classification
    CASE 
        WHEN revenue_30d >= 50000 THEN 'Top Performer'
        WHEN revenue_30d >= 25000 THEN 'Strong Performer'
        WHEN revenue_30d >= 10000 THEN 'Average Performer'
        WHEN revenue_30d > 0 THEN 'Underperformer'
        ELSE 'No Activity'
    END as performance_tier,
    -- Alert flags
    CASE WHEN device_status != 'active' THEN 'Device Issue' END as device_alert,
    CASE WHEN last_seen < CURRENT_DATE - INTERVAL '24 hours' THEN 'Connectivity Issue' END as connectivity_alert
FROM store_metrics
ORDER BY revenue_30d DESC NULLS LAST;

-- =====================================================
-- BRAND PERFORMANCE ANALYTICS
-- =====================================================

-- Brand Competition Analysis Dashboard
CREATE MATERIALIZED VIEW brand_competition_dashboard AS
WITH brand_metrics AS (
    SELECT 
        b.name as brand_name,
        b.category as brand_category,
        CASE WHEN b.name IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
             THEN 'TBWA Client' ELSE 'Competitor' END as brand_type,
        COUNT(DISTINCT ti.interaction_id) as transactions,
        SUM(ti.quantity) as units_sold,
        SUM(ti.quantity * p.unit_price) as revenue,
        AVG(ti.quantity) as avg_quantity_per_transaction,
        COUNT(DISTINCT s.region) as regional_presence,
        COUNT(DISTINCT si.store_id) as store_presence
    FROM transaction_items ti
    JOIN products p ON ti.product_id = p.id
    JOIN brands b ON p.brand_id = b.id
    JOIN sales_interactions si ON ti.interaction_id = si.interaction_id
    JOIN stores s ON si.store_id = s.id
    WHERE si.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY b.name, b.category
),
category_totals AS (
    SELECT 
        brand_category,
        SUM(revenue) as category_total_revenue,
        SUM(units_sold) as category_total_units
    FROM brand_metrics
    GROUP BY brand_category
)
SELECT 
    bm.brand_name,
    bm.brand_category,
    bm.brand_type,
    bm.transactions,
    bm.units_sold,
    bm.revenue,
    bm.avg_quantity_per_transaction,
    bm.regional_presence,
    bm.store_presence,
    -- Market share calculations
    ROUND(bm.revenue / ct.category_total_revenue * 100, 2) as category_market_share_percent,
    ROUND(bm.units_sold / ct.category_total_units * 100, 2) as category_volume_share_percent,
    -- Rankings
    RANK() OVER (PARTITION BY bm.brand_category ORDER BY bm.revenue DESC) as revenue_rank_in_category,
    RANK() OVER (ORDER BY bm.revenue DESC) as overall_revenue_rank,
    -- Performance indicators
    CASE 
        WHEN bm.revenue / ct.category_total_revenue >= 0.25 THEN 'Market Leader'
        WHEN bm.revenue / ct.category_total_revenue >= 0.15 THEN 'Strong Player'
        WHEN bm.revenue / ct.category_total_revenue >= 0.05 THEN 'Challenger'
        ELSE 'Niche Player'
    END as market_position
FROM brand_metrics bm
JOIN category_totals ct ON bm.brand_category = ct.brand_category
ORDER BY bm.revenue DESC;

-- Index for brand competition dashboard
CREATE UNIQUE INDEX idx_brand_competition_brand ON brand_competition_dashboard (brand_name);
CREATE INDEX idx_brand_competition_type ON brand_competition_dashboard (brand_type, revenue DESC);
CREATE INDEX idx_brand_competition_category ON brand_competition_dashboard (brand_category, revenue DESC);

-- =====================================================
-- CUSTOMER ANALYTICS DASHBOARD
-- =====================================================

-- Customer Behavior Analytics
CREATE OR REPLACE VIEW customer_analytics_dashboard AS
WITH customer_behavior AS (
    SELECT 
        si.gender,
        CASE 
            WHEN si.age BETWEEN 18 AND 25 THEN '18-25'
            WHEN si.age BETWEEN 26 AND 35 THEN '26-35'
            WHEN si.age BETWEEN 36 AND 45 THEN '36-45'
            WHEN si.age BETWEEN 46 AND 55 THEN '46-55'
            WHEN si.age BETWEEN 56 AND 65 THEN '56-65'
            ELSE '65+'
        END as age_group,
        si.emotion,
        s.region,
        pr.mega_region,
        COUNT(*) as transaction_count,
        SUM(si.total_amount) as total_spent,
        AVG(si.total_amount) as avg_transaction_value,
        AVG(EXTRACT(EPOCH FROM si.duration) / 60.0) as avg_duration_minutes,
        SUM(CASE WHEN si.is_attendant_influenced THEN 1 ELSE 0 END) as influenced_purchases,
        SUM(CASE WHEN si.substitution_occurred THEN 1 ELSE 0 END) as substitution_purchases
    FROM sales_interactions si
    JOIN stores s ON si.store_id = s.id
    JOIN ph_regions pr ON s.region = pr.region
    WHERE si.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY si.gender, age_group, si.emotion, s.region, pr.mega_region
)
SELECT 
    gender,
    age_group,
    emotion,
    region,
    mega_region,
    transaction_count,
    total_spent,
    avg_transaction_value,
    avg_duration_minutes,
    ROUND(influenced_purchases::NUMERIC / transaction_count * 100, 2) as influence_rate_percent,
    ROUND(substitution_purchases::NUMERIC / transaction_count * 100, 2) as substitution_rate_percent,
    -- Behavioral insights
    CASE 
        WHEN avg_transaction_value >= 200 THEN 'High Value'
        WHEN avg_transaction_value >= 100 THEN 'Medium Value'
        ELSE 'Low Value'
    END as value_segment,
    CASE 
        WHEN avg_duration_minutes >= 5 THEN 'Deliberate Shopper'
        WHEN avg_duration_minutes >= 2 THEN 'Average Browser'
        ELSE 'Quick Buyer'
    END as shopping_behavior
FROM customer_behavior
ORDER BY total_spent DESC;

-- =====================================================
-- OPERATIONAL HEALTH MONITORING
-- =====================================================

-- System Health Dashboard
CREATE OR REPLACE VIEW system_health_dashboard AS
WITH device_health AS (
    SELECT 
        COUNT(*) as total_devices,
        SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active_devices,
        SUM(CASE WHEN status = 'maintenance' THEN 1 ELSE 0 END) as maintenance_devices,
        SUM(CASE WHEN status = 'offline' THEN 1 ELSE 0 END) as offline_devices,
        SUM(CASE WHEN last_seen < CURRENT_DATE - INTERVAL '24 hours' THEN 1 ELSE 0 END) as stale_devices
    FROM device_master
),
data_quality AS (
    SELECT 
        COUNT(*) as total_transactions_today,
        SUM(CASE WHEN total_amount = 0 THEN 1 ELSE 0 END) as zero_amount_transactions,
        AVG(total_amount) as avg_transaction_amount,
        STDDEV(total_amount) as transaction_amount_stddev
    FROM sales_interactions 
    WHERE DATE(transaction_date) = CURRENT_DATE
),
anomaly_status AS (
    SELECT 
        COUNT(*) as total_anomalies,
        SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active_anomalies,
        SUM(CASE WHEN severity = 'high' THEN 1 ELSE 0 END) as high_severity_anomalies,
        SUM(CASE WHEN created_at >= CURRENT_DATE THEN 1 ELSE 0 END) as todays_anomalies
    FROM anomalies
),
performance_metrics AS (
    SELECT 
        -- Database performance indicators
        (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active') as active_connections,
        (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'idle in transaction') as idle_transactions,
        pg_size_pretty(pg_database_size(current_database())) as database_size
)
SELECT 
    CURRENT_TIMESTAMP as health_check_time,
    -- Device health
    dh.total_devices,
    dh.active_devices,
    dh.maintenance_devices,
    dh.offline_devices,
    dh.stale_devices,
    ROUND(dh.active_devices::NUMERIC / dh.total_devices * 100, 2) as device_uptime_percent,
    -- Data quality
    dq.total_transactions_today,
    dq.zero_amount_transactions,
    dq.avg_transaction_amount,
    -- Anomaly status
    ans.total_anomalies,
    ans.active_anomalies,
    ans.high_severity_anomalies,
    ans.todays_anomalies,
    -- Performance
    pm.active_connections,
    pm.idle_transactions,
    pm.database_size,
    -- Overall health score (0-100)
    ROUND(
        (dh.active_devices::NUMERIC / dh.total_devices * 40) +  -- 40% weight to device health
        (CASE WHEN ans.high_severity_anomalies = 0 THEN 30 ELSE 30 - LEAST(ans.high_severity_anomalies * 10, 30) END) +  -- 30% weight to anomalies
        (CASE WHEN pm.active_connections < 50 THEN 30 ELSE 30 - LEAST((pm.active_connections - 50) * 2, 30) END), -- 30% weight to performance
        0
    ) as overall_health_score
FROM device_health dh
CROSS JOIN data_quality dq
CROSS JOIN anomaly_status ans
CROSS JOIN performance_metrics pm;

-- =====================================================
-- BUSINESS INTELLIGENCE VIEWS
-- =====================================================

-- Time-based Analytics (Hourly patterns)
CREATE OR REPLACE VIEW hourly_sales_patterns AS
SELECT 
    EXTRACT(HOUR FROM transaction_date) as hour_of_day,
    EXTRACT(DOW FROM transaction_date) as day_of_week,
    COUNT(*) as transaction_count,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_transaction_value,
    COUNT(DISTINCT store_id) as active_stores,
    SUM(CASE WHEN is_attendant_influenced THEN 1 ELSE 0 END) as influenced_transactions,
    -- Regional breakdown
    COUNT(CASE WHEN s.region LIKE '%NCR%' THEN 1 END) as ncr_transactions,
    COUNT(CASE WHEN pr.mega_region = 'Luzon' THEN 1 END) as luzon_transactions,
    COUNT(CASE WHEN pr.mega_region = 'Visayas' THEN 1 END) as visayas_transactions,
    COUNT(CASE WHEN pr.mega_region = 'Mindanao' THEN 1 END) as mindanao_transactions
FROM sales_interactions si
JOIN stores s ON si.store_id = s.id
JOIN ph_regions pr ON s.region = pr.region
WHERE si.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY EXTRACT(HOUR FROM transaction_date), EXTRACT(DOW FROM transaction_date)
ORDER BY day_of_week, hour_of_day;

-- Product Category Performance
CREATE MATERIALIZED VIEW category_performance_analytics AS
SELECT 
    p.category,
    COUNT(DISTINCT ti.interaction_id) as transactions,
    SUM(ti.quantity) as total_units_sold,
    SUM(ti.quantity * p.unit_price) as total_revenue,
    AVG(ti.quantity * p.unit_price) as avg_revenue_per_transaction,
    COUNT(DISTINCT p.id) as product_count,
    COUNT(DISTINCT b.id) as brand_count,
    -- TBWA vs Competitor analysis
    SUM(CASE WHEN b.name IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
             THEN ti.quantity * p.unit_price ELSE 0 END) as tbwa_revenue,
    SUM(CASE WHEN b.name NOT IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
             THEN ti.quantity * p.unit_price ELSE 0 END) as competitor_revenue,
    -- Growth indicators
    RANK() OVER (ORDER BY SUM(ti.quantity * p.unit_price) DESC) as revenue_rank,
    -- Market dynamics
    COUNT(DISTINCT s.region) as regional_presence
FROM transaction_items ti
JOIN products p ON ti.product_id = p.id
JOIN brands b ON p.brand_id = b.id
JOIN sales_interactions si ON ti.interaction_id = si.interaction_id
JOIN stores s ON si.store_id = s.id
WHERE si.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY p.category
ORDER BY total_revenue DESC;

-- Index for category performance
CREATE UNIQUE INDEX idx_category_perf_category ON category_performance_analytics (category);
CREATE INDEX idx_category_perf_revenue ON category_performance_analytics (total_revenue DESC);

-- =====================================================
-- REFRESH PROCEDURES FOR MATERIALIZED VIEWS
-- =====================================================

-- Update the analytics refresh procedure to include new materialized views
CREATE OR REPLACE PROCEDURE refresh_all_analytics()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Refresh core analytics views
    REFRESH MATERIALIZED VIEW CONCURRENTLY daily_sales;
    REFRESH MATERIALIZED VIEW CONCURRENTLY product_performance;
    REFRESH MATERIALIZED VIEW CONCURRENTLY regional_performance;
    
    -- Refresh Philippine market specific views
    REFRESH MATERIALIZED VIEW CONCURRENTLY philippine_market_analysis;
    REFRESH MATERIALIZED VIEW CONCURRENTLY tbwa_brand_performance;
    
    -- Refresh business intelligence views
    REFRESH MATERIALIZED VIEW CONCURRENTLY brand_competition_dashboard;
    REFRESH MATERIALIZED VIEW CONCURRENTLY category_performance_analytics;
    
    RAISE NOTICE 'All analytics materialized views refreshed successfully';
END;
$$;

-- =====================================================
-- PERMISSIONS FOR MONITORING VIEWS
-- =====================================================

-- Grant access to monitoring views
GRANT SELECT ON executive_dashboard TO dashboard_user, data_analyst;
GRANT SELECT ON store_performance_dashboard TO dashboard_user, data_analyst, store_manager;
GRANT SELECT ON brand_competition_dashboard TO dashboard_user, data_analyst;
GRANT SELECT ON customer_analytics_dashboard TO dashboard_user, data_analyst;
GRANT SELECT ON system_health_dashboard TO dashboard_user, data_analyst, db_admin;
GRANT SELECT ON hourly_sales_patterns TO dashboard_user, data_analyst;
GRANT SELECT ON category_performance_analytics TO dashboard_user, data_analyst;

-- Grant execute permission for refresh procedure
GRANT EXECUTE ON PROCEDURE refresh_all_analytics() TO dashboard_user, db_admin;

-- =====================================================
-- MONITORING ALERTS AND NOTIFICATIONS
-- =====================================================

-- Critical performance alerts
CREATE OR REPLACE FUNCTION check_system_alerts()
RETURNS TABLE (
    alert_type TEXT,
    severity TEXT,
    message TEXT,
    affected_count INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    -- Device connectivity alerts
    SELECT 
        'DEVICE_CONNECTIVITY'::TEXT,
        'high'::TEXT,
        'Devices offline for more than 24 hours'::TEXT,
        COUNT(*)::INTEGER
    FROM device_master 
    WHERE last_seen < CURRENT_DATE - INTERVAL '24 hours'
    HAVING COUNT(*) > 0
    
    UNION ALL
    
    -- Revenue anomaly alerts
    SELECT 
        'REVENUE_ANOMALY'::TEXT,
        'medium'::TEXT,
        'Stores with zero revenue today'::TEXT,
        COUNT(*)::INTEGER
    FROM stores s
    WHERE NOT EXISTS (
        SELECT 1 FROM sales_interactions si 
        WHERE si.store_id = s.id 
        AND DATE(si.transaction_date) = CURRENT_DATE
    )
    HAVING COUNT(*) > 5
    
    UNION ALL
    
    -- High anomaly count
    SELECT 
        'ANOMALY_COUNT'::TEXT,
        'high'::TEXT,
        'High number of active anomalies'::TEXT,
        COUNT(*)::INTEGER
    FROM anomalies 
    WHERE status = 'active' AND severity = 'high'
    HAVING COUNT(*) > 10;
END;
$$;

-- Schedule alert checks
SELECT cron.schedule('system-alerts', '0 */2 * * *', 
    'INSERT INTO audit_log (table_name, action, new_data) 
     SELECT ''system_alerts'', ''ALERT_CHECK'', 
            json_agg(row_to_json(alerts))
     FROM check_system_alerts() alerts;'
);

-- Add comments for documentation
COMMENT ON VIEW executive_dashboard IS 'Real-time executive KPIs and performance indicators';
COMMENT ON VIEW store_performance_dashboard IS 'Individual store performance metrics and health status';
COMMENT ON VIEW brand_competition_dashboard IS 'Brand market share and competition analysis';
COMMENT ON VIEW customer_analytics_dashboard IS 'Customer behavior and demographic analytics';
COMMENT ON VIEW system_health_dashboard IS 'Operational health monitoring and system status';
COMMENT ON VIEW hourly_sales_patterns IS 'Time-based sales pattern analysis for operational insights';
COMMENT ON MATERIALIZED VIEW category_performance_analytics IS 'Product category performance and market dynamics';
COMMENT ON FUNCTION check_system_alerts() IS 'System health alerts and critical notifications';