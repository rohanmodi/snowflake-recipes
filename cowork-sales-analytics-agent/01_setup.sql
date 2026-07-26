-- ============================================================
-- CoWork Sales Analytics Agent — Setup
-- Creates database, warehouse, schema, and four sample tables
-- for a SaaS sales analytics demo with Snowflake CoWork.
--
-- 🔧 Parameters to change:
--   COWORK_DEMO_WH  — warehouse name (or reuse an existing one)
--
-- Run as ACCOUNTADMIN (or a role with CREATE DATABASE,
-- CREATE WAREHOUSE, and CORTEX_USER privileges).
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- 1. Database & schema -----------------------------------------------
CREATE DATABASE IF NOT EXISTS COWORK_DEMO_DB;
CREATE SCHEMA IF NOT EXISTS COWORK_DEMO_DB.SALES_ANALYTICS;

USE DATABASE COWORK_DEMO_DB;
USE SCHEMA SALES_ANALYTICS;

-- 2. Warehouse (🔧 change name/size if needed) ----------------------
CREATE WAREHOUSE IF NOT EXISTS COWORK_DEMO_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND   = 60
  AUTO_RESUME    = TRUE;

USE WAREHOUSE COWORK_DEMO_WH;

-- 3. Tables ----------------------------------------------------------

-- ─── CUSTOMERS ───
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID       INT,
    COMPANY_NAME      VARCHAR(200),
    INDUSTRY          VARCHAR(100),
    COMPANY_SIZE      VARCHAR(50),
    REGION            VARCHAR(50),
    COUNTRY           VARCHAR(100),
    ARR_TIER          VARCHAR(50),
    ONBOARDING_DATE   DATE,
    ACCOUNT_MANAGER   VARCHAR(100),
    HEALTH_SCORE      INT
);

-- ─── DEALS ───
CREATE OR REPLACE TABLE DEALS (
    DEAL_ID           INT,
    DEAL_NAME         VARCHAR(300),
    CUSTOMER_ID       INT,
    STAGE             VARCHAR(50),
    DEAL_TYPE         VARCHAR(50),
    AMOUNT_USD        FLOAT,
    CLOSE_DATE        DATE,
    CREATED_DATE      DATE,
    SALES_REP         VARCHAR(100),
    PRODUCT_LINE      VARCHAR(100),
    WIN_PROBABILITY   FLOAT,
    REGION            VARCHAR(50),
    INDUSTRY          VARCHAR(100),
    LOST_REASON       VARCHAR(200)
);

-- ─── MONTHLY_REVENUE ───
CREATE OR REPLACE TABLE MONTHLY_REVENUE (
    REVENUE_ID        INT,
    CUSTOMER_ID       INT,
    MONTH             DATE,
    MRR_USD           FLOAT,
    PRODUCT_LINE      VARCHAR(100),
    LICENSE_COUNT     INT,
    EXPANSION_USD     FLOAT,
    CHURN_FLAG        BOOLEAN
);

-- ─── SUPPORT_TICKETS ───
CREATE OR REPLACE TABLE SUPPORT_TICKETS (
    TICKET_ID         INT,
    CUSTOMER_ID       INT,
    CREATED_DATE      DATE,
    PRIORITY          VARCHAR(20),
    CATEGORY          VARCHAR(100),
    SUBJECT           VARCHAR(500),
    DESCRIPTION       VARCHAR(5000),
    RESOLUTION        VARCHAR(3000),
    STATUS            VARCHAR(50),
    RESOLUTION_HOURS  FLOAT,
    CSAT_SCORE        INT
);

-- 4. Sample data -----------------------------------------------------

