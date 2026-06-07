-- ============================================================================
--  Snowflake AI Usage — Daily Email Notification Framework
--  01_ai_usage_email_setup.sql   (single, self-contained setup script)
--
--  WHAT THIS DOES
--    Sends a daily HTML email summarizing your account's Cortex AI usage:
--      • Latest-settled-day and Month-to-date AI credits + $
--      • AI by TYPE and by TYPE+SUBTYPE (the agent/app), billed from the ledger
--      • (Optional) AI credit budget tracker with OK / WARN / OVER badges
--      • Drill-downs by function, model/agent, and USER
--      • Last 7 days trend
--
--  METERING-FIRST (why this is accurate)
--    The headline AI total, the by-type and by-type+subtype tables come from the
--    Snowflake billing ledger — SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY — which
--    is near real-time and bills in credits per service type (CORTEX_*, AI_*,
--    SNOWFLAKE_INTELLIGENCE). That total FOOTS to your invoice and is complete for
--    the latest settled day. The per-model / function / user DRILL-DOWNS come from
--    the dedicated Cortex usage views (CORTEX_*_USAGE_HISTORY), which carry those
--    dimensions but LAG ~39h — so the email labels each section with an "as of"
--    date badge: green "settled" (billed/metering) vs amber "detail" (drill-downs).
--    A prefix predicate (IS_AI_SERVICE) auto-includes any NEW Cortex/AI service
--    type Snowflake ships, and a banner flags any type without a friendly label.
--
--  DATA SOURCES (all standard, no custom infra required)
--    SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY / METERING_DAILY_HISTORY   (billed AI credits, by type + NAME)
--    SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY           (model/function detail)
--    SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY                  (Cortex Agents)
--    SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY               (Cortex Code CLI)
--    SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY         (Snowsight Copilot)
--    SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
--    SNOWFLAKE.ACCOUNT_USAGE.USERS                                      (USER_ID -> name)
--
--  PREREQUISITES
--    • Run as ACCOUNTADMIN (simplest). Needs CREATE DATABASE, CREATE INTEGRATION,
--      EXECUTE TASK, and read access to SNOWFLAKE.ACCOUNT_USAGE. The procedure runs
--      EXECUTE AS OWNER, so the owner keeps that access at run time.
--    • METERING_HISTORY is near real-time; Cortex detail views lag ~39h. The email
--      handles this automatically (data-driven "latest settled day").
--
--  ┌──────────────────────────────────────────────────────────────────────────┐
--  │  PARAMETERS — EDIT BEFORE RUNNING (find-and-replace)                        │
--  │   AI_USAGE_MONITORING        -> the database name you want (default is fine) │
--  │   'you@example.com'          -> the recipient email (appears 2x). Must be a  │
--  │                                 verified recipient (a Snowflake user's email │
--  │                                 is auto-verified; otherwise see the README). │
--  │   CRON 0 8 * * * Asia/Kolkata -> the schedule (default 08:00 IST daily).     │
--  │  Other knobs (credit price, budget, subject, top-N) live in the CONFIG table │
--  │  and can be changed any time with UPDATE — no redeploy.                      │
--  └──────────────────────────────────────────────────────────────────────────┘
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ----------------------------------------------------------------------------
-- STEP 1: Database, schema, and the email notification integration
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS AI_USAGE_MONITORING;
CREATE SCHEMA   IF NOT EXISTS AI_USAGE_MONITORING.NOTIFICATIONS;

CREATE NOTIFICATION INTEGRATION IF NOT EXISTS AI_USAGE_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('you@example.com')           -- recipient(s)
  COMMENT = 'Daily AI usage email — AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL';


-- ----------------------------------------------------------------------------
-- STEP 2: Unified Cortex detail view (for the model / function / user drill-downs)
--   One row per AI request across all Cortex services, USER_NAME resolved. This
--   powers the per-model/function/user tables only; the billed TOTAL/type/subtype
--   come from the metering ledger (STEP 5). These detail views lag ~39h.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
  COMMENT = 'Unified Cortex AI usage (detail). MODEL_NAME is the real LLM model and is only populated for AI Functions; AGENT_NAME holds the agent/app name for Agents and Snowflake Intelligence; Cortex Code reports neither. Used for drill-downs; lags ~39h.'
