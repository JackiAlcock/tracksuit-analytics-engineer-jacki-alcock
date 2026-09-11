with

source as (

    select * from {{ source('raw', 'subskribe_accounts') }}

),

renamed as (

    select
        account_id,
        trim(company_name) as company_name,
        crmid,
        upper(currency) as currency,
        created_at::date as created_at

    from source

)

select * from renamed
