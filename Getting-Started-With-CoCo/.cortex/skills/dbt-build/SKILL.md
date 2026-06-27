---
name: dbt-build
description: "Run dbt deps and dbt build for this TPC-H pipeline. Use when: user says build, run dbt, compile, test models, run pipeline, refresh models, dbt build, run the project. Invoke this skill for ANY request to execute or test the dbt pipeline."
---

# dbt Build

## Workflow

### Step 1: Run dbt deps (once per session)

```bash
cd <PROJECT_ROOT>/dbt_tpch && dbt deps
```

If deps fails, check that `packages.yml` exists and network access is available.

### Step 2: Run dbt build

```bash
cd <PROJECT_ROOT>/dbt_tpch && dbt build
```

### Step 3: Interpret results

**If all pass:** Report success with model/test counts.

**If tests fail:**
1. Identify failing tests from output
2. Run the failing test SQL directly to inspect bad rows:
   ```bash
   cd <PROJECT_ROOT>/dbt_tpch && dbt test --select <model_name>
   ```
3. Present findings to user with suggested fix
4. After fix, re-run `dbt build` to confirm zero failures

**If compilation fails:**
- Check for Jinja syntax errors or missing refs
- Verify source/ref names match `_sources.yml`

### Step 4: Selective builds (optional)

For targeted runs:
```bash
dbt build --select <model_name>        # single model + tests
dbt build --select +<model_name>       # model + upstream deps
dbt build --select <model_name>+       # model + downstream
```

## Success Criteria

- Zero test failures
- All models compiled and materialized
- Output target: `COCO_DEMO.DBT_TPCH`

## Stopping Points

- After build failure (present error + proposed fix before retrying)
