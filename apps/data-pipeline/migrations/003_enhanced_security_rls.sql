-- =====================================================
-- Scout Analytics Enhanced Security and RLS Policies
-- Version: 003 - Comprehensive Security Implementation
-- Purpose: Row-level security, audit triggers, and access controls
-- Target: Azure PostgreSQL Flexible Server
-- =====================================================

-- =====================================================
-- CREATE SECURITY ROLES AND USERS
-- =====================================================

-- Create roles if they don't exist
DO $$
BEGIN
    -- Dashboard application role
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'dashboard_user') THEN
        CREATE ROLE dashboard_user;
    END IF;
    
    -- Data analyst role
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'data_analyst') THEN
        CREATE ROLE data_analyst;
    END IF;
    
    -- Store manager role
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'store_manager') THEN
        CREATE ROLE store_manager;
    END IF;
    
    -- Database administrator role
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'db_admin') THEN
        CREATE ROLE db_admin;
    END IF;
    
    -- Audit viewer role
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'audit_viewer') THEN
        CREATE ROLE audit_viewer;
    END IF;
END
$$;

-- =====================================================
-- AUDIT TRAIL FUNCTIONS AND TRIGGERS
-- =====================================================

-- Enhanced audit trail function with IP and user agent capture
CREATE OR REPLACE FUNCTION log_data_changes()
RETURNS TRIGGER AS $$
DECLARE
    current_user_id UUID;
    client_ip INET;
    user_agent TEXT;
BEGIN
    -- Extract user context from application (if available)
    current_user_id := COALESCE(
        (current_setting('app.user_id', true))::UUID,
        NULL
    );
    
    -- Extract client IP (if available from application context)
    client_ip := COALESCE(
        (current_setting('app.client_ip', true))::INET,
        inet_client_addr()
    );
    
    -- Extract user agent (if available from application context)
    user_agent := current_setting('app.user_agent', true);
    
    -- Insert audit record
    INSERT INTO audit_log (
        user_id,
        table_name,
        action,
        old_data,
        new_data,
        ip_address,
        user_agent
    ) VALUES (
        current_user_id,
        TG_TABLE_NAME,
        TG_OP,
        CASE WHEN TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE NULL END,
        CASE WHEN TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN row_to_json(NEW) ELSE NULL END,
        client_ip,
        user_agent
    );
    
    -- Return appropriate record
    RETURN CASE 
        WHEN TG_OP = 'DELETE' THEN OLD
        ELSE NEW
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit triggers to sensitive tables
DROP TRIGGER IF EXISTS sales_interactions_audit ON sales_interactions;
CREATE TRIGGER sales_interactions_audit
    AFTER INSERT OR UPDATE OR DELETE ON sales_interactions
    FOR EACH ROW EXECUTE FUNCTION log_data_changes();

DROP TRIGGER IF EXISTS products_audit ON products;
CREATE TRIGGER products_audit
    AFTER UPDATE OR DELETE ON products
    FOR EACH ROW EXECUTE FUNCTION log_data_changes();

DROP TRIGGER IF EXISTS stores_audit ON stores;
CREATE TRIGGER stores_audit
    AFTER UPDATE OR DELETE ON stores
    FOR EACH ROW EXECUTE FUNCTION log_data_changes();

DROP TRIGGER IF EXISTS brands_audit ON brands;
CREATE TRIGGER brands_audit
    AFTER UPDATE OR DELETE ON brands
    FOR EACH ROW EXECUTE FUNCTION log_data_changes();

-- =====================================================
-- ROW LEVEL SECURITY POLICIES
-- =====================================================

-- Enable RLS on core tables
ALTER TABLE sales_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE anomalies ENABLE ROW LEVEL SECURITY;

-- Sales Interactions RLS Policies
DROP POLICY IF EXISTS "sales_interactions_admin_full_access" ON sales_interactions;
CREATE POLICY "sales_interactions_admin_full_access" ON sales_interactions
    FOR ALL TO db_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "sales_interactions_dashboard_read" ON sales_interactions;
CREATE POLICY "sales_interactions_dashboard_read" ON sales_interactions
    FOR SELECT TO dashboard_user
    USING (true);

