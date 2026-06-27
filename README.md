# Snowflake Recipes

Practical, **self-contained** recipes for Snowflake — SQL and native automation
you can drop into any account. Each recipe is independent and parameterized, with
its own README and `setup` / `verify` / `teardown` scripts. No external tools.

## Recipes

| Recipe | What it does |
|---|---|
| [**ai-usage-daily-email**](ai-usage-daily-email/) | A daily email summarizing your **Cortex AI** usage — credits, $, an optional budget tracker, and month-to-date breakdowns by service, function, model/agent, and **user**. Built entirely from `ACCOUNT_USAGE` + an email notification integration + a scheduled task. |
| [**Getting-Started-With-CoCo**](Getting-Started-With-CoCo/) | A **Cortex Code (CoCo) project** that builds a dbt-on-Snowflake data pipeline over TPC-H. Includes `AGENTS.md`, staging views, mart tables, schema tests, and a docs folder — designed to teach beginners how to use CoCo for dbt development. |

_More recipes coming — cost dashboards, budget alerts, and other Snowflake utilities._

## How to use

Each recipe folder is standalone:

1. Open the recipe's `README.md`.
2. Edit the clearly-marked parameters (recipient, schedule, etc.).
3. Run the setup script as `ACCOUNTADMIN` (or a role with the documented privileges).
4. Use the verify script to preview/test; the teardown script removes everything.

## Conventions

- `NN_*.sql` files are meant to be run in order.
- Parameters you must change are flagged inline (🔧) and listed in each README.
- Runtime-tunable settings live in a `CONFIG` table you can `UPDATE` without redeploying.
- Dates are computed in **UTC** to match the grain of `ACCOUNT_USAGE`.

## License

[MIT](LICENSE) — use it, fork it, ship it.

---

Built and battle-tested against a live Snowflake account. If a recipe helps you,
a ⭐ is appreciated.