-- ─── CUSTOMERS (30 companies) ───
INSERT INTO CUSTOMERS VALUES
(1,  'TechFlow Solutions',      'Technology',          'Mid-Market', 'North America', 'United States', 'Enterprise', '2023-01-15', 'Sarah Chen',     85),
(2,  'GreenLeaf Retail',        'Retail',              'Enterprise', 'North America', 'United States', 'Enterprise', '2022-06-01', 'Mike Rodriguez',  72),
(3,  'HealthFirst Systems',     'Healthcare',          'Enterprise', 'North America', 'United States', 'Strategic',  '2021-09-10', 'Sarah Chen',     91),
(4,  'Nordic Finance AB',       'Financial Services',  'Mid-Market', 'Europe',        'Sweden',        'Enterprise', '2023-03-20', 'James Smith',    68),
(5,  'AutoDrive Manufacturing', 'Manufacturing',       'Enterprise', 'North America', 'United States', 'Strategic',  '2022-01-05', 'Mike Rodriguez',  88),
(6,  'CloudScale India',        'Technology',          'Startup',    'Asia Pacific',  'India',         'Growth',     '2024-02-14', 'Priya Sharma',   79),
(7,  'MegaMart Holdings',       'Retail',              'Enterprise', 'North America', 'United States', 'Strategic',  '2021-04-22', 'Sarah Chen',     65),
(8,  'BioGenesis Labs',         'Healthcare',          'Mid-Market', 'Europe',        'Germany',       'Enterprise', '2023-07-30', 'James Smith',    82),
(9,  'FinEdge Capital',         'Financial Services',  'Enterprise', 'North America', 'United States', 'Strategic',  '2022-11-01', 'Mike Rodriguez',  76),
(10, 'SmartFactory GmbH',       'Manufacturing',       'Mid-Market', 'Europe',        'Germany',       'Enterprise', '2023-05-18', 'James Smith',    84),
(11, 'DataMinds Analytics',     'Technology',          'Startup',    'North America', 'Canada',        'Growth',     '2024-06-01', 'Sarah Chen',     90),
(12, 'FreshMart Grocery',       'Retail',              'Mid-Market', 'North America', 'United States', 'Enterprise', '2023-08-12', 'Mike Rodriguez',  71),
(13, 'MedTech Innovations',     'Healthcare',          'Startup',    'Asia Pacific',  'Singapore',     'Growth',     '2024-04-05', 'Priya Sharma',   87),
(14, 'Alpine Insurance',        'Financial Services',  'Mid-Market', 'Europe',        'Switzerland',   'Enterprise', '2023-01-28', 'James Smith',    73),
(15, 'PrecisionParts Inc',      'Manufacturing',       'Enterprise', 'North America', 'United States', 'Strategic',  '2021-12-15', 'Sarah Chen',     80),
(16, 'NexGen Software',         'Technology',          'Mid-Market', 'Asia Pacific',  'India',         'Enterprise', '2023-09-01', 'Priya Sharma',   86),
(17, 'LuxBrands Europe',        'Retail',              'Enterprise', 'Europe',        'France',        'Strategic',  '2022-03-10', 'James Smith',    69),
(18, 'CarePoint Hospitals',     'Healthcare',          'Enterprise', 'North America', 'United States', 'Strategic',  '2022-05-20', 'Mike Rodriguez',  92),
(19, 'CryptoVault Finance',     'Financial Services',  'Startup',    'North America', 'United States', 'Growth',     '2024-01-15', 'Sarah Chen',     61),
(20, 'RoboWorks Japan',         'Manufacturing',       'Mid-Market', 'Asia Pacific',  'Japan',         'Enterprise', '2023-04-08', 'Priya Sharma',   77),
(21, 'Velocity Cloud',          'Technology',          'Enterprise', 'North America', 'United States', 'Strategic',  '2021-07-01', 'Sarah Chen',     94),
(22, 'StyleHouse Brands',       'Retail',              'Startup',    'Asia Pacific',  'Australia',     'Growth',     '2024-03-22', 'Priya Sharma',   83),
(23, 'PharmaCore Research',     'Healthcare',          'Mid-Market', 'Europe',        'UK',            'Enterprise', '2023-02-14', 'James Smith',    78),
(24, 'TrustBank Singapore',     'Financial Services',  'Enterprise', 'Asia Pacific',  'Singapore',     'Strategic',  '2022-08-30', 'Priya Sharma',   85),
(25, 'SteelWorks Corp',         'Manufacturing',       'Enterprise', 'North America', 'United States', 'Enterprise', '2022-10-05', 'Mike Rodriguez',  74),
(26, 'PixelForge Studios',      'Technology',          'Startup',    'Europe',        'UK',            'Growth',     '2024-05-10', 'James Smith',    88),
(27, 'QuickShop Online',        'Retail',              'Mid-Market', 'North America', 'United States', 'Enterprise', '2023-06-15', 'Sarah Chen',     70),
(28, 'LifeScience Partners',    'Healthcare',          'Enterprise', 'North America', 'United States', 'Strategic',  '2021-11-20', 'Mike Rodriguez',  89),
(29, 'PayStream Fintech',       'Financial Services',  'Mid-Market', 'Europe',        'Netherlands',   'Enterprise', '2023-10-01', 'James Smith',    81),
(30, 'EcoMotors Ltd',           'Manufacturing',       'Mid-Market', 'Europe',        'UK',            'Enterprise', '2023-08-25', 'James Smith',    76);