AS
WITH users AS (
    SELECT USER_ID, MAX(NAME) AS USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
    GROUP BY USER_ID
),
raw AS (
    SELECT START_TIME::TIMESTAMP_LTZ AS USAGE_TIME, 'AI_FUNCTIONS' AS SERVICE,
           FUNCTION_NAME AS FUNCTION_NAME,
           NULLIF(MODEL_NAME, '') AS MODEL_NAME, NULL AS AGENT_NAME,
           CREDITS AS CREDITS, QUERY_ID AS USAGE_ID, USER_ID AS USER_ID, NULL AS USER_NAME_RAW
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY
    UNION ALL
    SELECT START_TIME::TIMESTAMP_LTZ, 'CORTEX_AGENTS', 'CORTEX_AGENT',
           NULL, COALESCE(AGENT_NAME, '(unknown)'),
           TOKEN_CREDITS, REQUEST_ID, USER_ID, USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
    UNION ALL
    SELECT USAGE_TIME::TIMESTAMP_LTZ, 'CORTEX_CODE_CLI', 'CORTEX_CODE_CLI',
           NULL, NULL, TOKEN_CREDITS, REQUEST_ID, USER_ID, USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY
    UNION ALL
    SELECT USAGE_TIME::TIMESTAMP_LTZ, 'CORTEX_CODE_SNOWSIGHT', 'CORTEX_CODE_SNOWSIGHT',
           NULL, NULL, TOKEN_CREDITS, REQUEST_ID, USER_ID, USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
    UNION ALL
    SELECT START_TIME::TIMESTAMP_LTZ, 'SNOWFLAKE_INTELLIGENCE', 'SNOWFLAKE_INTELLIGENCE',
           NULL, COALESCE(SNOWFLAKE_INTELLIGENCE_NAME, AGENT_NAME, '(unknown)'),
           TOKEN_CREDITS, REQUEST_ID, USER_ID, USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
)
SELECT
    r.USAGE_ID, r.USAGE_TIME, r.SERVICE, r.FUNCTION_NAME, r.MODEL_NAME, r.AGENT_NAME,
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
  SELECT 'AI_CREDIT_PRICE_USD'  AS KEY, '3.00'                AS VALUE, 'USD per AI credit (your contract rate). Note: AI_SERVICES may bill at your compute rate; adjust if needed.' AS DESCRIPTION UNION ALL
  SELECT 'AI_BUDGET_CREDITS',          '100',                        'Monthly AI credit budget. Set to 0 to hide the budget section.'              UNION ALL
  SELECT 'BUDGET_WARN_PCT',            '90',                         'Show WARN badge at >= this percent of budget'                                UNION ALL
  SELECT 'TOP_N',                      '10',                         'Rows per drill-down table before an "Others" row'                            UNION ALL
  SELECT 'AI_SUBTYPE_TOP_N',           '12',                         'Rows in the AI type+subtype table before an "Others" row'                    UNION ALL
  SELECT 'AI_KNOWN_SERVICE_TYPES',     'AI_FUNCTIONS,AI_INFERENCE,AI_SERVICES,CORTEX_AGENTS,CORTEX_CODE_CLI,CORTEX_CODE_SNOWSIGHT,CORTEX_SEARCH,SNOWFLAKE_INTELLIGENCE', 'Known AI metering SERVICE_TYPEs; anything else matching the predicate is flagged' UNION ALL
  SELECT 'EMAIL_RECIPIENT',            'you@example.com',            'Recipient (must also be in AI_USAGE_EMAIL_INT ALLOWED_RECIPIENTS)'            UNION ALL
  SELECT 'EMAIL_SUBJECT_PREFIX',       'Snowflake AI Usage',         'Prefix for the email subject line'                                           UNION ALL
  SELECT 'EMAIL_INTEGRATION',          'AI_USAGE_EMAIL_INT',         'Notification integration name used to send'
) s ON t.KEY = s.KEY
WHEN NOT MATCHED THEN INSERT (KEY, VALUE, DESCRIPTION) VALUES (s.KEY, s.VALUE, s.DESCRIPTION);

CREATE OR REPLACE VIEW AI_USAGE_MONITORING.NOTIFICATIONS.V_CONFIG AS
SELECT OBJECT_AGG(KEY, TO_VARIANT(VALUE)) AS CFG
FROM AI_USAGE_MONITORING.NOTIFICATIONS.CONFIG;


