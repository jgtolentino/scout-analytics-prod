-- =====================================================
-- Scout Analytics Stored Procedures and Functions
-- Version: 002 - Essential Automation Functions
-- Purpose: Data processing, analytics refresh, and anomaly detection
-- Target: Azure PostgreSQL Flexible Server
-- =====================================================

-- =====================================================
-- ANALYTICS REFRESH PROCEDURES
-- =====================================================

-- Daily Analytics Refresh Procedure
CREATE OR REPLACE PROCEDURE refresh_analytics()
LANGUAGE plpgsql
AS $$
DECLARE
    refresh_start_time TIMESTAMPTZ;
    refresh_end_time TIMESTAMPTZ;
    rows_affected INTEGER;
BEGIN
    refresh_start_time := NOW();
    
    -- Log refresh start
    INSERT INTO audit_log (table_name, action, new_data)
    VALUES ('analytics_refresh', 'START', json_build_object('started_at', refresh_start_time));
    
    -- Refresh materialized views in order of dependency
    RAISE NOTICE 'Refreshing daily_sales materialized view...';
    REFRESH MATERIALIZED VIEW CONCURRENTLY daily_sales;
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RAISE NOTICE 'daily_sales refreshed: % rows', rows_affected;
    
    RAISE NOTICE 'Refreshing product_performance materialized view...';
    REFRESH MATERIALIZED VIEW CONCURRENTLY product_performance;
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RAISE NOTICE 'product_performance refreshed: % rows', rows_affected;
    
    RAISE NOTICE 'Refreshing regional_performance materialized view...';
    REFRESH MATERIALIZED VIEW CONCURRENTLY regional_performance;
    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RAISE NOTICE 'regional_performance refreshed: % rows', rows_affected;
    
    refresh_end_time := NOW();
    
    -- Log successful completion
    INSERT INTO audit_log (table_name, action, new_data)
    VALUES ('analytics_refresh', 'COMPLETE', 
            json_build_object(
                'started_at', refresh_start_time,
                'completed_at', refresh_end_time,
                'duration_seconds', EXTRACT(EPOCH FROM (refresh_end_time - refresh_start_time))
            ));
            
    RAISE NOTICE 'Analytics refresh completed in % seconds', 
                 EXTRACT(EPOCH FROM (refresh_end_time - refresh_start_time));

EXCEPTION
    WHEN OTHERS THEN
        -- Log error
        INSERT INTO audit_log (table_name, action, new_data)
        VALUES ('analytics_refresh', 'ERROR', 
                json_build_object(
                    'error_message', SQLERRM,
                    'error_state', SQLSTATE,
                    'started_at', refresh_start_time,
                    'failed_at', NOW()
                ));
        RAISE;
END;
$$;

-- FMCG Transaction Flagging Procedure
CREATE OR REPLACE PROCEDURE flag_fmcg_transactions()
LANGUAGE plpgsql
AS $$
DECLARE
    updated_count INTEGER;
    start_time TIMESTAMPTZ;
BEGIN
    start_time := NOW();
    
    -- Update transactions that contain FMCG products
    UPDATE sales_interactions si
    SET is_fmcg = true
    WHERE EXISTS (
        SELECT 1 
        FROM transaction_items ti
        JOIN products p ON ti.product_id = p.id
        WHERE ti.interaction_id = si.interaction_id
        AND p.is_fmcg = true
    )
    AND (si.is_fmcg IS NULL OR si.is_fmcg = false);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    -- Log the operation
    INSERT INTO audit_log (table_name, action, new_data)
    VALUES ('sales_interactions', 'FMCG_FLAG_UPDATE', 
            json_build_object(
                'updated_count', updated_count,
                'execution_time_seconds', EXTRACT(EPOCH FROM (NOW() - start_time))
            ));
            
    RAISE NOTICE 'FMCG flagging completed: % transactions updated', updated_count;
END;
$$;

