with

source as (

    select * from {{ source('raw', 'subskribe_subscriptions') }}

),

renamed as (

    select
        subscription_id,
        account_id,
        upper(subscription_state) as subscription_state,
        start_date::date as start_date,
        end_date::date as end_date,
        nullif(cancelled_date, '')::date as cancelled_date,
        nullif(renewed_from_subscription_id, '') as renewed_from_subscription_id,
        creation_time::timestamp as creation_time,
        updated_at::timestamp as updated_at

    from source

)

select * from renamed