-- ----------------------------------------------------------------------------
-- STEP 4: Helper functions
-- ----------------------------------------------------------------------------
-- IS_AI_SERVICE: which metering SERVICE_TYPEs are AI/Cortex. Prefix-based, so it
-- AUTO-CATCHES new CORTEX_*/AI_* types. (Use STARTSWITH(...,'AI_'), NOT
-- ILIKE 'AI[_]%' which matches nothing — Snowflake ILIKE has no char classes.)
CREATE OR REPLACE FUNCTION AI_USAGE_MONITORING.NOTIFICATIONS.IS_AI_SERVICE(P_SERVICE STRING)
  RETURNS BOOLEAN
  COMMENT = 'TRUE for Cortex/AI metering SERVICE_TYPEs (CORTEX_*, AI_*, SNOWFLAKE_INTELLIGENCE).'
AS
$$
  (P_SERVICE ILIKE 'CORTEX%' OR STARTSWITH(P_SERVICE, 'AI_') OR P_SERVICE = 'SNOWFLAKE_INTELLIGENCE')
$$;

-- METER_AI_LABEL: friendly display name for a metering AI SERVICE_TYPE.
CREATE OR REPLACE FUNCTION AI_USAGE_MONITORING.NOTIFICATIONS.METER_AI_LABEL(P_SERVICE STRING)
  RETURNS STRING
  COMMENT = 'Human label for an AI metering SERVICE_TYPE; unknown types pass through (and get flagged).'
AS
$$
  CASE P_SERVICE
    WHEN 'AI_FUNCTIONS'           THEN 'AI Functions'
    WHEN 'AI_INFERENCE'           THEN 'AI Inference'
    WHEN 'AI_SERVICES'            THEN 'AI Services (Cortex Analyst, etc.)'
    WHEN 'CORTEX_AGENTS'          THEN 'Cortex Agents'
    WHEN 'CORTEX_CODE_CLI'        THEN 'Cortex Code (CLI)'
    WHEN 'CORTEX_CODE_SNOWSIGHT'  THEN 'Cortex Code (Snowsight)'
    WHEN 'CORTEX_SEARCH'          THEN 'Cortex Search'
    WHEN 'SNOWFLAKE_INTELLIGENCE' THEN 'Snowflake Intelligence'
    ELSE P_SERVICE
  END
$$;

