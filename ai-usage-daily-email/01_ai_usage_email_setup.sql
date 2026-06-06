-- ============================================================================
--  Snowflake AI Usage — Daily Email Notification Framework
--  01_ai_usage_email_setup.sql   (single, self-contained setup script)
--
--  WHAT THIS DOES
--    Sends a daily HTML email summarizing your account's Cortex AI usage:
--      • Yesterday and Month-to-date AI credits + $ + query count
--      • (Optional) AI credit budget tracker with OK / WARN / OVER badges
--      • Last 7 days trend
--      • Month-to-date breakdowns by service, function, model, and USER
--    It builds everything from scratch — database, schema, a unified AI-usage
--    view over SNOWFLAKE.ACCOUNT_USAGE, a config table, helper functions, the
--    stored procedure, the email integration, and a daily scheduled task.
--
--  DATA SOURCES (all standard, no custom infra required)
--    SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY   (AI_COMPLETE, …)
--    SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY          (Cortex Agents)
--    SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY       (Cortex Code CLI)
--    SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY (Snowsight Copilot)
--    SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
--    SNOWFLAKE.ACCOUNT_USAGE.USERS                              (USER_ID -> name)
--
--  PREREQUISITES
--    • Run as ACCOUNTADMIN (simplest). The role needs: CREATE DATABASE,
--      CREATE INTEGRATION, EXECUTE TASK, and read access to SNOWFLAKE.ACCOUNT_USAGE
--      (the ACCOUNTADMIN chain has the SNOWFLAKE.GOVERNANCE_VIEWER / IMPORTED
--      PRIVILEGES needed). The procedure runs EXECUTE AS OWNER, so the owner
--      keeps that access at run time.
--    • ACCOUNT_USAGE views have up to ~2–3h latency — “yesterday” (UTC) is safe.
--
--  ┌──────────────────────────────────────────────────────────────────────────┐
--  │  🔧 PARAMETERS — EDIT BEFORE RUNNING                                       │
--  │  Find-and-replace these tokens throughout this file:                       │
--  │                                                                            │
--  │   AI_USAGE_MONITORING   → the database name you want (default is fine)      │
--  │   'you@example.com'     → the recipient email (appears 2x: integration +    │
--  │                           config seed). MUST be a verified recipient*.      │
--  │   CRON 0 8 * * * Asia/Kolkata → the schedule (default = 08:00 IST daily).   │
--  │                           e.g. '0 8 * * * America/New_York' for 8 AM ET.    │
--  │                                                                            │
--  │  Other knobs (credit price, budget, subject, top-N) are seeded into the     │
--  │  CONFIG table in STEP 3 and can be changed any time with UPDATE — no        │
--  │  redeploy needed.                                                          │
--  │                                                                            │
--  │  * Snowflake only emails verified addresses. If the recipient is a         │
--  │    Snowflake user's email it's auto-verified; otherwise see the README.    │
--  └──────────────────────────────────────────────────────────────────────────┘
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ----------------------------------------------------------------------------
-- STEP 1: Database, schema, and the email notification integration
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS AI_USAGE_MONITORING;
CREATE SCHEMA   IF NOT EXISTS AI_USAGE_MONITORING.NOTIFICATIONS;

-- Email integration. ALLOWED_RECIPIENTS must list every address the proc can
-- email. (This is a deploy-time literal — add more addresses here if needed.)
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS AI_USAGE_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('you@example.com')           -- 🔧 recipient(s)
  COMMENT = 'Daily AI usage email — AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL';


-- ----------------------------------------------------------------------------
-- STEP 2: Unified AI usage view (with USER_NAME resolved)
--   One row per AI request/query across all Cortex services. USER_NAME comes
--   directly from the agent/code/intelligence tables; for AI Functions it is
--   resolved from USER_ID via ACCOUNT_USAGE.USERS.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
  COMMENT = 'Unified Cortex AI usage across all AI service types, with USER_NAME resolved. MODEL_NAME is the real LLM model and is only populated for AI Functions (the only source that reports it); AGENT_NAME holds the agent/app name for Cortex Agents and Snowflake Intelligence. Cortex Code reports neither.'
