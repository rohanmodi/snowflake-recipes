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
| `.cortex/skills/` | Custom CoCo skills for common dbt workflows |
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

## Prerequisites & Dependencies

### System requirements

| Tool | Version | Install |
|------|---------|---------|
| Python | 3.9+ | [python.org](https://www.python.org/downloads/) or `brew install python` |
| pip | latest | Comes with Python; upgrade with `pip install --upgrade pip` |
| dbt-core | 1.7+ | Installed via `dbt-snowflake` (see below) |
| dbt-snowflake | 1.7+ | `pip install dbt-snowflake` |
| Git | any | For cloning this repo |

### Python packages

Install in one command:

```bash
pip install dbt-snowflake
```

This installs both `dbt-core` and the Snowflake adapter. The project also uses:

| dbt Package | Version | Purpose | Installed by |
|-------------|---------|---------|--------------|
| `dbt-labs/dbt_utils` | >=1.0.0, <2.0.0 | Utility macros (surrogate keys, testing helpers) | `dbt deps` |

### Snowflake requirements

| Requirement | Details |
|---|---|
| Snowflake account | With `SNOWFLAKE_SAMPLE_DATA` share (included by default on all accounts) |
| Role | `SYSADMIN` or any role with `CREATE DATABASE` / `CREATE SCHEMA` |
| Warehouse | Any active warehouse (e.g. `COMPUTE_WH`) |
| Authentication | Password, key-pair, or SSO (`externalbrowser`) |

### Optional (recommended)

| Tool | Purpose | Install |
|------|---------|---------|
| Cortex Code (CoCo) | AI assistant for dbt development | [Cortex Code Desktop](https://docs.snowflake.com/en/user-guide/cortex-code/) |
| SnowCLI | Deploy dbt project natively to Snowflake | `pip install snowflake-cli` |

---

## Quick Start

### 1. Install dependencies

```bash
# Create a virtual environment (recommended)
python -m venv .venv
source .venv/bin/activate    # macOS/Linux
# .venv\Scripts\activate     # Windows

# Install dbt with Snowflake adapter
pip install dbt-snowflake
```

Verify installation:
```bash
dbt --version
# Should show dbt-core 1.7+ and dbt-snowflake 1.7+
```

### 2. Configure your dbt profile

```bash
cp dbt_tpch/profiles.yml.example ~/.dbt/profiles.yml
# Edit ~/.dbt/profiles.yml — fill in account, user, role, warehouse
```

Your `~/.dbt/profiles.yml` needs these values:

| Field | Example |
|-------|---------|
| `account` | `abc12345.us-east-1` |
| `user` | `JSMITH` |
| `password` | your password (or use `authenticator: externalbrowser` for SSO) |
| `role` | `SYSADMIN` |
| `warehouse` | `COMPUTE_WH` |

### 3. Create the target database

```sql
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS COCO_DEMO;
CREATE SCHEMA IF NOT EXISTS COCO_DEMO.DBT_TPCH;
```

### 4. Build the pipeline

```bash
cd dbt_tpch
dbt deps    # installs dbt_utils package
dbt build   # compiles models, runs tests
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

## Project Layout

```
Getting-Started-With-CoCo/
├── AGENTS.md                         ← CoCo project definition
├── README.md                         ← this file
├── .cortex/
│   └── skills/                       ← CoCo skills for dbt workflows
│       ├── dbt-build/SKILL.md        ← run dbt deps + dbt build
│       ├── add-model/SKILL.md        ← scaffold new models
│       ├── add-test/SKILL.md         ← add data quality tests
│       └── query-model/SKILL.md      ← preview built model data
└── dbt_tpch/                         ← the dbt project
    ├── dbt_project.yml               ← project config
    ├── packages.yml                  ← dbt package dependencies
    ├── profiles.yml.example          ← profile template (copy to ~/.dbt/)
    ├── .gitignore
    └── models/
        ├── staging/                  ← views over TPC-H source tables
        │   ├── _sources.yml
        │   ├── _staging.yml
        │   ├── stg_customers.sql
        │   ├── stg_orders.sql
        │   └── stg_lineitem.sql
        └── marts/                    ← tables with business logic
            ├── _marts.yml
            ├── dim_customers.sql
            └── fct_orders.sql
```

---

## CoCo Skills

When working in Cortex Code, these project skills are available:

| Skill | Trigger phrases | What it does |
|-------|----------------|--------------|
| `/dbt-build` | "build", "run dbt", "test models" | Runs `dbt deps` + `dbt build`, diagnoses failures |
| `/add-model` | "add model", "new staging view", "new fact table" | Scaffolds model + schema YAML + baseline tests |
| `/add-test` | "add tests", "validate column" | Adds tests to existing model schema |
| `/query-model` | "show data", "preview model", "query results" | Runs SQL against built models |

---

## Teardown

```sql
DROP DATABASE IF EXISTS COCO_DEMO;
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `dbt command not found` | Activate your venv: `source .venv/bin/activate` |
| `Database 'COCO_DEMO' does not exist` | Run the CREATE DATABASE step above |
| `Authentication failed` | Check credentials in `~/.dbt/profiles.yml` |
| `SNOWFLAKE_SAMPLE_DATA not found` | This share is auto-provisioned; contact your admin if missing |
| `dbt deps` fails | Check internet access; the package downloads from hub.getdbt.com |

---

## Next Steps

- Ask CoCo to add `stg_nation` and `stg_region` models
- Convert `fct_orders` to an incremental model
- Run `dbt docs generate && dbt docs serve` for a documentation site
- Deploy to Snowflake natively with `snow dbt deploy`