-- Sales Anomaly Detection Procedure
CREATE OR REPLACE PROCEDURE detect_sales_anomalies()
LANGUAGE plpgsql
AS $$
DECLARE
    anomaly_threshold NUMERIC;
    avg_transaction_amount NUMERIC;
    std_transaction_amount NUMERIC;
    high_value_threshold NUMERIC;
    suspicious_count INTEGER;
    unusual_pattern_count INTEGER;
BEGIN
    -- Calculate transaction statistics for the last 30 days
    SELECT 
        AVG(total_amount),
        STDDEV(total_amount)
    INTO avg_transaction_amount, std_transaction_amount
    FROM sales_interactions 
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days';
    
    high_value_threshold := avg_transaction_amount + (3 * std_transaction_amount);
    
    -- Clear existing active anomalies of the same type
    UPDATE anomalies 
    SET status = 'resolved', resolved_at = NOW() 
    WHERE type IN ('SUSPICIOUS_TRANSACTION', 'UNUSUAL_PATTERN', 'HIGH_SUBSTITUTION_RATE') 
    AND status = 'active';
    
    -- Detect suspicious high-value transactions
    INSERT INTO anomalies (type, details, severity)
    SELECT 
        'SUSPICIOUS_TRANSACTION',
        json_build_object(
            'interaction_id', interaction_id,
            'store_id', store_id,
            'amount', total_amount,
            'threshold', high_value_threshold,
            'date', transaction_date
        ),
        CASE 
            WHEN total_amount > high_value_threshold * 2 THEN 'high'
            ELSE 'medium'
        END
    FROM sales_interactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
    AND total_amount > high_value_threshold;
    
    GET DIAGNOSTICS suspicious_count = ROW_COUNT;
    
    -- Detect unusual store patterns (stores with significantly different performance)
    WITH store_performance AS (
        SELECT 
            store_id,
            AVG(total_amount) as avg_amount,
            COUNT(*) as transaction_count
        FROM sales_interactions 
        WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY store_id
        HAVING COUNT(*) >= 5  -- Only stores with sufficient data
    ),
    performance_stats AS (
        SELECT 
            AVG(avg_amount) as overall_avg,
            STDDEV(avg_amount) as overall_std
        FROM store_performance
    )
    INSERT INTO anomalies (type, details, severity)
    SELECT 
        'UNUSUAL_PATTERN',
        json_build_object(
            'store_id', sp.store_id,
            'store_avg_amount', sp.avg_amount,
            'overall_avg_amount', ps.overall_avg,
            'deviation_factor', ABS(sp.avg_amount - ps.overall_avg) / ps.overall_std
        ),
        'medium'
    FROM store_performance sp
    CROSS JOIN performance_stats ps
    WHERE ABS(sp.avg_amount - ps.overall_avg) > (2 * ps.overall_std);
    
    GET DIAGNOSTICS unusual_pattern_count = ROW_COUNT;
    
    -- Detect high substitution rates by store
    INSERT INTO anomalies (type, details, severity)
    SELECT 
        'HIGH_SUBSTITUTION_RATE',
        json_build_object(
            'store_id', store_id,
            'substitution_rate', substitution_rate,
            'transaction_count', transaction_count
        ),
        'low'
    FROM (
        SELECT 
            store_id,
            COUNT(*) as transaction_count,
            (SUM(CASE WHEN substitution_occurred THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100 as substitution_rate
        FROM sales_interactions 
        WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY store_id
        HAVING COUNT(*) >= 10  -- Only stores with sufficient transactions
    ) store_substitutions
    WHERE substitution_rate > 25;  -- Alert if substitution rate > 25%
    
    -- Log anomaly detection results
    INSERT INTO audit_log (table_name, action, new_data)
    VALUES ('anomalies', 'DETECTION_RUN', 
            json_build_object(
                'suspicious_transactions', suspicious_count,
                'unusual_patterns', unusual_pattern_count,
                'high_value_threshold', high_value_threshold,
                'detection_date', CURRENT_DATE
            ));
            
    RAISE NOTICE 'Anomaly detection completed: % suspicious transactions, % unusual patterns detected', 
                 suspicious_count, unusual_pattern_count;
END;
$$;

-- =====================================================
-- DATA MAINTENANCE PROCEDURES
-- =====================================================

-- Data Retention and Cleanup Procedure
CREATE OR REPLACE PROCEDURE purge_old_data(retention_months INTEGER DEFAULT 12)
LANGUAGE plpgsql
AS $$
DECLARE
    cutoff_date DATE;
    deleted_interactions INTEGER;
    deleted_audit_logs INTEGER;
    deleted_anomalies INTEGER;
BEGIN
    cutoff_date := CURRENT_DATE - INTERVAL '1 month' * retention_months;
    
    -- Delete old transaction items first (foreign key dependency)
    DELETE FROM transaction_items ti
    WHERE EXISTS (
        SELECT 1 FROM sales_interactions si 
        WHERE si.interaction_id = ti.interaction_id 
        AND si.transaction_date < cutoff_date
    );
    
    -- Delete old sales interactions
    DELETE FROM sales_interactions 
    WHERE transaction_date < cutoff_date;
    GET DIAGNOSTICS deleted_interactions = ROW_COUNT;
    
    -- Clean up old audit logs (keep 6 months regardless of retention setting)
    DELETE FROM audit_log 
    WHERE timestamp < CURRENT_DATE - INTERVAL '6 months';
    GET DIAGNOSTICS deleted_audit_logs = ROW_COUNT;
    
    -- Clean up resolved anomalies older than 3 months
    DELETE FROM anomalies 
    WHERE status = 'resolved' 
    AND resolved_at < CURRENT_DATE - INTERVAL '3 months';
    GET DIAGNOSTICS deleted_anomalies = ROW_COUNT;
    
    -- Log the cleanup operation
    INSERT INTO audit_log (table_name, action, new_data)
    VALUES ('data_cleanup', 'PURGE_COMPLETE', 
            json_build_object(
                'cutoff_date', cutoff_date,
                'deleted_interactions', deleted_interactions,
                'deleted_audit_logs', deleted_audit_logs,
                'deleted_anomalies', deleted_anomalies
            ));
            
    RAISE NOTICE 'Data purge completed: % interactions, % audit logs, % anomalies deleted', 
                 deleted_interactions, deleted_audit_logs, deleted_anomalies;
END;
$$;

-- =====================================================
-- BUSINESS INTELLIGENCE FUNCTIONS
-- =====================================================

-- Calculate Market Share by Brand and Region
CREATE OR REPLACE FUNCTION get_market_share(
    p_brand_name TEXT,
    p_region TEXT DEFAULT NULL,
    p_days INTEGER DEFAULT 30
) RETURNS TABLE (
    brand_name TEXT,
    region TEXT,
    total_revenue NUMERIC,
    market_share_percent NUMERIC,
    rank_in_region INTEGER
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH regional_sales AS (
        SELECT 
            b.name as brand,
            s.region,
            SUM(ti.quantity * p.unit_price) as revenue
        FROM transaction_items ti
        JOIN products p ON ti.product_id = p.id
        JOIN brands b ON p.brand_id = b.id
        JOIN sales_interactions si ON ti.interaction_id = si.interaction_id
        JOIN stores s ON si.store_id = s.id
        WHERE si.transaction_date >= CURRENT_DATE - INTERVAL '1 day' * p_days
        AND (p_region IS NULL OR s.region = p_region)
        GROUP BY b.name, s.region
    ),
    market_totals AS (
        SELECT 
            region,
            SUM(revenue) as total_market_revenue
        FROM regional_sales
        GROUP BY region
    )
    SELECT 
        rs.brand::TEXT,
        rs.region::TEXT,
        rs.revenue,
        ROUND((rs.revenue / mt.total_market_revenue) * 100, 2) as market_share_pct,
        RANK() OVER (PARTITION BY rs.region ORDER BY rs.revenue DESC)::INTEGER as rank_pos
    FROM regional_sales rs
    JOIN market_totals mt ON rs.region = mt.region
    WHERE (p_brand_name IS NULL OR rs.brand = p_brand_name)
    ORDER BY rs.region, rs.revenue DESC;
END;
$$;

-- Generate Customer Insights Report
CREATE OR REPLACE FUNCTION generate_customer_insights(p_days INTEGER DEFAULT 30)
RETURNS TABLE (
    segment TEXT,
    customer_count BIGINT,
    avg_transaction_value NUMERIC,
    total_revenue NUMERIC,
    avg_frequency NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cs.customer_segment::TEXT,
        COUNT(*)::BIGINT,
        ROUND(AVG(cs.avg_transaction_value), 2),
        ROUND(SUM(cs.total_spent), 2),
        ROUND(AVG(cs.transaction_count), 2)
    FROM customer_segments cs
    WHERE EXISTS (
        SELECT 1 FROM sales_interactions si 
        WHERE si.customer_id = cs.customer_id 
        AND si.transaction_date >= CURRENT_DATE - INTERVAL '1 day' * p_days
    )
    GROUP BY cs.customer_segment
    ORDER BY SUM(cs.total_spent) DESC;
END;
$$;

-- =====================================================
-- CRON JOB SCHEDULING (if pg_cron is available)
-- =====================================================

-- Schedule daily analytics refresh at 2 AM
SELECT cron.schedule('daily-analytics-refresh', '0 2 * * *', 'CALL refresh_analytics();');

-- Schedule FMCG flagging every 4 hours
SELECT cron.schedule('fmcg-flagging', '0 */4 * * *', 'CALL flag_fmcg_transactions();');

-- Schedule anomaly detection every hour during business hours
SELECT cron.schedule('anomaly-detection', '0 8-20 * * *', 'CALL detect_sales_anomalies();');

-- Schedule weekly data cleanup on Sundays at midnight
SELECT cron.schedule('weekly-cleanup', '0 0 * * 0', 'CALL purge_old_data(12);');

-- =====================================================
-- PERMISSIONS AND SECURITY
-- =====================================================

-- Grant execute permissions to application roles
GRANT EXECUTE ON PROCEDURE refresh_analytics() TO dashboard_user;
GRANT EXECUTE ON PROCEDURE flag_fmcg_transactions() TO dashboard_user;
GRANT EXECUTE ON PROCEDURE detect_sales_anomalies() TO dashboard_user;
GRANT EXECUTE ON FUNCTION get_market_share(TEXT, TEXT, INTEGER) TO dashboard_user;
GRANT EXECUTE ON FUNCTION generate_customer_insights(INTEGER) TO dashboard_user;

-- Restrict data maintenance procedures to admin role only
GRANT EXECUTE ON PROCEDURE purge_old_data(INTEGER) TO db_admin;

-- Add comments for documentation
COMMENT ON PROCEDURE refresh_analytics() IS 'Refreshes all materialized views for analytics dashboards. Run daily.';
COMMENT ON PROCEDURE flag_fmcg_transactions() IS 'Updates FMCG flags on transactions based on product categories.';
COMMENT ON PROCEDURE detect_sales_anomalies() IS 'Detects suspicious transactions and unusual patterns.';
COMMENT ON PROCEDURE purge_old_data(INTEGER) IS 'Removes old data based on retention policy. Admin only.';
COMMENT ON FUNCTION get_market_share(TEXT, TEXT, INTEGER) IS 'Calculates market share by brand and region over specified days.';
COMMENT ON FUNCTION generate_customer_insights(INTEGER) IS 'Generates customer segmentation insights for the specified period.';