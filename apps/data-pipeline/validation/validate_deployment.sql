-- =====================================================
-- Scout Analytics Production Deployment Validation
-- Version: 1.0 - Comprehensive System Validation
-- Purpose: Validate all database components, data quality, and system functionality
-- Target: Azure PostgreSQL Flexible Server
-- =====================================================

-- Set up validation context
\set QUIET 1
\timing on

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '================================================================';
    RAISE NOTICE '             SCOUT ANALYTICS PRODUCTION VALIDATION            ';
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'Starting comprehensive system validation...';
    RAISE NOTICE 'Timestamp: %', NOW();
    RAISE NOTICE '';
END;
$$;

-- =====================================================
-- 1. CORE SCHEMA VALIDATION
-- =====================================================

DO $$
DECLARE
    table_count INTEGER;
    expected_tables TEXT[] := ARRAY[
        'sales_interactions', 'transaction_items', 'products', 'brands', 
        'stores', 'device_master', 'ph_regions', 'audit_log', 'anomalies',
        'user_store_access', 'request_methods', 'session_matches'
    ];
    missing_tables TEXT[] := ARRAY[]::TEXT[];
    table_name TEXT;
BEGIN
    RAISE NOTICE '1. CORE SCHEMA VALIDATION';
    RAISE NOTICE '========================';
    
    -- Check if all expected tables exist
    FOREACH table_name IN ARRAY expected_tables
    LOOP
        SELECT COUNT(*) INTO table_count
        FROM information_schema.tables 
        WHERE table_name = table_name AND table_schema = 'public';
        
        IF table_count = 0 THEN
            missing_tables := missing_tables || table_name;
        END IF;
    END LOOP;
    
    IF array_length(missing_tables, 1) > 0 THEN
        RAISE NOTICE '❌ MISSING TABLES: %', array_to_string(missing_tables, ', ');
    ELSE
        RAISE NOTICE '✅ All core tables present (%)', array_length(expected_tables, 1);
    END IF;
    
    -- Check table row counts
    SELECT COUNT(*) INTO table_count FROM sales_interactions;
    RAISE NOTICE '📊 Sales Interactions: % records', table_count;
    
    SELECT COUNT(*) INTO table_count FROM transaction_items;
    RAISE NOTICE '📊 Transaction Items: % records', table_count;
    
    SELECT COUNT(*) INTO table_count FROM products;
    RAISE NOTICE '📊 Products: % records', table_count;
    
    SELECT COUNT(*) INTO table_count FROM brands;
    RAISE NOTICE '📊 Brands: % records', table_count;
    
    SELECT COUNT(*) INTO table_count FROM stores;
    RAISE NOTICE '📊 Stores: % records', table_count;
    
    SELECT COUNT(*) INTO table_count FROM ph_regions;
    RAISE NOTICE '📊 Philippine Regions: % records', table_count;
    
    RAISE NOTICE '';
END;
$$;

-- =====================================================
-- 2. MATERIALIZED VIEWS VALIDATION
-- =====================================================

DO $$
DECLARE
    view_count INTEGER;
    expected_views TEXT[] := ARRAY[
        'daily_sales', 'product_performance', 'regional_performance',
        'philippine_market_analysis', 'tbwa_brand_performance',
        'brand_competition_dashboard', 'category_performance_analytics'
    ];
    missing_views TEXT[] := ARRAY[]::TEXT[];
    view_name TEXT;
BEGIN
    RAISE NOTICE '2. MATERIALIZED VIEWS VALIDATION';
    RAISE NOTICE '===============================';
    
    -- Check if all materialized views exist
    FOREACH view_name IN ARRAY expected_views
    LOOP
        SELECT COUNT(*) INTO view_count
        FROM pg_matviews 
        WHERE matviewname = view_name AND schemaname = 'public';
        
        IF view_count = 0 THEN
            missing_views := missing_views || view_name;
        END IF;
    END LOOP;
    
    IF array_length(missing_views, 1) > 0 THEN
        RAISE NOTICE '❌ MISSING MATERIALIZED VIEWS: %', array_to_string(missing_views, ', ');
    ELSE
        RAISE NOTICE '✅ All materialized views present (%)', array_length(expected_views, 1);
    END IF;
    
    -- Check materialized view row counts
    SELECT COUNT(*) INTO view_count FROM daily_sales;
    RAISE NOTICE '📊 Daily Sales: % records', view_count;
    
    SELECT COUNT(*) INTO view_count FROM product_performance;
    RAISE NOTICE '📊 Product Performance: % records', view_count;
    
    SELECT COUNT(*) INTO view_count FROM regional_performance;
    RAISE NOTICE '📊 Regional Performance: % records', view_count;
    
    SELECT COUNT(*) INTO view_count FROM tbwa_brand_performance;
    RAISE NOTICE '📊 TBWA Brand Performance: % records', view_count;
    
    RAISE NOTICE '';
