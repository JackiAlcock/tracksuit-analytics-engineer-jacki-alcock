-- THE dimensional model deliverable: one row per customer per calendar
-- month they were an active, paying subscriber, with their segment and
-- that month's revenue. Designed to answer "what did our subscription book
-- look like as of any given month" for any downstream use, not just GRR —
-- the reporting model below is just one consumer of this.

with

customer_months as (

    select * from {{ ref('int_customer_months') }}

),

customers as (

    select * from {{ ref('dim_customers') }}

),

final as (

    select
        customers.customer_id,
        customers.company_name,
        customers.size_grouped,
        customer_months.activity_month,
        customer_months.revenue_nzd,
        customer_months.is_active,
        customers.customer_id
        || '_'
        || strftime(customer_months.activity_month, '%Y-%m') as customer_month_id

    from customer_months
    inner join customers
        on customer_months.account_id = customers.account_id

)

select * from final
