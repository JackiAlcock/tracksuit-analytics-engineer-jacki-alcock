-- Monthly Gross Revenue Retention by customer size segment, for the last
-- 12 months of data.
--
-- GRR for month M = revenue at M from the cohort of customers paying at
-- M-12, divided by that cohort's revenue at M-12. The cohort is fixed at
-- M-12 (customers acquired after M-12 never enter it), and retained
-- revenue is capped at each customer's M-12 amount so expansion can't
-- inflate the metric — that cap is what makes it "gross" rather than net.

with

customer_months as (

    select * from {{ ref('fct_customer_month') }}

),

months as (

    select distinct activity_month from customer_months

),

max_month as (

    select max(activity_month) as latest_month from months

),

reporting_months as (

    -- the last 12 calendar months of data we actually have
    select months.activity_month as report_month
    from months, max_month
    where
        months.activity_month > max_month.latest_month - interval '12 months'
        and months.activity_month <= max_month.latest_month

),

cohort_base as (

    -- the cohort for month M is whoever was an active, paying customer
    -- exactly 12 months earlier, at M-12
    select
        reporting_months.report_month,
        customer_months.customer_id,
        customer_months.size_grouped,
        customer_months.revenue_nzd as cohort_revenue_nzd

    from reporting_months
    inner join customer_months
        on
            customer_months.activity_month = reporting_months.report_month - interval '12 months'
            and customer_months.is_active
            and customer_months.revenue_nzd > 0

),

current_period_revenue as (

    select
        cohort_base.report_month,
        cohort_base.customer_id,
        cohort_base.size_grouped,
        cohort_base.cohort_revenue_nzd,
        -- cap retained revenue at the cohort-month amount: expansion within
        -- the cohort doesn't count towards GRR
        least(
            coalesce(current_month.revenue_nzd, 0),
            cohort_base.cohort_revenue_nzd
        ) as retained_revenue_nzd

    from cohort_base
    left join customer_months as current_month
        on
            cohort_base.customer_id = current_month.customer_id
            and cohort_base.report_month = current_month.activity_month

),

grr_by_segment as (

    select
        report_month,
        size_grouped,
        sum(cohort_revenue_nzd) as cohort_revenue_nzd,
        sum(retained_revenue_nzd) as retained_revenue_nzd,
        round(
            100.0 * sum(retained_revenue_nzd) / nullif(sum(cohort_revenue_nzd), 0),
            1
        ) as gross_revenue_retention_pct,
        {{ surrogate_key(['report_month', 'size_grouped']) }} as report_month_segment_id

    from current_period_revenue
    group by 1, 2

)

select * from grr_by_segment
order by 1, 2
