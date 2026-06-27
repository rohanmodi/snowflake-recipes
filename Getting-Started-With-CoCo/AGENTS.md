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

## Skills

This project includes custom CoCo skills in `.cortex/skills/` to accelerate common dbt workflows.
Invoke them by name (`/dbt-build`, `/add-model`, etc.) or let CoCo auto-trigger them from your request.

| Skill | When to use |
|-------|-------------|
| **dbt-build** | Run the pipeline (`dbt deps` + `dbt build`), diagnose failures, re-run after fixes. Use any time you say "build", "run dbt", "test models", or "refresh". |
| **add-model** | Scaffold a new staging view or mart table with correct naming, schema YAML, and baseline tests. Use when you want to add a dimension, fact table, or staging view. |
| **add-test** | Add data quality tests (unique, not_null, accepted_values, relationships) to an existing model's schema YAML. Use when you say "add tests" or "validate column". |
| **query-model** | Preview data from a built model via SQL. Use when you want to see rows, check counts, or run ad-hoc queries against `COCO_DEMO.DBT_TPCH`. |

## Project Layout

```
Getting-Started-With-CoCo/
├── AGENTS.md              ← you are here (CoCo project definition)
├── README.md              ← human-readable project overview
├── .cortex/
│   └── skills/            ← CoCo skills for dbt workflows
│       ├── dbt-build/SKILL.md
│       ├── add-model/SKILL.md
│       ├── add-test/SKILL.md
│       └── query-model/SKILL.md
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