-- ─── DEALS (35 deals across stages) ───
INSERT INTO DEALS VALUES
-- Closed Won
(1,  'TechFlow - Platform Migration',       1,  'Closed Won',  'New Business', 285000,  '2025-11-15', '2025-08-01', 'Sarah Chen',     'Data Platform',    1.0,  'North America', 'Technology',          NULL),
(2,  'GreenLeaf - Retail Analytics Suite',   2,  'Closed Won',  'Expansion',    420000,  '2025-10-20', '2025-06-15', 'Mike Rodriguez',  'Analytics',        1.0,  'North America', 'Retail',              NULL),
(3,  'HealthFirst - Data Lake Modernization',3,  'Closed Won',  'New Business', 750000,  '2025-09-30', '2025-04-10', 'Sarah Chen',     'Data Platform',    1.0,  'North America', 'Healthcare',          NULL),
(4,  'AutoDrive - IoT Data Pipeline',        5,  'Closed Won',  'New Business', 520000,  '2025-12-01', '2025-07-20', 'Mike Rodriguez',  'Data Engineering', 1.0,  'North America', 'Manufacturing',       NULL),
(5,  'Velocity Cloud - Cortex AI POC',       21, 'Closed Won',  'Expansion',    180000,  '2026-01-10', '2025-10-01', 'Sarah Chen',     'AI/ML',            1.0,  'North America', 'Technology',          NULL),
(6,  'MegaMart - Customer 360',              7,  'Closed Won',  'Expansion',    340000,  '2025-08-15', '2025-03-01', 'Sarah Chen',     'Analytics',        1.0,  'North America', 'Retail',              NULL),
(7,  'FinEdge - Risk Analytics',             9,  'Closed Won',  'New Business', 680000,  '2025-11-30', '2025-05-15', 'Mike Rodriguez',  'Analytics',        1.0,  'North America', 'Financial Services',  NULL),
(8,  'PrecisionParts - Supply Chain',        15, 'Closed Won',  'Expansion',    290000,  '2026-02-15', '2025-09-01', 'Sarah Chen',     'Data Engineering', 1.0,  'North America', 'Manufacturing',       NULL),
(9,  'TrustBank - Regulatory Reporting',     24, 'Closed Won',  'New Business', 890000,  '2025-10-05', '2025-03-20', 'Priya Sharma',   'Data Platform',    1.0,  'Asia Pacific',  'Financial Services',  NULL),
(10, 'CarePoint - Patient Analytics',        18, 'Closed Won',  'Expansion',    410000,  '2026-01-25', '2025-08-10', 'Mike Rodriguez',  'AI/ML',            1.0,  'North America', 'Healthcare',          NULL),
(31, 'TechFlow - Phase 2 Expansion',         1,  'Closed Won',  'Expansion',    190000,  '2026-03-15', '2025-12-01', 'Sarah Chen',     'AI/ML',            1.0,  'North America', 'Technology',          NULL),
(32, 'HealthFirst - Cortex AI Rollout',      3,  'Closed Won',  'Expansion',    380000,  '2026-04-20', '2026-01-10', 'Sarah Chen',     'AI/ML',            1.0,  'North America', 'Healthcare',          NULL),
(33, 'Velocity Cloud - Data Mesh',           21, 'Closed Won',  'Expansion',    450000,  '2026-02-28', '2025-11-01', 'Sarah Chen',     'Data Platform',    1.0,  'North America', 'Technology',          NULL),
(34, 'GreenLeaf - Supply Chain ML',          2,  'Closed Won',  'Expansion',    310000,  '2026-05-10', '2026-02-01', 'Mike Rodriguez',  'AI/ML',            1.0,  'North America', 'Retail',              NULL),
(35, 'AutoDrive - Real-time Telemetry',      5,  'Closed Won',  'Expansion',    280000,  '2026-04-01', '2026-01-15', 'Mike Rodriguez',  'Data Engineering', 1.0,  'North America', 'Manufacturing',       NULL),
-- Closed Lost
(11, 'Nordic Finance - Data Warehouse',      4,  'Closed Lost', 'New Business', 350000,  '2025-09-15', '2025-05-01', 'James Smith',    'Data Platform',    0.0,  'Europe',        'Financial Services',  'Lost to Databricks - price'),
(12, 'SmartFactory - Predictive Maintenance',10, 'Closed Lost', 'New Business', 480000,  '2025-11-01', '2025-06-20', 'James Smith',    'AI/ML',            0.0,  'Europe',        'Manufacturing',       'Budget constraints'),
(13, 'LuxBrands - Omnichannel Analytics',    17, 'Closed Lost', 'Expansion',    560000,  '2025-10-10', '2025-04-15', 'James Smith',    'Analytics',        0.0,  'Europe',        'Retail',              'Chose in-house solution'),
(14, 'CryptoVault - Transaction Monitoring', 19, 'Closed Lost', 'New Business', 220000,  '2026-01-05', '2025-09-10', 'Sarah Chen',     'Data Engineering', 0.0,  'North America', 'Financial Services',  'Startup funding issues'),
(15, 'RoboWorks - Factory Analytics',        20, 'Closed Lost', 'New Business', 390000,  '2025-12-20', '2025-07-01', 'Priya Sharma',   'Analytics',        0.0,  'Asia Pacific',  'Manufacturing',       'Lost to AWS Redshift'),
-- Negotiation
(16, 'DataMinds - Enterprise Platform',      11, 'Negotiation', 'New Business', 310000,  '2026-08-15', '2026-04-01', 'Sarah Chen',     'Data Platform',    0.75, 'North America', 'Technology',          NULL),
(17, 'BioGenesis - Clinical Data Platform',  8,  'Negotiation', 'New Business', 620000,  '2026-09-01', '2026-03-15', 'James Smith',    'Data Platform',    0.70, 'Europe',        'Healthcare',          NULL),
(18, 'FreshMart - Demand Forecasting',       12, 'Negotiation', 'Expansion',    275000,  '2026-07-30', '2026-02-10', 'Mike Rodriguez',  'AI/ML',            0.80, 'North America', 'Retail',              NULL),
(19, 'Alpine Insurance - Claims Analytics',  14, 'Negotiation', 'New Business', 445000,  '2026-08-20', '2026-04-05', 'James Smith',    'Analytics',        0.65, 'Europe',        'Financial Services',  NULL),
(20, 'NexGen - Snowpark Migration',          16, 'Negotiation', 'New Business', 360000,  '2026-09-10', '2026-05-01', 'Priya Sharma',   'Data Engineering', 0.72, 'Asia Pacific',  'Technology',          NULL),
-- Proposal
(21, 'LifeScience - Research Data Hub',      28, 'Proposal',    'Expansion',    530000,  '2026-10-01', '2026-06-01', 'Mike Rodriguez',  'Data Platform',    0.55, 'North America', 'Healthcare',          NULL),
(22, 'PayStream - Real-time Payments',       29, 'Proposal',    'New Business', 410000,  '2026-09-15', '2026-05-20', 'James Smith',    'Data Engineering', 0.50, 'Europe',        'Financial Services',  NULL),
(23, 'SteelWorks - Quality Analytics',       25, 'Proposal',    'Expansion',    320000,  '2026-10-15', '2026-06-15', 'Mike Rodriguez',  'Analytics',        0.60, 'North America', 'Manufacturing',       NULL),
(24, 'PharmaCore - Drug Discovery AI',       23, 'Proposal',    'New Business', 780000,  '2026-11-01', '2026-06-01', 'James Smith',    'AI/ML',            0.45, 'Europe',        'Healthcare',          NULL),
(25, 'EcoMotors - Connected Vehicle Data',   30, 'Proposal',    'New Business', 450000,  '2026-10-20', '2026-07-01', 'James Smith',    'Data Engineering', 0.50, 'Europe',        'Manufacturing',       NULL),
-- Discovery
(26, 'CloudScale - Full Stack Analytics',    6,  'Discovery',   'New Business', 195000,  '2026-11-15', '2026-07-10', 'Priya Sharma',   'Analytics',        0.25, 'Asia Pacific',  'Technology',          NULL),
(27, 'MedTech - Patient Outcomes AI',        13, 'Discovery',   'New Business', 550000,  '2026-12-01', '2026-07-15', 'Priya Sharma',   'AI/ML',            0.30, 'Asia Pacific',  'Healthcare',          NULL),
(28, 'StyleHouse - E-commerce Analytics',    22, 'Discovery',   'New Business', 180000,  '2026-11-30', '2026-07-20', 'Priya Sharma',   'Analytics',        0.20, 'Asia Pacific',  'Retail',              NULL),
(29, 'PixelForge - Content Analytics',       26, 'Discovery',   'New Business', 240000,  '2026-12-15', '2026-07-25', 'James Smith',    'Analytics',        0.25, 'Europe',        'Technology',          NULL),
(30, 'QuickShop - Inventory Optimization',   27, 'Discovery',   'Expansion',    310000,  '2026-11-01', '2026-07-01', 'Sarah Chen',     'AI/ML',            0.35, 'North America', 'Retail',              NULL);

