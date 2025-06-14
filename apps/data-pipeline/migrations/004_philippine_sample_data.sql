-- =====================================================
-- Scout Analytics Philippine Market Sample Data
-- Version: 004 - Realistic Philippine FMCG Market Simulation
-- Purpose: Create 5,000 realistic sales records with TBWA brands and competitor landscape
-- Target: Azure PostgreSQL Flexible Server
-- =====================================================

-- =====================================================
-- PHILIPPINE REGIONS AND GEOGRAPHIC DATA
-- =====================================================

-- Create Philippine regions table with economic weights
CREATE TABLE IF NOT EXISTS ph_regions (
    id SERIAL PRIMARY KEY,
    mega_region VARCHAR(50) NOT NULL,
    region VARCHAR(100) NOT NULL,
    population_millions NUMERIC(4,2),
    economic_weight NUMERIC(5,4) NOT NULL,
    urban_penetration NUMERIC(3,2) DEFAULT 0.50,
    avg_income_bracket TEXT DEFAULT 'middle',
    tbwa_presence_strength NUMERIC(3,2) DEFAULT 0.65
);

-- Insert Philippine regional data with realistic economic distribution
INSERT INTO ph_regions (mega_region, region, population_millions, economic_weight, urban_penetration, avg_income_bracket, tbwa_presence_strength) VALUES
-- Luzon regions (stronger economy, higher TBWA presence)
('Luzon', 'National Capital Region (NCR)', 13.48, 0.2200, 1.00, 'upper_middle', 0.85),
('Luzon', 'CALABARZON', 14.41, 0.1800, 0.75, 'middle', 0.80),
('Luzon', 'Central Luzon', 12.42, 0.1400, 0.70, 'middle', 0.75),
('Luzon', 'Ilocos Region', 5.30, 0.0800, 0.45, 'lower_middle', 0.60),
('Luzon', 'Cagayan Valley', 3.68, 0.0700, 0.40, 'lower_middle', 0.55),
('Luzon', 'Cordillera Administrative Region (CAR)', 1.80, 0.0600, 0.35, 'lower_middle', 0.50),
('Luzon', 'MIMAROPA', 3.23, 0.0650, 0.30, 'lower_middle', 0.45),
('Luzon', 'Bicol Region', 5.80, 0.0750, 0.45, 'lower_middle', 0.55),

-- Visayas regions (moderate economy, mixed TBWA presence)
('Visayas', 'Western Visayas', 7.95, 0.1100, 0.60, 'middle', 0.70),
('Visayas', 'Central Visayas', 7.81, 0.1200, 0.75, 'middle', 0.75),
('Visayas', 'Eastern Visayas', 4.55, 0.0650, 0.40, 'lower_middle', 0.50),

-- Mindanao regions (emerging markets, lower TBWA presence initially)
('Mindanao', 'Zamboanga Peninsula', 3.87, 0.0550, 0.35, 'lower_middle', 0.40),
('Mindanao', 'Northern Mindanao', 4.69, 0.0850, 0.55, 'middle', 0.60),
('Mindanao', 'Davao Region', 5.24, 0.1000, 0.65, 'middle', 0.65),
('Mindanao', 'SOCCSKSARGEN', 4.55, 0.0700, 0.45, 'lower_middle', 0.50),
('Mindanao', 'Caraga', 2.80, 0.0500, 0.35, 'lower_middle', 0.45),
('Mindanao', 'Bangsamoro Autonomous Region in Muslim Mindanao (BARMM)', 4.08, 0.0400, 0.25, 'lower', 0.30);

-- =====================================================
-- TBWA CLIENT BRANDS AND COMPETITIVE LANDSCAPE
-- =====================================================