DROP POLICY IF EXISTS "sales_interactions_analyst_read" ON sales_interactions;
CREATE POLICY "sales_interactions_analyst_read" ON sales_interactions
    FOR SELECT TO data_analyst
    USING (
        -- Analysts can see data from last 90 days
        transaction_date >= CURRENT_DATE - INTERVAL '90 days'
    );

DROP POLICY IF EXISTS "sales_interactions_store_manager" ON sales_interactions;
CREATE POLICY "sales_interactions_store_manager" ON sales_interactions
    FOR SELECT TO store_manager
    USING (
        -- Store managers can only see their store's data
        store_id IN (
            SELECT store_id FROM user_store_access 
            WHERE user_id = current_setting('app.user_id')::UUID
        )
        AND transaction_date >= CURRENT_DATE - INTERVAL '30 days'
    );

DROP POLICY IF EXISTS "sales_interactions_business_hours" ON sales_interactions;
CREATE POLICY "sales_interactions_business_hours" ON sales_interactions
    FOR SELECT TO data_analyst, store_manager
    USING (
        -- Restrict access to business hours (8 AM - 8 PM) unless admin
        EXTRACT(HOUR FROM CURRENT_TIME) BETWEEN 8 AND 20
        OR current_user = 'db_admin'
    );

-- Transaction Items RLS Policies
DROP POLICY IF EXISTS "transaction_items_admin_full_access" ON transaction_items;
CREATE POLICY "transaction_items_admin_full_access" ON transaction_items
    FOR ALL TO db_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "transaction_items_dashboard_read" ON transaction_items;
CREATE POLICY "transaction_items_dashboard_read" ON transaction_items
    FOR SELECT TO dashboard_user
    USING (true);

DROP POLICY IF EXISTS "transaction_items_analyst_read" ON transaction_items;
CREATE POLICY "transaction_items_analyst_read" ON transaction_items
    FOR SELECT TO data_analyst
    USING (
        EXISTS (
            SELECT 1 FROM sales_interactions si 
            WHERE si.interaction_id = transaction_items.interaction_id
            AND si.transaction_date >= CURRENT_DATE - INTERVAL '90 days'
        )
    );

-- Stores RLS Policies
DROP POLICY IF EXISTS "stores_admin_full_access" ON stores;
CREATE POLICY "stores_admin_full_access" ON stores
    FOR ALL TO db_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "stores_read_access" ON stores;
CREATE POLICY "stores_read_access" ON stores
    FOR SELECT TO dashboard_user, data_analyst
    USING (true);

DROP POLICY IF EXISTS "stores_manager_access" ON stores;
CREATE POLICY "stores_manager_access" ON stores
    FOR SELECT TO store_manager
    USING (
        id IN (
            SELECT store_id FROM user_store_access 
            WHERE user_id = current_setting('app.user_id')::UUID
        )
    );

-- Products RLS Policies
DROP POLICY IF EXISTS "products_admin_full_access" ON products;
CREATE POLICY "products_admin_full_access" ON products
    FOR ALL TO db_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "products_read_access" ON products;
CREATE POLICY "products_read_access" ON products
    FOR SELECT TO dashboard_user, data_analyst, store_manager
    USING (true);

DROP POLICY IF EXISTS "products_update_restricted" ON products;
CREATE POLICY "products_update_restricted" ON products
    FOR UPDATE TO dashboard_user
    USING (
        -- Only allow price updates, not core product info
        true
    )
    WITH CHECK (
        -- Ensure only price fields can be updated by non-admin users
        OLD.name = NEW.name
        AND OLD.brand_id = NEW.brand_id
        AND OLD.category = NEW.category
        AND OLD.is_fmcg = NEW.is_fmcg
    );

-- Audit Log RLS Policies
DROP POLICY IF EXISTS "audit_log_admin_access" ON audit_log;
CREATE POLICY "audit_log_admin_access" ON audit_log
    FOR ALL TO db_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "audit_log_viewer_access" ON audit_log;
CREATE POLICY "audit_log_viewer_access" ON audit_log
    FOR SELECT TO audit_viewer
    USING (
        -- Audit viewers can see logs from last 30 days
        timestamp >= CURRENT_DATE - INTERVAL '30 days'
    );

