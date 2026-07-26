-- ============================================================
-- CoWork Sales Analytics Agent — Semantic View & Agent Setup
--
-- Creates a Semantic View over the four sales tables, then
-- provides instructions for creating the Cortex Agent in the UI.
--
-- Run AFTER 01_setup.sql.
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE COWORK_DEMO_DB;
USE SCHEMA SALES_ANALYTICS;
USE WAREHOUSE COWORK_DEMO_WH;

-- ─── SEMANTIC VIEW ─────────────────────────────────────────
-- This is Snowflake's recommended approach (as of 2026) for
-- giving AI agents a structured understanding of your data.
-- It replaces the older "YAML on stage" semantic model pattern.

CREATE OR REPLACE SEMANTIC VIEW COWORK_DEMO_DB.SALES_ANALYTICS.SALES_ANALYTICS_VIEW
  TABLES (
    customers       AS COWORK_DEMO_DB.SALES_ANALYTICS.CUSTOMERS        PRIMARY KEY (CUSTOMER_ID),
    deals           AS COWORK_DEMO_DB.SALES_ANALYTICS.DEALS            PRIMARY KEY (DEAL_ID),
    monthly_revenue AS COWORK_DEMO_DB.SALES_ANALYTICS.MONTHLY_REVENUE  PRIMARY KEY (REVENUE_ID),
    support_tickets AS COWORK_DEMO_DB.SALES_ANALYTICS.SUPPORT_TICKETS  PRIMARY KEY (TICKET_ID)
  )
  RELATIONSHIPS (
    deals           (CUSTOMER_ID) REFERENCES customers,
    monthly_revenue (CUSTOMER_ID) REFERENCES customers,
    support_tickets (CUSTOMER_ID) REFERENCES customers
  )
  FACTS (
    deals.deal_amount           AS AMOUNT_USD,
    deals.win_prob              AS WIN_PROBABILITY,
    monthly_revenue.mrr         AS MRR_USD,
    monthly_revenue.expansion   AS EXPANSION_USD,
    monthly_revenue.licenses    AS LICENSE_COUNT,
    customers.health            AS HEALTH_SCORE,
    support_tickets.hours_to_resolve AS RESOLUTION_HOURS,
    support_tickets.csat        AS CSAT_SCORE
  )
  DIMENSIONS (
    -- Customer dimensions
    customers.company_name      AS COMPANY_NAME,
    customers.customer_industry AS INDUSTRY,
    customers.company_size      AS COMPANY_SIZE,
    customers.customer_region   AS REGION,
    customers.country           AS COUNTRY,
    customers.arr_tier          AS ARR_TIER,
    customers.onboarding_date   AS ONBOARDING_DATE,
    customers.account_manager   AS ACCOUNT_MANAGER,
    -- Deal dimensions
    deals.deal_name             AS DEAL_NAME,
    deals.deal_stage            AS STAGE,
    deals.deal_type             AS DEAL_TYPE,
    deals.close_date            AS CLOSE_DATE,
    deals.deal_created          AS CREATED_DATE,
    deals.sales_rep             AS SALES_REP,
    deals.deal_product          AS PRODUCT_LINE,
    deals.deal_region           AS REGION,
    deals.deal_industry         AS INDUSTRY,
    deals.lost_reason           AS LOST_REASON,
    -- Revenue dimensions
    monthly_revenue.revenue_month AS MONTH,
    monthly_revenue.rev_product   AS PRODUCT_LINE,
    monthly_revenue.is_churned    AS CHURN_FLAG,
    -- Support dimensions
    support_tickets.ticket_date     AS CREATED_DATE,
    support_tickets.ticket_priority AS PRIORITY,
    support_tickets.ticket_category AS CATEGORY,
    support_tickets.ticket_subject  AS SUBJECT,
    support_tickets.ticket_status   AS STATUS
  )
  METRICS (
    customers.total_customers        AS COUNT(CUSTOMER_ID),
    deals.total_deals                AS COUNT(DEAL_ID),
    deals.total_pipeline_value       AS SUM(deal_amount),
    deals.average_deal_size          AS AVG(deal_amount),
    deals.won_deals                  AS COUNT_IF(deal_stage = 'Closed Won'),
    deals.lost_deals                 AS COUNT_IF(deal_stage = 'Closed Lost'),
    monthly_revenue.total_mrr        AS SUM(mrr),
    monthly_revenue.total_expansion  AS SUM(expansion),
    support_tickets.total_tickets    AS COUNT(TICKET_ID),
    support_tickets.avg_resolution_hours AS AVG(hours_to_resolve),
    support_tickets.avg_csat         AS AVG(csat)
  );

-- Verify the semantic view was created
SHOW SEMANTIC VIEWS IN SCHEMA COWORK_DEMO_DB.SALES_ANALYTICS;

-- ============================================================
-- NEXT STEP: Create the Cortex Agent in the Snowsight UI
--
-- The Cortex Agent cannot be created via SQL — use the UI:
--
-- 1. Navigate to Snowsight → AI Studio → Agents
-- 2. Click "+ Agent" to create a new agent
-- 3. Configure:
--      Name:        SALES_ANALYTICS_AGENT
--      Database:    COWORK_DEMO_DB
--      Schema:      SALES_ANALYTICS
--      Description: A SaaS sales analytics assistant that answers
--                   questions about pipeline, revenue, customers,
--                   and support metrics.
--
-- 4. Under "Tools", click "+ Add semantic view" and select:
--      Database:      COWORK_DEMO_DB
--      Schema:        SALES_ANALYTICS
--      Semantic View: SALES_ANALYTICS_VIEW
--    Give it the tool name "SALES_ANALYTICS" and description:
--      "Query SaaS sales data including customers, deals, revenue,
--       and support tickets. Use this tool when users ask about
--       sales performance, pipeline, revenue trends, customer
--       details, or support metrics."
--
-- 5. Under "Instructions":
--    Orchestration instructions:
--      "You are a SaaS Sales Analytics assistant. When users ask
--       about sales performance, pipeline, revenue, customers, or
--       support metrics, use the SALES_ANALYTICS semantic view to
--       query the data. Always provide clear, actionable insights
--       with specific numbers. Break down results by relevant
--       dimensions like region, industry, product line, or time
--       period when appropriate."
--
--    Response instructions:
--      "Respond in a professional, concise manner. Format currency
--       values with $ signs and commas. Use bullet points for
--       lists of insights. When presenting metrics, include
--       comparisons and trends where possible."
--
-- 6. Click "Publish" to publish the agent
-- 7. Click "+ Add to Snowflake CoWork" to make it available
--    in the CoWork interface at ai.snowflake.com
--
-- 8. Test it! Go to ai.snowflake.com → Capabilities → Agents →
--    select SALES_ANALYTICS_AGENT → start chatting:
--      "What is our total pipeline value by stage?"
--      "Which customers have the lowest health scores?"
-- ============================================================