END;
$$;

-- =====================================================
-- 3. STORED PROCEDURES VALIDATION
-- =====================================================

DO $$
DECLARE
    proc_count INTEGER;
    expected_procedures TEXT[] := ARRAY[
        'refresh_analytics', 'flag_fmcg_transactions', 'detect_sales_anomalies',
        'purge_old_data', 'refresh_all_analytics'
    ];
    missing_procedures TEXT[] := ARRAY[]::TEXT[];
    proc_name TEXT;
BEGIN
    RAISE NOTICE '3. STORED PROCEDURES VALIDATION';
    RAISE NOTICE '==============================';
    
    -- Check if all procedures exist
    FOREACH proc_name IN ARRAY expected_procedures
    LOOP
        SELECT COUNT(*) INTO proc_count
        FROM pg_proc 
        WHERE proname = proc_name;
        
        IF proc_count = 0 THEN
            missing_procedures := missing_procedures || proc_name;
        END IF;
    END LOOP;
    
    IF array_length(missing_procedures, 1) > 0 THEN
        RAISE NOTICE '❌ MISSING PROCEDURES: %', array_to_string(missing_procedures, ', ');
    ELSE
        RAISE NOTICE '✅ All stored procedures present (%)', array_length(expected_procedures, 1);
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- =====================================================
-- 4. SECURITY VALIDATION
-- =====================================================

DO $$
DECLARE
    rls_count INTEGER;
    trigger_count INTEGER;
    role_count INTEGER;
BEGIN
    RAISE NOTICE '4. SECURITY VALIDATION';
    RAISE NOTICE '=====================';
    
    -- Check RLS is enabled on core tables
    SELECT COUNT(*) INTO rls_count
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname IN ('sales_interactions', 'transaction_items', 'products', 'stores')
    AND c.relrowsecurity = true
    AND n.nspname = 'public';
    
    IF rls_count >= 4 THEN
        RAISE NOTICE '✅ Row Level Security enabled on core tables';
    ELSE
        RAISE NOTICE '❌ RLS not properly enabled (% of 4 tables)', rls_count;
    END IF;
    
    -- Check audit triggers exist
    SELECT COUNT(*) INTO trigger_count
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE t.tgname LIKE '%_audit'
    AND c.relname IN ('sales_interactions', 'products', 'stores', 'brands');
    
    IF trigger_count >= 4 THEN
        RAISE NOTICE '✅ Audit triggers configured (% triggers)', trigger_count;
    ELSE
        RAISE NOTICE '⚠️  Audit triggers may be missing (% triggers)', trigger_count;
    END IF;
    
    -- Check security roles exist
    SELECT COUNT(*) INTO role_count
    FROM pg_roles 
    WHERE rolname IN ('dashboard_user', 'data_analyst', 'store_manager', 'db_admin', 'audit_viewer');
    
    RAISE NOTICE '📊 Security roles configured: %', role_count;
    
    RAISE NOTICE '';
END;
$$;

-- =====================================================
-- 5. DATA QUALITY VALIDATION
-- =====================================================

DO $$
DECLARE
    null_percentage NUMERIC;
    avg_transaction_amount NUMERIC;
    zero_amount_count INTEGER;
    future_transactions INTEGER;
    orphaned_items INTEGER;
    data_quality_score INTEGER := 100;