DROP POLICY IF EXISTS "audit_log_user_own_actions" ON audit_log;
CREATE POLICY "audit_log_user_own_actions" ON audit_log
    FOR SELECT TO dashboard_user, data_analyst, store_manager
    USING (
        -- Users can see their own actions
        user_id = current_setting('app.user_id')::UUID
        AND timestamp >= CURRENT_DATE - INTERVAL '7 days'
    );

-- Device Master RLS Policies
DROP POLICY IF EXISTS "device_master_admin_access" ON device_master;
CREATE POLICY "device_master_admin_access" ON device_master
    FOR ALL TO db_admin
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "device_master_store_access" ON device_master;
CREATE POLICY "device_master_store_access" ON device_master
    FOR SELECT TO store_manager
    USING (
        store_id IN (
            SELECT store_id FROM user_store_access 
            WHERE user_id = current_setting('app.user_id')::UUID
        )
    );

-- =====================================================
-- USER-STORE ACCESS MANAGEMENT
-- =====================================================

-- Create user-store access mapping table
CREATE TABLE IF NOT EXISTS user_store_access (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL,
    store_id INTEGER NOT NULL REFERENCES stores(id),
    access_level TEXT DEFAULT 'read' CHECK (access_level IN ('read', 'write', 'admin')),
    granted_by UUID,
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    UNIQUE(user_id, store_id)
);

-- Index for performance
CREATE INDEX idx_user_store_access_user ON user_store_access (user_id) WHERE is_active = true;
CREATE INDEX idx_user_store_access_store ON user_store_access (store_id) WHERE is_active = true;

-- =====================================================
-- SECURITY ENHANCEMENT FUNCTIONS
-- =====================================================

