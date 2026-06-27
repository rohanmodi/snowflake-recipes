---
name: add-test
description: "Add dbt tests to existing models. Use when: user wants to add tests, add data quality checks, validate a column, add uniqueness check, add not-null test, add accepted values, add relationship test, test my model."
---

# Add Test

## Workflow

### Step 1: Identify target model

Ask which model to add tests to. Read its current schema YAML to see existing tests.

- Staging schemas: `dbt_tpch/models/staging/_staging.yml`
- Mart schemas: `dbt_tpch/models/marts/_marts.yml`

### Step 2: Determine test type

Available dbt test types:

| Test | Purpose | Example |
|------|---------|---------|
| `unique` | No duplicate values | Primary keys |
| `not_null` | No NULL values | Required fields |
| `accepted_values` | Column only has known values | Status codes, flags |
| `relationships` | FK exists in another model | `customer_key` exists in `stg_customers` |

### Step 3: Add tests to schema YAML

Append under the model's `columns:` section:

```yaml
columns:
  - name: <column_name>
    description: "<description>"
    tests:
      - unique
      - not_null
      - accepted_values:
          values: ['A', 'B', 'C']
      - relationships:
          to: ref('<other_model>')
          field: <pk_column>
```

### Step 4: Run tests

```bash
cd <PROJECT_ROOT>/dbt_tpch && dbt test --select <model_name>
```

If failures appear, present the failing rows and suggest whether it's a data issue or a test that needs adjusting.

## Stopping Points

- After Step 2 (confirm which tests to add before editing YAML)
- After Step 4 if tests fail (explain findings before changing anything)
