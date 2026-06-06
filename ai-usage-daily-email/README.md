# Snowflake AI Usage — Daily Email Notification Framework

A small, **self-contained** framework that emails you a daily summary of your
Snowflake **Cortex AI** usage — credits, dollars, budget, and breakdowns by
service, function, model, and **user** — using nothing but standard
`SNOWFLAKE.ACCOUNT_USAGE` data and native Snowflake features (a view, a stored
procedure, an email notification integration, and a scheduled task).

No external tools, no warehouses to babysit, no third-party services. Deploy it
once and a report lands in your inbox every morning.

---

## What the email looks like

<p align="center">
  <img src="sample_email_redacted.png" alt="Sample daily Cortex AI usage email" width="420">
</p>

<sub>Real run against a live account; user emails and internal agent names redacted.</sub>

```
Snowflake AI Usage — Fri 2026-06-05 — 8.09 credits ($24.27)      <- subject

Snowflake AI Usage
Daily Cortex AI summary for Fri, 05 Jun 2026 (UTC)

Window          Credits     USD     Queries
Yesterday          8.09   $24.27         59
Month-to-date     58.92  $176.77        781

AI budget (month-to-date)
58.92 / 100.00 credits used — 58.9% [OK]

Last 7 days …
By service (MTD)  …  CORTEX_CODE_SNOWSIGHT, CORTEX_AGENTS, AI_FUNCTIONS …
By function (MTD) …
By model / agent  …  with a Type column (Model / Agent / Service) — see note below
By user (MTD)     …  who is spending the AI credits
```

Every breakdown table **foots to the month-to-date total**, and the "by user"
table attributes credits to the actual Snowflake user who ran each request.

---

## How it works

```
 SNOWFLAKE.ACCOUNT_USAGE                      AI_USAGE_MONITORING.NOTIFICATIONS
 ┌─────────────────────────────┐              ┌────────────────────────────────┐
 │ CORTEX_AI_FUNCTIONS_USAGE_…  │              │ VW_AI_USAGE  (unified view)     │
 │ CORTEX_AGENT_USAGE_HISTORY   │ ──────────▶  │   one row per AI request,        │
 │ CORTEX_CODE_CLI_USAGE_…      │   union +    │   USER_NAME resolved             │
 │ CORTEX_CODE_SNOWSIGHT_…      │   user join  │                                  │
 │ SNOWFLAKE_INTELLIGENCE_…     │              │ CONFIG (settings)                │
 │ USERS  (USER_ID → name)      │              │ SP_SEND_AI_USAGE_EMAIL (proc)    │
 └─────────────────────────────┘              │ TSK_DAILY_AI_USAGE_EMAIL (task)  │
                                              └───────────────┬────────────────┘
                                  SYSTEM$SEND_EMAIL via       │  08:00 daily
                                  AI_USAGE_EMAIL_INT  ◀───────┘  (your schedule)
                                              │
                                              ▼   📧  your inbox
```

- **`VW_AI_USAGE`** unifies the five Cortex usage views into one row-per-request
  shape and resolves `USER_NAME` (directly where present, otherwise via
  `ACCOUNT_USAGE.USERS`).
- **`SP_SEND_AI_USAGE_EMAIL(BOOLEAN)`** builds the HTML. `TRUE` sends it; `FALSE`
  returns the HTML so you can preview without sending.
- **Dates are computed in UTC** to match the daily grain of `ACCOUNT_USAGE` and
  to stay independent of your task's schedule timezone.
- **Dollars** are `credits × AI_CREDIT_PRICE_USD` (a single rate you configure).

---

## Prerequisites

- A role that can create the objects and read account usage. **`ACCOUNTADMIN`
  is simplest.** Specifically you need: `CREATE DATABASE`, `CREATE INTEGRATION`,
  `EXECUTE TASK`, and read access to `SNOWFLAKE.ACCOUNT_USAGE` (the
  `ACCOUNTADMIN` chain has the required `IMPORTED PRIVILEGES`).
- The procedure runs `EXECUTE AS OWNER`, so whoever creates it must retain
  `ACCOUNT_USAGE` access — keep it owned by an admin role.
- **A verified recipient email.** Snowflake only sends to addresses that belong
  to a user in your account or have been verified. The email of an existing
  Snowflake user is auto-verified.

---

## Quick start (3 steps)

1. **Edit the parameters** in `01_ai_usage_email_setup.sql` (see the table
   below) — at minimum the recipient and, if you don't want 08:00 IST, the
   schedule.
2. **Run `01_ai_usage_email_setup.sql`** in a Snowsight worksheet (or via the
   Snowflake CLI) as `ACCOUNTADMIN`. It creates everything and resumes the task.
3. **Verify** with `02_verify_and_test.sql` — preview the HTML, then send
   yourself a test.

That's it. The email goes out on your schedule from then on.

---

## Parameters