-- ─── MONTHLY_REVENUE (18 months × qualifying customers) ───
INSERT INTO MONTHLY_REVENUE
SELECT
    ROW_NUMBER() OVER (ORDER BY m.MONTH, c.CUSTOMER_ID) AS REVENUE_ID,
    c.CUSTOMER_ID,
    m.MONTH,
    CASE
        WHEN c.ARR_TIER = 'Strategic'  THEN ROUND(UNIFORM(25000, 45000, RANDOM()), 2)
        WHEN c.ARR_TIER = 'Enterprise' THEN ROUND(UNIFORM(12000, 28000, RANDOM()), 2)
        ELSE                                ROUND(UNIFORM(3000,  12000, RANDOM()), 2)
    END * (1 + (DATEDIFF('month', '2025-01-01', m.MONTH) * 0.015)) AS MRR_USD,
    CASE MOD(c.CUSTOMER_ID, 4)
        WHEN 0 THEN 'Data Platform'
        WHEN 1 THEN 'Analytics'
        WHEN 2 THEN 'Data Engineering'
        ELSE        'AI/ML'
    END AS PRODUCT_LINE,
    CASE
        WHEN c.ARR_TIER = 'Strategic'  THEN UNIFORM(50, 200, RANDOM())
        WHEN c.ARR_TIER = 'Enterprise' THEN UNIFORM(20, 80,  RANDOM())
        ELSE                                UNIFORM(5,  25,  RANDOM())
    END AS LICENSE_COUNT,
    CASE WHEN UNIFORM(1, 10, RANDOM()) > 7
         THEN ROUND(UNIFORM(1000, 8000, RANDOM()), 2)
         ELSE 0
    END AS EXPANSION_USD,
    CASE WHEN c.HEALTH_SCORE < 65 AND UNIFORM(1, 10, RANDOM()) > 8
         THEN TRUE
         ELSE FALSE
    END AS CHURN_FLAG
