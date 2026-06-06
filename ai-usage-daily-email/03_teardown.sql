-- ============================================================================
--  Snowflake AI Usage — Daily Email Framework :: TEARDOWN
--  Removes everything 01_ai_usage_email_setup.sql created. Safe to run even if
--  nothing exists (idempotent).
--  (If you renamed the database, find-replace AI_USAGE_MONITORING / the
--   integration name below to match.)
-- ============================================================================
USE ROLE ACCOUNTADMIN;

-- Dropping the database cascades the schema, view, config, helper functions,
-- the procedure, AND the task (running or not) in one shot.
DROP DATABASE    IF EXISTS AI_USAGE_MONITORING;

-- The email integration is account-level, so drop it separately.
DROP INTEGRATION IF EXISTS AI_USAGE_EMAIL_INT;
