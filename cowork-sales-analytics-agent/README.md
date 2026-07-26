# CoWork Sales Analytics Agent

Build a **conversational AI sales analyst** using Snowflake CoWork, Semantic
Views, and Cortex Agents — entirely inside Snowflake, no external infrastructure.

**CoWork** (GA: June 2, 2026) is Snowflake's personal AI work agent that lives
inside Snowsight at [ai.snowflake.com](https://ai.snowflake.com). It reasons
through multi-step tasks, writes and executes SQL, builds shareable artifacts,
remembers context across sessions, and respects your existing RBAC — all without
leaving Snowflake's governance perimeter.

---

## What this recipe builds

A Cortex Agent backed by a **Semantic View** over four SaaS sales tables
(customers, deals, monthly revenue, support tickets). Once published and added to
CoWork, business users can ask natural-language questions like:

- *"What is our total pipeline value by deal stage?"*
- *"Which customers have the lowest health scores and highest ticket volume?"*
- *"Show MRR trends by product line for the last 6 months"*

The agent generates SQL, executes it, and returns formatted insights — with
charts you can save as **Artifacts** (GA: June 17, 2026) and share with your
team.

---

## Architecture

```
Sample Data (4 tables)
  └─► Semantic View  (SALES_ANALYTICS_VIEW)
        └─► Cortex Agent  (SALES_ANALYTICS_AGENT)
              └─► CoWork UI  (ai.snowflake.com)
                    └─► Artifacts  (save & share charts/tables)
```

---

## Prerequisites

- Snowflake **Enterprise** edition (or higher)
- `ACCOUNTADMIN` role (or a role with `CREATE DATABASE`, `CREATE WAREHOUSE`, and
  `CORTEX_USER` privileges)
- CoWork enabled on your account (GA for all Enterprise+ accounts since June 2,
  2026)

---

## Quick start

### 1. Create the data

Open `01_setup.sql` in a Snowsight worksheet (or the Snowflake CLI) and run it.
It creates:

| Object | What |
|---|---|
| `COWORK_DEMO_DB` | Dedicated demo database |
| `COWORK_DEMO_DB.SALES_ANALYTICS` | Schema for all objects |
| `COWORK_DEMO_WH` | X-Small warehouse (auto-suspend 60s) |
| `CUSTOMERS` | 30 fictional SaaS companies |
| `DEALS` | 35 deals across 5 pipeline stages |
| `MONTHLY_REVENUE` | ~540 rows of MRR over 18 months |
| `SUPPORT_TICKETS` | 20 realistic support interactions |

### 2. Create the Semantic View

Run `02_semantic_view_and_agent.sql`. This creates `SALES_ANALYTICS_VIEW` — a
first-class Snowflake object that tells the AI engine:

- Which tables exist and how they're keyed
- How tables relate to each other (foreign keys)
- Which columns are **facts** (measures) vs. **dimensions** (attributes)
- Named **metrics** (aggregations like `total_pipeline_value`, `won_deals`)

> **Why Semantic Views?** They replace the older YAML-on-stage approach. Semantic
> Views are governed SQL objects, visible in `SHOW SEMANTIC VIEWS`, and they
> encode business logic (metrics, relationships) that the AI references by name.

### 3. Create the Cortex Agent (UI)

The Cortex Agent is created in the Snowsight UI — see the detailed instructions
in the comments at the bottom of `02_semantic_view_and_agent.sql`. Summary:

1. **Snowsight → AI Studio → Agents → + Agent**
2. Set name to `SALES_ANALYTICS_AGENT`, database/schema to
   `COWORK_DEMO_DB.SALES_ANALYTICS`
3. Add the semantic view as a tool
4. Add orchestration and response instructions (provided in the SQL file)
5. **Publish** the agent
6. **+ Add to Snowflake CoWork**

### 4. Chat with your agent

Go to [ai.snowflake.com](https://ai.snowflake.com) → **Capabilities** →
**Agents** → select **SALES_ANALYTICS_AGENT** → start chatting.

### 5. Save & share Artifacts

When the agent returns a chart or table you want to keep:

1. Click the **bookmark icon** on the response to save it as an Artifact
2. Go to the **Artifacts hub** (sidebar) to see all saved artifacts
3. Share via link — recipients see data filtered through **their own RBAC**
4. Artifacts auto-refresh after 12 hours

---

## Teardown

1. Delete the Cortex Agent in **Snowsight → AI Studio → Agents**
2. Run `03_teardown.sql` to drop the database and warehouse

---

## Files

| File | Purpose |
|---|---|
| `01_setup.sql` | Database, warehouse, schema, 4 tables + sample data |
| `02_semantic_view_and_agent.sql` | Semantic View + agent creation instructions |
| `03_teardown.sql` | Drop everything |

---

## Parameters

| Parameter | Where | Default | Notes |
|---|---|---|---|
| Warehouse name | `01_setup.sql` | `COWORK_DEMO_WH` | 🔧 Change if you want a different name |
| Warehouse size | `01_setup.sql` | `X-SMALL` | Scale up for larger datasets |
| Cross-region inference | `01_setup.sql` | `ANY_REGION` | Required for CoWork / Cortex |

---

## Companion article

For a full walkthrough with screenshots, architecture diagrams, and the Artifacts
demo, see the Medium article:
[Building a SaaS Sales Analytics Agent with Snowflake CoWork](https://medium.com/@rohanmodi)
