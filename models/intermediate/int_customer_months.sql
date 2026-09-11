-- The core building block for the dimensional model: one row per customer
-- (account) per calendar month they were under an in-force subscription,
-- with that month's billed revenue attached. This is what lets the mart
-- answer "what did our book of business look like as of any given month",
-- not just today, and is what the GRR reporting model cohorts against.

with

subscriptions as (

    select * from {{ ref('int_subscriptions_chained') }}

),

monthly_revenue as (

    select * from {{ ref('int_invoices_monthly') }}

),

-- expand each subscription into one row per month it was in force, capped
-- at the current month so we never project un-invoiced future contract
-- months as if they'd already happened. Relies on DuckDB's implicit lateral
-- join: generate_series can reference the preceding table's columns here.
subscription_months as (

    select
        subscriptions.subscription_id,
        subscriptions.account_id,
        month_series.activity_month::date as activity_month

    from subscriptions,
        generate_series(
            {{ month_start('subscriptions.start_date') }},
            least(
                {{ month_start('coalesce(subscriptions.cancelled_date, subscriptions.end_date)') }},
                {{ month_start('current_date') }}
            ),
            interval '1 month'
        ) as month_series (activity_month)

),

subscription_months_with_revenue as (

    select
        subscription_months.subscription_id,
        subscription_months.account_id,
        subscription_months.activity_month,
        coalesce(monthly_revenue.revenue_nzd, 0) as revenue_nzd

    from subscription_months
    left join monthly_revenue
        on
            subscription_months.subscription_id = monthly_revenue.subscription_id
            and subscription_months.activity_month = monthly_revenue.invoice_month

),

-- roll up to (account_id, month) rather than (subscription_id, month) so a
-- customer with more than one concurrent or chained subscription in the
-- same month still produces exactly one row — this is what fct_customer_month
-- relies on for its grain.
customer_months as (

    select
        account_id,
        activity_month,
        sum(revenue_nzd) as revenue_nzd,
        true as is_active

    from subscription_months_with_revenue
    group by 1, 2

)

select * from customer_months