-- Insert TBWA client brands
INSERT INTO brands (name, category, market_position, country_origin) VALUES
-- Alaska Milk Corporation (TBWA client - strong dairy presence)
('Alaska', 'Dairy', 'premium', 'Philippines'),
-- Oishi (TBWA client - leading snacks brand)
('Oishi', 'Snacks', 'market_leader', 'Philippines'),
-- Peerless (TBWA client - cleaning products)
('Peerless', 'Cleaning', 'challenger', 'Philippines'),
-- Del Monte (TBWA client - food and beverages)
('Del Monte', 'Food', 'premium', 'USA'),
-- JTI Tobacco brands (TBWA client)
('Winston', 'Tobacco', 'premium', 'USA'),
('Camel', 'Tobacco', 'premium', 'USA'),
('Mevius', 'Tobacco', 'premium', 'Japan'),
('More', 'Tobacco', 'value', 'Philippines'),

-- Competitor brands (to simulate market reality)
('Nestlé', 'Dairy', 'market_leader', 'Switzerland'),
('Bear Brand', 'Dairy', 'market_leader', 'Switzerland'),
('Jack n Jill', 'Snacks', 'market_leader', 'Philippines'),
('Richeese', 'Snacks', 'challenger', 'Indonesia'),
('Surf', 'Cleaning', 'market_leader', 'Netherlands'),
('Tide', 'Cleaning', 'premium', 'USA'),
('Dole', 'Food', 'premium', 'USA'),
('C2', 'Beverages', 'market_leader', 'Philippines'),
('Coca-Cola', 'Beverages', 'market_leader', 'USA'),
('Marlboro', 'Tobacco', 'market_leader', 'USA'),
('Philip Morris', 'Tobacco', 'premium', 'USA');

-- =====================================================
-- PRODUCTS WITH REALISTIC PHILIPPINE PRICING
-- =====================================================

-- TBWA Client Products (Alaska Milk Corporation)
INSERT INTO products (name, brand_id, category, is_fmcg, unit_price, package_size, target_segment) VALUES
-- Alaska products
('Alaska Evaporated Milk 410ml', (SELECT id FROM brands WHERE name = 'Alaska'), 'Dairy', true, 25.50, '410ml', 'mass_market'),
('Alaska Condensed Milk 387ml', (SELECT id FROM brands WHERE name = 'Alaska'), 'Dairy', true, 28.75, '387ml', 'mass_market'),
('Alaska Powdered Milk 1kg', (SELECT id FROM brands WHERE name = 'Alaska'), 'Dairy', true, 450.00, '1kg', 'family'),
('Alaska Crema All Purpose Cream 250ml', (SELECT id FROM brands WHERE name = 'Alaska'), 'Dairy', true, 32.50, '250ml', 'mass_market'),
('Alaska Fortified Powdered Milk 900g', (SELECT id FROM brands WHERE name = 'Alaska'), 'Dairy', true, 385.00, '900g', 'family'),

-- Oishi products (snacks category leader)
('Oishi Prawn Crackers Original 60g', (SELECT id FROM brands WHERE name = 'Oishi'), 'Snacks', true, 15.00, '60g', 'mass_market'),
('Oishi Pillows Chocolate 38g', (SELECT id FROM brands WHERE name = 'Oishi'), 'Snacks', true, 12.50, '38g', 'kids'),
('Oishi Smart C+ Orange 180ml', (SELECT id FROM brands WHERE name = 'Oishi'), 'Beverages', true, 18.25, '180ml', 'kids'),
('Oishi Marty''s Cracklin'' Chicharon 90g', (SELECT id FROM brands WHERE name = 'Oishi'), 'Snacks', true, 22.75, '90g', 'mass_market'),
('Oishi Potato Fries BBQ 50g', (SELECT id FROM brands WHERE name = 'Oishi'), 'Snacks', true, 14.00, '50g', 'mass_market'),
('Oishi Bread Pan Toasted Bread 200g', (SELECT id FROM brands WHERE name = 'Oishi'), 'Bakery', true, 35.50, '200g', 'family'),