FROM CUSTOMERS c
CROSS JOIN (
    SELECT DATEADD('month', SEQ4(), '2025-01-01')::DATE AS MONTH
    FROM TABLE(GENERATOR(ROWCOUNT => 18))
) m
WHERE c.ONBOARDING_DATE <= m.MONTH;

-- ─── SUPPORT_TICKETS (20 tickets) ───
INSERT INTO SUPPORT_TICKETS VALUES
(1,  1,  '2026-06-15', 'High',     'Performance',  'Slow query execution on large datasets',
     'Queries on the TRANSACTIONS table are taking over 30 minutes.',
     'Upgraded warehouse to Medium and implemented clustering on DATE column. Query times reduced to 2 minutes.',
     'Resolved', 4.5,  5),
(2,  2,  '2026-07-01', 'Critical', 'Data Quality', 'Missing revenue data for June batch load',
     'The nightly batch load failed silently on June 28. Revenue records for the last 3 days of June are missing.',
     'Identified failed COPY INTO command due to schema drift in source CSV. Added schema evolution handling and re-ran the load.',
     'Resolved', 2.0,  4),
(3,  3,  '2026-05-20', 'Medium',   'Feature Request', 'Need Cortex AI integration for clinical notes',
     'Clinical team wants to use Snowflake Cortex to analyze unstructured physician notes.',
     'Provided architecture recommendation for Cortex LLM functions. POC scheduled for next sprint.',
     'In Progress', NULL, NULL),
