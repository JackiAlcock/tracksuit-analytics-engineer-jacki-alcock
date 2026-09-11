<!--
DRAFT — this lists the meaningful prompts from the Claude session used to
build this project, in the order they happened. It's deliberately generous
(includes some setup/tooling prompts alongside the ones that shaped real
modelling decisions) — trim whatever you don't think is worth keeping,
tighten the wording to your own voice, and add anything from later sessions
that isn't captured here yet.
-->

# AI prompts used

Tool: Claude (Cowork), working directly against the cloned repo on my machine via a
device connection — Claude could read/write files in the repo folder directly, run
shell commands in its own sandbox (not on my machine), and read raw data files itself
rather than working only from descriptions of them.

## Getting set up

1. **"help me get setup for this technical test on my windows machine. give me clear
   simple instructions 1 at a time"** — walked through Python install, creating/
   activating a venv (`.venv\Scripts\activate`), fixing a PowerShell execution-policy
   block (`Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`),
   `pip install -r requirements.txt`, `python load_raw_data.py`, and a first
   `dbt build` to confirm the project was wired up correctly before doing any real
   work.

## Deciding on an approach

2. **"tell me what you think my options are?"** — asked before committing to a
   structure. Claude inspected the actual raw CSVs directly (not just the README's
   description of them) and surfaced things the brief doesn't spell out: there's no
   MRR/contract-value field anywhere, only invoices to derive revenue from;
   subscriptions renew into a brand new `subscription_id` each term
   (`renewed_from_subscription_id` chains) rather than the original persisting; ~10%
   of Subskribe accounts don't resolve straight to a HubSpot company (some via
   `merged_object_ids`, 2 not at all); and multi-currency is already handled via
   `total_nzd`. This is what shaped the decision to build a hybrid model — normalised
   staging/intermediate layers fixing those specific problems, feeding a denormalised
   monthly snapshot mart (`fct_customer_month`) — rather than a pure Kimball star or a
   single flattened GRR query.

3. **"what are the latest best practices recommended by dbt?"** (asked mid-turn,
   during the same conversation) — checked against dbt Labs' current published style
   guide rather than relying on possibly-stale training knowledge: staging/
   intermediate/marts layering, entity-grained marts, denormalise but break out
   intermediate models past ~4-5 joined concepts. Used to decide the folder structure
   and where entity-resolution/renewal-chain logic should live (intermediate) versus
   the marts themselves.

4. **"yes"** (to scaffolding the project based on the above) — had Claude generate the
   actual staging/intermediate/marts SQL and schema YAML, including a recursive CTE to
   collapse subscription renewal chains and the cohort-join-with-cap logic for GRR.

## Enforcing house SQL style

5. **"lets use more descriptive table aliases with at least 2 characters"** — Claude
   found and fixed the only two single-letter aliases in the project (`s`/`c` in the
   recursive renewal-chain CTE, `t` on an `unnest`), confirmed everything else already
   referenced CTEs by full name rather than aliasing.

