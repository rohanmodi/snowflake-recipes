---
name: query-model
description: "Query a built dbt model to preview data or validate results. Use when: user wants to see data, preview a model, check output, query a table, select from model, show me the data, verify results, sample rows."
---

# Query Model

## Workflow

### Step 1: Identify model

Determine which model to query. Built models live in `COCO_DEMO.DBT_TPCH`:

| Model | Object |
|-------|--------|
| stg_customers | `COCO_DEMO.DBT_TPCH.STG_CUSTOMERS` (view) |
| stg_orders | `COCO_DEMO.DBT_TPCH.STG_ORDERS` (view) |
| stg_lineitem | `COCO_DEMO.DBT_TPCH.STG_LINEITEM` (view) |
| dim_customers | `COCO_DEMO.DBT_TPCH.DIM_CUSTOMERS` (table) |
| fct_orders | `COCO_DEMO.DBT_TPCH.FCT_ORDERS` (table) |

### Step 2: Execute query

Use `snowflake_sql_execute` to run queries against the model. Common patterns:

**Preview rows:**
```sql
SELECT * FROM COCO_DEMO.DBT_TPCH.<MODEL_NAME> LIMIT 10;
```

**Row count:**
```sql
SELECT COUNT(*) AS row_count FROM COCO_DEMO.DBT_TPCH.<MODEL_NAME>;
```

**Custom aggregation:**
```sql
SELECT <columns>, COUNT(*), SUM(<metric>)
FROM COCO_DEMO.DBT_TPCH.<MODEL_NAME>
GROUP BY <columns>
ORDER BY <metric> DESC
LIMIT 20;
```

### Step 3: Present results

Format output clearly. If user wants deeper analysis, suggest additional queries or a chart visualization.

## Notes

- If a model hasn't been built yet, run `dbt-build` skill first
- Staging models are views (query directly hits source data)
- Mart models are tables (pre-computed, fast to query)