(4,  4,  '2026-06-28', 'High',     'Security',     'RBAC policy not applied to new schema',
     'The new ANALYTICS schema was created without inheriting the row-access policies.',
     'Applied row-access policy REGION_FILTER to all tables in ANALYTICS schema.',
     'Resolved', 3.0,  5),
(5,  5,  '2026-07-10', 'Low',      'How-To',       'How to set up Snowpipe for real-time IoT data',
     'Moving from batch to real-time ingestion for manufacturing sensor data. Need Snowpipe + Azure Event Hubs guidance.',
     'Provided step-by-step guide for Snowpipe with Azure integration.',
     'Resolved', 1.5,  5),
(6,  7,  '2026-06-05', 'Critical', 'Performance',  'Dashboard timeouts during Black Friday prep',
     'All Snowsight dashboards are timing out. Warehouse 100% utilized, queries queuing 20+ minutes.',
     'Implemented multi-cluster warehouse with scaling policy. Added result caching for common dashboard queries.',
     'Resolved', 1.0,  3),
(7,  9,  '2026-07-05', 'High',     'Data Quality', 'Duplicate transactions in risk calculations',
     'RISK_SCORES table has duplicate entries causing VaR calculations to be inflated by ~15%.',
     'Found duplicates caused by retry logic in ETL pipeline. Implemented MERGE for idempotent loads.',
     'Resolved', 5.0,  4),
(8,  11, '2026-07-12', 'Medium',   'Feature Request', 'Dynamic Tables for real-time customer scoring',
     'Want real-time customer health scores using Dynamic Tables instead of scheduled tasks.',
     'Set up Dynamic Table with 1-minute target lag. Scores now update within 90 seconds of data changes.',
     'Resolved', 8.0,  5),
(9,  14, '2026-06-20', 'High',     'Cost',         'Unexpected credit consumption spike in June',
     'Credit usage increased 340% in the second week of June.',
     'Identified materialized view refresh triggering full table scans every 15 minutes. Optimized to hourly.',
     'Resolved', 6.0,  4),
(10, 16, '2026-07-08', 'Medium',   'Integration',  'Kafka connector dropping messages under load',
     'Connector dropping ~5% of messages when throughput exceeds 50K messages/minute.',
     'Increased connector task count from 2 to 8 and adjusted buffer size. Message loss eliminated.',
     'Resolved', 12.0, 4),