-- Peerless cleaning products
('Peerless Champion Detergent Powder 1kg', (SELECT id FROM brands WHERE name = 'Peerless'), 'Cleaning', true, 45.00, '1kg', 'mass_market'),
('Peerless Suds Dishwashing Liquid 485ml', (SELECT id FROM brands WHERE name = 'Peerless'), 'Cleaning', true, 28.50, '485ml', 'mass_market'),
('Peerless Fabric Conditioner 1L', (SELECT id FROM brands WHERE name = 'Peerless'), 'Cleaning', true, 42.00, '1L', 'family'),

-- Del Monte products
('Del Monte Pineapple Juice 1L', (SELECT id FROM brands WHERE name = 'Del Monte'), 'Beverages', true, 68.00, '1L', 'family'),
('Del Monte Tomato Sauce 230g', (SELECT id FROM brands WHERE name = 'Del Monte'), 'Food', true, 22.75, '230g', 'mass_market'),
('Del Monte Fruit Cocktail 432g', (SELECT id FROM brands WHERE name = 'Del Monte'), 'Food', true, 85.50, '432g', 'family'),
('Del Monte Corned Beef 175g', (SELECT id FROM brands WHERE name = 'Del Monte'), 'Food', true, 58.00, '175g', 'mass_market'),
('Del Monte Fresh Cut Green Beans 425g', (SELECT id FROM brands WHERE name = 'Del Monte'), 'Food', true, 45.25, '425g', 'family'),

-- JTI Tobacco products (TBWA client)
('Winston Red 20s', (SELECT id FROM brands WHERE name = 'Winston'), 'Tobacco', true, 95.00, '20sticks', 'adult'),
('Camel Filters 20s', (SELECT id FROM brands WHERE name = 'Camel'), 'Tobacco', true, 100.00, '20sticks', 'adult'),
('Mevius Original 20s', (SELECT id FROM brands WHERE name = 'Mevius'), 'Tobacco', true, 105.00, '20sticks', 'adult'),
('More Menthol 20s', (SELECT id FROM brands WHERE name = 'More'), 'Tobacco', true, 75.00, '20sticks', 'adult'),

-- Competitor products for market realism
('Bear Brand Sterilized Milk 300ml', (SELECT id FROM brands WHERE name = 'Bear Brand'), 'Dairy', true, 130.00, '300ml', 'premium'),
('Nestlé All Purpose Cream 250ml', (SELECT id FROM brands WHERE name = 'Nestlé'), 'Dairy', true, 35.50, '250ml', 'mass_market'),
('Jack n Jill Piattos Cheese 85g', (SELECT id FROM brands WHERE name = 'Jack n Jill'), 'Snacks', true, 25.50, '85g', 'mass_market'),
('Richeese Nabati Cheese Wafer 58g', (SELECT id FROM brands WHERE name = 'Richeese'), 'Snacks', true, 16.75, '58g', 'mass_market'),
('Surf Powder Detergent 1kg', (SELECT id FROM brands WHERE name = 'Surf'), 'Cleaning', true, 48.50, '1kg', 'mass_market'),
('Tide Powder Detergent 1kg', (SELECT id FROM brands WHERE name = 'Tide'), 'Cleaning', true, 52.00, '1kg', 'premium'),
('Dole Pineapple Juice 1L', (SELECT id FROM brands WHERE name = 'Dole'), 'Beverages', true, 72.00, '1L', 'premium'),
('C2 Green Tea Apple 230ml', (SELECT id FROM brands WHERE name = 'C2'), 'Beverages', true, 20.00, '230ml', 'mass_market'),
('Coca-Cola Regular 330ml', (SELECT id FROM brands WHERE name = 'Coca-Cola'), 'Beverages', true, 18.00, '330ml', 'mass_market'),
('Marlboro Red 20s', (SELECT id FROM brands WHERE name = 'Marlboro'), 'Tobacco', true, 120.00, '20sticks', 'premium');

