with

source as (

    select * from {{ source('raw', 'subskribe_invoices') }}

),

renamed as (

    select
        invoice_id,
        account_id,
        subscription_id,
        invoice_date::date as invoice_date,
        total::decimal(18, 2) as total,
        total_nzd::decimal(18, 2) as total_nzd,
        upper(currency) as currency,
        upper(status) as status

    from source

)

select * from renamed
