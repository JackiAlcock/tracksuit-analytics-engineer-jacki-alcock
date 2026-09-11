-- Subscriptions renew into a brand new subscription_id rather than the
-- original persisting (208 of 330 rows have renewed_from_subscription_id
-- set). This walks each chain back to its root so downstream models can
-- treat a multi-year renewal history as one continuous customer
-- relationship instead of a series of unrelated "new" contracts.

with recursive

subscriptions as (

    select * from {{ ref('stg_subskribe__subscriptions') }}

),

chain as (

    -- anchor: the first subscription in each chain
    select
        subscription_id,
        subscription_id as root_subscription_id,
        0 as chain_position

    from subscriptions
    where renewed_from_subscription_id is null

    union all

    -- recursive step: walk forward to whatever renewed from this one
    select
        sub.subscription_id,
        chn.root_subscription_id,
        chn.chain_position + 1

    from subscriptions as sub
    inner join chain as chn
        on sub.renewed_from_subscription_id = chn.subscription_id

)

select
    subscriptions.subscription_id,
    subscriptions.account_id,
    subscriptions.subscription_state,
    subscriptions.start_date,
    subscriptions.end_date,
    subscriptions.cancelled_date,
    subscriptions.renewed_from_subscription_id,
    chain.root_subscription_id,
    chain.chain_position

from subscriptions
inner join chain
    on subscriptions.subscription_id = chain.subscription_id