(11, 18, '2026-05-15', 'Critical', 'Security',     'PHI data exposed in shared view',
     'Secure Data Share to research partner inadvertently included a view with patient PII columns.',
     'Immediately revoked the share. Applied dynamic data masking on PII columns. Incident report filed.',
     'Resolved', 0.5,  2),
(12, 21, '2026-07-15', 'Low',      'Feature Request', 'Cortex Code access for development team',
     '15-person data engineering team wants access to Cortex Code for AI-assisted SQL development.',
     'Enabled for all users in DEVELOPER role. Provided team training session on best practices.',
     'Resolved', 2.0,  5),
(13, 23, '2026-06-25', 'High',     'Performance',  'Time Travel storage costs exceeding budget',
     'Time Travel storage for TRANSACTIONS database has grown to 45TB, costing more than active storage.',
     'Implemented tiered retention: 90 days critical, 14 days staging, 1 day temp. Storage reduced by 60%.',
     'Resolved', 3.0,  5),
(14, 24, '2026-07-02', 'Medium',   'Compliance',   'Need audit trail for all data access in Singapore',
     'MAS requires complete audit trail of all data access for regulated datasets.',
     'Set up continuous replication of ACCESS_HISTORY to a dedicated audit database with 7-year retention.',
     'Resolved', 16.0, 5),
(15, 25, '2026-06-10', 'High',     'Data Quality', 'Inventory counts negative after warehouse merge',
     'After merging data from two warehouses, 2,300 SKUs show negative inventory counts.',
     'Identified join key mismatch. Rebuilt merge logic with correct composite key.',
     'Resolved', 4.0,  3),
(16, 6,  '2026-07-18', 'Medium',   'How-To',       'Best practices for Snowpark Python UDFs',
     'Team wants to deploy ML models as Snowpark Python UDFs.',
     'Shared best practices covering vectorized UDFs, package management, and caching strategies.',
     'In Progress', NULL, NULL),
(17, 8,  '2026-07-20', 'High',     'Integration',  'dbt model failures after Snowflake upgrade',
     '12 of 180 dbt models failing with new reserved keyword conflicts.',
     'Updated affected dbt models to quote the keyword. Added pre-deployment check to CI/CD pipeline.',
     'Resolved', 3.5,  4),
(18, 10, '2026-06-30', 'Critical', 'Performance',  'Production pipeline SLA breach - 4 hour delay',
     'Daily production pipeline missed its 6 AM SLA by 4 hours due to warehouse contention.',
     'Moved pipeline to dedicated warehouse with resource monitor. Added Slack alerting for SLA risk.',
     'Resolved', 2.0,  3),
(19, 12, '2026-07-22', 'Low',      'Feature Request', 'Implement Iceberg Tables for open data lake',
     'Want to evaluate Iceberg Tables for data lake strategy.',
     'Provided evaluation document. Set up POC with sample conversion of 3 tables.',
     'In Progress', NULL, NULL),
(20, 15, '2026-07-14', 'Medium',   'Cost',         'Need FinOps dashboard for Snowflake spend',
     'Finance wants detailed breakdown of Snowflake costs by team, project, and workload type.',
     'Built FinOps dashboard using WAREHOUSE_METERING_HISTORY and QUERY_HISTORY with cost allocation tags.',
     'Resolved', 20.0, 5);

-- 5. Enable cross-region inference (needed for CoWork / Cortex) ------
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- 6. Verify -----------------------------------------------------------
SELECT 'CUSTOMERS'       AS TBL, COUNT(*) AS ROWS FROM CUSTOMERS
UNION ALL
SELECT 'DEALS',                  COUNT(*)         FROM DEALS
UNION ALL
SELECT 'MONTHLY_REVENUE',       COUNT(*)         FROM MONTHLY_REVENUE
UNION ALL
SELECT 'SUPPORT_TICKETS',       COUNT(*)         FROM SUPPORT_TICKETS;