-- =====================================================
-- STORES DISTRIBUTED ACROSS PHILIPPINE REGIONS
-- =====================================================

-- Generate 100 stores distributed by economic weight
WITH regional_store_distribution AS (
    SELECT 
        region,
        mega_region,
        economic_weight,
        CEIL(100 * economic_weight) as target_stores
    FROM ph_regions
),
store_generation AS (
    SELECT 
        rsd.region,
        rsd.mega_region,
        generate_series(1, rsd.target_stores::integer) as store_num
    FROM regional_store_distribution rsd
)
INSERT INTO stores (name, address, region, store_type, size_category)
SELECT 
    CASE 
        WHEN store_num <= 2 THEN 'SM ' || region || ' Store ' || store_num
        WHEN store_num <= 4 THEN 'Robinson ' || region || ' Store ' || (store_num - 2)
        WHEN store_num <= 6 THEN '7-Eleven ' || region || ' Store ' || (store_num - 4)
        ELSE 'Sari-Sari Store ' || region || ' #' || (store_num - 6)
    END as store_name,
    'Brgy. ' || 
    (ARRAY['Poblacion', 'San Antonio', 'San Jose', 'Santa Cruz', 'Barangay 1', 'Maligaya', 'Riverside', 'Centro'])[
        ((store_num - 1) % 8) + 1
    ] || ', ' || region as address,
    region,
    CASE 
        WHEN store_num <= 2 THEN 'supermarket'
        WHEN store_num <= 4 THEN 'department_store'
        WHEN store_num <= 6 THEN 'convenience_store'
        ELSE 'sari_sari'
    END as store_type,
    CASE 
        WHEN store_num <= 2 THEN 'large'
        WHEN store_num <= 6 THEN 'medium'
        ELSE 'small'
    END as size_category
FROM store_generation;

-- =====================================================
-- DEVICE DEPLOYMENT ACROSS STORES
-- =====================================================

-- Deploy devices to all stores
INSERT INTO device_master (device_id, mac_address, store_id, status, deployment_date, device_type)
SELECT 
    'Pi5-' || LPAD(s.id::text, 3, '0') || '-' || SUBSTRING(md5(random()::text), 1, 6),
    UPPER(
        LPAD(TO_HEX((RANDOM() * 255)::int), 2, '0') || ':' ||
        LPAD(TO_HEX((RANDOM() * 255)::int), 2, '0') || ':' ||
        LPAD(TO_HEX((RANDOM() * 255)::int), 2, '0') || ':' ||
        LPAD(TO_HEX((RANDOM() * 255)::int), 2, '0') || ':' ||
        LPAD(TO_HEX((RANDOM() * 255)::int), 2, '0') || ':' ||
        LPAD(TO_HEX((RANDOM() * 255)::int), 2, '0')
    ),
    s.id,
    CASE WHEN RANDOM() < 0.95 THEN 'active' ELSE 'maintenance' END,
    CURRENT_DATE - (RANDOM() * 180)::int,
    'raspberry_pi_5'
FROM stores s;

-- =====================================================
-- REALISTIC SALES INTERACTIONS (5,000 RECORDS)
-- =====================================================

