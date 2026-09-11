<!--
DRAFT — review and rewrite this in your own words before submitting.
This captures the assumptions baked into the scaffolded models so far;
it is not a finished submission. Update it as you build out/change the
models, run dbt build yourself, and add anything this draft misses.
-->

# Submission notes

## How to run

```bash
python3 -m venv .venv
.venv\Scripts\activate      # source .venv/bin/activate on macOS/Linux
pip install -r requirements.txt
python load_raw_data.py
dbt build
```

`rpt_grr_monthly` (in `models/marts/reporting/`) is the reporting model —
after `dbt build`, query it directly in DuckDB to see monthly GRR by
segment for the last 12 months.

## Project structure

- `models/staging/` — 1:1 typed cleanup of the four raw sources, no business logic.
- `models/intermediate/` — entity resolution (`int_company_id_map`,
  `int_accounts_resolved`), renewal-chain collapsing
  (`int_subscriptions_chained`), and monthly revenue derivation
  (`int_invoices_monthly`, `int_customer_months`).
- `models/marts/core/` — the dimensional model: `dim_customers`,
  `fct_subscriptions` (contract grain), `fct_customer_month` (the headline
  monthly snapshot, reusable beyond GRR).
- `models/marts/reporting/` — `rpt_grr_monthly`, built on `fct_customer_month`.

## Key assumptions and metric definition calls

- **Revenue basis.** There's no MRR/contract-value field anywhere in the
  raw data — invoices are the only dollar figures available. Each invoice
  is attributed to the calendar month of `invoice_date` and summed in
  `total_nzd`. This is reasonable because billing is close to monthly for
  almost every subscription (most have ~13 invoices across a ~12-month
  term); it would need revisiting if a customer were billed annually
  upfront.
- **Invoice status.** `VOIDED` invoices are excluded (they're reversed, not
  real billed revenue). `PAID` and `POSTED` are both counted — GRR here is
  treated as a billed/accrual metric, not a cash-collected one. [Confirm
  this is the right call for your definition, or restrict to `PAID` if you
  decide GRR should reflect cash collected.]
- **Renewal continuity.** Subscriptions renew into a new `subscription_id`
  rather than the original persisting (208/330 rows have
  `renewed_from_subscription_id` set). `int_subscriptions_chained` walks
  each chain back to a root so a multi-year customer relationship isn't
  mistaken for repeated "new" and "churned" customers at every renewal
  anniversary.
- **Entity resolution.** Subskribe `crmid` doesn't always match a HubSpot
  `company_id` directly — some reference companies since merged in HubSpot
  (resolved via `merged_object_ids`), and 2 accounts in the current dataset
  reference a `crmid` that never resolves. Those 2 are kept, not dropped,
  with segment `Unknown`, so total revenue still reconciles to the full
  book even though they can't be segmented.
- **Dimension type.** `dim_customers` is a Type 1 (current-state) dimension
  — the raw data gives no history of segment changes over time, so there's
  nothing to version. If HubSpot started tracking segment changes, this
  would need to become Type 2.
- **Cohort/GRR mechanics.** Cohort for month M = customers with active,
  paying revenue at M-12. Retained revenue at M is capped at the M-12
  amount per customer (expansion excluded) — this is what makes it gross
  rather than net. Customers acquired after M-12 are excluded from the
  cohort by construction (the join to M-12 revenue simply won't match
  them).

## Data quality issues found

- 33 of 122 Subskribe accounts have a `company_name` that differs from
  their resolved HubSpot company's name — not a problem as long as joins
  use `crmid`/`company_id`, not name, but worth flagging since the raw data
  invites name-based joining.
- 2 accounts have a `crmid` that doesn't resolve to any HubSpot company
  even after following merges (`Wrenfield Brewing`, `Riverbend Co`) —
  handled as above.
- Raw data is loaded as all-`VARCHAR`; all typing/casting happens in
  staging.

## What I'd do differently in production

[This is a take-home, not production — add a short note here on anything
you'd handle differently at Tracksuit scale: e.g. incremental
materialization for `fct_customer_month` instead of a full rebuild, a
proper SCD2 dimension once segment history exists, alerting on
`is_unresolved_company` counts, package-managed tests via dbt_utils, etc.]

- Unit tests for complicated logic.
- Stakeholder sign-off on metrics definitions and data quality issues handling
- Semantic layer for all common metrics
- Incremental materialisation for all wide and long models
- More sepcific linting conventionos enforced on commits
- PR templates with checklists for pre-review steps (eg requiring evidence of a fulll run and regression testing)
- SCD2 dimension modelling for all events-based source data
