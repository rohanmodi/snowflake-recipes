-- ============================================================
-- CoWork Sales Analytics Agent — Teardown
-- Removes all objects created by 01_setup.sql and
-- 02_semantic_view_and_agent.sql.
--
-- NOTE: The Cortex Agent must be deleted manually in the
-- Snowsight UI (AI Studio → Agents → delete the agent)
-- before or after running this script.
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- Drop database (cascades schema, tables, semantic view, stage)
DROP DATABASE IF EXISTS COWORK_DEMO_DB;

-- Drop warehouse
DROP WAREHOUSE IF EXISTS COWORK_DEMO_WH;