-- Generate 5,000 realistic sales interactions with Philippine market dynamics
WITH interaction_generation AS (
    SELECT 
        s.id as store_id,
        dm.device_id,
        pr.region,
        pr.tbwa_presence_strength,
        pr.economic_weight,
        pr.urban_penetration,
        -- Weighted date distribution (more recent = more data)
        (CURRENT_DATE - (POWER(RANDOM(), 2) * 180)::int - (RANDOM() * INTERVAL '18 hours'))::timestamptz as transaction_date,
        -- Demographic simulation based on region
        CASE 
            WHEN RANDOM() < 0.55 THEN 'F' 
            ELSE 'M' 
        END as gender,
        -- Age distribution realistic for Philippine shoppers
        CASE 
            WHEN RANDOM() < 0.15 THEN FLOOR(18 + RANDOM() * 12)::int  -- Young adults 18-30
            WHEN RANDOM() < 0.45 THEN FLOOR(30 + RANDOM() * 15)::int  -- Prime shoppers 30-45
            WHEN RANDOM() < 0.75 THEN FLOOR(45 + RANDOM() * 15)::int  -- Middle-aged 45-60
            ELSE FLOOR(60 + RANDOM() * 15)::int  -- Seniors 60+
        END as age,
        -- Emotion distribution
        (ARRAY['happy', 'neutral', 'satisfied', 'neutral', 'happy', 'curious'])[FLOOR(1 + RANDOM() * 6)] as emotion,
        -- Shopping duration varies by store type
        CASE s.store_type
            WHEN 'supermarket' THEN (5 + RANDOM() * 15) * INTERVAL '1 minute'
            WHEN 'department_store' THEN (3 + RANDOM() * 12) * INTERVAL '1 minute'
            WHEN 'convenience_store' THEN (1 + RANDOM() * 5) * INTERVAL '1 minute'
            ELSE (1 + RANDOM() * 3) * INTERVAL '1 minute'
        END as duration,
        -- TBWA influence varies by region
        RANDOM() < (pr.tbwa_presence_strength * 0.4) as is_attendant_influenced,
        -- Substitution rates
        RANDOM() < 0.12 as substitution_occurred,
        -- Customer ID (some are returning customers)
        CASE WHEN RANDOM() < 0.3 THEN uuid_generate_v4() ELSE NULL END as customer_id
    FROM generate_series(1, 5000) i
    JOIN stores s ON s.id = (1 + (RANDOM() * (SELECT COUNT(*) FROM stores))::int)
    JOIN device_master dm ON dm.store_id = s.id
    JOIN ph_regions pr ON s.region = pr.region
)
INSERT INTO sales_interactions (
    store_id, device_id, transaction_date, gender, age, emotion, 
    duration, total_amount, is_attendant_influenced, substitution_occurred, customer_id
)
SELECT 
    store_id, device_id, transaction_date, gender, age, emotion,
    duration, 0, is_attendant_influenced, substitution_occurred, customer_id
FROM interaction_generation;

-- =====================================================
-- TRANSACTION ITEMS (15,000+ ITEMS)
-- =====================================================

-- Generate realistic transaction items based on Philippine shopping patterns
WITH item_generation AS (
    SELECT 
        si.interaction_id,
        si.store_id,
        pr.tbwa_presence_strength,
        s.store_type,
        -- Product selection bias based on TBWA presence and store type
        CASE 
            WHEN RANDOM() < pr.tbwa_presence_strength THEN 
                -- TBWA products more likely in high-presence regions
                (SELECT p.id FROM products p JOIN brands b ON p.brand_id = b.id 
                 WHERE b.name IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More')
                 ORDER BY RANDOM() LIMIT 1)
            ELSE
                -- Competitor products
                (SELECT p.id FROM products p JOIN brands b ON p.brand_id = b.id 
                 WHERE b.name NOT IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More')
                 ORDER BY RANDOM() LIMIT 1)
        END as product_id,
        -- Quantity based on product type and store type
        CASE s.store_type
            WHEN 'supermarket' THEN FLOOR(1 + RANDOM() * 5)::int
            WHEN 'department_store' THEN FLOOR(1 + RANDOM() * 3)::int
            ELSE FLOOR(1 + RANDOM() * 2)::int
        END as quantity
    FROM sales_interactions si
    JOIN stores s ON si.store_id = s.id
    JOIN ph_regions pr ON s.region = pr.region
    CROSS JOIN generate_series(1, 
        -- Items per transaction based on store type
        CASE s.store_type
            WHEN 'supermarket' THEN FLOOR(2 + RANDOM() * 6)::int
            WHEN 'department_store' THEN FLOOR(2 + RANDOM() * 4)::int
            WHEN 'convenience_store' THEN FLOOR(1 + RANDOM() * 3)::int
            ELSE FLOOR(1 + RANDOM() * 2)::int
        END
    ) item_num
)
INSERT INTO transaction_items (interaction_id, product_id, quantity)
SELECT interaction_id, product_id, quantity
FROM item_generation
WHERE product_id IS NOT NULL;

