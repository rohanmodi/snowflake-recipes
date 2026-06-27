# Getting Started with CoCo — dbt on Snowflake

A **Cortex Code (CoCo) project** that teaches you how to build and maintain a
dbt-on-Snowflake data pipeline using an AI coding assistant. It transforms the
TPC-H benchmark dataset into a clean analytics layer — staging views and mart
tables — inside a dedicated `COCO_DEMO` database.

---

## This is a CoCo Project

This folder is structured as a **CoCo project**:

| Path | Purpose |
|---|---|
| `AGENTS.md` | Project definition for Cortex Code — role, conventions, guardrails |
| `dbt_tpch/` | The dbt project (models, tests, config) |
| `README.md` | This file — human-readable overview |

Open this folder in **Cortex Code** and it will read `AGENTS.md` to understand how
to operate: where the source data lives, what database to write to, which commands
to run, and what safety rules to follow.

---

## Architecture

```
 SNOWFLAKE_SAMPLE_DATA.TPCH_SF1          COCO_DEMO.DBT_TPCH
 ┌───────────────────────────┐           ┌──────────────────────────────┐
 │  CUSTOMER                 │──source──▶│  stg_customers (view)        │─┐
 │  ORDERS                   │──source──▶│  stg_orders    (view)        │─┼─▶ fct_orders    (table)
 │  LINEITEM                 │──source──▶│  stg_lineitem  (view)        │─┘         │
 └───────────────────────────┘           │                              │            │
                                         │  dim_customers (table) ◀─────┼────────────┘
                                         └──────────────────────────────┘
```

---

## Prerequisites

| Requirement | Details |
|---|---|
| Snowflake account | With `SNOWFLAKE_SAMPLE_DATA` share (included by default) |
| Cortex Code | Desktop IDE or browser-based |
| Role | `SYSADMIN` or any role with `CREATE DATABASE` |
| Warehouse | Any active warehouse (e.g. `COMPUTE_WH`) |
| dbt-core + dbt-snowflake | `pip install dbt-snowflake` |
| Python | 3.9+ |

---

## Quick Start

### 1. Create the target database

```sql
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS COCO_DEMO;
CREATE SCHEMA IF NOT EXISTS COCO_DEMO.DBT_TPCH;
```

### 2. Configure your dbt profile

```bash
cp dbt_tpch/profiles.yml.example ~/.dbt/profiles.yml
# Edit ~/.dbt/profiles.yml — fill in account, user, role, warehouse
```

### 3. Build the pipeline

```bash
cd dbt_tpch
dbt deps
dbt build
```

Or simply ask CoCo: **"Run dbt build for this project"**

---

## What Gets Created

All objects land in `COCO_DEMO.DBT_TPCH`:

| Model | Type | Description |
|---|---|---|
| `stg_customers` | view | Cleaned customer dimension |
| `stg_orders` | view | Cleaned order headers |
| `stg_lineitem` | view | Cleaned line items |
| `fct_orders` | table | Order-grain fact with revenue and line item count |
| `dim_customers` | table | Customer dimension with order aggregates |

---

## Teardown

```sql
DROP DATABASE IF EXISTS COCO_DEMO;
```

---

## Next Steps

- Ask CoCo to add `stg_nation` and `stg_region` models
- Convert `fct_orders` to an incremental model
- Run `dbt docs generate && dbt docs serve` for a documentation site
- Deploy to Snowflake natively with `snow dbt deploy`
