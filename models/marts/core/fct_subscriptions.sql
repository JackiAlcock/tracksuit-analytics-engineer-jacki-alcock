-- Subscription-contract grain: one row per subscription term, tagged with
-- the resolved customer_id and its position in the renewal chain. Kept
-- separate from the monthly snapshot below so contract-level questions
-- (e.g. "when did this customer last renew") don't require unpicking a
-- monthly grain.

with

subscriptions as (

    select * from {{ ref('int_subscriptions_chained') }}

),

customers as (

    select
        account_id,
        customer_id
    from {{ ref('dim_customers') }}

)

select
    subscriptions.subscription_id,
    subscriptions.root_subscription_id,
    customers.customer_id,
    subscriptions.account_id,
    subscriptions.subscription_state,
    subscriptions.start_date,
    subscriptions.end_date,
    subscriptions.cancelled_date,
    subscriptions.renewed_from_subscription_id,
    subscriptions.chain_position

from subscriptions
inner join customers
    on subscriptions.account_id = customers.account_id