-- =====================================================
-- UPDATE TRANSACTION TOTALS
-- =====================================================

-- Calculate and update total amounts for all transactions
UPDATE sales_interactions si
SET total_amount = COALESCE(
    (SELECT SUM(p.unit_price * ti.quantity)
     FROM transaction_items ti
     JOIN products p ON ti.product_id = p.id
     WHERE ti.interaction_id = si.interaction_id), 
    0
);

-- =====================================================
-- GENERATE REQUEST METHODS AND SESSION DATA
-- =====================================================

-- Generate request methods based on Philippine shopping behavior
INSERT INTO request_methods (interaction_id, method, details, language_used)
SELECT 
    si.interaction_id,
    (ARRAY['vocal', 'pointing', 'generic_ask', 'assisted', 'browsing'])[FLOOR(1 + RANDOM() * 5)],
    CASE 
        WHEN RANDOM() < 0.6 THEN 'Request made in Tagalog'
        WHEN RANDOM() < 0.8 THEN 'Request made in English'
        WHEN RANDOM() < 0.9 THEN 'Request made in Cebuano'
        ELSE 'Mixed language request'
    END,
    CASE 
        WHEN RANDOM() < 0.6 THEN 'Tagalog'
        WHEN RANDOM() < 0.8 THEN 'English'
        WHEN RANDOM() < 0.9 THEN 'Cebuano'
        ELSE 'Mixed'
    END
FROM sales_interactions si;

-- Generate session matches for tracking
INSERT INTO session_matches (interaction_id, transcript_id, detection_id, match_confidence)
SELECT 
    si.interaction_id,
    'transcript-' || SUBSTRING(md5(si.interaction_id::text || si.transaction_date::text), 1, 12),
    'detection-' || SUBSTRING(md5(si.interaction_id::text || si.store_id::text), 1, 12),
    0.75 + (RANDOM() * 0.24)  -- 75-99% confidence
FROM sales_interactions si;

-- =====================================================
-- BUSINESS INTELLIGENCE VIEWS FOR PHILIPPINE MARKET
-- =====================================================

-- Regional Market Analysis
CREATE MATERIALIZED VIEW philippine_market_analysis AS
SELECT 
    pr.mega_region,
    pr.region,
    pr.population_millions,
    pr.economic_weight,
    COUNT(DISTINCT si.interaction_id) as total_transactions,
    SUM(si.total_amount) as total_revenue,
    AVG(si.total_amount) as avg_transaction_value,
    COUNT(DISTINCT si.store_id) as active_stores,
    -- TBWA vs Competitor performance
    SUM(CASE WHEN b.name IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
             THEN ti.quantity * p.unit_price ELSE 0 END) as tbwa_revenue,
    SUM(CASE WHEN b.name NOT IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
             THEN ti.quantity * p.unit_price ELSE 0 END) as competitor_revenue,
    -- Market penetration metrics
    ROUND(
        SUM(CASE WHEN b.name IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
                 THEN ti.quantity * p.unit_price ELSE 0 END) / 
        NULLIF(SUM(ti.quantity * p.unit_price), 0) * 100, 2
    ) as tbwa_market_share_percent
FROM sales_interactions si
JOIN stores s ON si.store_id = s.id
JOIN ph_regions pr ON s.region = pr.region
JOIN transaction_items ti ON si.interaction_id = ti.interaction_id
JOIN products p ON ti.product_id = p.id
JOIN brands b ON p.brand_id = b.id
WHERE si.transaction_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY pr.mega_region, pr.region, pr.population_millions, pr.economic_weight
ORDER BY tbwa_revenue DESC;

