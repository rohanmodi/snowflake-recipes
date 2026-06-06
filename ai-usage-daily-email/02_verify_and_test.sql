-- ============================================================================
--  Snowflake AI Usage — Daily Email Framework :: VERIFY & TEST
--  Run these AFTER 01_ai_usage_email_setup.sql. Run as ACCOUNTADMIN.
-- ============================================================================
USE ROLE ACCOUNTADMIN;

-- 1) Does the unified AI view return data? (account-wide, all time)
SELECT COUNT(*) AS ROWS, ROUND(SUM(CREDITS), 2) AS TOTAL_CREDITS,
       MIN(USAGE_TIME) AS FIRST_SEEN, MAX(USAGE_TIME) AS LAST_SEEN
FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE;

-- 2) Sanity: month-to-date AI credits by service (UTC)
SELECT SERVICE, ROUND(SUM(CREDITS), 4) AS CREDITS, COUNT(DISTINCT USAGE_ID) AS QUERIES
FROM AI_USAGE_MONITORING.NOTIFICATIONS.VW_AI_USAGE
WHERE CONVERT_TIMEZONE('UTC', USAGE_TIME)::DATE
      >= DATE_TRUNC('MONTH', (CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()))::DATE)
GROUP BY SERVICE ORDER BY CREDITS DESC;

-- 3) Current settings
SELECT KEY, VALUE, DESCRIPTION FROM AI_USAGE_MONITORING.NOTIFICATIONS.CONFIG ORDER BY KEY;

-- 4) PREVIEW the email HTML without sending (copy the result into an .html file
--    and open it in a browser, or just eyeball it):
CALL AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL(FALSE);

-- 5) SEND a real test email now (goes to EMAIL_RECIPIENT):
-- CALL AI_USAGE_MONITORING.NOTIFICATIONS.SP_SEND_AI_USAGE_EMAIL(TRUE);

-- 6) Task status + recent runs
SHOW TASKS LIKE 'TSK_DAILY_AI_USAGE_EMAIL' IN SCHEMA AI_USAGE_MONITORING.NOTIFICATIONS;
SELECT NAME, STATE, SCHEDULED_TIME, ERROR_CODE, ERROR_MESSAGE, RETURN_VALUE
FROM TABLE(AI_USAGE_MONITORING.INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME => 'TSK_DAILY_AI_USAGE_EMAIL',
        SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP())))
ORDER BY SCHEDULED_TIME DESC;

-- ----------------------------------------------------------------------------
-- COMMON CHANGES (no redeploy needed — just UPDATE the CONFIG table)
-- ----------------------------------------------------------------------------
-- Change the $/credit rate:
-- UPDATE AI_USAGE_MONITORING.NOTIFICATIONS.CONFIG SET VALUE='2.00' WHERE KEY='AI_CREDIT_PRICE_USD';
-- Change the monthly AI budget (0 hides the budget block):
-- UPDATE AI_USAGE_MONITORING.NOTIFICATIONS.CONFIG SET VALUE='250' WHERE KEY='AI_BUDGET_CREDITS';
-- Change the recipient (must ALSO be added to the integration — see below):
-- UPDATE AI_USAGE_MONITORING.NOTIFICATIONS.CONFIG SET VALUE='ops@example.com' WHERE KEY='EMAIL_RECIPIENT';
-- ALTER NOTIFICATION INTEGRATION AI_USAGE_EMAIL_INT SET ALLOWED_RECIPIENTS=('ops@example.com');

-- Change the SCHEDULE (this one is on the task, not the config table):
-- ALTER TASK AI_USAGE_MONITORING.NOTIFICATIONS.TSK_DAILY_AI_USAGE_EMAIL SUSPEND;
-- ALTER TASK AI_USAGE_MONITORING.NOTIFICATIONS.TSK_DAILY_AI_USAGE_EMAIL
--   SET SCHEDULE = 'USING CRON 0 9 * * 1-5 America/New_York';   -- 9 AM ET, weekdays
-- ALTER TASK AI_USAGE_MONITORING.NOTIFICATIONS.TSK_DAILY_AI_USAGE_EMAIL RESUME;
