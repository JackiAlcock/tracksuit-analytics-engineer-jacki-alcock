with

source as (

    select * from {{ source('raw', 'hubspot_companies') }}

),

renamed as (

    select
        company_id,
        trim(company_name) as company_name,
        size_grouped,
        industry,
        country,
        nullif(trim(merged_object_ids), '') as merged_object_ids,
        created_at::date as created_at

    from source

)

select * from renamed