BEGIN
    RAISE NOTICE '5. DATA QUALITY VALIDATION';
    RAISE NOTICE '=========================';
    
    -- Check for NULL values in critical fields
    SELECT 
        ROUND(
            (SUM(CASE WHEN total_amount IS NULL THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100, 2
        ) INTO null_percentage
    FROM sales_interactions;
    
    IF null_percentage > 5 THEN
        RAISE NOTICE '❌ High NULL percentage in total_amount: %%', null_percentage;
        data_quality_score := data_quality_score - 20;
    ELSE
        RAISE NOTICE '✅ NULL values in total_amount: %%', null_percentage;
    END IF;
    
    -- Check transaction amounts are reasonable
    SELECT AVG(total_amount) INTO avg_transaction_amount FROM sales_interactions;
    
    IF avg_transaction_amount BETWEEN 20 AND 500 THEN
        RAISE NOTICE '✅ Average transaction amount reasonable: PHP %', ROUND(avg_transaction_amount, 2);
    ELSE
        RAISE NOTICE '⚠️  Average transaction amount unusual: PHP %', ROUND(avg_transaction_amount, 2);
        data_quality_score := data_quality_score - 10;
    END IF;
    
    -- Check for zero-amount transactions
    SELECT COUNT(*) INTO zero_amount_count 
    FROM sales_interactions 
    WHERE total_amount = 0;
    
    IF zero_amount_count > 100 THEN
        RAISE NOTICE '⚠️  High number of zero-amount transactions: %', zero_amount_count;
        data_quality_score := data_quality_score - 10;
    ELSE
        RAISE NOTICE '✅ Zero-amount transactions within acceptable range: %', zero_amount_count;
    END IF;
    
    -- Check for future-dated transactions
    SELECT COUNT(*) INTO future_transactions
    FROM sales_interactions 
    WHERE transaction_date > NOW();
    
    IF future_transactions > 0 THEN
        RAISE NOTICE '❌ Future-dated transactions found: %', future_transactions;
        data_quality_score := data_quality_score - 15;
    ELSE
        RAISE NOTICE '✅ No future-dated transactions';
    END IF;
    
    -- Check for orphaned transaction items
    SELECT COUNT(*) INTO orphaned_items
    FROM transaction_items ti
    WHERE NOT EXISTS (
        SELECT 1 FROM sales_interactions si 
        WHERE si.interaction_id = ti.interaction_id
    );
    
    IF orphaned_items > 0 THEN
        RAISE NOTICE '❌ Orphaned transaction items found: %', orphaned_items;
        data_quality_score := data_quality_score - 15;
    ELSE
        RAISE NOTICE '✅ No orphaned transaction items';
    END IF;
    
    RAISE NOTICE '📊 Data Quality Score: %/100', data_quality_score;
    RAISE NOTICE '';
END;
$$;

-- =====================================================
-- 6. PHILIPPINE MARKET DATA VALIDATION
-- =====================================================

DO $$
DECLARE
    region_count INTEGER;
    tbwa_brands INTEGER;
    competitor_brands INTEGER;
    tbwa_revenue NUMERIC;
    competitor_revenue NUMERIC;
    market_share NUMERIC;
BEGIN
    RAISE NOTICE '6. PHILIPPINE MARKET DATA VALIDATION';
    RAISE NOTICE '===================================';
    
    -- Check Philippine regions coverage
    SELECT COUNT(DISTINCT region) INTO region_count FROM stores;
    
    IF region_count >= 15 THEN
        RAISE NOTICE '✅ Philippine regional coverage: % regions', region_count;
    ELSE
        RAISE NOTICE '⚠️  Limited regional coverage: % regions', region_count;
    END IF;
    
    -- Check TBWA vs competitor brand distribution
    SELECT COUNT(*) INTO tbwa_brands
    FROM brands 
    WHERE name IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More');
    
    SELECT COUNT(*) INTO competitor_brands
    FROM brands 
    WHERE name NOT IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More');
    
    RAISE NOTICE '📊 TBWA Client Brands: %', tbwa_brands;
    RAISE NOTICE '📊 Competitor Brands: %', competitor_brands;
    
    -- Calculate market share
    SELECT 
        SUM(CASE WHEN b.name IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
                 THEN ti.quantity * p.unit_price ELSE 0 END),
        SUM(CASE WHEN b.name NOT IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
                 THEN ti.quantity * p.unit_price ELSE 0 END)
    INTO tbwa_revenue, competitor_revenue
    FROM transaction_items ti
    JOIN products p ON ti.product_id = p.id
    JOIN brands b ON p.brand_id = b.id;
    
    market_share := ROUND(tbwa_revenue / (tbwa_revenue + competitor_revenue) * 100, 2);
    
    RAISE NOTICE '📊 TBWA Revenue: PHP %', ROUND(tbwa_revenue, 2);
    RAISE NOTICE '📊 Competitor Revenue: PHP %', ROUND(competitor_revenue, 2);
    RAISE NOTICE '📊 TBWA Market Share: %%', market_share;
    
    IF market_share BETWEEN 55 AND 75 THEN
        RAISE NOTICE '✅ Market share within expected range (55-75%%)';
    ELSE
        RAISE NOTICE '⚠️  Market share outside expected range: %%', market_share;
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- =====================================================
-- 7. PERFORMANCE VALIDATION
-- =====================================================

DO $$
DECLARE
    index_count INTEGER;
    query_time INTERVAL;
    start_time TIMESTAMP;
BEGIN
    RAISE NOTICE '7. PERFORMANCE VALIDATION';
    RAISE NOTICE '========================';
    
    -- Check critical indexes exist
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE tablename IN ('sales_interactions', 'transaction_items', 'products', 'stores')
    AND indexname LIKE 'idx_%';
    
    IF index_count >= 10 THEN
        RAISE NOTICE '✅ Performance indexes configured: %', index_count;
    ELSE
        RAISE NOTICE '⚠️  Limited performance indexes: %', index_count;
    END IF;
    
    -- Test query performance on daily_sales
    start_time := clock_timestamp();
    PERFORM COUNT(*) FROM daily_sales WHERE sale_date >= CURRENT_DATE - 30;
    query_time := clock_timestamp() - start_time;
    
    IF query_time < INTERVAL '1 second' THEN
        RAISE NOTICE '✅ Daily sales query performance: %', query_time;
    ELSE
        RAISE NOTICE '⚠️  Slow daily sales query: %', query_time;
    END IF;
    
    -- Test product performance query
    start_time := clock_timestamp();
    PERFORM COUNT(*) FROM product_performance WHERE category = 'Dairy';
    query_time := clock_timestamp() - start_time;
    
    IF query_time < INTERVAL '500 milliseconds' THEN
        RAISE NOTICE '✅ Product performance query: %', query_time;
    ELSE
        RAISE NOTICE '⚠️  Slow product performance query: %', query_time;
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- =====================================================
-- 8. BUSINESS INTELLIGENCE VALIDATION
-- =====================================================

DO $$
DECLARE
    executive_data RECORD;
    top_brand RECORD;
    top_region RECORD;
BEGIN
    RAISE NOTICE '8. BUSINESS INTELLIGENCE VALIDATION';
    RAISE NOTICE '==================================';
    
    -- Test executive dashboard
    SELECT * INTO executive_data FROM executive_dashboard LIMIT 1;
    
    IF executive_data IS NOT NULL THEN
        RAISE NOTICE '✅ Executive Dashboard: % transactions today, PHP % revenue', 
                     COALESCE(executive_data.total_transactions_today, 0),
                     ROUND(COALESCE(executive_data.revenue_today, 0), 2);
    ELSE
        RAISE NOTICE '❌ Executive Dashboard query failed';
    END IF;
    
    -- Test brand performance
    SELECT brand_name, total_revenue INTO top_brand 
    FROM tbwa_brand_performance 
    ORDER BY total_revenue DESC LIMIT 1;
    
    IF top_brand IS NOT NULL THEN
        RAISE NOTICE '✅ Top TBWA Brand: % (PHP %)', top_brand.brand_name, ROUND(top_brand.total_revenue, 2);
    ELSE
        RAISE NOTICE '❌ Brand performance data missing';
    END IF;
    
    -- Test regional analysis
    SELECT region, total_revenue INTO top_region 
    FROM philippine_market_analysis 
    ORDER BY total_revenue DESC LIMIT 1;
    
    IF top_region IS NOT NULL THEN
        RAISE NOTICE '✅ Top Performing Region: % (PHP %)', top_region.region, ROUND(top_region.total_revenue, 2);
    ELSE
        RAISE NOTICE '❌ Regional analysis data missing';
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- =====================================================
-- 9. MONITORING AND ALERTS VALIDATION
-- =====================================================

DO $$
DECLARE
    health_score INTEGER;
    active_anomalies INTEGER;
    system_alerts RECORD;
BEGIN
    RAISE NOTICE '9. MONITORING AND ALERTS VALIDATION';
    RAISE NOTICE '===================================';
    
    -- Test system health dashboard
    SELECT overall_health_score INTO health_score FROM system_health_dashboard LIMIT 1;
    
    IF health_score IS NOT NULL THEN
        IF health_score >= 90 THEN
            RAISE NOTICE '✅ System Health Score: %/100 (Excellent)', health_score;
        ELSIF health_score >= 75 THEN
            RAISE NOTICE '✅ System Health Score: %/100 (Good)', health_score;
        ELSE
            RAISE NOTICE '⚠️  System Health Score: %/100 (Needs Attention)', health_score;
        END IF;
    ELSE
        RAISE NOTICE '❌ System health monitoring not working';
    END IF;
    
    -- Check anomaly detection
    SELECT COUNT(*) INTO active_anomalies FROM anomalies WHERE status = 'active';
    RAISE NOTICE '📊 Active Anomalies: %', active_anomalies;
    
    -- Test alert function
    SELECT COUNT(*) INTO active_anomalies FROM check_system_alerts();
    RAISE NOTICE '📊 System Alerts Generated: %', active_anomalies;
    
    RAISE NOTICE '';
END;
$$;

-- =====================================================
-- 10. FINAL VALIDATION SUMMARY
-- =====================================================

DO $$
DECLARE
    total_interactions INTEGER;
    total_revenue NUMERIC;
    validation_score INTEGER := 0;
    max_score INTEGER := 100;
BEGIN
    RAISE NOTICE '10. FINAL VALIDATION SUMMARY';
    RAISE NOTICE '===========================';
    
    -- Calculate overall metrics
    SELECT COUNT(*), SUM(total_amount) 
    INTO total_interactions, total_revenue 
    FROM sales_interactions;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 DEPLOYMENT METRICS:';
    RAISE NOTICE '  - Total Sales Interactions: %', total_interactions;
    RAISE NOTICE '  - Total Revenue Generated: PHP %', ROUND(total_revenue, 2);
    RAISE NOTICE '  - Average Transaction Value: PHP %', ROUND(total_revenue / total_interactions, 2);
    
    -- Calculate validation score based on key checks
    IF total_interactions >= 5000 THEN validation_score := validation_score + 20; END IF;
    IF total_revenue > 1000000 THEN validation_score := validation_score + 15; END IF;
    IF EXISTS (SELECT 1 FROM daily_sales LIMIT 1) THEN validation_score := validation_score + 15; END IF;
    IF EXISTS (SELECT 1 FROM tbwa_brand_performance LIMIT 1) THEN validation_score := validation_score + 15; END IF;
    IF EXISTS (SELECT 1 FROM philippine_market_analysis LIMIT 1) THEN validation_score := validation_score + 15; END IF;
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'brand_competition_dashboard') THEN validation_score := validation_score + 10; END IF;
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'refresh_analytics') THEN validation_score := validation_score + 10; END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎯 VALIDATION SCORE: %/% (%%)', validation_score, max_score, ROUND(validation_score::NUMERIC / max_score * 100, 1);
    
    IF validation_score >= 90 THEN
        RAISE NOTICE '✅ DEPLOYMENT VALIDATION: PASSED (Excellent)';
        RAISE NOTICE '🚀 System ready for production deployment';
    ELSIF validation_score >= 75 THEN
        RAISE NOTICE '✅ DEPLOYMENT VALIDATION: PASSED (Good)';
        RAISE NOTICE '📝 Minor improvements recommended';
    ELSIF validation_score >= 60 THEN
        RAISE NOTICE '⚠️  DEPLOYMENT VALIDATION: PARTIAL (Acceptable)';
        RAISE NOTICE '🔧 Several issues require attention';
    ELSE
        RAISE NOTICE '❌ DEPLOYMENT VALIDATION: FAILED';
        RAISE NOTICE '🔥 Critical issues must be resolved before production';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '================================================================';
    RAISE NOTICE '             VALIDATION COMPLETE - %            ', NOW()::DATE;
    RAISE NOTICE '================================================================';
    
    -- Log validation results to audit trail
    INSERT INTO audit_log (table_name, action, new_data)
    VALUES ('deployment_validation', 'VALIDATION_COMPLETE', 
            json_build_object(
                'validation_score', validation_score,
                'max_score', max_score,
                'total_interactions', total_interactions,
                'total_revenue', total_revenue,
                'validation_date', CURRENT_DATE,
                'validation_timestamp', NOW()
            ));
END;
$$;

\timing off
\set QUIET 0