| Parameter | Where | Default | Notes |
|---|---|---|---|
| **Recipient email** | `01_…setup.sql` (integration + config) — token `you@example.com` | — | Must be verified / an account user's email. Appears **twice**; replace both. |
| **Schedule** | `01_…setup.sql` task `SCHEDULE` | `USING CRON 0 8 * * * Asia/Kolkata` (08:00 IST) | Standard Snowflake CRON + timezone. |
| **Database name** | `01_…setup.sql` — token `AI_USAGE_MONITORING` | `AI_USAGE_MONITORING` | Find-replace if you want a different DB. |
| `AI_CREDIT_PRICE_USD` | `CONFIG` table | `3.00` | Your $/credit for AI compute. |
| `AI_BUDGET_CREDITS` | `CONFIG` table | `100` | Monthly AI budget. **Set to `0` to hide the budget section.** |
| `BUDGET_WARN_PCT` | `CONFIG` table | `90` | `WARN` badge at ≥ this %; `OVER BUDGET` at ≥ 100%. |
| `TOP_N` | `CONFIG` table | `10` | Rows per breakdown before an "Others" row. |
| `EMAIL_SUBJECT_PREFIX` | `CONFIG` table | `Snowflake AI Usage` | Subject prefix. |

Everything in the `CONFIG` table can be changed **without redeploying** — just
`UPDATE` the row (see `02_verify_and_test.sql`).

---

## Changing the schedule

The schedule lives on the task (a CRON literal). To change it after deploy:

```sql
ALTER TASK AI_USAGE_MONITORING.NOTIFICATIONS.TSK_DAILY_AI_USAGE_EMAIL SUSPEND;
ALTER TASK AI_USAGE_MONITORING.NOTIFICATIONS.TSK_DAILY_AI_USAGE_EMAIL
  SET SCHEDULE = 'USING CRON 0 9 * * 1-5 America/New_York';   -- 9 AM ET, weekdays
ALTER TASK AI_USAGE_MONITORING.NOTIFICATIONS.TSK_DAILY_AI_USAGE_EMAIL RESUME;
```

CRON is `minute hour day-of-month month day-of-week timezone`. Examples:
`0 8 * * * Asia/Kolkata` (08:00 IST daily) · `30 7 * * 1-5 Europe/London`
(07:30 London, weekdays) · `0 0 1 * * UTC` (midnight UTC on the 1st).

---

## Adding / changing recipients

A recipient must be in **both** the integration's `ALLOWED_RECIPIENTS` and the
`EMAIL_RECIPIENT` config value:

```sql
ALTER NOTIFICATION INTEGRATION AI_USAGE_EMAIL_INT
  SET ALLOWED_RECIPIENTS = ('ops@example.com', 'lead@example.com');
UPDATE AI_USAGE_MONITORING.NOTIFICATIONS.CONFIG
  SET VALUE = 'ops@example.com' WHERE KEY = 'EMAIL_RECIPIENT';
```

To email a non-user address, verify it first:
`SELECT SYSTEM$SEND_EMAIL(...)` will fail until the address is verified via
**Snowsight → your profile → Notifications**, or it belongs to an account user.

---

## Verify & test

`02_verify_and_test.sql` includes:
- a row-count / total sanity check on the view,
- MTD credits by service,
- the current config,
- **preview** (`CALL …(FALSE)` returns the HTML — save to a `.html` file and open it),
- **send a test** (`CALL …(TRUE)`),
- task status + last 7 days of task runs.

---

## Customizing

The procedure is plain SQL — easy to extend. Ideas:
- Add a **day-over-day delta** column to the headline table.
- Add **per-user sub-tables** (each user's split by service/model).
- Swap the flat `AI_CREDIT_PRICE_USD` for a live rate from
  `SNOWFLAKE.ORGANIZATION_USAGE.RATE_SHEET_DAILY` (needs org-level access).
- Add a **cost-center** dimension if you tag roles/users and join the tags.

---

## Teardown

`03_teardown.sql` removes everything (suspends + drops the task, drops the
database — which cascades the schema/view/config/proc/functions — and drops the
integration).

---

## Notes & gotchas

- **Latency:** `ACCOUNT_USAGE` lags up to ~2–3h. Running for "yesterday (UTC)"
  in the morning is well within that window.
- **`USER_NAME` for AI Functions:** the AI-functions view exposes `USER_ID`, not
  a name; the view resolves it via `ACCOUNT_USAGE.USERS`. Cortex
  Agents/Code/Intelligence carry `USER_NAME` directly.
- **Model vs. agent:** only **AI Functions** report the underlying LLM model
  (e.g. `claude-4-sonnet`). **Cortex Agents** and **Snowflake Intelligence**
  report the *agent/app* name (not the model), and **Cortex Code** reports
  neither. The view keeps these in separate columns (`MODEL_NAME`, `AGENT_NAME`)
  and the email's "By model / agent" table tags each row with a **Type**
  (Model / Agent / Service) so an agent is never mistaken for a model.
- **Legacy Cortex functions** (`CORTEX_FUNCTIONS_QUERY_USAGE_HISTORY`) are
  intentionally omitted to avoid GA/legacy double counting on migrated accounts;
  add a `UNION ALL` branch if you still need them.
- **Least privilege:** for a hardened setup, replace `ACCOUNTADMIN` with a
  purpose-built role granted only `IMPORTED PRIVILEGES` on `SNOWFLAKE`,
  `CREATE INTEGRATION`, `EXECUTE TASK`, and ownership of the framework database.

---

## Files

| File | Purpose |
|---|---|
| `01_ai_usage_email_setup.sql` | One-shot setup: infra + view + config + proc + integration + task. |
| `02_verify_and_test.sql` | Sanity checks, preview, send a test, inspect task runs. |
| `03_teardown.sql` | Remove everything. |
| `sample_email_redacted.png` | Screenshot of a real run (user emails redacted) — for docs / the article. |
| `sample_email_redacted.html` | The same sample as standalone HTML (open in a browser). |
