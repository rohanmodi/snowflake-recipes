# Getting Started with CoCo — dbt on Snowflake TPC-H Pipeline

## Purpose

This is a **getting-started CoCo project** that builds and maintains a dbt-on-Snowflake
data pipeline. It transforms the TPC-H benchmark dataset (`SNOWFLAKE_SAMPLE_DATA.TPCH_SF1`)
into a clean analytics layer of staging views and mart tables.

Use this project to learn how Cortex Code (CoCo) assists with dbt development: writing
models, running builds, debugging test failures, and iterating on transformations — all
from a conversational interface.

## Agent Role and Operating Conventions

When working in this project, the agent follows these rules:

- **Connection:** Use the user's dbt profile (`coco_demo` profile in `~/.dbt/profiles.yml`).
- **Sources are READ-ONLY.** Never modify `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1`.
- **Outputs only to `COCO_DEMO.DBT_TPCH`.** Do not create objects in any other database or schema.
- **Least privilege.** Assume `SYSADMIN` or equivalent — no `ACCOUNTADMIN` required.
- **Never commit secrets.** Credentials live in `~/.dbt/profiles.yml`, never in this repo.
- **Materializations:** staging models = `view`; mart models = `table`.
- **Build command:** always run `dbt deps` (once) then `dbt build` from the `dbt_tpch/` directory.
- **Tests must pass.** Every `dbt build` must end with zero failures before considering work complete.
- **No destructive operations** on objects outside `COCO_DEMO`.

## Project Layout

```
Getting-Started-With-CoCo/
├── AGENTS.md              ← you are here (CoCo project definition)
├── README.md              ← human-readable project overview
└── dbt_tpch/              ← the dbt project
    ├── dbt_project.yml
    ├── packages.yml
    ├── profiles.yml.example
    ├── .gitignore
    └── models/
        ├── staging/       ← views over TPCH source tables
        │   ├── _sources.yml
        │   ├── _staging.yml
        │   ├── stg_customers.sql
        │   ├── stg_orders.sql
        │   └── stg_lineitem.sql
        └── marts/         ← tables with business logic
            ├── _marts.yml
            ├── dim_customers.sql
            └── fct_orders.sql
```

## Get Started in CoCo

1. **Open this folder** in Cortex Code (CoCo reads `AGENTS.md` to understand the project).

2. **Set up your profile** — copy the template and fill in your Snowflake credentials:
   ```bash
   cp dbt_tpch/profiles.yml.example ~/.dbt/profiles.yml
   # Edit ~/.dbt/profiles.yml with your account, user, role, warehouse
   ```

3. **Create the target database** (one-time):
   ```sql
   USE ROLE SYSADMIN;
   CREATE DATABASE IF NOT EXISTS COCO_DEMO;
   CREATE SCHEMA IF NOT EXISTS COCO_DEMO.DBT_TPCH;
   ```

4. **Ask CoCo to build the pipeline:**
   > "Run dbt build for this project"

   Or run manually:
   ```bash
   cd dbt_tpch
   dbt deps
   dbt build
   ```

5. **Iterate** — ask CoCo to add models, fix tests, or extend the pipeline. It will
   follow the conventions above automatically.
