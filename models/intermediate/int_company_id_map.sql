-- Maps every id a Subskribe account's crmid might reference — a current
-- HubSpot company_id, or a historical id that has since been merged into
-- one — onto the current, resolved company_id. Without this, ~10% of
-- accounts fail to join straight to hubspot_companies.

with

companies as (

    select * from {{ ref('stg_hubspot__companies') }}

),

-- every company resolves to itself
self_map as (

    select
        company_id as source_id,
        company_id as resolved_company_id

    from companies

),

-- each historical, merged-away id also resolves to the current company_id
merged_map as (

    select
        trim(old_id) as source_id,
        company_id as resolved_company_id

    from companies, unnest(string_split(merged_object_ids, ';')) as ids (old_id)

    where merged_object_ids is not null

),

combined as (

    select * from self_map
    union all
    select * from merged_map

)

select * from combined
group by all
