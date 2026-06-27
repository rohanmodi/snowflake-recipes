---
name: add-model
description: "Scaffold a new dbt model (staging view or mart table) for this TPC-H pipeline. Use when: user wants to add a model, create a new model, add a staging view, add a mart table, add a dimension, add a fact table, new transformation, model a table."
---

# Add Model

## Workflow

### Step 1: Determine model type

Ask the user:
- **Staging model** — thin renaming view over a TPC-H source table (materialized as view)
- **Mart model** — business logic combining staging models (materialized as table)

### Step 2: Gather details

**For staging:**
- Which source table? Currently in `_sources.yml`: CUSTOMER, ORDERS, LINEITEM
- Other TPC-H tables available (add to `_sources.yml` first): PART, SUPPLIER, PARTSUPP, NATION, REGION

**For mart:**
- Business purpose (e.g., "revenue by nation", "supplier performance")
- Which staging models to reference

### Step 3: Create the model file

**Staging convention** (`models/staging/stg_<plural_noun>.sql`):
```sql
with source as (
    select * from {{ source('tpch', '<TABLE_NAME>') }}
)

select
    <original_col> as <clean_name>,
    ...
from source
```

**Mart convention** (`models/marts/<dim|fct>_<name>.sql`):
```sql
with <cte_name> as (
    select * from {{ ref('stg_<name>') }}
),
...
select
    ...
from <cte>
```

### Step 4: Add schema entry

- Staging: add to `models/staging/_staging.yml`
- Mart: add to `models/marts/_marts.yml`

Include at minimum:
- model name
- description
- `not_null` + `unique` tests on the primary key column

### Step 5: Build and verify

Run dbt build (invoke `dbt-build` skill) to confirm the new model compiles and passes tests.

## File Paths

| Type | Directory | Naming |
|------|-----------|--------|
| Staging | `dbt_tpch/models/staging/` | `stg_<plural>.sql` |
| Mart dim | `dbt_tpch/models/marts/` | `dim_<name>.sql` |
| Mart fact | `dbt_tpch/models/marts/` | `fct_<name>.sql` |

## Stopping Points

- After Step 2 (confirm scope with user before writing files)
- After Step 4 (show user the schema YAML entry before building)