AS
WITH users AS (
    SELECT USER_ID, MAX(NAME) AS USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
    GROUP BY USER_ID
),
raw AS (
    -- Cortex AI Functions — the ONLY source that reports the underlying LLM model.
    SELECT START_TIME::TIMESTAMP_LTZ AS USAGE_TIME, 'AI_FUNCTIONS' AS SERVICE,
           FUNCTION_NAME AS FUNCTION_NAME,
           NULLIF(MODEL_NAME, '') AS MODEL_NAME, NULL AS AGENT_NAME,
           CREDITS AS CREDITS, QUERY_ID AS USAGE_ID, USER_ID AS USER_ID,
           NULL AS USER_NAME_RAW
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY
    UNION ALL
    -- Cortex Agents — usage reports the AGENT, not the model it calls.
    SELECT START_TIME::TIMESTAMP_LTZ, 'CORTEX_AGENTS', 'CORTEX_AGENT',
           NULL AS MODEL_NAME, COALESCE(AGENT_NAME, '(unknown)') AS AGENT_NAME,
           TOKEN_CREDITS, REQUEST_ID, USER_ID, USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
    UNION ALL
    -- Cortex Code (CLI) — reports neither model nor agent.
    SELECT USAGE_TIME::TIMESTAMP_LTZ, 'CORTEX_CODE_CLI', 'CORTEX_CODE_CLI',
           NULL, NULL, TOKEN_CREDITS, REQUEST_ID, USER_ID, USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    -- Cortex Code (Snowsight Copilot) — reports neither model nor agent.
    SELECT USAGE_TIME::TIMESTAMP_LTZ, 'CORTEX_CODE_SNOWSIGHT', 'CORTEX_CODE_SNOWSIGHT',
           NULL, NULL, TOKEN_CREDITS, REQUEST_ID, USER_ID, USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
    UNION ALL
    -- Snowflake Intelligence — reports the SI / agent name, not the model.
    SELECT START_TIME::TIMESTAMP_LTZ, 'SNOWFLAKE_INTELLIGENCE', 'SNOWFLAKE_INTELLIGENCE',
           NULL, COALESCE(SNOWFLAKE_INTELLIGENCE_NAME, AGENT_NAME, '(unknown)'),
           TOKEN_CREDITS, REQUEST_ID, USER_ID, USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
)
SELECT
    r.USAGE_ID,
    r.USAGE_TIME,
    r.SERVICE,
    r.FUNCTION_NAME,
    r.MODEL_NAME,                                         -- real LLM model (AI Functions only)
    r.AGENT_NAME,                                         -- agent / app name (Agents, Intelligence)
    r.CREDITS::NUMBER(38, 9) AS CREDITS,
    COALESCE(r.USER_NAME_RAW, u.USER_NAME, '(unknown)') AS USER_NAME
FROM raw r
LEFT JOIN users u ON u.USER_ID = r.USER_ID;