-- TBWA Brand Performance Dashboard
CREATE MATERIALIZED VIEW tbwa_brand_performance AS
SELECT 
    b.name as brand_name,
    p.category,
    COUNT(DISTINCT ti.interaction_id) as transaction_count,
    SUM(ti.quantity) as total_units_sold,
    SUM(ti.quantity * p.unit_price) as total_revenue,
    AVG(ti.quantity) as avg_quantity_per_transaction,
    COUNT(DISTINCT s.region) as regional_presence,
    RANK() OVER (ORDER BY SUM(ti.quantity * p.unit_price) DESC) as revenue_rank
FROM transaction_items ti
JOIN products p ON ti.product_id = p.id
JOIN brands b ON p.brand_id = b.id
JOIN sales_interactions si ON ti.interaction_id = si.interaction_id
JOIN stores s ON si.store_id = s.id
WHERE b.name IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More')
AND si.transaction_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY b.name, p.category
ORDER BY total_revenue DESC;

-- Create indexes for the new materialized views
CREATE UNIQUE INDEX idx_ph_market_analysis_region ON philippine_market_analysis (region);
CREATE INDEX idx_ph_market_analysis_revenue ON philippine_market_analysis (total_revenue DESC);
CREATE INDEX idx_tbwa_brand_perf_brand ON tbwa_brand_performance (brand_name);
CREATE INDEX idx_tbwa_brand_perf_revenue ON tbwa_brand_performance (total_revenue DESC);

-- Grant permissions
GRANT SELECT ON ph_regions TO dashboard_user, data_analyst;
GRANT SELECT ON philippine_market_analysis TO dashboard_user, data_analyst;
GRANT SELECT ON tbwa_brand_performance TO dashboard_user, data_analyst;

-- Add final data quality check
DO $$
DECLARE
    total_interactions INTEGER;
    total_items INTEGER;
    tbwa_revenue NUMERIC;
    competitor_revenue NUMERIC;
BEGIN
    SELECT COUNT(*) INTO total_interactions FROM sales_interactions;
    SELECT COUNT(*) INTO total_items FROM transaction_items;
    
    SELECT 
        SUM(CASE WHEN b.name IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
                 THEN ti.quantity * p.unit_price ELSE 0 END),
        SUM(CASE WHEN b.name NOT IN ('Alaska', 'Oishi', 'Peerless', 'Del Monte', 'Winston', 'Camel', 'Mevius', 'More') 
                 THEN ti.quantity * p.unit_price ELSE 0 END)
    INTO tbwa_revenue, competitor_revenue
    FROM transaction_items ti
    JOIN products p ON ti.product_id = p.id
    JOIN brands b ON p.brand_id = b.id;
    
    RAISE NOTICE 'Philippine Market Data Generation Complete:';
    RAISE NOTICE '- Total Sales Interactions: %', total_interactions;
    RAISE NOTICE '- Total Transaction Items: %', total_items;
    RAISE NOTICE '- TBWA Total Revenue: PHP %', tbwa_revenue;
    RAISE NOTICE '- Competitor Total Revenue: PHP %', competitor_revenue;
    RAISE NOTICE '- TBWA Market Share: %', ROUND(tbwa_revenue / (tbwa_revenue + competitor_revenue) * 100, 2);
    
    -- Log to audit trail
    INSERT INTO audit_log (table_name, action, new_data)
    VALUES ('sample_data_generation', 'COMPLETE', 
            json_build_object(
                'total_interactions', total_interactions,
                'total_items', total_items,
                'tbwa_revenue', tbwa_revenue,
                'competitor_revenue', competitor_revenue,
                'generation_date', CURRENT_DATE
            ));
END;
$$;