6. **"does the sql dialect support casting using ::?"** — verification question before
   picking a style; confirmed DuckDB supports Postgres-style `::` casting as an exact
   equivalent to `CAST(x AS type)`, and that the project was inconsistently mixing both
   styles (which would trip SQLFluff's `convention.casting_style` rule).

7. **"I prefer :: let's enforce across the project"** — converted all `CAST(x AS type)`
   usages (5 in staging, 1 in `int_customer_months.sql`) to `::`, matching the one spot
   that already used it.

8. **"i think later versions of dbt use 'data_tests'. can you verify that?"** —
   verified against dbt's docs: `data_tests:` replaced `tests:` in YAML when unit tests
   were introduced in dbt-core 1.8; `tests:` still works for backward compatibility but
   isn't the current syntax.

9. **"yes please. can you check everything else is also latest version best
   practice?"** — converted all `tests:` keys to `data_tests:` across the four schema
   YAML files, and separately checked the whole project (materialization config,
   `config-version: 2`, generic test names) against the actual installed
   `dbt-core==1.12.4` and its changelog, rather than assuming. Nothing else was out of
   date.

10. **"i personally prefer the fct and dim prefixes. let's leave them"** — confirmed
    decision to keep `fct_`/`dim_` naming rather than switch to dbt Labs' newer
    plain-entity-name convention (discussed as an open style choice back in prompt 3).

## Testing

11. **"do i need to have core models for each test? isn't that native dbt test
    functionality?"** — clarified that `unique`/`not_null`/`accepted_values`/
    `relationships` are dbt's built-in generic tests, declared in YAML with no SQL
    file needed; a `.sql` file under `tests/` is only for bespoke singular tests.

12. **"yes, let's include that"** — added a singular test
    (`tests/assert_grr_retention_capped.sql`, later renamed — see next) asserting
    `retained_revenue_nzd` never exceeds `cohort_revenue_nzd` in `rpt_grr_monthly`,
    since that invariant (the expansion cap) isn't covered by any generic test.

13. **"oooft. can we call it something more succinct?"** — renamed the test file from
    `assert_grr_retained_revenue_not_greater_than_cohort_revenue.sql` to
    `assert_grr_retention_capped.sql`. Claude can't delete files on my machine (only
    read/write), so I deleted the old one myself once the new one landed.

## Formatting preferences

14. **"i hate the extra whitespace to align column aliases. can we remove all the
    compound spaces?"** — stripped the padding used to vertically align `as alias`
    across 10 files, leaving standard single spaces and untouched 4-space indentation.