-- Function to grant store access to users
CREATE OR REPLACE FUNCTION grant_store_access(
    p_user_id UUID,
    p_store_id INTEGER,
    p_access_level TEXT DEFAULT 'read',
    p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    granting_user UUID;
BEGIN
    -- Get the current user (must be admin or have admin access to the store)
    granting_user := current_setting('app.user_id')::UUID;
    
    -- Verify the granting user has admin rights
    IF NOT EXISTS (
        SELECT 1 FROM user_store_access 
        WHERE user_id = granting_user 
        AND store_id = p_store_id 
        AND access_level = 'admin'
        AND is_active = true
    ) AND current_user != 'db_admin' THEN
        RAISE EXCEPTION 'Insufficient privileges to grant store access';
    END IF;
    
    -- Insert or update access record
    INSERT INTO user_store_access (user_id, store_id, access_level, granted_by, expires_at)
    VALUES (p_user_id, p_store_id, p_access_level, granting_user, p_expires_at)
    ON CONFLICT (user_id, store_id) 
    DO UPDATE SET 
        access_level = p_access_level,
        granted_by = granting_user,
        granted_at = NOW(),
        expires_at = p_expires_at,
        is_active = true;
        
    -- Log the access grant
    INSERT INTO audit_log (table_name, action, new_data)
    VALUES ('user_store_access', 'GRANT_ACCESS', 
            json_build_object(
                'user_id', p_user_id,
                'store_id', p_store_id,
                'access_level', p_access_level,
                'granted_by', granting_user
            ));
            
    RETURN true;
END;
$$;

-- Function to revoke store access
CREATE OR REPLACE FUNCTION revoke_store_access(
    p_user_id UUID,
    p_store_id INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    revoking_user UUID;
BEGIN
    revoking_user := current_setting('app.user_id')::UUID;
    
    -- Verify the revoking user has admin rights
    IF NOT EXISTS (
        SELECT 1 FROM user_store_access 
        WHERE user_id = revoking_user 
        AND store_id = p_store_id 
        AND access_level = 'admin'
        AND is_active = true
    ) AND current_user != 'db_admin' THEN
        RAISE EXCEPTION 'Insufficient privileges to revoke store access';
    END IF;
    
    -- Deactivate access
    UPDATE user_store_access 
    SET is_active = false 
    WHERE user_id = p_user_id AND store_id = p_store_id;
    
    -- Log the access revocation
    INSERT INTO audit_log (table_name, action, new_data)
    VALUES ('user_store_access', 'REVOKE_ACCESS', 
            json_build_object(
                'user_id', p_user_id,
                'store_id', p_store_id,
                'revoked_by', revoking_user
            ));
            
    RETURN true;
END;
$$;

-- =====================================================
-- DATA ENCRYPTION AND SENSITIVE DATA PROTECTION
-- =====================================================

-- Function to encrypt sensitive data (for future use)
CREATE OR REPLACE FUNCTION encrypt_sensitive_data(data TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    -- Placeholder for encryption logic
    -- In production, integrate with Azure Key Vault or pgcrypto
    RETURN encode(digest(data, 'sha256'), 'hex');
END;
$$;

-- =====================================================
-- MONITORING AND ALERTING VIEWS
-- =====================================================

-- Security monitoring view
CREATE OR REPLACE VIEW security_dashboard AS
SELECT 
    DATE(timestamp) as audit_date,
    table_name,
    action,
    COUNT(*) as action_count,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT ip_address) as unique_ips
FROM audit_log 
WHERE timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 4 DESC;

-- Failed access attempts view
CREATE OR REPLACE VIEW failed_access_attempts AS
SELECT 
    ip_address,
    user_agent,
    COUNT(*) as attempt_count,
    MIN(timestamp) as first_attempt,
    MAX(timestamp) as last_attempt
FROM audit_log 
WHERE action = 'FAILED_ACCESS'
AND timestamp >= CURRENT_DATE - INTERVAL '24 hours'
GROUP BY 1, 2
HAVING COUNT(*) > 5  -- More than 5 failed attempts
ORDER BY 3 DESC;

-- =====================================================
-- PERMISSIONS AND ROLE ASSIGNMENTS
-- =====================================================

-- Grant basic read permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dashboard_user;
GRANT SELECT ON daily_sales TO dashboard_user;
GRANT SELECT ON product_performance TO dashboard_user;
GRANT SELECT ON regional_performance TO dashboard_user;
GRANT SELECT ON customer_segments TO dashboard_user;

-- Grant analyst permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO data_analyst;
GRANT SELECT ON security_dashboard TO data_analyst;

-- Grant audit viewer permissions
GRANT SELECT ON audit_log TO audit_viewer;
GRANT SELECT ON security_dashboard TO audit_viewer;
GRANT SELECT ON failed_access_attempts TO audit_viewer;

-- Grant store manager permissions
GRANT SELECT ON stores TO store_manager;
GRANT SELECT ON sales_interactions TO store_manager;
GRANT SELECT ON transaction_items TO store_manager;
GRANT SELECT ON products TO store_manager;

-- Grant security function permissions
GRANT EXECUTE ON FUNCTION grant_store_access(UUID, INTEGER, TEXT, TIMESTAMPTZ) TO db_admin;
GRANT EXECUTE ON FUNCTION revoke_store_access(UUID, INTEGER) TO db_admin;

-- =====================================================
-- SECURITY MONITORING SCHEDULED TASKS
-- =====================================================

-- Schedule security monitoring (if pg_cron is available)
SELECT cron.schedule('security-audit', '0 */6 * * *', 
    'INSERT INTO anomalies (type, details, severity) 
     SELECT ''SECURITY_ALERT'', 
            json_build_object(''suspicious_ips'', COUNT(*)), 
            ''high''
     FROM failed_access_attempts 
     WHERE attempt_count > 10;'
);

-- Clean up expired access tokens daily
SELECT cron.schedule('cleanup-expired-access', '0 1 * * *',
    'UPDATE user_store_access 
     SET is_active = false 
     WHERE expires_at < NOW() AND is_active = true;'
);

-- Add table comments for documentation
COMMENT ON TABLE user_store_access IS 'Manages user access permissions to specific stores with expiration support';
COMMENT ON VIEW security_dashboard IS 'Security monitoring dashboard showing audit activity patterns';
COMMENT ON VIEW failed_access_attempts IS 'Tracks failed access attempts for security monitoring';
COMMENT ON FUNCTION grant_store_access(UUID, INTEGER, TEXT, TIMESTAMPTZ) IS 'Grants store access to users with audit trail';
COMMENT ON FUNCTION revoke_store_access(UUID, INTEGER) IS 'Revokes store access from users with audit trail';