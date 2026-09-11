-- Singular test: GRR is a gross metric, so retained revenue is deliberately
-- capped at each cohort's M-12 revenue (expansion is excluded — see
-- rpt_grr_monthly.sql and SUBMISSION.md). If retained_revenue_nzd ever
-- exceeds cohort_revenue_nzd for the same segment/month, that cap has been
-- broken somewhere upstream. dbt fails this test if the query below
-- returns any rows.

select *
from {{ ref('rpt_grr_monthly') }}
where retained_revenue_nzd > cohort_revenue_nzd