15. **"Instead of `with ctename as (` ... I prefer `with` / blank line / `ctename as
    (`"** — reformatted the opening `with` clause of every model (13 files, including
    the `with recursive` case) to match.

16. **"what about the marts models?"** followed by **"i really don't [see the
    change]. can you check again?"** — turned out to be a stale VS Code buffer, not a
    real gap; Claude re-fetched the live files from disk to confirm the change had
    actually landed correctly.

## Validation tooling (not project code)

17. **"can you show me a lineage diagram?"** — a Mermaid DAG of the project
    (sources → staging → intermediate → marts/core → marts/reporting), plus a pointer
    to `dbt docs generate && dbt docs serve` for the real interactive/column-level
    version.

18. **"can I query this data using an ide like datagrip?" / "where do i add the file
    path?"** — walked through connecting DataGrip to `tracksuit.duckdb` via its
    built-in DuckDB driver, including the DuckDB single-writer-lock gotcha (DataGrip
    and a running `dbt build` can't hold a write lock on the file at the same time).

## Refactoring for repetition

19. **"is there anythying repetitive here that a macro might address?"** — Claude
    grepped the actual codebase rather than guessing, and found `date_trunc('month',
    ...)` repeated 4 times across 2 files (genuinely worth a macro — added
    `macros/month_start.sql` and swapped all 4 call sites) versus two weaker
    candidates it deliberately left alone: `nullif(x, '')` (3 occurrences, but each is
    a single short call — a macro would just relocate the logic, not simplify it) and
    the GRR safe-divide-to-percentage pattern (only 1 occurrence today, so macro-ing
    it now would be abstracting ahead of actual need, even though it's likely to
    recur if more reporting models get added later).

## Considering (and rejecting) a Semantic Layer

20. **"can we add the reporting metrics as a semantic layer?"** — Claude researched
    dbt's Semantic Layer/MetricFlow rather than assuming it would just work: confirmed
    it's technically usable against a local DuckDB file (via `dbt-metricflow` +
    `mf query`, not one of dbt's officially-listed platforms but a working community
    pattern), but found a real correctness problem — MetricFlow's derived/offset
    metrics combine already-aggregated values, so they can't cap an individual
    customer's retained revenue at their own M-12 amount *before* summing by segment,
    which is exactly what GRR's definition requires. Capping the aggregate instead of
    each customer would silently produce a different, wrong number. Given that, and
    that the brief weights 80% of assessment to the dimensional model (not tooling),
    I chose to skip it for GRR specifically rather than build an incorrect or
    over-engineered version — documented as its own section in `SUBMISSION.md` (“Why
    GRR isn't in the dbt Semantic Layer”) rather than silently dropping the idea.

## Adding build checks / CI

21. **"should we add build checks? particularly linting using sqlfluff?"** — rather
    than just wiring up a `.sqlfluff` config on faith, Claude built a full working copy
    of the project in its own sandbox (raw CSVs, `load_raw_data.py`, all models/macros/
    tests) and actually ran `dbt build` and `sqlfluff lint` end to end — the first real
    execution of the whole project, not just a compile check. That run surfaced (and
    fixed) something unrelated to SQLFluff too: 6 generic tests (`accepted_values`,
    `relationships`) were using the pre-1.10.5 flat-argument YAML style, which now
    throws a deprecation warning and needed nesting under `arguments:`. SQLFluff itself
    then flagged 15 auto-fixable issues (fixed via `sqlfluff fix`, hand-diffed
    afterwards to confirm nothing but whitespace and equality-side ordering changed)
    and 5 that needed a manual call: an unaliased expression in the recursive CTE,
    three genuinely ambiguous unqualified column references in `rpt_grr_monthly`
    (two tables in scope, so `activity_month` alone was a real risk, not just a lint
    nitpick), and a `GROUP BY`/`ORDER BY` addressing-style mismatch. One rule
    (`structure.column_order`) was deliberately turned off rather than obeyed, since it
    wanted staging models to reorder columns away from the source table's own column
    order — documented as a comment in `.sqlfluff` rather than silently applied. Added
    `sqlfluff`/`sqlfluff-templater-dbt` to `requirements.txt` (pinned to the exact
    4.3.0 actually tested against, not a guess) and a GitHub Actions workflow
    (`.github/workflows/ci.yml`) running `dbt build` + `sqlfluff lint` on every push/PR
    — though Claude couldn't write that specific file itself (workflow files are
    blocked from remote/automated writes as a safety measure on the device bridge it
    was using), so I added it by hand from the content Claude gave me.

27. **"are there any other build checks I've missed?"** followed by **"I thought about
    unit tests but figured the small data sets and relatively straightforward logic
    didn't warrant any for this task. Go ahead with the concrete gaps though"** — Claude
    audited the actual current YAML/CI config (not a generic checklist) and found two
    real, low-cost gaps rather than proposing a long wishlist: `relationships`/`not_null`
    tests were applied consistently in staging but inconsistently above it — missing
    entirely on `stg_subskribe__invoices.account_id` and `int_subscriptions_chained
    .account_id`, and present as `not_null`-only (no `relationships`) on
    `int_customer_months.account_id`, `fct_subscriptions.customer_id`, and
    `fct_customer_month.customer_id`. Added the missing tests (49 → 56 data tests,
    all passing). Separately proposed adding `macros/` to the CI SQLFluff lint scope,
    but actually tested it first and found SQLFluff's dbt templater can't lint macro
    files at all — it has no compiled-SQL node for a macro to check, so it just skips
    the file with a warning; SQLFluff's own docs recommend excluding `macros/` outright.
    So instead of a lint-scope change, added a `.sqlfluffignore` to make that exclusion
    explicit rather than an unexplained warning on every run. dbt unit tests (native
    `unit_tests:`, testing transformation logic against synthetic fixtures rather than
    the real data) were raised as an option for the trickiest logic — the recursive
    renewal-chain collapse and the GRR cap — but I judged the dataset size and logic
    complexity here didn't justify the extra fixture-writing effort for this task.

## What I verified myself / changed

    At this point I compiled the code and reviewed in datagrip.
    In production I'd probably have either real data or a validated query and at this 
    stage I would run regression testing.
    In this case I ran some sample queries to manually verify expected values in the 
    `rpt_grr_monthly` model.
    I ran a sample of data from each model to confirm data types looked correct and 
    values seemed sensible. 
    I specifically checked the recursive model `int_subscriptions_chained` as I know
    from experience this is the least intuitive code to write and the most likely to
    cause unexpected results, but I was happy with Claude's output.