-- ----------------------------------------------------------------------------
-- STEP 3: Config table (runtime-tunable settings — edit with UPDATE, no redeploy)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS AI_USAGE_MONITORING.NOTIFICATIONS.CONFIG (
  KEY STRING NOT NULL PRIMARY KEY,
  VALUE STRING,
  DESCRIPTION STRING,
  UPDATED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

MERGE INTO AI_USAGE_MONITORING.NOTIFICATIONS.CONFIG t USING (
  SELECT 'AI_CREDIT_PRICE_USD'  AS KEY, '3.00'                       AS VALUE, 'USD per AI credit (set to your contract rate)'                     AS DESCRIPTION UNION ALL
  SELECT 'AI_BUDGET_CREDITS',          '100',                               'Monthly AI credit budget. Set to 0 to hide the budget section.'              UNION ALL
  SELECT 'BUDGET_WARN_PCT',            '90',                                'Show WARN badge at >= this percent of budget'                                UNION ALL
  SELECT 'TOP_N',                      '10',                                'Rows to show in each breakdown table before an "Others" row'                 UNION ALL
  SELECT 'EMAIL_RECIPIENT',            'you@example.com',                   'Recipient (must also be in AI_USAGE_EMAIL_INT ALLOWED_RECIPIENTS)'  UNION ALL  -- 🔧
  SELECT 'EMAIL_SUBJECT_PREFIX',       'Snowflake AI Usage',                'Prefix for the email subject line'                                           UNION ALL
  SELECT 'EMAIL_INTEGRATION',          'AI_USAGE_EMAIL_INT',                'Notification integration name used to send'
) s ON t.KEY = s.KEY
WHEN NOT MATCHED THEN INSERT (KEY, VALUE, DESCRIPTION) VALUES (s.KEY, s.VALUE, s.DESCRIPTION);

-- One-row OBJECT view of the config, for easy loading inside the procedure.
CREATE OR REPLACE VIEW AI_USAGE_MONITORING.NOTIFICATIONS.V_CONFIG AS
SELECT OBJECT_AGG(KEY, TO_VARIANT(VALUE)) AS CFG
FROM AI_USAGE_MONITORING.NOTIFICATIONS.CONFIG;


-- ----------------------------------------------------------------------------
-- STEP 4: Small formatting helpers (trim Snowflake's number padding)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(P FLOAT)
  RETURNS STRING AS $$ TRIM(TO_VARCHAR(COALESCE(P, 0), '999,999,990.0000')) $$;
CREATE OR REPLACE FUNCTION AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(P FLOAT)
  RETURNS STRING AS $$ TRIM(TO_VARCHAR(COALESCE(P, 0), '999,999,990.00')) $$;
CREATE OR REPLACE FUNCTION AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(P FLOAT)
  RETURNS STRING AS $$ '$' || TRIM(TO_VARCHAR(COALESCE(P, 0), '999,999,990.00')) $$;


-- ----------------------------------------------------------------------------
-- STEP 5: The procedure that builds and sends the email
--   CALL ...(TRUE)  -> sends via SYSTEM$SEND_EMAIL, returns 'sent: <subject>'
--   CALL ...(FALSE) -> returns the HTML body without sending (preview)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL(P_SEND BOOLEAN)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  cfg            OBJECT;
  credit_price   FLOAT;
  ai_budget      FLOAT;
  warn_pct       FLOAT;
  top_n          NUMBER;
  recipient      STRING;
  subj_prefix    STRING;
  integration    STRING;

  report_day     DATE;
  m_start        DATE;
  wk_start       DATE;

  ai_cr_y FLOAT;  ai_usd_y FLOAT;  ai_q_y NUMBER;
  ai_cr_m FLOAT;  ai_usd_m FLOAT;  ai_q_m NUMBER;

  budget_pct     FLOAT;
  budget_block   STRING;

  daily_rows STRING;  svc_rows STRING;  fn_rows STRING;  model_rows STRING;  user_rows STRING;

  tbl STRING DEFAULT 'cellpadding="8" style="border-collapse:collapse;border:1px solid #ddd"';
  th  STRING DEFAULT 'style="background:#f4f9fc"';
  hdr  STRING;
  subj STRING;  body STRING;
BEGIN
  --------------------------------------------------------------------------
  -- Load config
  --------------------------------------------------------------------------
  SELECT CFG INTO :cfg FROM AI_USAGE_MONITORING.NOTIFICATIONS.V_CONFIG;
  credit_price := COALESCE(cfg:AI_CREDIT_PRICE_USD::FLOAT,  3.00);
  ai_budget    := COALESCE(cfg:AI_BUDGET_CREDITS::FLOAT,    0);
  warn_pct     := COALESCE(cfg:BUDGET_WARN_PCT::FLOAT,      90);
  top_n        := COALESCE(cfg:TOP_N::NUMBER,               10);
  recipient    := cfg:EMAIL_RECIPIENT::STRING;
  subj_prefix  := COALESCE(cfg:EMAIL_SUBJECT_PREFIX::STRING,'Snowflake AI Usage');
  integration  := COALESCE(cfg:EMAIL_INTEGRATION::STRING,   'AI_USAGE_EMAIL_INT');

  -- Date boundaries in UTC (matches ACCOUNT_USAGE; independent of the schedule TZ).
  SELECT y, DATE_TRUNC('MONTH', y), y - 6
    INTO :report_day, :m_start, :wk_start
    FROM (SELECT (CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()))::DATE - 1 AS y);

  --------------------------------------------------------------------------
  -- Yesterday + Month-to-date headline numbers
  --------------------------------------------------------------------------
  SELECT COALESCE(SUM(CREDITS), 0), COALESCE(SUM(CREDITS), 0) * :credit_price, COUNT(DISTINCT USAGE_ID)
    INTO :ai_cr_y, :ai_usd_y, :ai_q_y
    FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
   WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE = :report_day;

  SELECT COALESCE(SUM(CREDITS), 0), COALESCE(SUM(CREDITS), 0) * :credit_price, COUNT(DISTINCT USAGE_ID)
    INTO :ai_cr_m, :ai_usd_m, :ai_q_m
    FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
   WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE BETWEEN :m_start AND :report_day;

  --------------------------------------------------------------------------
  -- Optional budget block
  --------------------------------------------------------------------------
  IF (ai_budget > 0) THEN
    budget_pct := 100.0 * ai_cr_m / ai_budget;
    budget_block :=
      '<h3 style="margin-bottom:4px">AI budget (month-to-date)</h3><p>' ||
      AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(ai_cr_m) || ' / ' ||
      AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(ai_budget) || ' credits used - <b>' ||
      TRIM(TO_VARCHAR(budget_pct, '999990.0')) || '%</b>' ||
      CASE WHEN budget_pct >= 100      THEN ' <span style="color:#c0392b;font-weight:bold">[OVER BUDGET]</span>'
           WHEN budget_pct >= warn_pct THEN ' <span style="color:#e67e22;font-weight:bold">[WARN]</span>'
           ELSE ' <span style="color:#27ae60;font-weight:bold">[OK]</span>' END ||
      '</p>';
  ELSE
    budget_block := '';
  END IF;

  --------------------------------------------------------------------------
  -- Last 7 days trend
  --------------------------------------------------------------------------
  SELECT LISTAGG('<tr><td>' || TO_VARCHAR(DAY) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(CR) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(CR * :credit_price) ||
                 '</td></tr>', '') WITHIN GROUP (ORDER BY DAY DESC)
    INTO :daily_rows
    FROM (SELECT CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE AS DAY, SUM(CREDITS) AS CR
            FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
           WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE BETWEEN :wk_start AND :report_day
           GROUP BY 1);

  --------------------------------------------------------------------------
  -- MTD breakdown by SERVICE (top N + Others, foots to MTD total)
  --------------------------------------------------------------------------
  SELECT LISTAGG('<tr' || IFF(SORT_RN = 999999, ' style="font-style:italic;color:#666"', '') ||
                 '><td>' || GRP || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(CR) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(CR * :credit_price) ||
                 '</td></tr>', '') WITHIN GROUP (ORDER BY SORT_RN)
    INTO :svc_rows
    FROM (
        SELECT CASE WHEN RN <= :top_n THEN RN  ELSE 999999             END AS SORT_RN,
               CASE WHEN RN <= :top_n THEN GRP0 ELSE 'Others'           END AS GRP,
               SUM(CR) AS CR
          FROM (SELECT SERVICE AS GRP0, SUM(CREDITS) AS CR,
                       ROW_NUMBER() OVER (ORDER BY SUM(CREDITS) DESC) AS RN
                  FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
                 WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE BETWEEN :m_start AND :report_day
                 GROUP BY SERVICE)
         GROUP BY 1, 2);

  --------------------------------------------------------------------------
  -- MTD breakdown by FUNCTION
  --------------------------------------------------------------------------
  SELECT LISTAGG('<tr' || IFF(SORT_RN = 999999, ' style="font-style:italic;color:#666"', '') ||
                 '><td>' || GRP || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(CR) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(CR * :credit_price) ||
                 '</td></tr>', '') WITHIN GROUP (ORDER BY SORT_RN)
    INTO :fn_rows
    FROM (
        SELECT CASE WHEN RN <= :top_n THEN RN  ELSE 999999   END AS SORT_RN,
               CASE WHEN RN <= :top_n THEN GRP0 ELSE 'Others' END AS GRP,
               SUM(CR) AS CR
          FROM (SELECT COALESCE(FUNCTION_NAME, '(none)') AS GRP0, SUM(CREDITS) AS CR,
                       ROW_NUMBER() OVER (ORDER BY SUM(CREDITS) DESC) AS RN
                  FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
                 WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE BETWEEN :m_start AND :report_day
                 GROUP BY 1)
         GROUP BY 1, 2);

  --------------------------------------------------------------------------
  -- MTD breakdown by MODEL / AGENT
  --   The finest identity each AI service reports: the LLM model for AI
  --   Functions, the agent/app name for Agents & Intelligence, or the service
  --   for Cortex Code (which reports neither). The Type column makes it explicit
  --   so an agent name is never mistaken for a model.
  --------------------------------------------------------------------------
  SELECT LISTAGG('<tr' || IFF(SORT_RN = 999999, ' style="font-style:italic;color:#666"', '') ||
                 '><td>' || GRP || '</td><td>' || TYP ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(CR) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(CR * :credit_price) ||
                 '</td></tr>', '') WITHIN GROUP (ORDER BY SORT_RN)
    INTO :model_rows
    FROM (
        SELECT CASE WHEN RN <= :top_n THEN RN   ELSE 999999   END AS SORT_RN,
               CASE WHEN RN <= :top_n THEN GRP0 ELSE 'Others'  END AS GRP,
               CASE WHEN RN <= :top_n THEN TYP0 ELSE ''        END AS TYP,
               SUM(CR) AS CR
          FROM (SELECT GRP0, TYP0, SUM(CR0) AS CR,
                       ROW_NUMBER() OVER (ORDER BY SUM(CR0) DESC) AS RN
                  FROM (SELECT COALESCE(MODEL_NAME, AGENT_NAME, SERVICE) AS GRP0,
                               CASE WHEN MODEL_NAME IS NOT NULL THEN 'Model'
                                    WHEN AGENT_NAME IS NOT NULL THEN 'Agent'
                                    ELSE 'Service' END AS TYP0,
                               CREDITS AS CR0
                          FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
                         WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE BETWEEN :m_start AND :report_day)
                 GROUP BY 1, 2)
         GROUP BY 1, 2, 3);

  --------------------------------------------------------------------------
  -- MTD breakdown by USER
  --------------------------------------------------------------------------
  SELECT LISTAGG('<tr' || IFF(SORT_RN = 999999, ' style="font-style:italic;color:#666"', '') ||
                 '><td>' || GRP || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(CR) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(CR * :credit_price) ||
                 '</td></tr>', '') WITHIN GROUP (ORDER BY SORT_RN)
    INTO :user_rows
    FROM (
        SELECT CASE WHEN RN <= :top_n THEN RN  ELSE 999999   END AS SORT_RN,
               CASE WHEN RN <= :top_n THEN GRP0 ELSE 'Others' END AS GRP,
               SUM(CR) AS CR
          FROM (SELECT USER_NAME AS GRP0, SUM(CREDITS) AS CR,
                       ROW_NUMBER() OVER (ORDER BY SUM(CREDITS) DESC) AS RN
                  FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
                 WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE BETWEEN :m_start AND :report_day
                 GROUP BY 1)
         GROUP BY 1, 2);

  --------------------------------------------------------------------------
  -- Subject + HTML body
  --------------------------------------------------------------------------
  subj := subj_prefix || ' - ' || TO_VARCHAR(:report_day, 'Dy YYYY-MM-DD') ||
          ' - ' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(ai_cr_y) || ' credits (' ||
          AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(ai_usd_y) || ')';

  hdr := '<tr ' || th || '><th align="left">Name</th><th align="right">Credits</th><th align="right">USD</th></tr>';

  body :=
    '<html><body style="font-family:Arial,Helvetica,sans-serif;color:#222;font-size:14px">' ||
    '<h2 style="color:#29b5e8;margin-bottom:2px">Snowflake AI Usage</h2>' ||
    '<p style="color:#666;margin-top:0">Daily Cortex AI summary for <b>' ||
        TO_VARCHAR(:report_day, 'Dy, DD Mon YYYY') || '</b> (UTC)</p>' ||

    -- Yesterday vs MTD headline
    '<table ' || tbl || '>' ||
    '<tr ' || th || '><th align="left">Window</th><th align="right">Credits</th><th align="right">USD</th><th align="right">Queries</th></tr>' ||
    '<tr><td>Yesterday</td><td align="right">'    || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(ai_cr_y) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(ai_usd_y) || '</td><td align="right">' || TO_VARCHAR(ai_q_y) || '</td></tr>' ||
    '<tr><td>Month-to-date</td><td align="right">'|| AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(ai_cr_m) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(ai_usd_m) || '</td><td align="right">' || TO_VARCHAR(ai_q_m) || '</td></tr>' ||
    '</table>' ||

    budget_block ||

    '<h3 style="margin-bottom:4px">Last 7 days</h3>' ||
    CASE WHEN daily_rows IS NULL THEN '<p><i>No AI activity.</i></p>'
         ELSE '<table ' || tbl || '><tr ' || th || '><th align="left">Day (UTC)</th><th align="right">Credits</th><th align="right">USD</th></tr>' || daily_rows || '</table>' END ||

    '<h3 style="margin-bottom:4px">By service (MTD)</h3>' ||
    CASE WHEN svc_rows IS NULL THEN '<p><i>No AI activity.</i></p>'
         ELSE '<table ' || tbl || '>' || hdr || svc_rows ||
              '<tr style="font-weight:bold;border-top:2px solid #bbb"><td>Total</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(ai_cr_m) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(ai_usd_m) || '</td></tr></table>' END ||

    '<h3 style="margin-bottom:4px">By function (MTD)</h3>' ||
    CASE WHEN fn_rows IS NULL THEN '<p><i>No AI activity.</i></p>'
         ELSE '<table ' || tbl || '>' || hdr || fn_rows ||
              '<tr style="font-weight:bold;border-top:2px solid #bbb"><td>Total</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(ai_cr_m) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(ai_usd_m) || '</td></tr></table>' END ||

    '<h3 style="margin-bottom:4px">By model / agent (MTD)</h3>' ||
    '<p style="color:#777;margin:0 0 6px 0;font-size:12px">Snowflake reports the LLM model only for AI Functions; Agents and Intelligence report the agent/app name, and Cortex Code reports neither.</p>' ||
    CASE WHEN model_rows IS NULL THEN '<p><i>No AI activity.</i></p>'
         ELSE '<table ' || tbl || '><tr ' || th || '><th align="left">Name</th><th align="left">Type</th><th align="right">Credits</th><th align="right">USD</th></tr>' || model_rows ||
              '<tr style="font-weight:bold;border-top:2px solid #bbb"><td>Total</td><td></td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(ai_cr_m) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(ai_usd_m) || '</td></tr></table>' END ||

    '<h3 style="margin-bottom:4px">By user (MTD)</h3>' ||
    CASE WHEN user_rows IS NULL THEN '<p><i>No AI activity.</i></p>'
         ELSE '<table ' || tbl || '>' || hdr || user_rows ||
              '<tr style="font-weight:bold;border-top:2px solid #bbb"><td>Total</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(ai_cr_m) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(ai_usd_m) || '</td></tr></table>' END ||

    '<p style="color:#666;margin-top:24px;font-size:11px">Generated by AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL - ' ||
    'USD at $' || TRIM(TO_VARCHAR(credit_price, '990.00')) || '/credit - dates UTC - ACCOUNT_USAGE has up to ~2-3h latency.</p>' ||
    '</body></html>';

  --------------------------------------------------------------------------
  -- Send or preview
  --------------------------------------------------------------------------
  IF (P_SEND) THEN
    CALL SYSTEM$SEND_EMAIL(:integration, :recipient, :subj, :body, 'text/html');
    RETURN 'sent: ' || subj;
  ELSE
    RETURN body;
  END IF;
END;
$$;


-- ----------------------------------------------------------------------------
-- STEP 6: Daily scheduled task  (🔧 edit SCHEDULE for your time / timezone)
--   Default: 08:00 every day, India Standard Time.
--   Examples: '0 8 * * * America/New_York'  -> 08:00 US Eastern
--             '30 7 * * 1-5 Europe/London'  -> 07:30 London, weekdays only
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TASK AI_USAGE_MONITORING.NOTIFICATIONS.TSK_DAILY_AI_USAGE_EMAIL
  SCHEDULE = 'USING CRON 0 8 * * * Asia/Kolkata'                  -- 🔧 schedule
  USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
  COMMENT = 'Daily AI usage email'
AS
  CALL AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL(TRUE);

-- Tasks are created suspended — resume to activate.
ALTER TASK AI_USAGE_MONITORING.NOTIFICATIONS.TSK_DAILY_AI_USAGE_EMAIL RESUME;


-- ============================================================================
-- DONE.  Next: preview, then send a test  (see 02_verify_and_test.sql)
--   Preview (no send):  CALL AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL(FALSE);
--   Send a test now:    CALL AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL(TRUE);
-- ============================================================================