-- Number formatting helpers (trim Snowflake's padding)
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
  subtype_top_n  FLOAT;
  known_ai_types STRING;
  recipient      STRING;
  subj_prefix    STRING;
  integration    STRING;

  report_day     DATE;
  m_start        DATE;
  wk_start       DATE;
  detail_max_day DATE;
  detail_lag     NUMBER;

  -- Billed (metering ledger)
  ai_cr_y FLOAT;  ai_usd_y FLOAT;
  ai_cr_m FLOAT;  ai_usd_m FLOAT;
  -- Detail (union; lags ~39h)
  u_ai_cr_m FLOAT;  u_ai_usd_m FLOAT;  ai_q_m NUMBER;

  budget_pct   FLOAT;
  budget_block STRING;
  new_types    STRING;  guard_banner STRING;
  badge_settled STRING; badge_detail STRING;

  type_rows STRING;  subtype_rows STRING;  daily_rows STRING;
  fn_rows STRING;    model_rows STRING;    user_rows STRING;

  tbl  STRING DEFAULT 'cellpadding="8" style="border-collapse:collapse;border:1px solid #ddd;margin:0 0 10px 0"';
  th   STRING DEFAULT 'style="background:#eef5fb"';
  css_h3   STRING DEFAULT 'font-size:15px;color:#1a6aa8;margin:24px 0 6px 0;font-weight:bold';
  css_h4   STRING DEFAULT 'font-size:13px;color:#333333;margin:18px 0 6px 0;font-weight:bold';
  css_note STRING DEFAULT 'color:#777777;font-size:12px;margin:0 0 8px 0';
  css_band STRING DEFAULT 'color:#ffffff;font-size:16px;font-weight:bold;padding:9px 14px';
  subj STRING;  body STRING;
BEGIN
  --------------------------------------------------------------------------
  -- Load config
  --------------------------------------------------------------------------
  SELECT CFG INTO :cfg FROM AI_USAGE_MONITORING.NOTIFICATIONS.V_CONFIG;
  credit_price  := COALESCE(cfg:AI_CREDIT_PRICE_USD::FLOAT,  3.00);
  ai_budget     := COALESCE(cfg:AI_BUDGET_CREDITS::FLOAT,    0);
  warn_pct      := COALESCE(cfg:BUDGET_WARN_PCT::FLOAT,      90);
  top_n         := COALESCE(cfg:TOP_N::NUMBER,               10);
  subtype_top_n := COALESCE(cfg:AI_SUBTYPE_TOP_N::FLOAT,     12);
  known_ai_types:= COALESCE(cfg:AI_KNOWN_SERVICE_TYPES::STRING,
                   'AI_FUNCTIONS,AI_INFERENCE,AI_SERVICES,CORTEX_AGENTS,CORTEX_CODE_CLI,CORTEX_CODE_SNOWSIGHT,CORTEX_SEARCH,SNOWFLAKE_INTELLIGENCE');
  recipient     := cfg:EMAIL_RECIPIENT::STRING;
  subj_prefix   := COALESCE(cfg:EMAIL_SUBJECT_PREFIX::STRING,'Snowflake AI Usage');
  integration   := COALESCE(cfg:EMAIL_INTEGRATION::STRING,   'AI_USAGE_EMAIL_INT');

  --------------------------------------------------------------------------
  -- Reporting window (UTC). report_day = latest fully-settled metering day (D-1).
  --------------------------------------------------------------------------
  SELECT MAX(USAGE_DATE) INTO :report_day
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
   WHERE USAGE_DATE < CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::DATE;
  SELECT DATE_TRUNC('MONTH', :report_day), :report_day - 6 INTO :m_start, :wk_start;

  -- How far the Cortex detail views have settled (~D-2), for the drill-down badge.
  SELECT COALESCE(MAX(CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE), :report_day)
    INTO :detail_max_day
    FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
   WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE <= :report_day;

  SELECT DATEDIFF('day', :detail_max_day, :report_day) INTO :detail_lag;
  badge_settled := '<span style="background:#e8f5e9;color:#2e7d32;border:1px solid #a5d6a7;border-radius:10px;padding:2px 9px;font-size:11px;font-weight:normal">settled · ' || TO_VARCHAR(:report_day) || '</span>';
  badge_detail  := '<span style="background:#fff8e1;color:#b26a00;border:1px solid #ffe082;border-radius:10px;padding:2px 9px;font-size:11px;font-weight:normal">detail · ' || TO_VARCHAR(:detail_max_day) ||
                   IFF(:detail_lag > 0, ' (' || TO_VARCHAR(:detail_lag) || ' day' || IFF(:detail_lag = 1, '', 's') || ' behind)', '') || '</span>';

  --------------------------------------------------------------------------
  -- Billed totals from the metering ledger (latest day + MTD)
  --------------------------------------------------------------------------
  SELECT COALESCE(SUM(CREDITS_USED), 0), COALESCE(SUM(CREDITS_USED), 0) * :credit_price
    INTO :ai_cr_y, :ai_usd_y
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
   WHERE AI_USAGE_MONITORING.NOTIFICATIONS.IS_AI_SERVICE(SERVICE_TYPE)
     AND CONVERT_TIMEZONE('UTC', START_TIME)::DATE = :report_day;

  SELECT COALESCE(SUM(CREDITS_USED), 0), COALESCE(SUM(CREDITS_USED), 0) * :credit_price
    INTO :ai_cr_m, :ai_usd_m
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
   WHERE AI_USAGE_MONITORING.NOTIFICATIONS.IS_AI_SERVICE(SERVICE_TYPE)
     AND CONVERT_TIMEZONE('UTC', START_TIME)::DATE BETWEEN :m_start AND :report_day;

  -- Detail (union) MTD total + call count, for the drill-down tables.
  SELECT COALESCE(SUM(CREDITS), 0), COALESCE(SUM(CREDITS), 0) * :credit_price, COUNT(DISTINCT USAGE_ID)
    INTO :u_ai_cr_m, :u_ai_usd_m, :ai_q_m
    FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
   WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE BETWEEN :m_start AND :report_day;

  --------------------------------------------------------------------------
  -- Dynamic new-AI-type guard
  --------------------------------------------------------------------------
  SELECT LISTAGG(DISTINCT SERVICE_TYPE, ', ') WITHIN GROUP (ORDER BY SERVICE_TYPE)
    INTO :new_types
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
   WHERE AI_USAGE_MONITORING.NOTIFICATIONS.IS_AI_SERVICE(SERVICE_TYPE)
     AND CONVERT_TIMEZONE('UTC', START_TIME)::DATE BETWEEN :m_start AND :report_day
     AND SERVICE_TYPE NOT IN (SELECT TRIM(VALUE) FROM TABLE(SPLIT_TO_TABLE(:known_ai_types, ',')));
  guard_banner := IFF(new_types IS NULL OR new_types = '', '',
      '<div style="background:#fff3cd;border:1px solid #ffe69c;padding:8px 12px;margin:10px 0;border-radius:4px">' ||
      '⚠️ <b>New AI service type detected:</b> ' || new_types ||
      ' — it is already counted in the totals; add a label in METER_AI_LABEL() and AI_KNOWN_SERVICE_TYPES.</div>');

  --------------------------------------------------------------------------
  -- Optional budget block (billed MTD vs budget)
  --------------------------------------------------------------------------
  IF (ai_budget > 0) THEN
    budget_pct := 100.0 * ai_cr_m / ai_budget;
    budget_block :=
      '<h3 style="' || css_h3 || '">AI budget (month-to-date)   ' || badge_settled || '</h3><p style="margin:0 0 4px 0">' ||
      AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(ai_cr_m) || ' / ' ||
      AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(ai_budget) || ' credits used - <b>' ||
      TRIM(TO_VARCHAR(budget_pct, '999990.0')) || '%</b>' ||
      CASE WHEN budget_pct >= 100      THEN ' <span style="color:#c0392b;font-weight:bold">[OVER BUDGET]</span>'
           WHEN budget_pct >= warn_pct THEN ' <span style="color:#e67e22;font-weight:bold">[WARN]</span>'
           ELSE ' <span style="color:#27ae60;font-weight:bold">[OK]</span>' END || '</p>';
  ELSE
    budget_block := '';
  END IF;

  --------------------------------------------------------------------------
  -- AI by TYPE — MTD (metering). Foots to the billed AI MTD total.
  --------------------------------------------------------------------------
  SELECT LISTAGG('<tr><td>' || AI_USAGE_MONITORING.NOTIFICATIONS.METER_AI_LABEL(STYP) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(CR) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(CR * :credit_price) ||
                 '</td></tr>', '') WITHIN GROUP (ORDER BY CR DESC)
    INTO :type_rows
    FROM (SELECT SERVICE_TYPE AS STYP, SUM(CREDITS_USED) AS CR
            FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
           WHERE AI_USAGE_MONITORING.NOTIFICATIONS.IS_AI_SERVICE(SERVICE_TYPE)
             AND CONVERT_TIMEZONE('UTC', START_TIME)::DATE BETWEEN :m_start AND :report_day
           GROUP BY SERVICE_TYPE)
   WHERE CR > 0;

  --------------------------------------------------------------------------
  -- AI by TYPE + SUBTYPE — MTD (metering NAME = the agent/app). Top-N + Others.
  --------------------------------------------------------------------------
  SELECT LISTAGG('<tr' || IFF(SORT_RN = 999999, ' style="font-style:italic;color:#666"', '') ||
                 '><td>' || GRP_TYPE || '</td><td>' || GRP_SUB ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(CR) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(CR * :credit_price) ||
                 '</td></tr>', '') WITHIN GROUP (ORDER BY SORT_RN)
    INTO :subtype_rows
    FROM (
        SELECT CASE WHEN RN <= :subtype_top_n THEN RN   ELSE 999999 END AS SORT_RN,
               CASE WHEN RN <= :subtype_top_n THEN TLBL ELSE 'Others' END AS GRP_TYPE,
               CASE WHEN RN <= :subtype_top_n THEN SUB  ELSE '(remaining subtypes)' END AS GRP_SUB,
               SUM(CR) AS CR
          FROM (SELECT TLBL, SUB, CR, ROW_NUMBER() OVER (ORDER BY CR DESC) AS RN
                  FROM (SELECT AI_USAGE_MONITORING.NOTIFICATIONS.METER_AI_LABEL(SERVICE_TYPE) AS TLBL,
                               COALESCE(NULLIF(NAME, ''), '—') AS SUB, SUM(CREDITS_USED) AS CR
                          FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
                         WHERE AI_USAGE_MONITORING.NOTIFICATIONS.IS_AI_SERVICE(SERVICE_TYPE)
                           AND CONVERT_TIMEZONE('UTC', START_TIME)::DATE BETWEEN :m_start AND :report_day
                         GROUP BY 1, 2))
         GROUP BY 1, 2, 3);

  --------------------------------------------------------------------------
  -- Last 7 days trend (billed, metering)
  --------------------------------------------------------------------------
  SELECT LISTAGG('<tr><td>' || TO_VARCHAR(DAY) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(CR) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(CR * :credit_price) ||
                 '</td></tr>', '') WITHIN GROUP (ORDER BY DAY DESC)
    INTO :daily_rows
    FROM (SELECT CONVERT_TIMEZONE('UTC', START_TIME)::DATE AS DAY, SUM(CREDITS_USED) AS CR
            FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
           WHERE AI_USAGE_MONITORING.NOTIFICATIONS.IS_AI_SERVICE(SERVICE_TYPE)
             AND CONVERT_TIMEZONE('UTC', START_TIME)::DATE BETWEEN :wk_start AND :report_day
           GROUP BY 1);

  --------------------------------------------------------------------------
  -- Drill-downs (union): by function, by model/agent, by user. Lag ~39h.
  --------------------------------------------------------------------------
  SELECT LISTAGG('<tr' || IFF(SORT_RN = 999999, ' style="font-style:italic;color:#666"', '') ||
                 '><td>' || GRP || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(CR) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(CR * :credit_price) ||
                 '</td></tr>', '') WITHIN GROUP (ORDER BY SORT_RN)
    INTO :fn_rows
    FROM (SELECT CASE WHEN RN <= :top_n THEN RN ELSE 999999 END AS SORT_RN,
                 CASE WHEN RN <= :top_n THEN GRP0 ELSE 'Others' END AS GRP, SUM(CR) AS CR
            FROM (SELECT COALESCE(FUNCTION_NAME, '(none)') AS GRP0, SUM(CREDITS) AS CR,
                         ROW_NUMBER() OVER (ORDER BY SUM(CREDITS) DESC) AS RN
                    FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
                   WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE BETWEEN :m_start AND :report_day
                   GROUP BY 1)
           GROUP BY 1, 2);

  SELECT LISTAGG('<tr' || IFF(SORT_RN = 999999, ' style="font-style:italic;color:#666"', '') ||
                 '><td>' || GRP || '</td><td>' || TYP ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(CR) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(CR * :credit_price) ||
                 '</td></tr>', '') WITHIN GROUP (ORDER BY SORT_RN)
    INTO :model_rows
    FROM (SELECT CASE WHEN RN <= :top_n THEN RN ELSE 999999 END AS SORT_RN,
                 CASE WHEN RN <= :top_n THEN GRP0 ELSE 'Others' END AS GRP,
                 CASE WHEN RN <= :top_n THEN TYP0 ELSE '' END AS TYP, SUM(CR) AS CR
            FROM (SELECT GRP0, TYP0, SUM(CR0) AS CR, ROW_NUMBER() OVER (ORDER BY SUM(CR0) DESC) AS RN
                    FROM (SELECT COALESCE(MODEL_NAME, AGENT_NAME, SERVICE) AS GRP0,
                                 CASE WHEN MODEL_NAME IS NOT NULL THEN 'Model'
                                      WHEN AGENT_NAME IS NOT NULL THEN 'Agent' ELSE 'Service' END AS TYP0,
                                 CREDITS AS CR0
                            FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
                           WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE BETWEEN :m_start AND :report_day)
                   GROUP BY 1, 2)
           GROUP BY 1, 2, 3);

  SELECT LISTAGG('<tr' || IFF(SORT_RN = 999999, ' style="font-style:italic;color:#666"', '') ||
                 '><td>' || GRP || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(CR) ||
                 '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(CR * :credit_price) ||
                 '</td></tr>', '') WITHIN GROUP (ORDER BY SORT_RN)
    INTO :user_rows
    FROM (SELECT CASE WHEN RN <= :top_n THEN RN ELSE 999999 END AS SORT_RN,
                 CASE WHEN RN <= :top_n THEN GRP0 ELSE 'Others' END AS GRP, SUM(CR) AS CR
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

  body :=
    '<html><body style="font-family:Arial,Helvetica,sans-serif;color:#222;font-size:14px;line-height:1.45">' ||
    '<h2 style="color:#29b5e8;font-size:22px;margin:0 0 2px 0">Snowflake AI Usage</h2>' ||
    '<p style="color:#666;margin:0 0 14px 0;font-size:13px">Daily Cortex AI summary · all dates UTC</p>' ||
    guard_banner ||

    -- Legend: two as-of dates
    '<div style="background:#f4f9fc;border:1px solid #d6e9f5;border-radius:6px;padding:10px 14px;margin:6px 0 10px 0;font-size:12px;color:#333">' ||
    '<div style="font-size:13px;font-weight:bold;margin-bottom:7px">How to read this report — two "as of" dates</div>' ||
    '<div style="margin:4px 0">' || badge_settled || '  Billed totals, AI by type and subtype — from the metering ledger (complete, foots to the invoice).</div>' ||
    '<div style="margin:4px 0">' || badge_detail  || '  Per model / function / user drill-downs — from Cortex detail views, which lag ~39h.</div>' ||
    '<div style="margin:7px 0 0 0;color:#555">$ = credits × your AI_CREDIT_PRICE_USD rate · dates UTC</div>' ||
    '</div>' ||

    -- ZONE: Billed (metering ledger)
    '<table width="100%" cellpadding="0" cellspacing="0" style="margin:26px 0 12px 0"><tr><td style="background:#1a6aa8;' || css_band || '">Billed (from the metering ledger)</td></tr></table>' ||

    '<h3 style="' || css_h3 || '">Latest settled day and month-to-date   ' || badge_settled || '</h3>' ||
    '<table ' || tbl || '>' ||
    '<tr ' || th || '><th align="left">Window</th><th align="right">Credits</th><th align="right">USD</th></tr>' ||
    '<tr><td>Latest settled day (' || TO_VARCHAR(:report_day) || ')</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(ai_cr_y) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(ai_usd_y) || '</td></tr>' ||
    '<tr><td>Month-to-date</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(ai_cr_m) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(ai_usd_m) || '</td></tr>' ||
    '</table>' ||

    budget_block ||

    '<h3 style="' || css_h3 || '">AI by type   ' || badge_settled || '</h3>' ||
    '<p style="' || css_note || '">From the billing/metering ledger — the authoritative AI total. Foots to the AI MTD figure above.</p>' ||
    CASE WHEN type_rows IS NULL THEN '<p><i>No AI activity.</i></p>'
         ELSE '<table ' || tbl || '><tr ' || th || '><th align="left">AI service type</th><th align="right">Credits</th><th align="right">USD</th></tr>' || type_rows ||
              '<tr style="font-weight:bold;border-top:2px solid #bbb"><td>Total</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(ai_cr_m) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(ai_usd_m) || '</td></tr></table>' END ||

    '<h3 style="' || css_h3 || '">AI by type and subtype   ' || badge_settled || '</h3>' ||
    '<p style="' || css_note || '">Subtype = the agent / app / service the credits were billed under (metering NAME). Top ' || TRIM(TO_VARCHAR(:subtype_top_n, '990')) || ' + Others; foots to the AI MTD total.</p>' ||
    CASE WHEN subtype_rows IS NULL THEN '<p><i>No AI activity.</i></p>'
         ELSE '<table ' || tbl || '><tr ' || th || '><th align="left">Type</th><th align="left">Subtype</th><th align="right">Credits</th><th align="right">USD</th></tr>' || subtype_rows ||
              '<tr style="font-weight:bold;border-top:2px solid #bbb"><td colspan="2">Total</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(ai_cr_m) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(ai_usd_m) || '</td></tr></table>' END ||

    -- ZONE: Detail (Cortex usage views, ~39h lag)
    '<table width="100%" cellpadding="0" cellspacing="0" style="margin:32px 0 12px 0"><tr><td style="background:#5d6d7e;' || css_band || '">Detail drill-downs (Cortex usage views)</td></tr></table>' ||
    '<p style="' || css_note || '">Model / function / user dimensions the billing ledger does not carry. These lag ~39h, so they total to <b>' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(u_ai_cr_m) || ' cr</b> — the settled-detail subset of the ' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR2(ai_cr_m) || ' cr billed AI MTD above.   ' || badge_detail || '</p>' ||

    '<h4 style="' || css_h4 || '">By function</h4>' ||
    CASE WHEN fn_rows IS NULL THEN '<p><i>No AI activity.</i></p>'
         ELSE '<table ' || tbl || '><tr ' || th || '><th align="left">Function</th><th align="right">Credits</th><th align="right">USD</th></tr>' || fn_rows ||
              '<tr style="font-weight:bold;border-top:2px solid #bbb"><td>Total (detail)</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(u_ai_cr_m) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(u_ai_usd_m) || '</td></tr></table>' END ||

    '<h4 style="' || css_h4 || '">By model / agent</h4>' ||
    '<p style="' || css_note || '">Snowflake reports the LLM model only for AI Functions; Agents and Intelligence report the agent / app name, and Cortex Code reports neither.</p>' ||
    CASE WHEN model_rows IS NULL THEN '<p><i>No AI activity.</i></p>'
         ELSE '<table ' || tbl || '><tr ' || th || '><th align="left">Name</th><th align="left">Type</th><th align="right">Credits</th><th align="right">USD</th></tr>' || model_rows ||
              '<tr style="font-weight:bold;border-top:2px solid #bbb"><td>Total (detail)</td><td></td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(u_ai_cr_m) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(u_ai_usd_m) || '</td></tr></table>' END ||

    '<h4 style="' || css_h4 || '">By user</h4>' ||
    CASE WHEN user_rows IS NULL THEN '<p><i>No AI activity.</i></p>'
         ELSE '<table ' || tbl || '><tr ' || th || '><th align="left">User</th><th align="right">Credits</th><th align="right">USD</th></tr>' || user_rows ||
              '<tr style="font-weight:bold;border-top:2px solid #bbb"><td>Total (detail)</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_CR(u_ai_cr_m) || '</td><td align="right">' || AI_USAGE_MONITORING.NOTIFICATIONS.FMT_USD(u_ai_usd_m) || '</td></tr></table>' END ||

    -- ZONE: Trend
    '<table width="100%" cellpadding="0" cellspacing="0" style="margin:32px 0 12px 0"><tr><td style="background:#148f77;' || css_band || '">Trend</td></tr></table>' ||
    '<h3 style="' || css_h3 || '">Last 7 days   ' || badge_settled || '</h3>' ||
    CASE WHEN daily_rows IS NULL THEN '<p><i>No AI activity.</i></p>'
         ELSE '<table ' || tbl || '><tr ' || th || '><th align="left">Day (UTC)</th><th align="right">Credits</th><th align="right">USD</th></tr>' || daily_rows || '</table>' END ||

    '<p style="color:#666;margin-top:30px;font-size:11px;border-top:1px solid #e5e5e5;padding-top:10px">' ||
    'Generated by AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL · billed AI from SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY · drill-downs from the Cortex usage views (~39h lag) · ' ||
    '$ at $' || TRIM(TO_VARCHAR(credit_price, '990.00')) || '/credit · dates UTC.</p>' ||
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
-- STEP 6: Daily scheduled task  (edit SCHEDULE for your time / timezone)
--   Examples: '0 8 * * * America/New_York'  -> 08:00 US Eastern
--             '30 7 * * 1-5 Europe/London'  -> 07:30 London, weekdays only
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TASK AI_USAGE_MONITORING.NOTIFICATIONS.TSK_DAILY_AI_USAGE_EMAIL
  SCHEDULE = 'USING CRON 0 8 * * * Asia/Kolkata'                  -- schedule
  USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
  COMMENT = 'Daily AI usage email'
AS
  CALL AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL(TRUE);

ALTER TASK AI_USAGE_MONITORING.NOTIFICATIONS.TSK_DAILY_AI_USAGE_EMAIL RESUME;


-- ============================================================================
-- DONE.  Next: preview, then send a test  (see 02_verify_and_test.sql)
--   Preview (no send):  CALL AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL(FALSE);
--   Send a test now:    CALL AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL(TRUE);
-- ============================================================================
